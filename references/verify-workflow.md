# Lite Wearable 验证工作流（静态检查 / 模拟运行 / 模拟器实测）

> `node --check` 只能保证语法，`构建成功` 只能保证能打包 —— 两者都**证明不了页面能用**。
> 本文是「改完代码如何真正验证」的可复用流程，含一处**性价比极高**的手段：
> 用 node + mock 把每个页面的逻辑真跑一遍。

---

## 一、验证三层（从便宜到贵，逐层爬）

| 层 | 手段 | 能发现 | 耗时 |
|---|---|---|---|
| 1. 静态 | `node --check` + 结构校验 + 交叉一致性 | 语法错、标签/CSS 不配平、死绑定、死调用 | 秒级 |
| 2. 模拟运行 | node + mock 系统模块，跑每页方法 | `TypeError`、undefined 引用、死状态、回调时序 | 秒级 |
| 3. 真实 | 构建 + 快照自测 + 装模拟器/真机实测 | 体积超限、布局裁切、点击无效、跳转失败 | 分钟级 |

**原则：任何一层报错都先修掉再往下一层走**，不要在带病状态下构建。

---

## 二、第 1 层：静态检查

### 2.1 语法与结构

```bash
# JS 语法（注意：查不出"语法合法但引擎不支持"的正则 —— 那要靠第 2/3 层的引擎校验）
node --check pages/*/index.js
```

结构校验（自己写 20 行 Python 就够，不必依赖工具）：

- HML：`<div` 与 `</div>`、`<stack`/`<text`/`<swiper`/`<list` 等各自开闭数量配平；
- CSS：`{` 数 == `}` 数；**逐行深度追踪**，深度变负 = 孤儿 `}`；深度 > 0 到文件尾 = 缺 `}`；
- **孤儿属性行**：某行以 `xxx:` 开头却不在任何 `{}` 内（多由批量删 CSS 造成，会直接导致构建
  报 `missing '}'`）；
- JSON 配置：能被 `json.load` 解析、页面清单与页面目录**一一对应**。

### 2.2 交叉一致性（最能抓到「点了没反应」）

四个方向都要查：

```python
# ① HML 的 {{绑定}} 是否都在 JS 的 data/方法/模块变量里
binds = set(re.findall(r'\{\{\s*([A-Za-z_]\w*)\s*\}\}', hml))
missing = binds - data_fields - methods - module_vars

# ② HML 的 onclick/onchange 处理函数是否都有定义   ← 死绑定 = 按钮点了没反应
handlers = set(re.findall(r'on(?:click|change|swipe)\s*=\s*"(\w+)"', hml))
missing_h = handlers - methods

# ③ HML 用到的 class 是否都在本页 CSS 里定义
# ④ JS 里 this.xxx() 调用的方法是否都有定义        ← 死调用 = 运行时抛异常
calls = set(re.findall(r'this\.(\w+)\s*\(', js))
bad = calls - methods - {'fileApi', 'fetchApi', 'vibratorApi'}   # 后三个是懒初始化的模块句柄
```

> 注意 `list-item` 的 `for="{{$item.x}}"` 里 `$item`、`$idx` 是**作用域变量**，不是缺失绑定（误报要认识）。

---

## 三、第 2 层：node 模拟运行（性价比最高）

思路：**不让工程文件改动**，把页面 JS 复制到临时目录 → 把 ESM 转成 CJS → mock 掉
`@system.*` → 构造实例 → 遍历调用每个方法 → 捕获异常。

### 3.1 转换与 mock

