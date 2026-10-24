# Lite Wearable 页面体积预算与快照闸门（API 10 实战）

> 这块是 Lite Wearable 开发里**最反直觉、最容易翻车**的部分：页面体积不是「差不多就行」，
> 而是有几道**硬闸门**，超一点点就整页打不开。本文所有阈值和数据都来自真机 / DevEco 构建实操。

---

## 一、两道闸门（先记结论）

| 闸门 | 阈值（经验值） | 超了会怎样 | 报错长什么样 |
|---|---|---|---|
| ① **快照转换**（jerry-snapshot） | 编译产物 **≈46.6KB** 以下才稳 | 快照生成失败 → 该页**打不开/黑屏** | `Failed to convert the xxx.js file to a snapshot.` |
| ② **单页 JS 上限** | **≈55KB** | jerry 直接报错 | `Script Error: null` → 真机黑屏 |

关键认知：

1. **这两个闸门看的是「编译产物」（ace-loader 输出的那份 JS），不是源码**。
   源码 45KB 编译后可能只有 39KB（注释/空白被压掉），也可能几乎不减。
2. **闸门 ① 在构建期就把快照生成掉了**，所以「源码能编译通过」≠「页面能用」。
   一个超限的页面可以**构建成功**，但运行时**永远打不开**——表现为「点进去没反应/黑屏/卡死」，
   极容易被误判成路由或点击 bug。
3. **口径要统一**：团队里说「页面多大」时，一律说**编译产物字节数**，否则各说各的。

---

## 二、🔴 阈值不是一个固定数字：取决于「用哪个 SDK 的 jerry-snapshot」

这是最容易让人误判的一点（真实踩坑）：

同一份编译产物，用**两个不同 SDK** 里的快照工具跑，结果完全不同：

| 工具来源 | 页面 A（43.5KB / 254 个 function） | 页面 B（46.6KB / 207 个 function） |
|---|---|---|
| OpenHarmony 独立 SDK（如 `.../10/js/build-tools/ace-loader/bin/`） | ✅ 成功，生成 34.5KB .bc | ✅ 成功 |
| DevEco Studio 自带 SDK（`<DevEco>/sdk/default/openharmony/...`） | ❌ `ERR_OUT_OF_MEMORY` | ✅ 成功 |

- 两者的堆都是 **65,528 B**，但 **DevEco 版那套的分配开销更大**（报错时
  `allocated 47752 / peak 52560`，同一输入 OH 版能过）。
- 结论：**「安全线 46.6KB」是按「DevEco 自带 SDK」这套更严的工具算出来的**。
  如果你用 CLI 构建（走 rich 链、不产快照）就永远看不到这个错，一上 DevEco 构建就炸。
- 因此：
  - **自测阈值时必须标明用的是哪套工具**；
  - 换 SDK / 换 DevEco 版本后，体积红线要**重新校准**一次。

---

## 三、怎么自己测（唯一权威手段）

**手动跑快照工具**是判断「某页能不能出快照」的最快办法，比等完整构建快得多：

```bash
# 工具位置：<SDK>/js/build-tools/ace-loader/bin/jerry-snapshot.exe
jerry-snapshot.exe generate -o /tmp/probe.bc <构建产物>/pages/<页>/index.js
```

- **成功**：打印 `Input file '...' (NNNNN bytes) loaded.` + `Created snapshot file: ... (MMMMM bytes)`
- **失败**：打印 `Error: ERR_OUT_OF_MEMORY` + 一段内存明细（heap total / allocated / peak /
  bytecode / strings）——**这段明细就是调优依据**：
  - `allocated memory for strings` 大 → **字符串太多/太长**（搬 rawfile 最有效）
  - `allocated memory for byte code` 大 → **代码量太大**（拆页/删死代码）
- 快速循环：把产物拷到临时文件、**用脚本把一部分函数体替换成 `{}`**（保持语法），
  二分出「要削多少才过」。实测这种做法能精确定位到「只需削 ~2%」这种量级。

**日常自检三道**（改完代码就跑，别等 DevEco）：
1. 静态规则检查（伪类选择器 / 正则 / 数据绑定 class 等 lite 硬错）；
2. **真机同款 JS 引擎**跑一遍编译产物的语法（能抓出「语法合法但引擎不支持」的正则）；
3. 真实构建一把，看产物字节数。

---

## 四、体积不只跟「字节数」有关

实测数据（同一套 DevEco SDK 工具）：

