# 页面拆分与重构方法论（Lite Wearable 实战）

> 当某个页面逼近体积红线（见 `size-budget-and-snapshot.md`）、或一屏功能与页面其余部分
> 关系很弱时，**把整屏搬成独立页**是收益最大的瘦身手段。本文是三次实操沉淀的完整流程，
> 含**拆完必做但极易漏掉**的一步（屏索引常量同步，漏了会出现「某屏按钮点不动」这种鬼 bug）。

---

## 一、判断要不要拆

拆屏的收益与代价：

| 收益 | 代价 |
|---|---|
| 主页面 -4~8KB、**-20~30 个编译函数**（HML 的 if/绑定/组件都会编译成函数） | 多一个页面文件（3 件套）要维护 |
| 该屏内容后续可以随便加，不再挤主页面预算 | 多一次路由跳转（lite 路由会重建页面，状态不保留） |
| 主页面回归「一眼可见」的定位，观感更清楚 | 需要处理返回、传参 |

**适合拆的信号**：某屏是大段「内容展示 + 双视图（列表⇄详情）」、且与主页面其它屏无状态耦合。

---

## 二、拆屏完整流程（7 步）

### Step 0 — 先摸清「谁在调用它」

在动手之前，把要搬走的方法/字段的**所有调用点**列出来（含**切屏/自动刷新**这类间接调用）：

```bash
grep -n "loadX\|fillX\|openXDetail\|xBack\|X_PAGES\|X_API" main/index.js main/index.hml
```

最容易漏的是**「按当前屏索引自动加载」的那段逻辑**（切屏时调 `this.loadX(false)`）。
搬走后要把它一起删掉或改成无操作，否则会留死调用。

### Step 1 — 建新页三件套

新页面 = `index.js` + `index.hml` + `index.css`。**每页的 CSS 是独立的**，
所以新页必须**自带基础样式**（根容器 / 标题 / 按钮 / 文本），不能引用别页的 CSS。

新页 JS 需要自带基础设施（这些不能省）：
`applyMetrics`（读设备尺寸）、`ensureFile`、`ensureApi`、`getJson`、`vibrate`、`toast`、`go`/`back`。

⚠️ **易错点**：`getJson` 的实现如果是「串行队列版」，它内部会调用 `this.fetchQueued(...)`。
只搬 `getJson` 不搬队列方法 → 运行时 `TypeError`。要么一起搬，要么把新页的 `getJson`
改成**直接 fetch**（单请求场景不需要队列）。

### Step 2 — 代码提取（用深度匹配，别用「截到下一个大括号」）

**JS 方法**：按「大括号配平」抽取完整块：

```python
def extract_method(src, name):
    m = re.search(r'\n  %s: function' % re.escape(name), src)
    if not m: return None
    start = m.start() + 1
    k = src.find('{', m.end() - 8)
    depth, i = 0, k
    while i < len(src):
        if src[i] == '{': depth += 1
        elif src[i] == '}':
            depth -= 1
            if depth == 0: break
        i += 1
    end = i + 1
    if end < len(src) and src[end] == ',': end += 1   # 连同结尾逗号
    return src[start:end]
```

**HML 屏**：同样用**标签深度匹配**（`<div` 与 `</div>` 配平），**绝不能**简单
`text[:text.rindex('</div>')]` —— 屏内含嵌套 div 时会多剥/少剥一层。

**CSS 类删除**：⚠️ **绝不要用 `\.ClassName \{[^}]*\}` 这种正则批量删** ——
`[^}]*` 会**跨块**吃掉后面的内容（实测把下一节的属性行留下、把闭合 `}` 带走，
最后表现为构建报 `missing '}'`）。正确做法：**深度匹配**取整块；
改完立刻校验 `{` 数 == `}` 数，并用**逐行深度追踪**定位孤儿括号：

```python
depth = 0
for i, l in enumerate(css.split('\n'), 1):
    depth += l.count('{') - l.count('}')
    if depth < 0:
        print('孤儿 } 在第 %d 行: %r' % (i, l.strip()[:40])); depth = 0
```

> 顺带一个更隐蔽的坑：用 `grep -A N` 从旧版本捞一段 CSS 回来时，
> **grep 的分隔符 `--` 会被一起写进文件**，污染结果。要么用 Python 精确截取，要么事后核验。

### Step 3 — 依赖扫描（搬之前先算清要带什么）