```js
// run.cjs
const Module = require('module');
const orig = Module._load;
const FAKE_OK = { /* 接口返回的假数据，照真实结构造 */ };

Module._load = function (req) {
  if (req === '@system.fetch') return {
    fetch: function (o) {
      try { o.success({ data: JSON.stringify({ code: 0, data: FAKE_OK }) }); }   // 成功分支
      catch (e) {}
    }
  };
  if (req === '@system.file') return {
    readText: function (o) { try { o.fail && o.fail(); } catch (e) {} },          // 失败分支也要跑
    writeText: function () {}
  };
  if (req === '@system.router') return { replaceUrl: function () {}, replace: function () {} };
  if (req === '@system.device') return { getInfo: function (o) { try { o.success({ windowWidth: 466, windowHeight: 466 }); } catch (e) {} } };
  if (req === '@system.vibrator') return { vibrate: function () {} };
  if (req === '@system.storage') return { get: function (o) { try { o.fail && o.fail(); } catch (e) {} }, set: function () {} };
  if (req === '@system.prompt') return { showToast: function () {} };
  return orig.apply(this, arguments);
};

const page = require('./page.cjs');        // 页面文件里 export default 已替换成 module.exports
const def = page.default || page;
const inst = JSON.parse(JSON.stringify(def.data || {}));
for (const k of Object.keys(def)) {
  if (typeof def[k] === 'function') inst[k] = def[k].bind(inst);
}

// 生命周期
inst.onInit && inst.onInit();
inst.onShow && inst.onShow();

// 遍历所有方法，用多种入参各试一次
const ARGS = [undefined, 0, '', {}];
for (const k of Object.keys(def)) {
  if (typeof def[k] !== 'function') continue;
  for (const a of ARGS) {
    try { inst[k](a); } catch (e) { console.log('[异常]', k, e.constructor.name, e.message); }
  }
}
```

### 3.2 怎么判读结果（重要）

- **【异常】集中在某个方法** → 看它是否 UI 可达：
  - 如果是 `getJson/getJson 回调/内部 helper` 被强喂错类型（`cb` 不是函数等），
    属于**测试脚手架产物**，UI 到不了（HML 不会那样调）→ 记录但不算 bug；
  - 如果是**被 `onclick` 绑定的方法**抛异常 → **真 bug，必修**。
- **`this.xxx` 读到 undefined 但没抛** → 看是不是懒初始化（首次访问后建立的 `fileApi` 之类）→ 不算 bug。
- **断言真实流程更值钱**：喂真实结构的假数据，断言关键字段被正确填充
  （例：填完 `pt1` 应含年份与截断后的标题）。这类断言能把「回调里用错 `this`」
  这种静默 bug 直接钉死。

### 3.3 想要更强的验证：**让子代理独立做**

把这份体检工作**独立交给一个子代理**（不被主对话的上下文影响），给它：
- 工程路径与你已知的约束（lite 雷区清单）；
- 要求：**只读、不改任何源码**；用 node 真跑每页逻辑；输出结构化问题清单（含文件:行号 + 证据）；
- 要求它**给出可复现材料**（临时目录里的 mock/sim/断言脚本路径），便于你复核。

实测这种「独立质检」能找出主开发者视线盲区的 bug（典型：某个只在 fail 分支才暴露的
`this` 误用，跑一年也不会在正常路径上出现，但用户一遇到网络失败就永恒失效）。

---

## 四、第 3 层：模拟器实测

### 4.1 常用命令（hdc）

```bash
hdc list targets                                  # 设备列表（模拟器通常是 127.0.0.1:5555）
hdc -t 127.0.0.1:5555 shell aa start -b <bundle> -a <ability>    # 启动应用
hdc -t 127.0.0.1:5555 shell snapshot_display -f /data/local/tmp/a.jpeg   # 截图（必须是 .jpeg）
cd <本地目录> && hdc -t 127.0.0.1:5555 file recv /data/local/tmp/a.jpeg a.jpeg   # 取回
hdc -t 127.0.0.1:5555 shell uitest uiInput click X Y             # 注入点击
hdc -t 127.0.0.1:5555 shell uitest uiInput swipe X1 Y1 X2 Y2     # 注入滑动
```

**踩过的坑**：
- `file recv` 的**目标必须 cd 到本地目录只传文件名** —— 传 Windows 全路径会得到 0 字节文件；
- 截图命令打印 `I/O error ... i18n_param_config.xml: Permission denied` 是**无害噪音**，
  文件其实生成成功（用 `ls -l` 确认大小）；
- `aa start` 的 **ability 名要与设备里注册的一致**，不同构建可能不一样 →
  准备多个候选名轮流试，或先 `bm dump` 查；