| 页面 | 编译产物 | function 词频 | 字符串数 | 结果 |
|---|---|---|---|---|
| 页面 A | **43.5KB** | **254** | 942 | ❌ 挂 |
| 页面 B | 46.6KB | 207 | 773 | ✅ 过 |
| 页面 C | 44.9KB | 161 | 491 | ✅ 过 |
| 页面 D | 22.1KB | — | — | ✅ 过 |

**页面 A 字节最少却挂了** → 说明快照工具的堆消耗与 **AST 规模（函数数）、字符串表规模**
相关性更强，不是单纯比字节。

**因此**：减不了字节时，**把「屏」拆出去（减少 HML 编译出的函数）往往比抠字节更有效**。
HML 里的 `if` / 事件绑定 / 组件结构都会编译成函数——**一屏 HML 通常贡献 20~30 个函数**。

---

## 五、瘦身手段库（按性价比排序）

### 5.1 拆屏到独立页（收益最大，-4~8KB / -20~30 函数）

把内容最重的一屏整体搬成独立页；首页只留「入口屏」。完整流程与坑见
`page-splitting-and-refactor.md`。**注意：拆完必须同步所有屏索引常量**（否则逻辑分支错位）。

### 5.2 大字符串搬 rawfile（-4~6KB，且不动逻辑）

适合**数据表类**长字符串（短语表、词库、字典、城市列表）。范式：

```js
/* 1) 页面内只留一份「精简兜底表」（够用就行，如 20 条） */
var TABLE_MINI = '...';
var TABLE = TABLE_MINI;

/* 2) 模块级加载函数：异步读 rawfile，成功则整表替换；失败保持兜底（功能不中断） */
function loadFullTable(inst) {
  try {
    if (!inst.ensureFile()) { return; }
    inst.fileApi.readText({
      uri: 'internal://rawfile/your_table.txt',
      success: function (res) {
        var t = '';
        if (res) {
          if (typeof res.text === 'string') { t = res.text; }
          else if (typeof res === 'string') { t = res; }
        }
        if (t && t.length > 200) { TABLE = t; CACHE = null; }   // CACHE 是解析好的列表，置空强制重建
      },
      fail: function () {}
    });
  } catch (e) {}
}

/* 3) onInit 里挂上（异步，不阻塞首屏） */
onInit: function () { loadFullTable(this); ... }
```

要点：
- **必须有兜底表**：rawfile 在模拟器/某些环境读不到，没兜底会直接功能缺失。
- **解析结果要能失效重建**（`CACHE = null`），否则替换了源表但列表还是旧的。
- rawfile **不占页面 JS 体积预算**，这是它最大的价值。

### 5.3 精简数据表（-1~3KB）

同上面的表，直接把条目数砍到「常用集」（例如 150 条 → 72 条常用），代价是功能面变窄。
适合「用户 90% 场景只用前 1/3 条目」的情况。

### 5.4 删死代码（-0.2~1KB，零风险）

扫描方法（把结果按体积排序，先删大的）：

```python
# 找出「只被赋值、从不被读取」的属性
assigned = set(re.findall(r'this\.([A-Za-z_]\w*)\s*=', js))
for name in assigned:
    assigns = len(re.findall(r'this\.%s\s*=' % name, js))
    allref  = len(re.findall(r'this\.%s\b' % name, js))
    if allref - assigns == 0 and name not in hml_text:   # HML 也没绑定 → 死写
        print(name)   # 连同它的 data 定义与所有赋值行一起删
```

常见死代码来源：**功能拆分后遗留的常量与状态字段**（页面搬走了，data 字段和赋值还留着）。

### 5.5 CSS / 注释精简（-0.2~1KB）

被删页面的专属样式记得跟着删；但**通用样式（标题/按钮/容器）千万留**——
多页复用同一套类名时，删错会让别的页面样式崩。

### 5.6 ⚠️ 反面清单：不要为了压体积做的事

- **不要把 `if` 判断删成硬编码**（省不了多少，功能却废了）。
- **不要动 `stack` / 根容器结构**（那是层级唯一手段，改了就是黑屏）。
- **不要在功能改动的同时顺手瘦身**（改与压混在一起，出问题无法二分定位）。

---

## 六、日常纪律（血泪）

1. **每个页面都要有体积台账**（页名 / 编译产物 KB / 最后修改日期），改完就更新。
2. **改完立刻跑体检**，页面上限是「离红线还有余量」而不是「刚好不超」——
   留至少 **3~5KB 余量**，否则下次加两行代码就翻车。