把要搬的方法体拼起来，扫出它们引用的 `this.xxx`，减去「本组方法」与「本页 data 字段」，
剩下的就是**额外要带走的**：

```python
refs = set(re.findall(r'this\.([A-Za-z_]\w*)', bodies))
need = refs - set(moved_methods) - set(data_fields)   # 逐个确认：是方法？是字段？还是懒初始化？
```

经验上需要额外带走的通常是：`ensureFile` / `ensureApi` / `getJson` / `vibrate` / `toast` /
`dayIndex`（日期索引）/ `refreshXxx`（派生字段刷新）等。

### Step 4 — 落地新页并注册

- 新页目录必须**真实存在**（否则构建会静默失败，报「编译未产出目录」这种不指向根因的错）。
- 路由表（页面清单）里**加上新页路径**；同时确认**页面目录与清单一一对应**
  （清单里有但目录没有 = 构建失败；目录有但清单没有 = 页面进不去）。

### Step 5 — 入口：改主页面那一屏

把原屏整块换成**「入口屏」**：标题 + 一行说明 + 若干按钮。
按钮各自的处理函数**按参数分派**（入口要区分进哪个子内容时，见 Step 6）。

### Step 6 — 传参：路由 params 优先，文件兜底
lite 的 `writeText` 是 fire-and-forget，「写文件 → 跳页 → 目标页读文件」**必有竞态**
（症状：哪个入口进去都显示同一个内容）。正确做法：

```js
// 入口侧
try { r.replaceUrl({ uri: 'pages/target/index', params: { pick: kind } }); return; } catch (e) {}
try { r.replace({ uri: 'pages/target/index', params: { pick: kind } }); } catch (e) {}

// 目标页：data 里放同名字段（params 会覆盖它），onInit 同步决定首屏，再异步读文件兜底
data: { pick: 'word', ... },
onInit: function () {
  if (this.pick !== 'word' && this.pick !== 'hist' && this.pick !== 'brief') { this.pick = 'word'; }
  this.ensureFile();       // ⚠️ 必须在 enter() 之前
  this.enter();
  // 异步读文件：仅当 params 没带（还是默认值）时才采用，避免旧值覆盖路由参数
}
```

### Step 7 — 屏索引常量同步 🔴（最容易漏，症状极怪）

**如果你拆掉/合并了「屏」，主页面所有按屏索引判断的逻辑都会错位。**典型症状：

- 某一屏的按钮**点了没反应**（走进了给别的屏准备的分支）；
- 页码显示不对（如 8 屏的页面显示 `5/10`）；
- 切到某屏时加载了**已经搬走**的数据（死调用被 try/catch 吞掉，静默无数据）。

**必须同步的三处**：
1. **屏索引常量**（`P_XXX = N`）：按 HML 里屏的**真实顺序**重新编号；
2. **总屏数常量**（`PAGE_TOTAL`）；
3. **页码初值**（data 里写死的 `'1/10'` 之类）。

**拆/合屏后的自检**：
```bash
grep -c 'class="screen"' main/index.hml      # 实际屏数
grep -n '^var P_' main/index.js              # 常量定义：应连续且与上面一致
grep -n 'PAGE_TOTAL' main/index.js           # 总屏数
grep -n "pageText: '" main/index.js          # 页码初值
```

再逐个确认 `applyScreen(i)` / `onSwiperChange(i)` 里的分支：**删掉已搬走屏的分支**
（连同它们的「离开该屏重置视图」逻辑），把「本体在独立页」的屏统一并入无操作分支。

> 血泪总结：**这一条不是「优化」，是「必须」。** 拆屏当天没做，第二天用户就会报
> 「某屏按钮点不动」，而因为它既不报错也不崩溃，排查会绕很久。

---

## ★★ 跨页传数据的硬约束：`common/` 的模块级变量不共享

**这是最容易致命、且最难自查的一条。**

lite 构建会把**公共 JS 静态内联进每个引用它的页面**。所以当 A 页 `import { S } from './session.js'`
且 B 页也 import 时，**两个页面里各有一份独立的 `session.js` 模块实例** ——
A 页对 `S` 的赋值，B 页**看不到**。

**实测症状（预览器日志铁证）**：`draw` 页选容器后 `go('pages/pack/pack')`，
`pack` 页 `onShow` 判定「会话为空」于是 `go('pages/draw/draw')` 弹回，
用户再点、再弹 —— **draw ↔ pack 无限弹跳，表现为整机卡死**：

