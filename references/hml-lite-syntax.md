# Lite Wearable HML 语法白名单

## 目录

- [判定原则](#判定原则)
- [内置标签](#内置标签)
- [公共属性与渲染指令](#公共属性与渲染指令)
- [标签专属属性](#标签专属属性)
- [事件](#事件)
- [父子结构](#父子结构)
- [HML 表达式](#hml-表达式)
- [控件数量不能由数据驱动](#控件数量不能由数据驱动)
- [AI 生成规则](#ai-生成规则)

## 判定原则

HML 不是 HTML，也不是 Vue、React JSX、ArkUI 或完整 OpenHarmony ArkUI。生成或修改 `.hml` 时只使用目标 SDK Lite 白名单中存在的标签、属性和事件。

本表依据：

- `<DevEco-SDK>/default/openharmony/js/build-tools/ace-loader/lib/templater/lite_component_map.js`
- 同目录 `component_validator.js`
- 华为官方 [ArkUI JS 完整组件参考](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkui-js-full-comp)
- 官方 Lite Wearable 开发文档的“HML语法参考”（需用户自行合法获取）

完整组件参考用于查询标签的完整属性、事件和用法，不是 Lite Wearable 白名单。若项目的 SDK 版本不同，先读取该 SDK 的同名文件并用它缩小范围。自定义组件标签需在项目中找到真实定义和注册，不能因“像组件名”或官方完整组件页中存在就放行。官方网页若因登录、地区或反爬限制无法读取，明确说明并使用本地 SDK，不得猜测。

## 内置标签

仅以下标签属于当前 SDK 的 Lite Wearable 内置白名单：

```text
div canvas stack qrcode list list-item swiper tabs tab-bar tab-content
image-animator image img progress text marquee analog-clock clock-hand
chart input slider switch picker-view
```

不要生成 Web 标签，如 `button`、`span`、`p`、`section`、`video`、`audio`、`svg`。Lite 按钮使用 `<input type="button">`。

## 公共属性与渲染指令

所有内置标签可用：

```text
id style class ref if elif else for tid show
```

也允许 `data-*`。约束如下：

- Lite 不支持 `class="{{...}}"` 动态绑定。使用固定类名，或在可验证范围内绑定具体 `style` 属性。
- 同一元素禁止同时设置 `if` 和 `for`。
- `if`、`elif`、`else` 必须是同一父节点下连续的兄弟节点；`elif`/`else` 不得脱离前序条件节点。
- `if`、`elif`、`show` 使用布尔值或 `{{...}}`；`if=false` 不构建节点，`show=false` 仍构建 VDOM。
- `for` 支持 `for="{{array}}"`、`for="{{value in array}}"`、`for="{{(index, value) in array}}"`，也支持文档中的不带花括号形式。
- `tid="id"` 是数组元素唯一字段名，不支持表达式。每个元素必须存在该字段并保持唯一。
- 页面 `data` 属性名不能以 `$` 或 `_` 开头，不要使用保留名 `for`、`if`、`show`、`tid`。

## 标签专属属性

除公共属性和 `data-*` 外，当前 SDK 白名单如下：

| 标签 | 专属属性与限制 |
|---|---|
| `qrcode` | 必需 `value`；`type=rect|circle` |
| `swiper` | `index` 数字；`loop=true|false`；`duration` 数字；`vertical=false|true` |
| `tab-bar` | `mode=fixed` |
| `image-animator` | 必需 `images`、`duration`；`iteration`；`reverse=false|true`；`fixedsize=true|false`；`fillmode=none|forwards` |
| `image` / `img` | `src` |
| `progress` | `type=horizontal|arc`；`percent` 数字 |
| `text` | `type=text|html`；`value` |
| `marquee` | `scrollamount` 数字 |
| `analog-clock` | `hour`、`min`、`sec` 数字 |
| `clock-hand` | `type=hour|min|sec`；`src` |
| `chart` | `type=line|bar`；`datasets`；`options` |
| `input` | `checked=true|false`；`type=button|checkbox|password|radio|text`；`name`、`value`、`placeholder`；`maxlength` 数字 |
| `slider` | `min`、`max`、`value` 数字 |
| `switch` | `checked=true|false` |
| `picker-view` | `type=text|time`；`range`；`selected` |

`div`、`canvas`、`stack`、`list`、`list-item`、`tabs`、`tab-content` 没有额外 HML 属性白名单。样式必须放在 `class`/`style` 或样式文件中，不能把浏览器属性猜测为可用。

## 事件

公共事件：

```text
click longpress touchstart touchmove touchcancel touchend key swipe
```

专属事件：

- `list`: `scrollend`
- `swiper`: `change`
- `tabs`: `change`
- `image-animator`: `stop`
- `input`: `change`
- `slider`: `change`
- `switch`: `change`
- `qrcode`: 仅 `click`、`longpress`、`swipe`
- `picker-view`: 仅 `change`

绑定形式包括 `@click`、`onclick`、`on:click`、`grab:click`，以及 SDK 接受的 `.bubble`/`.capture` 修饰。事件冒泡机制从 API 5 开始；面向更低 API 时不得依赖它。回调名和传参必须使用 HML 表达式可接受的 ES5 形式，不能在属性中写箭头函数。

## 父子结构

- `list` 的直接组件子节点只能是 `list-item`；`list-item` 的直接父节点必须是 `list`，且不能作为页面根。
- `swiper` 不支持包含 `list`。
- `tabs` 的直接组件子节点只能是 `tab-bar`、`tab-content`。
- `tab-bar` 的直接组件子节点只能是 `text`，且直接父节点必须是 `tabs`。
- `tab-content` 的直接组件子节点只能是 `div`、`stack`，且直接父节点必须是 `tabs`。
- `clock-hand` 的直接父节点必须是 `analog-clock`。
- `list-item`、带 `if`、带 `for` 或带 `else` 的组件不能作为页面根节点。
- 原子组件不能包含组件子节点。`text` 只承载文本内容；不要在其中嵌套其他组件。

## HML 表达式

开发文档明确规定：HML 中的 JS 表达式不支持 ES6。即使页面 `.js` 文件支持部分 ES6，也不能在 `{{...}}`、事件参数、`if`、`show`、属性绑定中使用：

- 箭头函数、`let`/`const`、`class`
- 模板字符串
- 解构、默认参数、剩余参数、展开语法
- `for...of`、模块声明
- `async/await`、生成器
- 可选链、空值合并、动态 `import()`

保持表达式短小：属性读取、数组索引、基础算术/比较/逻辑运算和简单方法调用。复杂计算、数组转换、格式化和容错逻辑放到 `.js` 方法或预先计算的 `data` 字段中。

```html
<!-- 允许 -->
<text if="{{visible}}">{{items[index].name}}</text>
<input type="button" value="放大" @click="multiply(2)"></input>

<!-- 禁止：箭头函数和模板字符串都属于 HML 中的 ES6 -->
<text>{{items.map(item => `${item.name}`).join(',')}}</text>
```

## 控件数量不能由数据驱动

Lite 的 HML 可以用 `list` + `list-item` + `for` 渲染**行数不定**的同构列表，但**没有"对任意元素按数据生成 N 个控件"的能力**（不存在通用 `v-for`）。实践中三条路：

| 做法 | 适用 | 说明 |
|---|---|---|
| **固定槽位 + `if` 控制显示** | 维度少且上限明确（如品类筛选按钮最多 5 个） | 写死最大条数的控件，用 `if="{{ncat > 0}}"` / `if="{{ncat > 1}}"` … 逐槽决定显隐；文案同样预先在 JS 里算好填进 `t1..t5`（表达式里不能调 JS 函数） |
| **展开写死（unroll）** | 网格、固定格子（如 5×5 背包 = 25 格） | 每个槽一个独立 data 字段（`c0..c24` / `s0..s24`），HML 里逐条写出 |
| **`list` + `list-item` + `for`** | 长列表、每行结构相同 | 见「父子结构」一节 |

> 🔴 **动态下标只能打在「已声明的」data 字段上**：先 `data: { c0:'#000', c1:'#000', … }` 显式声明，运行时再 `this['c' + i] = v` —— 实测可行且会触发重渲染。对**未声明**的 key 赋值不会被 MVVM 观察到，界面不更新也不报错（静默失效，极难排查）。

## AI 生成规则

1. 先从本页白名单选择标签，再查专属属性和事件；不确定即停止猜测并查当前 SDK。
2. 生成后运行 `scripts/audit_lite_watch_project.ps1`，再以 DevEco 的真实编译错误为准修正。
3. 审计脚本的未知标签可能是自定义组件；只有找到组件实现和注册后才能确认。
4. 不通过删除事件前缀、改成 Web 标签或把逻辑塞进内联表达式来绕过编译器。
5. 对 SDK 版本差异、事件语义和自定义扩展明确标为待构建/真机验证。

## 🔴 页面对象的方法名：避开保留字（含 `render`）

页面对象（`export default { ... }`）上**不要定义**这些名字：

| 保留名 | 说明 |
|---|---|
| `onInit` / `onReady` / `onShow` / `onHide` / `onDestroy` | 生命周期钩子 |
| **`render`** | **lite 内部的渲染入口**，同名方法会被吞掉 |

**`render` 的症状极具迷惑性**：调用处抛 `TypeError: Expected a function`，
而该函数**前面**的赋值（如 `this.phase = 'x'`）**已经生效** ——
于是**界面切过去了、但这个函数里的渲染全都没执行**，看起来像"数据没更新"而不是"报错"。

> 实测：`pick()` 里调 `this.render()` 把容器外的格子涂暗，异常导致画布 12 格
> 全部停留在 `data` 的初始色。**改名为 `paint` 即解决。**

**排查口诀**：`grep -a "JS Error" previewer.log | tail` —— 这类错误语法检查一律抓不到。

## 🔴 页面空白但无报错 → 先查 CSS 高度

lite 的 `list-item`、滚动容器、flex 子项只要**高度塌成 0 就静默不显示**：
**没有 JS 异常、没有布局告警**，只有一片空白。

- `list-item` **必须给固定 `height`**（只有 `width` 不够）。
- 里面的 `<text>` 也建议给同高，避免行高塌陷。
- 排查法：把 HML 里用到的 class 逐个回到 CSS 里对，
  缺 `height` 的就是元凶；日志里查不到任何东西时尤其要往这想。

> 实测：about 页 `.ali`（list-item）与 `.aline`（text）只有 width 没有 height，
> 整页只剩标题和返回按钮，日志干净得像没问题。

## ✅ 列表正确写法（来自逆向成品工程，**已实测可用**）

> **教训先行**：上面那些"点了没反应 / 只渲染 1 个"的坑，我试了三轮都没试对。
> 最后是去翻 **逆向出来的成品工程** `/g/_reverse/xxjzs/out/hml/musical.hml` 才找到正解。
> **lite 的疑难杂症，先翻已有项目和逆向产物，别自己瞎试。**

**正确写法**（原文照抄，注释是我加的）：

```html
<list class="list">
  <list-item class="list_item" style="height: {{listItemHeight}}px;">
    <text style="font-size: 38px;">乐器</text>
    <div style="width: 406px; display: flex; flex-wrap: wrap; height: {{itemHeight}}px;">
      <div class="box center" onclick="selectMusical($item)" for="{{musicalList}}">
        <text class="item_text">{{$item.cnName}}</text>
      </div>
    </div>
  </list-item>
</list>
```

**四个关键点，缺一不可**：

| 点 | 正确 | 错误（我试过的） |
|---|---|---|
| 循环变量名 | **`$item`**（内置名） | `it`（自定义名，**不生效**） |
| `for` 语法 | **`for="{{数组}}"`** | `for="{{it in 数组}}"` |
| `for` 挂在哪 | **`list-item` 内部的普通 `div`** | 挂在 `list-item` 自己身上 |
| 点击传参 | **`onclick="fn($item)"`** 传整个对象 | `onclick="fn(it.i)"` |

**配套 JS**：把数据组织成**对象数组**（不是二维数组），字段名与 `$item.xxx` 对应。

```js
buildList: function () {
  var arr = [];
  for (var i = 0; i < b.length; i++) {
    arr.push({ i: i, n: b[i][0], d: b[i][1] + '×' + b[i][2] });
  }
  this.boxes = arr;               // 整个数组一次性赋值（数组本身是显式属性名）
},
pick: function (item) {           // item 就是 $item
  var k = item.i | 0;
}
```

**这样写的好处**：
- **`list` 可正常滚动**（不必自己分页）
- **点击可靠**
- 数据整体替换一次赋值，**绕开了"动态 key 不被追踪"的问题**

## 🔴 **动态 key 赋值不被 MVVM 追踪**（界面"纹丝不动"的头号原因）

**实测三种写法全部失败**（点击被系统收到、无任何 JS 报错、回调不执行）：

| 写法 | 结果 |
|---|---|
| `<list-item onclick="f(it.i)">` | ✗ 回调不执行 |
| `<list-item>` 内嵌 `<div onclick="f(it.i)">` | ✗ 回调同样不执行 |
| `<div for="{{it in rows}}" onclick="f(it.i)">` | ✗ `for` 在普通 div 上也不生效，只渲染 1 个 |

**唯一可靠的方案：不用 `list`，手写固定数量的普通 `div`。**

```html
<div class="bl" if="{{phase === 'pick'}}">
  <div class="br" onclick="pick(0)"><text>{{n0}}</text></div>
  <div class="br" onclick="pick(1)"><text>{{n1}}</text></div>
  <!-- …固定 N 个，onclick 传常量 -->
</div>
<div class="pg">
  <div class="pb" onclick="prevPg">‹</div><text>{{pgText}}</text><div class="pb" onclick="nextPg">›</div>
</div>
```

JS 侧维护 `o0..oN` 映射"页内序号 → 真实下标"：

```js
buildList: function () {
  for (var i = 0; i < PG; i++) {
    var k = pg * PG + i;
    this['n' + i] = k < b.length ? b[k][0] : '';
    this['o' + i] = k < b.length ? k : -1;
  }
  this.pgText = (pg + 1) + ' / ' + (Math.ceil(b.length / PG));
},
pick: function (i) { var k = this['o' + i]; if (k < 0) return; /* … */ }
```

**代价**：牺牲滚动，超过一屏的数据必须自己分页。
**选型建议**：
- 列表项**需要点击** → 普通 `div` + 分页（本页方案）
- 列表项**只需展示、不需点击** → 用 `list`（可滚动，性能也好）

**判断口诀**：lite 里"点了没反应 + 无报错 + 点击日志正常" → **先怀疑 `list-item`，直接换 `div`。**

## 🔴 **动态 key 赋值不被 MVVM 追踪**（界面"纹丝不动"的头号原因）

```js
this.pgText = x;          // ✓ 显式属性名 —— MVVM 追踪得到，界面更新
this['n' + i] = x;        // ✗ 动态 key  —— 追踪不到，界面完全不动
```

**这条最难查，因为它的行为是「半好半坏」**：

| 时机 | 动态 key 表现 |
|---|---|
| **首次渲染**（节点刚构建，如 `onShow` 里一次性铺数据） | **能生效**（渲染时直接读当前值，不依赖观察者） |
| **增量更新**（事件回调里改数据，如翻页 / 点击后刷新） | **完全不生效**，界面纹丝不动，**且没有任何报错** |

**实测**：分页列表第 1 页正常、翻到第 4 页整片空白，**但同一函数里写的 `this.pgText` 却正常更新** ——
这个"一半更新一半不动"的现象就是它的指纹。

**修法**：把循环展开成显式赋值。

```js
// ✗ 不行
for (var i = 0; i < 5; i++) { this['n' + i] = ...; }

// ✓ 正确：逐行写死属性名
x = o < b.length ? b[o] : null;
this.n0 = x ? x[0] : '';
this.d0 = x ? ... : '';
this.o0 = x ? o : -1;
// …n1/d1/o1 … n4/d4/o4
```

**在写页面时就要注意**：凡是**事件回调里会变**的数据字段，
**一律用 `this.xxx` 显式赋值，坚决不用 `this['prefix' + i]`**。
（首屏一次性铺的数据可以放宽，但为统一起见建议全部显式。）

## 🔴 列表项点击**不要依赖 `for` 循环变量**

实测两个写法**都不行**：

| 写法 | 结果 |
|---|---|
| `<list-item for="{{it in rows}}" onclick="f(it.i)">` | 点击被系统收到，但回调不执行，**无报错** |
| `<div for="{{it in rows}}" onclick="f(it.i)">` | **`for` 在普通 `div` 上不生效，只渲染 1 个** |

**可行写法：手写固定数量的 `list-item`，`onclick` 传常量**，再用分页切换数据：

```html
<list class="bl" style="height:{{listH}}px;">
  <list-item class="bi"><div class="br" onclick="pick(0)"><text>{{n0}}</text></div></list-item>
  <list-item class="bi"><div class="br" onclick="pick(1)"><text>{{n1}}</text></div></list-item>
  <!-- …固定 5 个，onclick 传 0..4 常量 -->
</list>
<div class="pg">
  <div class="pb" onclick="prevPg">‹</div>
  <text>{{pgText}}</text>
  <div class="pb" onclick="nextPg">›</div>
</div>
```

JS 侧维护 `o0..o4` 存"页内序号 → 真实下标"的映射：

```js
buildList: function () {
  for (var i = 0; i < PG; i++) {
    var k = pg * PG + i;
    this['n' + i] = k < b.length ? b[k][0] : '';
    this['o' + i] = k < b.length ? k : -1;
  }
},
pick: function (i) { var k = this['o' + i]; if (k < 0) return; /* … */ }
```

> 代价：HML 要写死份数（本例 5 个），数据超过一屏就得分页。
> 但这是 lite 上**唯一实测可用**的列表点击方案。

---

## 🔴 **兄弟节点中间的 `if` 会中断后续兄弟渲染**（真机实测，2026-10）

**症状**：页面"少了一半" —— 某个 `if` 之后的所有兄弟节点**完全不渲染**，
**没有任何报错、没有布局告警**，日志干净。

**复现**（index 页）：
```html
<div class="page">
  <text class="title">三角洲开箱</text>
  <text class="sub">搜容器 · 摸物资 · 拾取结算</text>
  <text class="rec" if="{{rec !== ''}}">{{rec}}</text>   <!-- ← 元凶 -->
  <div class="btn main" onclick="start">…开始开箱…</div>
  <div class="btn" onclick="goCodex">…物品图鉴…</div>     <!-- ✗ 不渲染 -->
  <div class="btn" onclick="goAbout">…玩法说明…</div>     <!-- ✗ 不渲染 -->
  <text class="foot">物品数据 · 三角洲行动</text>          <!-- ✗ 不渲染 -->
</div>
```
实测只有 `title / sub / rec / 开始开箱` 出来了，**后两个按钮和 foot 全部消失**。

**修法**：把 `if` 从兄弟链中间拿掉 —— 让它永远渲染（空串也无妨），
或把带 `if` 的节点挪到**兄弟链的最前 / 最后**。

```html
<text class="rec">{{rec}}</text>    <!-- ✅ 去掉 if，rec 为空就显示空行 -->
```

**排查口诀**：页面元素"成片消失"且**无报错** → 先检查兄弟链中间有没有 `if`。

---

## ✅ 编译期内联数据（绕开 rawfile 读取问题）

**症状**：`@system.file` 读 `internal://app/rawfile/...` 返回 `code=301`（文件不存在），
但 hap 里资源确实在 `assets/entry/resources/rawfile/...`。
（标准 hap 包结构下 lite 的 `internal://app/rawfile` 前缀不成立。）

**修法**：**放弃运行时读文件，改为编译期生成 JS 数据模块**。
- 用 Python 生成 `common/db.js`（`export var ITEMS=[…]; export var BOXES=[…];`）
- `data.js` 只做 `import` + 展开成并行数组，**同步、零异步**
- 好处：首屏立即渲染（符合"永不等回调"）、无 IO 失败路径、真机/预览器行为一致
- 代价：单页产物变大（注意 48KB 上限），需要控制内联数据量

