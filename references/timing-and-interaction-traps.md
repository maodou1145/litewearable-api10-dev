# 页面时序与交互陷阱（Lite Wearable 实战）

> 「点进去黑屏 / 卡死 / 按钮点了没反应」这类问题，**九成不是因为功能没写，而是因为时序和
> 交互写法踩了 lite 的坑**。本文按「症状 → 根因 → 正确写法」组织，全部来自真机复现。

---

## 一、时序三铁律（最常翻车的地方）

### 1.1 首屏渲染**永不等回调**

**症状**：某页点进去是**空白/只剩按钮**，或一直转圈，感觉「卡死」。

**根因**：把首屏显示的决定权交给了异步回调（读文件 / 网络）：

```js
// ❌ 错误：回调不触发 → enter() 永不执行 → 所有面板都不显示 → 页面看上去"卡死"
onInit: function () {
  var that = this;
  this.fileApi.readText({ uri: F, success: function (res) {
    that.pick = parse(res);
    that.enter();                 // ← 全部渲染都挂在这个回调里
  }});
}
```

lite 上**文件/网络回调「可能不触发」**（不同环境行为不一致），
所以把渲染挂在回调里 = 赌运气。

```js
// ✅ 正确：先同步渲染（默认值或路由参数），再异步覆盖
onInit: function () {
  if (!valid(this.pick)) { this.pick = 'default'; }   // 1) 同步定下首屏
  this.ensureFile();                                  // 2) 先初始化 fileApi
  this.enter();                                       // 3) 立刻渲染，不等任何人
  var that = this;
  try {                                               // 4) 异步兜底，成功了才覆盖
    this.fileApi.readText({ uri: F, success: function (res) {
      var v = parse(res);
      if (valid(v) && that.pick === 'default') { that.pick = v; that.enter(); }
    }, fail: function () {} });
  } catch (e) {}
}
```

### 1.2 `fileApi` / `fetchApi` 必须**先初始化**再用

**症状**：页面一进去就崩（白屏），或某方法一调就 `TypeError`。

**根因**：系统模块是懒加载的（`this.fileApi = require('@system.file')`），
如果初始化写在某个方法里，而另一条更早的路径直接用了它 → `this.fileApi` 还是 `null`。

```js
// ✅ 在 onInit 的最前面同步初始化，之后所有方法才能安全使用
onInit: function () {
  this.applyMetrics();
  this.ensureFile();     // @system.file
  this.ensureApi();      // @system.fetch（如页面会联网）
  this.enter();
  ...
}
```

> 习惯做法：`ensureFile/ensureApi` 返回布尔，调用方 `if (!this.ensureFile()) { return; }`，
> 让「模块不可用」变成可处理的失败路径，而不是崩溃。

### 1.3 回调内部**绝不能用 `this`**

**症状**：某屏数据永远出不来（一直「正在获取…」或「获取失败」），但**不报错到界面上**。

**根因**：在 `success: function (res) { ... }` 里写 `var that = this;` —— 那里的 `this`
不是页面实例。后面 `that.xxx()` 抛 `TypeError`，异常常被队列/框架的 try/catch 吞掉。

```js
// ❌
loadX: function () {
  this.getJson(url, function (ok, d) {
    var that2 = this;                    // ← 回调里的 this，不是实例
    that2.pt1 = row(d[0]);               // TypeError: that2.row is not a function
  });
}

// ✅
loadX: function () {
  var that = this;                       // 方法体第一层捕获
  this.getJson(url, function (ok, d) {
    that.pt1 = row(d[0]);                // 直接用闭包的 that
  });
}
```

**自查**：全局搜 `= this;`，凡出现在内层 `function` 里的都逐个核对。
另外**内层再嵌套一层函数**时也要小心：`var row = function (it) { ... that2.x ... }`
—— 这里的 `that2` 必须来自**最外层**。

---

## 二、交互写法陷阱

### 2.1 事件必须用**裸名** `onclick` / `onchange`

带前缀的写法（`grab:` / `on:` 之类）**不会注册**，点了毫无反应。
自查：布局树里该节点的 `click` 属性是 `false` 就是没注册上。

### 2.2 HML 的 `{{}}` 只能绑 **data 字段**，不能绑方法

**症状**：界面上显示空白，或显示 `undefined`。

```html
<!-- ❌ 想显示"下一个是什么"（方法名）→ 渲染不出来 -->
<text class="pill-t">{{switchLabel}}</text>

<!-- ✅ 做成 data 字段，在切换时更新它 -->
<text class="pill-t">{{switchLabelText}}</text>
```
```js
switchPanel: function () {
  this.pick = next(this.pick);
  this.switchLabelText = labelOf(this.pick);   // 同步更新派生字段
  this.enter();
}
```

### 2.3 `swiper` 的 `index="{{x}}"` 是**单向**的