```
11:04:35.082  MousePress (184, 200)
11:04:35.210  Vibrate short mode        ← draw 的 pick() 确实执行了
11:04:35.228  destroy → init → ready → show   ← 跳转
11:04:35.245  MousePress (184, 200)     ← 又回到选容器界面，用户又点
…… 459 ms 内重复 4 遍（8 次页面重建）
```

> 自查口诀：**`grep -a "undefined state -> init state" previewer.log`**
> 若短时间（几百毫秒）内密集出现 = 页面弹跳死循环。

**允许的做法**
1. **同页内**用模块级变量做状态（没问题，同页只有一份实例）。
2. 跨页只传**小数据**：`router.replace({ uri, params: { k: v } })`，
   目标页 `data` 里放同名字段接收（params 会覆盖）。
3. 需要更可靠的兜底时用 `@system.storage`（系统 API，跨页共享；注意 128B 上限与异步）。

**禁止的做法**
- ❌ 在 `common/xxx.js` 里放模块级单例，然后靠它跨页传对象/数组。
- ❌ 目标页 `onShow` 里「发现数据为空就 `go` 回上一页」——
  数据一旦没传过去，立刻变成**死循环**。宁可显示空态，也不要回跳。

**首选规避法：干脆别跨页。** 把连续流程（选 → 操作 → 结算）放在**同一页用 `phase` 切换**。
实测代价很小：本项目把「选容器 / 方格装填 / 结算」合成一页后，页面数 8 → 6，
单页产物 47467 B（仍 < 48KB）。

> 合页会撞 48KB 时，优先**把长文本字段从数据里拆出去**：
> 物品名占全部数据的 46%，而抽卡/装填这类算法页根本不需要名字。
> 拆成 `db.js`（数值 8.8KB）+ `names.js`（名称 8.4KB）后，算法页少背 8.2KB。

## 三、拆完的复查清单（按顺序跑，别跳）
1. **语法**：新页与主页的 JS 都 `node --check`；
2. **结构**：HML 标签配平、CSS `{`/`}` 配平、无孤儿属性行、JSON 清单合法；
3. **交叉一致性**（最关键）：
   - HML 里每个 `{{绑定}}` 都能在 JS 的 data/方法里找到；
   - HML 里每个 `onclick/onchange` 处理函数都有定义（**死绑定 = 点了没反应**）；
   - HML 用到的 class 都在本页 CSS 里有定义；CSS 里定义但没用的类列出来（只提示）；
   - JS 里 `this.xxx()` 调用的方法都有定义（**死调用 = 运行时抛异常**）；
4. **模拟运行**：把新页 JS 用 node + mock 系统模块跑一遍 `onInit/onShow` 与主要方法，
   找 `TypeError`（详见 `verify-workflow.md`）；
5. **体积**：跑快照工具确认新页与主页都过闸门；
6. **真机/模拟器实测**：走一遍「入口 → 新页 → 返回」，确认内容正确、按钮可点。

---

## 四、页内「返回上一屏」这类交互的坑

想用「改 `swiperIdx` 回第 0 屏」实现「返回首页」按钮？**不行**：
`swiper` 的 `index="{{x}}"` 是**单向绑定** —— 改数据只会改页码显示，**不会驱动 swiper 真的滚回去**。
要程序化翻屏必须走 `$refs` 的组件方法（表冠那套 `rotation({focus:true})` 是另一回事）。

务实结论：**页内的「回到第一屏」按钮在 lite 上不要做**；
真要提供出口，就在入口屏写一句「上下滑动可切换页面」的引导文字。

---

## 五、一句话速查

- 拆屏收益最大：主页面 **-4~8KB / -20~30 函数**；拆完新页要**自带基础样式与基础设施**。
- 提取代码一律用**深度匹配**；**HML/CSS 都不能靠「截到最后一个闭合标签」**。
- 批量删 CSS 类**禁用 `[^}]*` 正则**（跨块），改完必查 `{`/`}` 配平 + 孤儿括号。
- 🔴 **拆/合屏后必须同步：屏索引常量 + 总屏数 + 页码初值**（否则「某屏按钮点不动」）。
- 传参 **params 优先、文件兜底**；新页 `ensureFile()` 要在 `enter()` 之前。
- 页内「回第一屏」按钮做不了（`swiper` index 单向绑定），用文字引导代替。
