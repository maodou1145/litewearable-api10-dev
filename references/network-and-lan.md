# Lite Wearable 网络请求与局域网通信（API 10 实战沉淀）

> 适用范围：Lite Wearable / HarmonyOS FA（JS/HML）工程，手表端需要联网取数据、
> 或需要与同网段的手机/PC 做**局域网直连**时。所有结论均来自真机 + 模拟器实操，
> 括号里的时间戳是踩坑时间。

---

## 一、@system.fetch 基础与坑

### 1.1 最小可用封装（JSON 容错 + 人话错误）

```js
ensureApi: function () {
  if (this.fetchApi) { return true; }
  try { this.fetchApi = require('@system.fetch'); } catch (e) { this.fetchApi = null; }
  return !!this.fetchApi;
},

getJson: function (url, cb) {
  if (!this.ensureApi()) { cb(false, '联网模块不可用'); return; }
  try {
    this.fetchApi.fetch({
      url: url,
      method: 'GET',
      header: { 'Accept': 'application/json' },
      success: function (res) {
        var raw = res ? res.data : null;
        var obj = null;
        if (raw && typeof raw === 'object') { obj = raw; }          // 有些实现直接给对象
        else { try { obj = JSON.parse(String(raw)); } catch (e) { obj = null; } }
        if (obj) { cb(true, obj); } else { cb(false, '返回体解析失败'); }
      },
      fail: function (res, code) { cb(false, '网络失败(' + code + ')'); }
    });
  } catch (e) { cb(false, '请求异常'); }
},
```

要点：
- **`fail` 的 code 一定要透出**。`code === 0` 基本等价于「根本没连上」（DNS/网段/端口/服务没起），
  不是 HTTP 状态码。分不清 `0` 和 `4xx` 会让排查方向完全跑偏。
- **HTTP 状态码在 `success` 里**（`res.code`），业务错误码在返回体里 —— 两层都要判。
- `JSON.parse` 必须包 try/catch：lite 上返回体偶尔是空串/半截。

### 1.2 并发请求会把小内存设备打爆 → 串行队列

页面里同时发多个请求（尤其刷新时一次拉好几个接口）容易出现：请求丢回调、页面卡住、
甚至整页重渲染失败。做法是**串行化**：

```js
fetchQueued: function (options) {
  if (!this.q) { this.q = []; this.qRunning = false; }
  this.q.push(options);
  if (this.qRunning) { return; }
  this.pumpQueue();
},

pumpQueue: function () {
  var that = this;
  this.qRunning = true;
  var next = this.q.shift();
  if (!next) { this.qRunning = false; return; }
  var done = false;
  var finish = function () {
    if (done) { return; }
    done = true;
    try { setTimeout(function () { that.pumpQueue(); }, 30); }   // 让出事件循环，别嵌套太深
    catch (e) { that.qRunning = false; }
  };
  try {
    next.success = (function (orig) {
      return function (r) { try { orig(r); } catch (e) {} finish(); };
    })(next.success || function () {});
    next.fail = (function (orig) {
      return function (a, b) { try { orig(a, b); } catch (e) {} finish(); };
    })(next.fail || function () {});
    this.fetchApi.fetch(next);
  } catch (e) { finish(); }
},
```

- 队列里**每个请求的 success/fail 都必须调到 `finish()`**，否则队列死锁（后续请求永不发出）。
- ⚠️ **`this` 陷阱（真机上表现为「某屏永远是"获取失败"」）**：
  在 `fetch` 的 **success 回调内部**写 `var that = this;` 是**错的** —— 那里 `this`
  不是页面实例，后面 `that.xxx()` 直接 `TypeError`，而且异常常被队列的 try/catch 吞掉，
  只表现为「数据永远不出来」。

  ```js
  // ❌ 错误：回调里的 this 不是页面实例
  loadX: function () {
    var that = this;                       // 方法体第一层的 this 才对
    this.fetchApi.fetch({ url: u, success: function (res) {
      var that2 = this;                    // ← 这里的 this 是 undefined/回调上下文
      that2.fill(res);                     // TypeError: that2.fill is not a function
    }});
  }

  // ✅ 正确：用外层闭包捕获的 that
  loadX: function () {
    var that = this;
    this.fetchApi.fetch({ url: u, success: function (res) {
      that.fill(res);                      // 直接复用外层 that
    }});
  }
  ```

  自查方法：全局搜 `= this;`，凡出现在 `function (...) {` **内层**的都是嫌疑。真机日志里
  搜 `TypeError: xxx is not a function` 也能定位。