改 `x` 只会改**页码显示**，**不会驱动 swiper 真的滚过去**。
所以「点按钮回到第 1 屏」这种交互在 lite 上做不了可靠实现（要走 `$refs` 的组件方法）。
务实做法：**不做这个按钮**，改用文字引导（「上下滑动可切换页面」）。

### 2.4 空 `<list>` 会渲染成黑框

列表数据还没到时，`<list>` 如果被渲染出来，视觉上就是一块黑框。**用 `if` 包住**：

```html
<list class="picker-list" if="{{isPick}}">     <!-- 数据模式才渲染 -->
  <list-item for="{{list}}" tid="id" onclick="pick($item.t)">
    <text class="picker-item-t">{{$item.t}}</text>
  </list-item>
</list>
```

⚠️ 本项目曾用 `show="{{...}}"` 控显隐，但工程其它页一律用 `if`。
**统一用 `if`**：语义明确、渲染与否可控，避免「属性存在但引擎不认」的不确定性。

### 2.5 `list-item` 的 click **没有 `index`**

`e.index` 是 `undefined`。要拿数据就**直接把值传进回调**（HML 事件支持传参）：

```html
<list-item onclick="pick($item.t)">   <!-- ✅ -->
```

### 2.6 页面内多按钮时，**不要再加整屏兜底点击**

有些页面为了「点击被吞」做了一层「点屏幕任意处触发主操作」的兜底。
**多按钮页面不要这么做**：会与按钮叠加触发（点一下执行两次、状态被重置）。

---

## 三、布局陷阱（导致「按钮点不到」「内容被裁」）

### 3.1 圆屏安全区（466 圆屏实测）

| 纵坐标 y | 可用宽度约 |
|---|---|
| 233（中线） | 466px |
| 380 | ~360px |
| 420 | ~278px |

**推论**：任何贴在屏幕底部（y > 400）的按钮，宽度必须收到 ~250px 以内，
否则两侧会被圆角裁掉 → **看得见但点不到**。

### 3.2 容器总高溢出 → 底部元素被裁

**症状**：底部按钮「露一半」「点不到」；或有内容但用户说"出不去"。

**根因**：外层容器固定高（如 466px），子项高度之和**超过**它，且用了 `justify-content: center`
→ 上下各越界一半，**最后一项落在圆屏最窄处**。

**自己算一遍**（别靠肉眼）：

```
子项高度合计 = 面板高 + 操作栏高 + 间距
若 > 容器高 → 必然溢出
操作栏底边 y = (容器高 - 合计)/2 + 面板高 + 操作栏高     ← 这个值要 < 400 才安全
```

修法：把**内容面板高度**调小（不要让它占满 466），给底部操作栏留位置。

### 3.3 `stack` 里子节点过多 / 根元素不唯一

- 页面根元素**只能有一个**（`stack` 或 `div`），其余全放它内部；
- `stack` 内平铺多个「面板 + 操作栏」时，**包一层 wrap 容器**更稳
  （避免工具把平铺的兄弟节点误判成多个根）。

### 3.4 布局一律用 flex，`position` 不存在

`position: absolute/relative` 在 lite 上**无效**（元素退化成文档流），
固定 `width` 的子元素会被甩到异常位置。层叠只能用 `stack`（声明顺序即层级）。

CSS 其它禁用项：伪类（`:hover`/`:nth-child`…）、子选择器 `>`、兄弟选择器、属性选择器、
`calc()`、`gap`；`class="{{x}}"` 数据绑定也会编译报错。
**同族元素差异样式一律用独立 class**（`.item-0` `.item-1`）。

---

## 四、复查清单（改完页面必看）

1. 页面上每个 `onclick` 的处理函数**都存在**（死绑定 = 点了没反应）；
2. 每个 `{{绑定}}` 都是 data 字段（不是方法名）；
3. `onInit` 里**没有任何「等回调再渲染」**的路径；
4. `fileApi`/`fetchApi` 在 onInit 开头就初始化了；
5. 内层函数里没有 `this`（只有闭包变量）；
6. 底部按钮的 y 坐标 < 400、宽度 < 250；
7. 容器子项高度合计 ≤ 容器高（算一遍）；
8. 空数据状态的 `<list>` 有 `if` 保护。

---

## 五、一句话速查

- **首屏永不等回调**；`ensureFile/ensureApi` 放在 onInit 最前；**内层函数只用闭包 `that`**。
- `{{}}` 只绑 data 字段；事件必须**裸名** `onclick`；`list-item` click 里没有 index，直接传值。
- `swiper` 的 `index` **单向**（改 data 不驱动滚动）；页内「回第一屏」按钮别做。
- 底部按钮要 **y < 400、宽 < 250**；容器子项总高必须 ≤ 容器高（自己算，别目测）。
- 一律 flex，没有 `position`；同族差异用独立 class，不用伪类。