3. **逼近红线的页面必须当次处理，不要写「下次再说」**：
   只要你把「接近上限」记成待办，用户下次体验到的就是「某页打不开」。
4. **打不开 = 先怀疑快照，不要先怀疑路由**：
   跑一次 `jerry-snapshot` 就能排除，顺序反了会浪费几小时。
5. 换 SDK、换 DevEco 大版本、升级构建工具后，**重新校准一次体积红线**。

---

## 七、一句话速查

- 两道闸门：**快照 ≈46.6KB**（超了就「打不开」）、**单页 JS ≈55KB**（超了黑屏）。
- 阈值**跟工具/ SDK 绑定**：同一产物，OH SDK 过、DevEco 自带 SDK 可能挂 → 自测要标明工具。
- 权威自测：`jerry-snapshot.exe generate -o x.bc x.js`，看 `ERR_OUT_OF_MEMORY` 的明细定位原因。
- **字节少也可能挂**：函数数/AST 与字符串表同样是决定因素。
- 瘦身优先级：**拆屏 > 大字符串搬 rawfile > 精简数据表 > 删死代码 > 压 CSS**。
- 台账 + 余量 + 当次处理：**「接近上限」= 「即将打不开」**。

---

## 八、⭐ hvigor 日志里**看不到**真实原因（2026-10-04 实锤补充）

### 现象：日志只会说一句废话
构建（含 IDE 与命令行）失败时只打印：
```
 Failed to convert the <page>.js file to a snapshot.
```
**没有 OOM、没有语法错、什么都没有** —— 极易被误判成"体积超了某个固定阈值"而盲目瘦身。

### 根因：插件把 `err` 详情丢了
`<SDK>/js/build-tools/ace-loader/lib/lite/lite-snapshot-plugin.js` 核心（压缩后）：
```js
exec('"'+snapshot+'" generate -o "'+out+'" "'+inp+'"', function(err){
  if (err) console.error("", "Failed to convert the "+name+" file to a snapshot.", "");
  //      ↑ 只打印固定文案，err.stderr / err.message 全部丢弃
});
```
所以 **hvigor 日志永远是"哑的"**，原因必须自己复现。

### ✅ 正确姿势：手动跑同一条命令（秒级）
```bash
SNAP="<SDK>/default/openharmony/js/build-tools/ace-loader/bin/jerry-snapshot.exe"
PG="<工程>/entry/build/default/intermediates/lite_source/default/assets/js/MainAbility/pages"
"$SNAP" generate -o /tmp/x.bc "$PG/<page>/<page>.js"
```
- ⚠️ **输入必须是 `lite_source` 那份 js**（= HAP 内实际装载的版本，也是快照编译的输入）；
  不要用 `releaseAssets` / `temporary` 的版本（体积与内容都不同）
- **单页 1 秒**即可出结果，不必等完整构建（3 分钟）→ **优化迭代必备**，可"改一版测一版"

### 实测两种失败形态（不是一种！）
| 错误输出 | 含义 | 处理 |
|---|---|---|
| `Error: ERR_OUT_OF_MEMORY` + Memory info 明细 | **编译堆耗尽**（绝大多数情况） | 走瘦身库（§五） |
| `Error: Generating snapshot failed!` / `Snapshot error: null` | **更深层编译器限制**（超大页，如 72KB 的剧情正文页） | 光瘦身可能不够，优先**拆页** |

### 64KB 编译堆的**内部账**（实测样例，这是"字节少也挂"的答案）
```
heap total size: 65528                    ← 硬上限 ≈64KB，不可配置
currently allocated bytes: 50864
peak allocated bytes: 54096
bytes waste due to blocks filled partially: 2401   ← 碎片！会被算进占用
allocated memory for byte code: 28216      ← 代码复杂度（AST/指令数）
allocated memory for strings:   14327      ← 字符串表总字节（中文 3B/字）
allocated memory for objects:      48
allocated memory for properties:    0
```
**判定量 = `bytecode + strings + objects + properties + 碎片`**，
任一叠加逼近 **65528** 就挂。**碎片**正是"源文件更小却先挂"的原因
（实测：`ach` 源 39,756B → OOM，而 `cafe` 源 40,800B → 通过、bc 产物 37,256B）。

### 快速判读顺序（建议固定动作）
1. 看错误是 `ERR_OUT_OF_MEMORY` 还是 `Generating snapshot failed`
2. 若是 OOM：看 `for byte code` 与 `for strings` 谁大 → 决定"砍代码"还是"砍字符串"
3. 改完**立刻重跑单页命令**验证，通过后再跑完整构建