---

## 二、局域网通信（手表 ⇄ 同网段手机/电脑）

### 2.1 可行性与前提

- **手表端用 `fetch` 访问 `http://<局域网IP>:<port>/...` 明文可用**（无需 https，无需特殊权限，
  只要工程声明了 `ohos.permission.INTERNET`）。
- 前提是**两端在同一网段**：手机开热点让手表连、或都连同一个路由器。
- 端口建议选 **8000~9000 区间的冷门端口**，并做好「连不上」的兜底。

### 2.2 铁律一：地址绝不写死，且默认值必须为空

这是最容易犯、最难自查的错：**调试期为了图快塞了一个默认 IP**，忘了删，
上线后手表拿着一个不存在的地址去请求 → `code=0` → 用户看到「连不上」。

```js
/* ✅ 正确姿势：常量只留端口，地址从「用户可改的持久化配置」里读，读不到就为空 */
var LAN_PORT = 8123;
var LAN_HOST_DEFAULT = '';                 // 默认必须为空字符串！
var FILE_HOST = 'internal://app/lan_host.txt';

readHost: function (cb) {
  var that = this;
  try {
    this.fileApi.readText({
      uri: FILE_HOST,
      success: function (res) {
        var t = '';
        if (res) {
          if (typeof res.text === 'string') { t = res.text; }
          else if (typeof res === 'string') { t = res; }
        }
        cb(trimAll(t) || LAN_HOST_DEFAULT);       // 空 → 空，不要 fallback 成某个 IP
      },
      fail: function () { cb(LAN_HOST_DEFAULT); }
    });
  } catch (e) { cb(LAN_HOST_DEFAULT); }
},

doFetchLan: function () {
  var that = this;
  this.readHost(function (host) {
    if (!host) {                                   // ✅ 没配置 → 不发请求，直接引导用户
      that.isFailed = true;
      that.title = '先在「改地址」里填手机上显示的 IP';
      return;
    }
    that.fetchUrl('http://' + host + ':' + LAN_PORT + '/token.json');
  });
},
```

### 2.3 铁律二：失败不要自动退出，要留在当前页给出口

「失败 900ms 后自动返回首页」看似友好，实际让用户完全看不到错误、也不知道能怎么办。
正确做法：**成功才自动返回；失败停在原页**，并提供「改地址 / 重试 / 返回」三个按钮。

```html
<!-- 失败时才出现的两个出口 -->
<div class="picker-back" onclick="editHost" if="{{isFetch}}">
  <text class="picker-back-t">改地址</text>
</div>
<div class="picker-back" onclick="retryFetch" if="{{isFailed}}">
  <text class="picker-back-t">重试</text>
</div>
```

```js
endFetch: function (msg) {
  this.title = msg;
  if (msg.indexOf('成功') < 0) {          // 失败：停留，可改地址可重试
    this.isFailed = true;
    return;
  }
  var that = this;
  try { setTimeout(function () { that.back(); }, 900); } catch (e) { this.back(); }
},
```

### 2.4 铁律三：地址输入要能在手表上完成（别假设用户会连电脑改）

手表上让用户输 IP 的可行做法：**复用键盘页加一个 `ip` 模式**（只收数字与点号、
数字键盘锁定到含数字那一页、进页时预填当前地址方便改末段），校验规则：
长度 ≥ 7 且至少 2 个点（`192.168.1.5` 这种）才算合法。

---

## 三、页面间传参：路由 params 优先，文件仅兜底

### 3.1 异步写文件的时序陷阱

`@system.file.writeText` 是 **fire-and-forget**（回调经常不触发），
所以「**写文件 → 立即跳页 → 目标页读文件**」这条链**一定有竞态**：
目标页读到的往往是**上一次的旧值**。

症状：入口有多个按钮（A/B/C），**点哪个进去都显示 A**（因为读到的是旧值/默认值）。

```js
// ❌ 只靠文件：目标页经常读到旧值
writeText({ uri: FILE_MODE, text: kind });
router.replaceUrl({ uri: 'pages/more/index' });

// ✅ 路由 params 优先（同步、可靠）
try {
  r.replaceUrl({ uri: 'pages/xxx/index', params: { pick: kind } });
} catch (e) {
  r.replace({ uri: 'pages/xxx/index', params: { pick: kind } });
}
// 文件照写，作为兜底（目标页 params 缺失时才采用）
```