- `uitest uiInput** 能注入 swipe（**实测可以把竖向 swiper 从第 1 屏推到第 4 屏**），
  但**表冠旋转没有对应注入手段**（表冠交互只能真机验）；
- 点击坐标要按**当前屏的实际布局**给，给错了会静默落空（截图复核最稳）。

### 4.2 模拟器 ≠ 真机（必须记住）

- 模拟器常见是 **rich 引擎**，真机是 **lite 引擎**：`@system.file`、表冠、图片解码、
  内存行为都可能不同 → **模拟器全绿 ≠ 真机可用**；
- 模拟器能有效验证的：**UI 布局/裁切、跳转链路、文案、数据渲染、按钮可点性**；
- 必须真机验的：**lite 专属能力、体积闸门后的真实加载、性能与内存**。

### 4.3 装机前先本地签名（让模拟器验证跑起来）

标准 HAP 可以本地自签（SDK 自带的签名工具 + 测试证书 + 一份 debug profile 模板，
bundle 名与设备 UDID 填进去即可），然后 `hdc install -r <signed.hap>`。
⚠️ **lite 单 bin 压缩包形式的 HAP，命令行签不了** —— 那种包只能在 IDE 里 Run。
所以：**模拟器验证用标准包，真机验证走 IDE**。

---

## 五、构建静默化（避免打扰用户）

后台执行构建命令时，Windows 上会**每次弹出一个控制台窗口**（跑几次就弹几次，非常扰民）。
两个措施一起用：

1. **用 Python `subprocess` + `CREATE_NO_WINDOW`（0x08000000）** 启动构建进程，输出走管道写日志；
2. **关掉工具链的「安全删除」钩子**：某些环境会给 node 注入删除保护 shim，
   它调用的回收站二进制一旦超时，构建就报 `00308018 Unknown Error` 之类的怪错。
   若该 shim 提供开关环境变量（拼写形如 `*_SAFE_DELETE_ENABLED=0`），构建前设上即可
   —— 删除走原生实现，既不弹窗也不再超时。

```python
env = dict(os.environ)
env['<TOOL>_SAFE_DELETE_ENABLED'] = '0'          # 关删除保护钩子（按你的环境名替换）
subprocess.run(cmd, cwd=workdir, env=env, capture_output=True,
               creationflags=0x08000000, timeout=900)
```

**纪律**：能前台跑就前台跑；必须后台时用上面的静默方式。
构建日志一律落盘（`--console=plain > build.log`），出问题看日志而不是指望看输出。

---

## 六、遇到「点不进去 / 打不开 / 黑屏」的排查顺序

**按这个顺序走，能省最多时间**：

1. **先跑快照自测**（`jerry-snapshot` 对页面产物）→ 排除体积闸门（占这类问题的多数）；
2. **再看是否页面不存在/未注册**（页面清单 vs 目录）；
3. **再用 node 模拟跑 onInit**→ 排除首屏时序/`this` 误用；
4. **再查交叉一致性** → 排除死绑定（按钮没绑上方法）；
5. **最后才怀疑路由/点击被吞**（这类最少见）。

**记录纪律**：每修一处，**立刻把第 1、2 层的检查重跑一遍**确认没有改坏别的地方
（改一处、查一轮），再进入下一处 —— 批量修完再查，出问题无法二分定位。

---

## 七、一句话速查

- 三层验证：**静态（秒级）→ node 模拟（秒级，性价比最高）→ 模拟器/真机（分钟级）**。
- 交叉一致性四查：**绑定 / 事件处理函数 / class / `this.xxx()` 调用**，缺一个都会产生「点了没反应」。
- node 模拟：mock `@system.*` + 遍历所有方法 × 多种入参；被 `onclick` 绑定的方法抛异常 = 真 bug。
- 模拟器：`snapshot_display` 截图 + `uitest uiInput click/swipe`；
  **`file recv` 必须 cd 到目录传文件名**；**swipe 能推 swiper，表冠不能**。
- **模拟器 ≠ 真机**（rich vs lite）：UI/跳转能验，体积/内存/文件能力必须真机。
- 后台构建：`CREATE_NO_WINDOW` + 关删除保护钩子 = 不弹窗不超时。
- 排查顺序：**快照 → 页面注册 → 首屏时序 → 死绑定 → 路由**；**改一处查一轮**。