### 3.2 目标页的正确读法

```js
data: {
  pick: 'word',        // ← 与 params 键同名，路由参数会（同步）覆盖它
  ...
},

onInit: function () {
  // 1) 先用 params（或默认值）**同步**定下首屏 —— 绝不阻塞在回调上
  if (this.pick !== 'word' && this.pick !== 'hist' && this.pick !== 'brief') { this.pick = 'word'; }
  this.ensureFile();     // ⚠️ fileApi 必须在任何用到它的方法之前初始化
  this.enter();

  // 2) 再异步读文件兜底：只在「params 没带」时才采用，避免旧值覆盖路由参数
  var that = this;
  if (this.ensureFile()) {
    try {
      this.fileApi.readText({ uri: FILE_MODE,
        success: function (res) {
          var t = trimAll(res && res.text ? res.text : res);
          if ((t === 'hist' || t === 'brief') && that.pick === 'word') {
            that.pick = t;
            that.enter();
          }
        },
        fail: function () {}
      });
    } catch (e) {}
  }
},
```

**核心原则：首屏渲染永不等回调。** 文件/网络回调在 lite 上「可能不触发」，
把它放在渲染路径上 = 页面永远空白（观感就是「点进去卡死/黑屏」）。

### 3.3 ensureFile 要提前到 enter 之前

`fileApi` 是懒初始化的：如果 `enter()` → `loadX()` → 内部直接 `this.fileApi.readText(...)`，
而此时 `fileApi` 还是 `null`，就抛 `TypeError`，整页崩。

```js
onInit: function () {
  this.applyMetrics();
  this.ensureFile();       // ✅ 先同步初始化 fileApi
  this.enter();            // 再渲染 / 加载
  ...
}
```

---

## 四、lite JS 里做网络相关处理的硬限制

| 想做的事 | lite 的替代写法 |
|---|---|
| `encodeURIComponent` | **不存在**。手写 UTF-8 逐字节 `%XX` 编码（含中文） |
| `atob` / `btoa` | **不存在**。手写 base64 解码成字节数组 |
| `str.replace(/re/g, x)` | **不支持正则字面量**（真机直接整页黑屏）。用 `split().join()` 或 `charAt` 循环 |
| `String.replace` 全局替换 | 只替换第一个。要全替换就用 `split(sep).join('')` |
| `Array.map/filter/reduce` | 可不用就不用；一律 `for` 循环最稳 |
| 大响应体直接 `JSON.parse` | 先判长度/首字符，避免解析半截数据 |

自查手段：把编译产物丢给 **真机同款 JS 引擎**做一次 `--parse-only`
（工程若已有体检脚本就直接用），或 `node --check` 只查语法、**查不出正则问题**
（正则语法合法但引擎不支持），必须用真机引擎跑。

---

## 五、可复用的排查顺序（联网类问题）

1. **先分清是「没发出去」还是「发了但失败」**：在点击处理里加一句 toast/标题反馈
   （如「正在打开…」），用户一眼就能回报卡在哪一步。
2. **看 `fail` 的 code**：`0` = 连不上（网段/端口/服务未启动/地址错）；
   有值 = HTTP 层错误。
3. **本地同网段用电脑先验证服务**：`curl http://<IP>:<端口>/xxx` 能通再让手表试，
   避免在手表上盲调。
4. **地址类问题优先怀疑「配置没生效/读到旧值」**：把读到的地址**显示到界面上**
   （调试期），比任何日志都直接。
5. **失败路径必须有出口**：改地址 + 重试 + 返回，三选一不能让用户无路可走。

---

## 六、一句话速查

- fetch 的 `fail(code)`：`code=0` 就是「连不上」，别当 HTTP 状态码。
- 回调里**永远不要用 `this`**，用方法体第一层的 `that`。
- 局域网地址**默认值留空**，没配置就引导用户去填，不要拿假地址去撞。
- 失败**不要自动退出**，留在页面给「改地址/重试/返回」。
- 跨页传参 **params 优先、文件兜底**；首屏渲染**永不等回调**。
- `fileApi` 要在 `enter()` 之前 `ensureFile()`。
