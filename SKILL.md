---
name: litewearable-api10-dev
description: 华为 Lite Wearable (API 10 / hvigor / FA 模型) 应用开发经验库。Invoke when
  developing LiteWearable HML/CSS/JS apps, fixing 页面黑屏/数据重置/卡加载/进不去对局 bugs,
  handling 48KB 页面限制、storage 持久化（128B 以下）、swiper 滑动交互、冷启动恢复、params 闭环传参，or
  running node 测试 + SDK ace-loader 编译验证。与 litewearable-api6-dev (Gradle/API6)
  互补，本 skill 适用于 API 10 hvigor 体系工程。
agent_created: true
---

# LiteWearable API 10 (hvigor) 开发经验库

华为轻量级穿戴（WATCH GT4 / FIT3 等，圆表物理 466×466、方表 408×480，API 10，FA 模型：HML+CSS+JS，hvigor 构建体系）实战踩坑总结。经验来自两套真实工程：一套 15 页游戏工程（页面清单 15 项，params 闭环 + 写后校验 + 冷启动竞态全实证），一套 15 页目录 / 14 页注册进 manifest.json 的工程（API10 FA 全量编译验证）。

## 工程骨架与配置文件标准写法（实战项目A 实测，逐文件照抄）

> 以下全部内容提炼自真实工程文件，**可直接复制套用**。本项目是 **API 10 FA 模型（HML+CSS+JS）**，页面清单有两套合法落点：**hvigor 新版工程在 `config.json` 的 `js.pages`**（见三、）；**老式/部分工程在 `MainAbility/manifest.json` 的 `pages` 数组**（字段写法见三、末段）。两套都是合法 FA 模型配置，关键是清单必须与实际页面目录完全一致（缺一个编译就找不到页）。

### 一、根目录配置

**`oh-package.json5`**（根，注意 `modelVersion`）
```json5
{
  "modelVersion": "5.0.4",   // DevEco 5.x；DevEco 6.x 工程需改为 "6.0.0"（见第四节版本差异）
  "description": "项目描述",
  "dependencies": {},
  "devDependencies": {}
}
```

**`build-profile.json5`**（根）
```json5
{
  "app": {
    "signingConfigs": [],
    "products": [             // ★ products 在 app 级，不是模块级
      {
        "name": "default",
        "signingConfig": "default",
        "compatibleSdkVersion": "4.0.0(10)",   // API 10 写法
        "runtimeOS": "HarmonyOS",
        // ★ 无 compileSdkVersion 字段（FA 模板本就没有）
        "buildOption": { "strictMode": { "caseSensitiveCheck": true, "useNormalizedOHMUrl": false } }
      }
    ],
    "buildModeSet": [ { "name": "debug" }, { "name": "release" } ]  // ★ buildModeSet 在 app 级
  },
  "modules": [                // ★ 数组
    { "name": "entry", "srcPath": "./entry", "targets": [ { "name": "default", "applyToProducts": ["default"] } ] }
  ]
}
```

**`hvigorfile.ts`**（根，App 级用 `legacyAppTasks`）
```ts
import { legacyAppTasks } from '@ohos/hvigor-ohos-plugin';
export default {
  system: legacyAppTasks,
  plugins: []
}
```

**`hvigor/hvigor-config.json5`**（最易漏！modelVersion 与根一致）
```json5
{
  "modelVersion": "5.0.4",
  "dependencies": {},
  "execution": {}, "logging": {}, "debugging": {}, "nodeOptions": {}
}
```
> 实际文件里 execution/logging/debugging/nodeOptions 各有一堆被注释掉的示例项，留空对象即可，不影响构建。

**`.gitignore`**（标准，注意排除 `/oh_modules` 与 `**/build`）
```
/node_modules
/oh_modules
/local.properties
/.idea
**/build
/.hvigor
.cxx
/.clangd
/.clang-format
/.clang-tidy
**/.test
/.appanalyzer
.DS_Store
```
**`.clang-format`**：IDE 需要（Cpp 风格，ColumnLimit 120 等），直接复制模板默认内容即可。

### 二、entry 模块配置

**`entry/build-profile.json5`**（★ 必须 `"apiType": "faMode"` —— Hvigor 识别 FA 模型的关键字段）
```json5
{
  "apiType": "faMode",
  "buildOption": {},
  "targets": [ { "name": "default" } ]
}
```

**`entry/hvigorfile.ts`**（模块级用 `legacyHapTasks`，**不是 default 系列**）
```ts
import { legacyHapTasks } from '@ohos/hvigor-ohos-plugin';
export default {
  system: legacyHapTasks,
  plugins: []
}
```

**`entry/oh-package.json5`**（DevEco 5.x 无 modelVersion；6.x 需补 `"modelVersion": "6.0.0"`）
```json5
{
  "name": "entry",
  "version": "1.0.0",
  "description": "entry module (FA / liteWearable)",
  "main": "", "author": "", "license": "",
  "dependencies": {}, "devDependencies": {}
}
```

### 三、FA 应用配置（核心，决定页面/设备/权限）

**`entry/src/main/config.json`**（★ 页面清单在 `js.pages`；`deviceType` 含 `liteWearable`；此为 hvigor 新版 FA 工程写法，老式工程见本段末 manifest.json 注）
```json
{
  "app": {
    "bundleName": "com.example.buckshotroulette",   // 包名，全局唯一
    "vendor": "example",
    "version": { "code": 1000000, "name": "1.0.0" }
  },
  "deviceConfig": {},
  "module": {
    "deviceType": [ "liteWearable", "wearable" ],    // ★ 轻智能穿戴
    "distro": { "deliveryWithInstall": true, "moduleName": "entry", "moduleType": "entry" },
    "reqPermissions": [                              // 需要的系统权限（如振动）
      { "name": "ohos.permission.VIBRATE", "reason": "开枪/命中触发马达振动", "usedScene": { "when": "inuse" } }
    ],
    "abilities": [
      {
        "name": ".MainAbility",
        "srcLanguage": "js",                         // ★ FA 用 js
        "srcPath": "MainAbility",
        "icon": "$media:icon",
        "description": "$string:MainAbility_desc",
        "label": "$string:MainAbility_label",
        "type": "page"
      }
    ],
    "js": [
      {
        "pages": [                                   // ★ 全部页面路径（无 .hml 后缀），缺一个编译就找不到页
          "pages/disclaimer/disclaimer",
          "pages/home/home",
          "pages/mode/mode",
          "pages/index/index",
          "pages/index_easy/index_easy",
          "pages/index_hard/index_hard",
          "pages/index_endless/index_endless",
          "pages/pvp_normal/pvp_normal",
          "pages/pvp_hard/pvp_hard",
          "pages/settings/settings",
          "pages/result/result",
          "pages/about/about",
          "pages/waiver/waiver",
          "pages/tutorial/tutorial",
          "pages/stats/stats"
        ],
        "name": ".MainAbility"
      }
    ]
  }
}
```

> **老式 FA 工程用 `MainAbility/manifest.json` 而非 config.json**：字段差异如下，写法同样合法（已在一套 15 页工程的 API10 FA 全量编译验证）：
> - 页面清单：`"pages": ["pages/xxx/xxx", ...]`（字符串数组，路径无 .hml 后缀，必须含全部页面，缺一个编译找不到页）。
> - `minPlatformVersion`：**可写字符串 `"zsdk 1.0.0"`**（hvigor 5.0.4 接受），也可写数字；不要误以为必须是数字 10。
> - `icon`：写像素尺寸数字（如 `114`，对应 114×114 图标），不是 `$media:icon`。
> - 清单位置在 `entry/src/main/js/MainAbility/manifest.json`，与 hvigor 工程的 config.json 二选一，按你工程创建方式决定。

#### 配置校验避坑（三处写错即编译 / schema 校验失败 ★高频）

**① compileSdkVersion / 三 SDK 版本字段配置（FA 工程）**
- 现象：导入或编译报 `Incorrect settings found in the build-profile.json5`、或 `The compile API version X is not compatible with the target API version Y`、或 schema 校验失败。
- 根因：
  - FA 模型（老式 FA 模板）`products[0]` **本就没有 `compileSdkVersion` 字段**；若照新工程（Stage）模板误加该字段，或 `compatibleSdkVersion` / `targetSdkVersion` / `compileSdkVersion` 三者不满足 `compatible ≤ target ≤ compile` 的大小关系，即报错。
  - `compatibleSdkVersion` 必须写成 `"4.0.0(10)"` 这种「版本号(API号)」格式（API 10 → `(10)`），**不能只写数字 `10`**，也别漏括号 / 用中文点。
  - `runtimeOS` 必须配在**工程级（根）`build-profile.json5` 的 `products` 下**；**不能**配在模块级（entry）`build-profile.json5` 里，否则报错。
- 正确写法：FA 工程根 `build-profile.json5` 的 `products[0]` 用 `{ name, compatibleSdkVersion, targetSdkVersion, runtimeOS }` 即可，**无需 `compileSdkVersion`**（与「工程骨架」章节结论一致）；要写也必须满足三字段大小关系。

**② label 引用的 `$string` 资源名过长（超 22 字符）**
- 现象：编译 / 打包阶段报资源名过长相关错误（用户实测 2026-08-23），或安装后应用名显示异常。
- 根因：`app.json5` 的 `label: "$string:xxx"` 中，冒号后的**资源 key 名（xxx）长度建议 ≤ 22 字符**。超长会在资源编译阶段因索引长度限制报错。
- 正确写法：用简短清晰的 key 名。例如 `$string:app_name`、`$string:MainAbility_label`（18 字符，安全）。**避免** `$string:this_is_a_very_long_ability_label_name_exceeds` 这类长串。多页面需要不同名时，用短前缀区分（如 `label_home` / `label_mode`）。

**③ `module.abilities.permissions` 不合法**
- 现象：编译报 `module.abilities.permissions` 不合法 / schema 校验失败，或权限声明根本不生效。
- 根因：FA 模型（config.json）的权限声明**不是**写在 `module.abilities` 里，而是写在 **`module.reqPermissions`**（module 层级数组）。在单个 ability 内、或在 `abilities` 数组层级写 `permissions` 字段，都是非法 schema 字段。
- 正确写法（FA）：
```json
"module": {
  "reqPermissions": [
    {
      "name": "ohos.permission.VIBRATE",
      "reason": "$string:perm_vibrate_reason",
      "usedScene": { "abilities": ["MainAbility"], "when": "inuse" }
    }
  ],
  "abilities": [ { "name": ".MainAbility", "srcLanguage": "js", "type": "page" } ]
}
```
  - 注意：FA 用 `reqPermissions`（**不是** Stage 的 `requestPermissions`）；`usedScene.abilities` 是数组。误写成 `module.abilities: [{ "permissions": [...] }]` 或 `module.abilities.permissions` 都会 schema 报错。

**`entry/src/main/js/MainAbility/app.js`**（全局 App 对象，onCreate/onDestroy 生命周期）
```js
export default {
    onCreate() {
        console.info('App onCreate');
    },
    onDestroy() {
        console.info('App onDestroy');
    }
};
```

**`entry/src/main/js/MainAbility/i18n/zh-CN.json` + `en-US.json`**（★ lite 初始化强依赖此目录；结构 `{ "strings": {...} }`）
```json
{ "strings": { "app_name": "恶魔轮盘赌", "label_win": "你赢了！" } }
```
> 本项目 HML 实际用字面中文串、未接 `{{$t()}}`（见巧法 7）；但 `i18n/` 目录**必须存在**，否则 lite 框架初始化失败、应用卡加载态。

**`entry/src/main/resources/`**（图标与字符串占位）
```
resources/base/element/string.json   // {"string":[{"name":"MainAbility_label","value":"恶魔轮盘赌"},{"name":"MainAbility_desc","value":"三阶段轮盘对决"}]}
resources/base/media/icon.png        // 应用图标（config.json abilities.icon 引用 $media:icon）
resources/base/media/icon_small.png
```
> FA lite 实际文案用字面串，resources 主要供 config.json 的 `$string:`/`$media:` 引用占位；删了图标引用会编译报错。

### 四、版本差异备注（DevEco 5.x vs 6.x，关键！）

| 项 | DevEco 5.x（实测） | DevEco 6.x（实测） |
|---|---|---|
| `modelVersion`（根 oh-package + hvigor-config） | `"5.0.4"` | `"6.0.0"`（6.x 向下兼容，5.x 串也能跑，非必改） |
| `entry/oh-package.json5` 是否有 modelVersion | 无 | 可有（`6.0.0` 或 `5.0.4` 均可） |
| `build-profile.json5` buildModeSet 位置 | app 级 | app 级（同） |
| `products[0]` 字段 | 无 `compileSdkVersion` | 无 `compileSdkVersion`（FA 模板本就无） |

> **铁律**：同一工程三处 modelVersion 必须**一致**；DevEco 6.x **向下兼容**，5.x 工程（modelVersion `5.0.4`）可直接打开构建，**无需强改 `6.0.0`**（报错 `00303038`/`00303190` 多因 `deviceConfig` 缺失等其他 schema 项，非版本号本身）。

### 四·补、从 Gradle 老 FA 工程迁移到 hvigor（API 12 实证，2026-09-25）

**场景**：老工程是 Gradle 构建（根 `build.gradle` 里 `compileSdkVersion 6/7`、`compatibleSdkVersion 3`，目录 `js/default/`，abilities name `default`），要迁到 hvigor + 更高 API。

**七步迁移法**（fetchbilibili-project 实测，产物已构建验证）：

1. **删 Gradle 体系**：`build.gradle` `settings.gradle` `gradle.properties` `gradlew(.bat)` `gradle/` `entry/build.gradle` `entry/proguard-rules.pro` `package.json` `.gradle/` `.idea/`。`local.properties` 可删，DevEco 会自己重建（内容可为空）。
2. **建 hvigor 七件套**（照抄本文「一、二」），`compatibleSdkVersion` 换成目标版本。
3. **`config.json` 改造**：`abilities[0]` → `name: ".MainAbility"` + `srcLanguage: "js"` + `srcPath: "MainAbility"`；`js[0].name` → `".MainAbility"`；按需补 `reqPermissions`（联网需 `ohos.permission.INTERNET`）。
4. **目录改名** `js/default/` → `js/MainAbility/`。⚠️ **`abilities.srcPath` = `js[].name`（去掉前导点）= 实际目录名，三处必须互相对得上**，否则编译找不到页。
5. **`string.json` 补 `MainAbility_label` / `MainAbility_desc`**（`config.json` 的 label/description 引用这两个 key，缺了资源解析失败）。
6. **建 `hvigor/hvigor-config.json5`**，`modelVersion` 与根 `oh-package.json5` 一致。
7. **布局适配**：Gradle 时代常见 `<stack style="width:1000px;height:1000px">` 这种「虚拟大画布」，在 466×466 真机上直接溢出裁切 → 改成 JS 读 `@system.device.getInfo` 的 `windowWidth`/`windowHeight` 后绑定到内联 style，缺省值按目标机型预置（GT 5 = 466）。

**API 12 专项参数**：

- `compatibleSdkVersion: "5.0.0(12)"`；`modelVersion` 用 `"5.0.0"`（DevEco 6.x 向下兼容，实测可直接构建）。
- **API 12 对应的 Lite 设备**：WATCH GT 5、WATCH D2。对照表见本文「官方能力全景速查 · 1」。
- **本机没装 API 12 SDK 也能编**：DevEco 6.1.1（内置 API 24 SDK）实测直接编出 `compatible: 50000012` 的 lite HAP —— 产物里 `target`（60101024）与 `compatible`（50000012）是分离的，不必为低 compatible 单独装旧 SDK。
- **构建后必须核对两处产物**（这是真机安装校验的依据，别只看"Build 成功"）：
  - `entry/build/default/intermediates/lite_source/default/config.json` → `app.apiVersion.compatible` 应为 `50000012`
  - `entry/build/default/intermediates/lite_source/default/assets/js/MainAbility/manifest.json` → `minPlatformVersion` 应为 `12`
- ⚠️ **`minPlatformVersion` 就是安装门槛**：写 12 ⇒ 只有 API 12+ 设备（GT 5 / D2）能装，GT 4（API 10）会装不上。要下探旧设备就把 `compatibleSdkVersion` 降回 `4.0.0(10)` 再重编。
- ⚠️ `compatibleSdkVersion` 写成非 `"平台版本(API号)"` 格式（如裸写 `12`），真机安装会报「安装失败:40 配置文件格式错误」。
- 最终产物：`entry/build/default/outputs/default/entry-default-lite-unsigned.hap`，内部只有一个 `entry-default-unsigned.bin`。

### 四·补2、迁移/新工程安装失败 `9568344 install parse profile prop check error`（2026-09-25 实证）

**头号根因：`config.json` 里 `app.version.code = 0` 是非法值。**

老 Gradle 工程（`app.version = {code: 0, name: "1.0.3"}`）原样迁到 hvigor 后，hvigor 把 0 原样写进产物 profile，**设备侧做 profile 属性校验时直接拒绝** → `9568344`。
修复：`version.code` 改成 ≥1 的整数（推荐 `1000003` 这种「1.0.3 → 1000003」风格，与 `version.name` 对应）。改完重编 → `install bundle successfully`。

> 官方 FAQ 对 9568344 只写了「bundleName / module name 命名规则」和「ACL 提权白名单」两类原因，**versionCode=0 这条没写**，但实测复现 100% 命中。迁移动手时顺手把 `version.code` 从 0 提上来，能省一轮排查。

**排查方法论（关键，别走弯路）**

1. **产物有两个 HAP，别拿错**：

   | 产物 | 形态 | 用途 | 复现 DevEco 部署报错？ |
   |---|---|---|---|
   | `entry-default-lite-unsigned.hap` | 单个 `.bin` | **真机手表**（应用调测助手安装） | ❌ 拿它测会得到误导性的 `9568413 device type is not supported` |
   | `entry-default-unsigned.hap` | 标准 jsbundle 结构（config.json + assets/js） | **DevEco 部署模拟器用这个** | ✅ 能 1:1 复现 |

2. **模拟器能装 Lite 应用**。官方 FAQ「暂不支持在 HarmonyOS NEXT 上直接调试 Lite Wearable」说的是**真机**；DevEco 的 wearable 模拟器（`127.0.0.1:5555`，API 24，`const.product.devicetype=wearable`）实测可正常安装并前台运行 Lite 应用。
3. **`signingConfigs: []` 为空不影响模拟器安装**。hvigor 只打警告 `Will skip sign ... No signingConfigs profile is configured`，DevEco 侧也提示「模拟器上安装HAP可以跳过签名」。**只有真机才必须配签名**。
4. 手动复现用 hdc（**Git Bash 下必须先 cd 到 HAP 目录再用相对文件名**，绝对路径会被拼成 `<cwd>/H:/xxx.hap`）：
   ```bash
   cd <...>/entry/build/default/outputs/default
   hdc -t 127.0.0.1:5555 install -r entry-default-unsigned.hap
   # 查装没装 / 系统记的 apiVersion
   hdc -t 127.0.0.1:5555 shell bm dump -n <bundleName> | head -30   # 看 apiCompatibleVersion / appProvisionType
   hdc -t 127.0.0.1:5555 shell bm dump -a | grep -i <关键字>
   ```

**其它零碎但会咬人的点**

- **DevEco 会自动改写源 `config.json`**：`deviceType` 会从 `["liteWearable"]` 被补成 `["liteWearable","wearable"]`。改这个文件前**先重读**，否则 Edit 报 `File has been modified since read`。
- 标准 HAP 产物的 `module.deviceType` 是 `["wearable"]`；`module.package` 被注入默认值 `com.example.myapplication`，**ability 全名因此是 `com.example.myapplication.MainAbility`**（`aa start -a MainAbility` 找不到，要带包名前缀）。
- **hvigor 命令行构建**（绕开 IDE）：
  ```bash
  cd <工程根>
  unset NODE_OPTIONS   # 必须！否则 WorkBuddy 的 safe-delete shim 拦住 hvigor 的 rmSync → Error Code 00308018
  export DEVECO_SDK_HOME="D:/Devceo Studio 6.1.1/DevEco Studio/sdk"
  export NODE_HOME="D:\\Devceo Studio 6.1.1\\DevEco Studio\\tools\\node"   # 缺则报 NODE_HOME is not set
  export PATH="/d/Devceo Studio 6.1.1/DevEco Studio/jbr/bin:/d/Devceo Studio 6.1.1/DevEco Studio/tools/node:$PATH"  # 缺 jbr → spawn java ENOENT
  "D:/Devceo Studio 6.1.1/DevEco Studio/tools/hvigor/bin/hvigorw.bat" assembleHap --no-daemon
  ```
  - **备选（2026-10-01 fetch-read 工程实证）**：直接跑 `tools/node/node.exe node_modules/@ohos/hvigor/bin/hvigor.js assembleHap ... --no-daemon`，需满足：① 工程建 junction `node_modules/@ohos/{hvigor,hvigor-ohos-plugin}` → `tools/hvigor/{hvigor,hvigor-ohos-plugin}`；② `NODE_PATH=<工程>\node_modules`（否则 hvigor-ohos-plugin 内部 `require('@ohos/hvigor')` 报 MODULE_NOT_FOUND）。未实测 `unset NODE_OPTIONS` 是否同样必需。

### 五、新增一个页面的标准流程

1. 在 `pages/<name>/` 下建 `hml` + `css` + `js` 三件套（HML 根 `<div class="container">`）。
2. 在 `config.json` 的 `js.pages` 数组**末尾加一行** `"pages/<name>/<name>"`（顺序即路由可达性，disclaimer 必须首位做冷启动入口）。
3. 跑 SDK ace-loader 编译验证（见验证流程），确认新页进编译产物、不超 48KB。
4. 跨页跳转用 `router.replaceUrl({ uri: 'pages/<name>/<name>', params: {...} })`（**API10 用 `replaceUrl`**；API6 旧链才用 `replace`；lite 均无 push/back/clear）。

- **不需要**：根 `package.json`（只有 oh-package.json5）、`.appanalyzer/.cache/.hvigor/.idea/build`（DevEco 打开后自动生成运行时目录，已被 .gitignore 排除）。
- 参考实证：15 页游戏工程（页面清单 15 项）、另一套 15 页目录 / 14 页注册进 manifest 的工程

## 触发场景

- 开发/修改 Lite Wearable API 10 应用的任意页面（HML/CSS/JS 三件套）
- 遇到：页面黑屏、数据退出重进重置、卡在"加载中"、进不去对局、点击/滑动没反应、按钮不显示
- 修改后需要验证：node 逻辑测试 + SDK ace-loader 编译产物大小检查
- ⚠️ **整段替换含 `if/else {}` 的分支后，立刻跑 `node --input-type=module --check`**：这类替换极易多写一个 `}`（旧代码「闭合 else 块」+「闭合 else-if 分支」共两个，去掉内层 if/else 后只该留一个），表现为 `SyntaxError: Unexpected token 'if'`，且报错点常在后面**看似无关**的行（如 `if (noSchedule)`）。2026-09-11、2026-10-10 两次踩同款坑。

## ⚠️ 先分清「模拟器限制」与「真机限制」（很重要，别把两者混为一谈）

本平台**只有 wearable 模拟器 / 预览器，没有 Lite 模拟器**。因此下面这些能力**在真机上是好的**，
只在模拟器/预览器里不可用 —— 不要把「模拟器跑不了」错误地记成「这个 API 不能用」：

| 能力 | 真机 | 模拟器 / 预览器 |
|---|---|---|
| `$app`（读写 app.js 的 `export default`） | ✅ 可用 | ❌ `typeof $app === 'undefined'` |
| `@system.file`（file / rawfile 读写） | ✅ 可用 | ❌ 调不通 |
| 表冠旋转事件 | ✅ 可用 | ❌ 无注入手段 |
| 运行时网络取图后渲染 | ✅ 可用 | ⚠️ 行为不一致 |

**实践推论**：涉及 `$app` / `@system.file` / 表冠 的功能，**模拟器结果不能作数，必须真机验证**；
同时为了让模拟器也能跑通调试，关键链路（跨页传参、持久化）**保留一条文件通道作为兜底**是值得的。

## 核心硬约束（踩坑铁律，勿再犯）

1. **每页 JS 产物 ≤48KB（49152B），红线按真机加载的 release 产物算**：ace-loader 注入约 **16KB 框架运行时**（固定，压缩影响很小）；release 压缩后业务代码安全上限 ≈ 48−16 = 32KB（约 31KB），**源码（未压缩）建议压在 ~31KB 内**，使 release 产物远小于 48KB。超限（release 产物 >48KB）编译报 `bigger than 48 KB` 或**该页真机黑屏**；debug 产物不压缩（≈16KB框架+未压缩源码，约 53KB）仅开发参考、**不真机加载、不代表黑屏**（详见「§SDK 与编译方法 · 三、48KB 红线」）。**node 测试跑源文件不受限会漏检体积** → 改完必做 ace-loader 编译验证！根治 = 按功能拆独立页面（实测 2026-09-26：某页 ace-loader 产物 55.5KB 即真机黑屏；把 20 屏拆到独立页后 index 降到 46.2KB 恢复正常）；⚠️ **「单页产物」= HML 模板 + CSS + 页面 JS 全算**（HML/CSS 会被编译进页面 JS，每加一屏约 +0.5~0.8KB、每条 CSS 约 +60~280B），只数 JS 源码会低估；单页压缩手段：去注释压空白 → 整词缩短内部字段（data 键名/hml 绑定/方法名不动）→ 操作符空格压缩，每步 node --check + 回归。
2. **storage value 必须 <128 字节**：JSON 档案（>10 字段）必超限 → 拆短 key 存储（`br_p_<字段名>`，每 key 一个数字串）。
3. **storage 裸 set 会静默失败**（无回调无异常）→ 写后校验：`set` → 300ms 后 `get` 读回比对 → 不一致重试（token 版本号防旧链覆盖新档案）。
4. **`get` 一个不存在的 key 会走 fail 回调**（真机，不返回 default）→ "标记不存在"类检查把 fail 当"无标记"处理，但要二次确认防误发。
5. **flex-start 全禁用**（justify-content 和 align-items 都不行）→ 整区渲染异常/不渲染；永远用 `center`。
6. **任何 div 容器必须给固定 height**：自适应高度的 column 容器整区不渲染（统计页/关于页两次踩坑）；带 `if` 条件渲染的 div 更要固定高度 class。
7. **CSS 不要用后代选择器 `.a .b`**（无成功用例）→ 独立 class。
8. **随机数防御**：lite 精简引擎 `Math.random()`/`Date.now()` 可能异常（恒 0/NaN/偏小）→ randInt 加 NaN 全防御（入参校验 + t/r 值校验 + 结果兜底）；所有依赖 Date.now 的写入（时间戳）也要防御。
9. **事件**：lite 只支持 click/longpress/swipe（**API10 长按事件名 = `onlongpress`**，SDK10 组件白名单 `text.json` 等实锤；API6 旧链才用 `onlongclick`）；`@system.router` 在 lite 上 **API10 用 `replaceUrl`、API6 用 `replace`**，均无 push/back/clear；`@font-face` 不支持。
10. **音频 = `@system.audio`（半官方接口，2026-08 实证）**：Lite Wearable **有**音频播放接口，但 SDK **不含官方声明**（本机 10/js/api 只有标准系统 `@ohos.multimedia.audio`；`@kit.MediaKit` SoundPool/AVPlayer 仍不可用——那是标准系统 API）。`@system.audio` 来自华为开发者学堂课程（视频 22:40）+ Nexus 腕连社区实践。**仅 GT3、Fit3 及后续设备支持，Fit2 不行**（开发中记录的 GT4/FIT3 在支持列表）。用法：rawfile 放 `music/` 目录（mp3 等）+ `cur_playlist`（当前播放列表文件名）+ `playList`（格式 `[music1.mp3,1,0,10;music2.mp3,1,0,10]`）；首次安装把 `internal://app/rawfile/audio/` 迁移到 `internal://app/`；`import audio from '@system.audio'`，`audio.src='internal://app/music/x.mp3'` → `audio.stop()` → `audio.play()`，`audio.volume`（0-1）读写。d.ts 补丁放对应 SDK 的 `js/api/liteWearable` 目录（API6: `hmscore/2.2.0/js/api/liteWearable`、API7: `hmscore/3.0.0_7/js/api/liteWearable`；本工程 API10 用 `<SDK_ROOT>/js/api/liteWearable`，路径按实际 SDK 版本目录调整，未官方声明、需真机验证）。社区资源（蓝奏云）：d.ts `wwbff.lanzout.com/ixIYf26wa4vg`、copyDir 迁移函数 `iSAB23zdlpha`、鸡音盒示例 `iDyOL3zdkf2j`。没有音频需求时，唯一可靠反馈仍是 `@system.vibrator`。WearEngine（HiWear）连接监听是 HMS Core 三方能力，主场景在手机侧 App，lite 手表端需申请 Wear Engine 服务审批 + config.json 配对端包名/指纹（错误码 206）+ 手机端配合，`WearEngineLite` 模块名官方文档查无、存疑。
11. **data 初值 / 兜底文本绝不用 `—`（em dash U+2014）**（2026-10-02 实证）：lite 字体未必有该字形 → **渲染成空白** → 看起来就是「这行没显示/没渲染」。改用 ASCII `-` 或中文全角「无」。**诊断指纹**：同一页里**静态文本全正常、只有带 `{{}}` 绑定的行空白** → 一定是 data 初值的字符字形问题（因为绑定行才会显示初值）。同类风险字符：`—` `–` `…` 等排版符号，能换 ASCII 就换。⚠️ 注意区分：`·`(U+00B7)、`×`(U+00D7) 是拉丁扩展区，中文字体通常有，实测可显示。
12. **数据加载不能只挂 `onInit`，`onShow` 必须有兜底**（2026-10-02 实证）：lite 的 `onInit` **在部分环境（DevEco 预览器等）根本不触发** → 只挂 onInit 的页面会**永远停在 data 初值**（配合第 11 条就是「一片空白」）。做法：`onShow` 里也调一次加载方法。
    - **数据会变的页面**（详情页翻译结果 / 笔记列表 / 设置项）→ **不加幂等锁**，onShow 重读是**正确行为**。
    - **数据恒定的页面**（关于页词库规模、屏幕尺寸）→ 加幂等标志避免重复读文件；⚠️ 标志**只在成功回调里锁定**，失败必须允许重试，否则一次失败永久锁死。
    - ⚠️⚠️ **但「onInit + onShow 都调」会双跑**：两条读链并发抢同一文件的 file I/O → Lite 上互相干扰甚至吊死 → **打开页面即卡死**（笔记页实证）。修：加载方法加**实例级在飞守卫** `if (this._ld) return; this._ld = true;`（挂**实例**而非模块级——模块级标志会跨页面实例残留）。
13. **`readText` 分块读：`length` 必须夹到「剩余字节数」，判成功要看「是否读满 `file.get` 的长度」**（2026-10-03 实证，本条最阴）：
    ```js
    var ask = READ_CHUNK;                                  // 4096
    if (total >= 0) {                                      // total 来自 file.get
      var rem = total - pos;
      if (rem <= 0) { /* 读毕 */ }
      if (rem < ask) ask = rem;                            // ★ 夹住，绝不越界
    }
    readText({ uri: uri, position: pos, length: ask, ... });
    ```
    - **为什么**：恒传 `length: 4096` 时最后一块必然请求越界区间
      （如 13799 B 的文件 → 请 position=12288 + 4096 = 16384 > 13799），
      部分 Lite 固件对越界区间**直接 fail** → 只拿到前面几块 → **内容残缺**。
    - **诊断指纹（关键）**：**只在「需要分块 + 最后一块不满」时暴露** ——
      即小文件（<4KB）一直正常，**某个文件一长大/一扩容就突然全废**。
      本项目实例：词库 5000 词（索引 2782 B，单块）好，扩到 11335 词（13799 B，4 块）后
      本地查询全部报「未收录」。
    - ⚠️ 配套：**判成功不能只看 `minLen`**（那只是粗估，如给 400 而实际 13799）——
      残缺内容会被当成功接受、后续解析静默失败。应比对 `file.get` 的长度；
      且**读不完整要重试**（同 URI 重试 1 次再换候选 URI）。
14. **表冠（crown）焦点：任何 data 写入都会让 `<list>` 重渲染并丢掉 `rotation` 焦点**（2026-10-03 实证）：
    - `crown()` 要**多段补焦**（如 50ms / 400ms / 1100ms 各 arm 一次，`rotation` 幂等），
      只 arm 一次会被随后的数据落地冲掉 → 表现为「表冠滑不动」。
    - **写 data 前先判「真的变了」**：`onShow` 每次都会调 restoreXxx/applyMetrics，
      无脑赋值等于每次进页面都冲掉一次焦点。
    - 数据异步落地后（loadRows/loadLast 回调）补一次 `crown(true)`。
15. **索引/大文件「切小到单块可读」是**可选**思路；**首选仍是「分块读 + 长度判 EOF」**（2026-10-03 更正）**：
    > ⚠️⚠️ **本条前半的「索引分片」已在本工程真机实测失败，别照抄。**
    > 实测：把 `dict.idx` 切成 `dict.idx0..3` 后按序读，**每片都读不到（长度 -1）**，
    > 而同一版里**整块** `dict_cn.idx` 是正常的。⇒ **分片这条路在本工程真机上不成立**，
    > 已回退为「单个索引文件 + 分块读」。**首选永远是下面 §13/§4.1 的正解**：
    > **分块读 + 「返回长度 < 请求长度即 EOF」收工**（ASCII 资源适用；
    > 含中文的文件字符数≠字节数，只能靠精确尺寸夹 `length`）。
    - （历史记录，仅作参考思路）把稀疏索引**按行边界**切成 `<x>.idx0 / .idx1 / …`（每片 ≤4096 B），
      运行时按序读、每片只发一次 `readText`，读到空片即停；首片读不到退回整块读。
      **本工程实测：分片读在真机上返回空 → 不可用。**
    - 参考实现：开源版 Weardict（`sage-jpg/Weardict-gaokao-`）的 `common/fs.js` + 按首字母分文件的
      `dic_a_<字母>_map.bin` 索引 —— ⚠️ 注意**它是把「词库数据」按首字母分文件**（每片本身小），
      不是「把索引切分片」，两者不是一回事。
      ⚠️ **它也不通过 `rawfile://` 读**，而是用 `storage:bundle_name` 推出解包目录绝对路径
      （`internal://app/..\..\run\<bundle>\assets\...`）—— 本工程照抄这条路**实测失败**
      （把未验证的绝对路径放候选首位后，连原本好用的 `dict_cn.idx` 都读不到了）。
      ⇒ **在技能给出「rawfile 就是规定位置」的前提下，不要擅自改路径方案。**
    - ⚠️ 若确要走分块读：**每块读结果必须单次收口**（双回调 → 重试链指数翻倍 → 灌爆文件 API → 卡死），
      且**同一时刻只允许一条读链在飞**（重入守卫）。另：**索引读不到时不要让 onShow 反复重跑整条启动链**
      —— 每轮几十个文件请求会把真机砸到系统级异常（**整块表重启**）；用计数器封顶自动重跑次数。
16. **★★★ 页面存活标记（`PAGE_ALIVE` 这类模块级布尔）在 lite 上必然出错 —— 改用「代际计数」**（2026-10-03 定案）：
    - **错法**：`var PAGE_ALIVE = true;` → `onInit` 置真、`onDestroy` 置假，异步链与定时器都用
      `if (!PAGE_ALIVE) return;` 做守卫。
    - **两重必坏**：
      ① lite 的 **`onInit` 本来就不可靠**（所以数据加载都要 onShow 兜底）→ onInit 没跑时永不置真；
      ② lite 上 `replace` 的生命周期是「**新页 onInit/onShow → 旧页 onDestroy**」→
         **旧实例的 onDestroy 会把新实例刚置的 `true` 冲成 `false`** → 活着的页被当成已销毁。
    - **症状指纹（很好认）**：**结果其实已经拿到了，只是「收尾动作」全被守卫拦掉** ——
      「加载界面收不收得起」取决于查询耗时是否跨过 loading 最短显示时长（如 500ms）：
      **快查询一直卡在「加载中」；慢查询能退出界面但看不到结果、也不跳页**。
      （本项目实例：「本地查询一直停在『正在查询中』，联网也看不到结果」。）
    - **正解**：用**代际计数** `var PAGE_GEN = 0;` ——
      实例在 `onInit`（且**必须**在 `onShow` 也补一次，因为 onInit 不可靠）取号 `myGen = ++PAGE_GEN`；
      每条异步链/定时器**发起时**记下自己的号，回调时 `if (myGen !== PAGE_GEN) return;` 即停手。
      **`onDestroy` 什么都不用置**（旧实例的链自然因代际不符而停手），
      与生命周期先后顺序**无关**，从根上免疫。
      若确有「旧实例不得再导航/改界面」的需求，用**实例级**标志（`this._gone`）而不是模块级布尔。
17. **★★★ 系统模块必须用静态 `import`，**绝不能用 `require()`**（2026-10-03 本工程实证，有构建产物铁证）**：
    - **症状指纹（极好认）**：某个页面的**所有**文件读/网络请求**既不 success 也不 fail**
      —— 回调永远不触发 → 表现为「一直加载中 / 启动链吊死 / 点某按钮卡死」，
      **而同一工程里别的页面完全正常**。
    - **实测依据**：本工程 `index.js` 里 13 处 `require('@system.file')` / `require('@system.fetch')` 等，
      该页**所有**读都拿不到回调；改成 `import file from '@system.file'` 后，
      构建产物里才出现 `@system.file`/`@system.device`/… 六个模块标识
      （**修之前产物里一个 `@system.*` 都没有**）。
    - **原理**：ace-loader 用 **webpack** 打包，`import` 会被**静态**编进模块图
      （产物可见 `__webpack_modules__` / `__webpack_require__`），
      所以 `import File from '@system.file'` 在表端可用；而 `require('@system.file')`
      是**运行期动态调用，webpack 无法解析** → 表端得到空壳/未定义 →
      方法调用静默失败、回调永不触发。
      （技能 `hmlwskill/references/js-syntax.md` 亦明文：Node 的 `require`/`fs`/`path`/`Buffer`/`process`
      **绝不能在 JerryScript 表端导入或执行**。）
    - **`import` 的本地名随便起**：`import File from '@system.file'` 与 `import file from …`
      **完全等价**（只是本地绑定名不同），大写小写没有功能差别。
    - ⚠️ 排查时**先对比产物**：`grep '@system\.' <lite_source>/pages/xx/xx.js`
      —— 若产物里没有任何 `@system.*`，说明该页的模块调用根本没被编进去。
18. **★★★ 启动串行链开跑之前，绝不允许有任何「在飞」的文件 I/O**（2026-10-03 本工程实证）：
    - **不是**「别在链跑起来之后发起读」这么简单 ——
      **链开始前发起的、还没回来的 I/O，同样会污染文件通道** ✗
      （lite 的 file I/O 是串行的：**并发会让链上的读不回调/失败**）。
    - **实测指纹**：`B1 + I-1`（`BOOT_CHAIN` 永远 true、索引永远读不到），
      表现为「本地词库用不了 / 一直加载中」，而查询本身能走到 `waitForDict`（tag=`wait`）。
    - **本工程踩的坑**：`onInit` 里
      ```js
      this.ensureKbFile();   // 异步 I/O，发起后不等 ✗
      this.probeKbFile();    // 「对照实验」读，发起后不等、2s 超时 ✗✗
      this.bootLoad();       // ← 链立刻开跑 → 并发 ✗
      ```
      ⚠️ 讽刺的是**注释里自己就写着**「必须在启动链的读操作之前，否则通道已被占死」——
      但「发起后不等」等于把占用状态带进了链里。
    - **修法**：任何前置 I/O 都必须**用回调串起来**：
      `this.ensureKbFile(function () { that.bootLoad(); });`
      并且**必须带超时兜底**（如 800ms `fin()`）—— lite 的回调不可靠，
      等不回来也要继续，否则整页卡死。**纯诊断性的读一律删掉**，别拿可用性换诊断信息。

## 跨技能提炼的 API10 通用要点（来自 hmlwskill / huawei-lite-watch-development / litewearable-api6-dev / litewearable-reference）

> 以下提炼自其他 4 个 Lite Wearable 开发 skill，**已筛选 API 10 可用、且本 skill 前文（含「参考规范引用」738-754 行）未充分覆盖** 的要点。版本专属（仅 API6/旧 Gradle 链）部分已剔除或显式标注；所有内容以「真机 > SDK 白名单 > 官方 > 演示 > 推测」为准。

### 1. 图标与资源尺寸
- 应用图标：`icon.png` = **114×114**、`icon_small.png` = **80×80**。放 `resources/base/media/`，config.json `abilities.icon` 引用 `$media:icon`。
- **图标文件体积硬约束：占用空间必须 ≤5KB**（与 48KB 页体积红线同级的重要限制）。114×114 RGBA 原始约 52KB，须用最高压缩（zlib level 9 / 导出时选最小 PNG）压到 1~2KB；**纯色块 / 少色图标最稳，照片类易超 5KB**。超 5KB 真机可能加载失败或包体超限（示例脚本 `tools/gen_icon.py` 用 `zlib.compress(..., 9)` 最高压缩，并 `print` 字节数做体积自检——实测量级 1~2KB）。
- 图片文件名必须 **英文 ASCII**（字母/数字/`_`/`-`），禁止中文、空格、全角、emoji；引用大小写须与磁盘名一致。
- 解码内存估算 `宽×高×4`（RGBA）；固定页面图放 `common/`，以 `/common/...` 绝对路径引用；`common` 对文件系统不可见，不能用 `@system.file` 读写。

### 1.1 Lite Wearable 真机安装三大硬约束（装不上/卡死的根因，优先级高于包体）
**① 型号-API 对照：`compatibleSdkVersion` 必须 ≤ 设备支持的 API**（官方 FAQ faqs-app-debugging-76）
| 型号 | 支持 API |
|---|---|
| WATCH GT 2 | API 5 |
| WATCH GT 2 Pro | API 6 |
| WATCH GT 3 | **API 6** |
| WATCH GT 4 | API 10 |
| WATCH GT 5 | API 12 |
官方明确："GT3 只支持到 API 6，不支持 API 10"。超了报 **Error 40（配置文件格式错误）** 或安装/传输时直接崩。

**② 新版 DevEco 编译的 HAP 格式，老 Lite 设备认不出来**（最常见的"卡死/装不上"真凶）
- 官方/论坛结论：**"The newer DevEco Studio compile the hap file in different format that your watch cannot understand, so you have to use old SDK for it"**。
- 用 DevEco 6.x（API 20+/23/24 SDK）构建 → GT3 这类 API 6 设备**无法解析**，表现为安装/传输时手表卡死重启、断开连接，而非干净报错。
- 对策：老设备必须用**对应旧版 DevEco + 旧 SDK**（GT3 → DevEco 3.1 + API 6 SDK）重新构建。

**③ Lite Wearable 不能直连 DevEco Studio**（官方原文）
- 因此**不能用自动签名**，只能**手动签名**（AGC 申请调试证书 + 注册设备 UDID + 下载 Profile）。
- 安装必须**手机中转**：HAP 拷到手机 `/sdcard/haps/` → 运动健康 APP 配对手表 → **应用调测助手** APP 选包安装。

**④ 包体约束**（在满足①②③后才考虑）
- Lite Wearable（GT 系列）RAM 只有几十 MB，HAP 总包体超过 ~2MB 就可能在安装时（解压+校验+写存储阶段）耗尽内存 → 设备 watchdog 触发 → 手表卡死重启 + 断开连接。
- **症状识别**：签名无效 → 报"签名校验失败"；API/版本不匹配 → 报 Error 40 或传输中卡死；确认前三项无误后仍重启，才是包体问题。
- **注意 debug 产物不压缩**：源码 700KB 的工程，DevEco debug 构建的 `*-lite-signed.hap` 可能达 **3MB**（Lite 版打成单个 `.bin`）。装机前看 `.hap` 实际字节数，别只看源码大小；改用 release 构建可显著缩小。
- **常见重量级资源**：第三方输入法/词库的 rawfile 大字典（如 crabKeyboard 拼音字典 `pinyinDictV5_20260416` 达 **3.9MB**，key6.dat 364KB、key7.dat 361KB…共 21 个文件）。原作者可能在**大内存 wearable（Watch 3/4）**上验证过，Lite 设备扛不住。
- **瘦身方案（按优先级）**：① 移除大字典，改用**内置精简兜底表**（如 `pinyinFallback.js`，约 400 常用拼音，15KB）+ 代码开关（如 `const USE_FILE_DICT = false`）**直接跳过 File.readText 查兜底表**——注意不要只删文件不关调用，否则每次查询都要空等 300ms 超时；② 词库按首字母分片 + 按需读取；③ 大字典移出工程但**保留本地备份目录**，方便恢复。
- **健康体量参考**：EnglishDict 瘦身前 4.4MB（安装卡死）→ 瘦身后约 700KB（JS 132KB + 词库 305KB + 键盘素材 198KB + 内存词库 36KB），**降幅约 90%**，Lite 真机可正常安装。

### 2. HML 组件白名单（SDK10 实测）
- 内置标签：`div canvas stack qrcode list list-item swiper tabs tab-bar tab-content image-animator image img progress text marquee analog-clock clock-hand chart input slider switch picker-view`。
- 无 `<button>`：用 `<input type="button">` 或 `div`+事件代替。
- **根元素必须且只能是 `div` 或 `stack`**（与 §参考规范引用 一致）。

### 3. 显示/黑屏补充隐患（前文未点名）
- **`<text>` 未显式 `width`+`height` 会被算成 0 尺寸 → 文字看不见**（flex 下尤其常见）。重要 text 强制固定 width/height + text-align。
- `if=false` 不构建节点不占内存；`show=false` 仍构建 VDOM 占内存 → 优先 if（与 §参考规范引用 一致）。
- 仅 `.class`/`#id` 选择器；不支持后代 `.a .b`、链式 `.a.b`、伪类/伪元素、`@media`；`top`/`left` 支持、`bottom`/`right` 不稳。

### 4. @system.file 真机验证铁律
- 错误码：202 参数 / 300 I/O / 301 不存在 / 302 文本超限（readText 默认上限 4096 B）；`access` 判存在只认 `code===301`。
- **`@system.file` **真机可用**；部分 DevEco 5.0/API10 预览器与（wearable）模拟器调不通** → file/rawfile 流程必须打包签名后上真机验证，模拟器成功/失败都不能代替结论。

#### 4.1 ⚠️ readText 单次至多 4KB —— >4KB 的文件**必须分块循环读**
这是最容易踩、且**完全没有报错**的坑（实战连续两次踩中：界面一切正常，数据却是残的）：

- 官方：`readText({uri, position, length})` —— **`length` 默认 4096**；fail 码 **302 = 要读取的文件内容超过 4KB**。
  ⇒ **不传 `length` 只拿到前 4KB**（部分固件直接 fail）。
- 典型症状：119KB 的词库只读到前 4KB ≈ 65 条；若该长度 > 自己设的 `minLen`，就被**误判成读成功**
  → 页面正常、查询全空，极难定位。
- **正解模板**（块间 `setTimeout` 让出 runtime —— 一次吞几十 KB 会卡 UI，甚至被看门狗重启设备）：

```js
function readWholeText(fileApi, uri, cb) {
  var CHUNK = 4096; var acc = ''; var pos = 0; var guard = 0;
  function step() {
    if (++guard > 256) { cb(acc); return; }          // 兜底上限 1MB
    fileApi.readText({
      uri: uri, position: pos, length: CHUNK,
      success: function (res) {
        var t = (res && typeof res.text === 'string') ? res.text : '';
        if (!t) { cb(acc); return; }                  // 空块 = 已到文件尾
        acc += t;
        pos += CHUNK;                                 // 按「请求量」推进，不按返回长度
        setTimeout(step, 5);
      },
      fail: function () { cb(acc); }                  // ⚠️ EOF 在部分固件走 fail，按「读毕」处理
    });
  }
  step();
}
```

- 三个必须记住的细节：
  1. `pos += CHUNK`（**请求量**）而不是返回文本长度 —— 部分固件返回值不可靠。
  2. `fail` 不代表失败：EOF 可能走 `fail` → 返回已累积内容，别整段丢掉。
  3. 自检「是否读全」要用**接近文件真实大小的 `minLen`**（119460 B 的文件就用 100000），
     不要用 1000 这类小值 —— 否则截断出来的 4KB 会被判成功。
- **两个真机跑通的第三方实证**（照抄即可）：
  - 某商业词典 app 的 `readNormalText`：先 `file.get({uri})` 取 `data.length`，再循环 `readText({position, length:4096})`；
  - 螃蟹键盘 `lookupDictV5.js`：读 `key*/value*.dat` 显式传 `position`/`length` 分段读。
  **两者都不是「整文件一次读」**，且都同时把 URI 写成带 `/app` 的 `internal://app/rawfile/…`。

#### 4.1b ⚠️ 「读固定小文件」也必须显式传 `length` —— 文件会长大

实战踩坑：某页要读 `dict.idx` 的头行显示词库规模，写成
`readText({ uri })` **不传 length** —— 当时索引只有 1657 B，读得动；
后来词库从 5000 涨到 11335 条，索引变成 **13799 B**，**超过 4096 的默认上限** →
`readText` 直接 **fail(302)**，界面上的数字就一直是占位符 `—`。

⇒ **规则**：`readText` **永远显式给 `length`**。
- 只要头部 → `length: 256`
- 要整块 → `length: 4096`（配 `position` 分块）
- 别指望"文件很小不用传" —— 数据会增长，这是**延迟雷**。

#### 4.1c ⚠️⚠️ 会增长的「数据文件」必须**分块读全** —— 否则一写就丢数据

**这个 bug 的后果比"少显示几条"严重得多。** 实测场景：

| 文件 | 设计最大 | 单条最大 | 总体积 | 单次读 4KB 的后果 |
|---|---|---|---|---|
| 笔记 `nx_fav.txt` | 50 条 | 302 B | **15.1 KB** | 只读到 ~13 条 |
| 历史 `nx_history.txt` | 20 条 | 302 B | **6.0 KB** | 只读到 ~13 条 |

> 单条 302 B = `oneLine(src,40)` 120 B + `oneLine(dst,60)` 180 B + 分隔符
> （中文 UTF-8 **3 字节/字**，估算体积时别按 1 字节算）

**危害链**：读方只拿到前 4KB（约 13 条）→ 用户增删一条 → `writeText` 以
「读到的 13 条」为基础写回 → **剩余 37 条永久消失**。
（数据丢失是静默的 —— 用户只会发现「我的笔记少了」。）

**正解：分块读全 helper**
```js
function readTextAll(api, uri, cb) {
  var acc = '', pos = 0, prev = '', chunks = 0, finished = false;
  function finish() { if (finished) return; finished = true; cb(acc); }
  function step() {
    if (finished) return;
    if (++chunks > 16) { finish(); return; }        // 64KB 硬上限，防死循环
    var settled = false;
    /* ★ 超时兜底：部分固件在 position 越界时**既不 success 也不 fail**（永久卡住）*/
    setTimeout(function () { if (!settled) { settled = true; finish(); } }, 300);
    api.readText({ uri: uri, position: pos, length: 4096,
      success: function (res) {
        if (settled || finished) return;
        var t = (res && typeof res.text === 'string') ? res.text : '';
        if (!t || t === prev) { settled = true; finish(); return; }  // 空块/重复块 → EOF
        prev = t; acc += t; pos += 4096; settled = true;
        setTimeout(step, 20);
      },
      fail: function () { if (!settled) { settled = true; finish(); } }   // EOF 走 fail 的固件
    });
  }
  step();
}
```
**判据**：拿「最大条数 × 单条最大字符 × 3」估体积，**> 4096 就必须分块**。
单条小文件（如 `nx_last.txt` 542 B、模式标记 14 B）不需要。

> `tools/inspect.py` 的 **⑱ 大文件分块读** 已把这条固化：
> 按条数×单条×3 估算，超 4KB 的文件若没用 `readTextAll` 就报错。

#### 4.1d ⚠️ 异步定时器要检查「页面存活」标记

项目若有 `PAGE_ALIVE`（onDestroy 置 false）之类的机制，
**所有异步 setTimeout 回调都应先判它再干活** —— 尤其是**跳转类**：
```js
setTimeout(function () {
  if (!PAGE_ALIVE) { return; }      // ★ 页面已销毁 → 不跳转/不回调
  that.setLoading(false);
  that.openDetail();
}, wait);
```
不检查的后果：用户已退出页面，定时器到点仍执行 → 跳转到已销毁页面的目标（异常/白屏）。

#### 4.2 ⚡ 但「分块读全」是下策 —— 大文件要「建小索引 + 按需读」
4KB 修好之后很容易以为万事大吉，其实**「能读全」≠「够快」**：

- 算笔账：119 KB 的词典整表分块读需要 **30 次 readText**（外加块间 `setTimeout`），
  Lite 真机上一两秒才就绪 —— 用户看到的症状是
  「**第一次查词没结果、过一会才又出结果**」（慢，但不再失败）。
- **正解** = 把「读全文」换成「**读小索引 + 按需取段**」：
  1. **构建期**生成稀疏索引（本工程每 16 行取一个采样点，格式 `<字节偏移>|<行首单词>`；
     119 KB 的词库索引只有 **1666 B**）；
  2. **运行时启动**只读索引（1 块，几乎瞬间）；
  3. **每次查询**：在采样点上二分 → 只读命中的那一段（1 块）→ 段内查找。
  ⇒ **30 次 I/O 降到 2 次**；内存也从「整表常驻 119 KB」降到「索引 + 一小段」。
- 落地时必踩的三个坑（务必照做）：
  - `position`/`length` 单位是**字节**；采样点必须落在**行首**（ASCII 字符），
    否则 `position` 会切进多字节 UTF-8 汉字中间导致乱码。
  - 只读**一段**不够：`w` 正好落在段边界时，它的候选在**下一段首行** ⇒ 一次读**两段**。
  - 「未精确命中时的前缀回退」（输入 `abando` → 应命中 `abandon`）在段内扫描里必须按
    「**第一个 > w 的行**」判断，**不是**「最后一个 < w 的行」—— 用后者会丢掉前缀命中。
  - 索引头里带上「总字节数 / 总行数 / 条目数」，运行时做完整性自校验；
    对不上就拒绝使用（宁可回退极小兜底，也不拿残缺索引静默查错）。
- **离线回归**（强烈建议）：用 Node 的 `Buffer.slice` 模拟 `readText` 的 {position,length}
  字节语义，把**全部词条 + 每个词的全部前缀**与「整表线性」结果逐条比对 ——
  上面那三类 bug 全都能在上真机前抓出来。

#### 4.3 索引分段要「贪心按字节 + 自动调优」，别按固定行数
词库从 2000 扩到 5000 后，固定行数采样的两个隐患全爆了：

- 行数翻倍 → 索引本身超过 1 块（>4KB），启动加载从 1 次 I/O 变 2 次；
- 个别超长词条（多义项可到 148B）把某些段撑爆 → 「读两段」撞上 4KB 被截断 → 静默查错。

**正解**：每段累积 ≈1.5KB 就切一刀；生成后检查「两段最大字节」，
超了就自动收小阈值重切（1900 → 1500 → 1200 → …）——
任何文件、任何行长分布都能保证两段 ≤ 4KB。

#### 4.3b ⚠️ 二分索引的「排序键 / 索引键 / 比较键」必须同一个口径

实战踩坑：词库里存 `AIDS`、`A.M.`、`Abigail` 这类**含大写的词条**，而查询侧一律 `toLowerCase()`，
结果 **329 个词查不到**。根因是二分查找要求「排序键 == 比较键」，
而这里排序（原样）与比较（小写）不一致 → 定位到错的段 → 精确匹配必然落空。

**三处必须一起改，缺一不可**：
1. **生成数据**时按 `w.lower()` 排序，并按小写键去重（`AIDS` / `aids` 只留一条）
2. **生成索引**时采样点关键词 `.lower()`
3. **段内匹配**用 `key.toLowerCase() === w`

> 同类问题还有：词形里混进 `3-D` / `blond(e)` / `fiancé` / `Absolutely!` 这类
> 带数字/括号/非 ASCII/句尾标点的词条 —— 生成时用白名单
> `^[a-zA-Z][a-zA-Z'\- .]*$` 过滤 + `rstrip('!?;,')` 清尾，否则用户永远查不到。
> **离线回归脚本要与运行时逻辑同步改**（否则测试报的"失败"其实是脚本自己的口径不同）。

#### 4.4 反向词典（中译英）= 从释义抽中文词建倒排表
只有英→中的词库做不了中译英。把每条释义里的**中文词**抽出来建倒排：

1. 按双空格拆义项 → 去词性标记（`n.` `vt.` `adj.`）→ 按标点切分；
2. 过滤噪声：数字、超长（>6 字）、**全角引号 `“”` 和书名号都会混进来，必须进黑名单**；
3. 合并成 `中文词|英文1,英文2`，按中文升序，套同一套「索引 + 按需读」。

注意：常用中文全在 BMP，Python 的 code point 排序与 JS 字符串比较（UTF-16 序）一致，
运行时可以放心二分。

#### 4.5 ⚠️ 启动期的文件/网络读取必须**串行**，且「一次性 TRIED」必须可重试
真机翻过车（离线验证全绿、真机上功能整个失效）：

- `onInit` 里同时并发发起 4 条 `@system.file` 读链（各带 `file.get` + 兜底定时器），
  Lite 上**并发文件 I/O 会互相干扰**（失败甚至不回调）；
- 而 `XX_TRIED = true` 是一次性的 → 失败的那条索引**永远不再加载** → 功能永久失效；
- 叠加 bug：某条索引「就绪后重翻」的逻辑只在英文分支有、中文分支漏抄 →
  首次查询落在就绪前就一直显示「查不到」。

**正解**：
1. 启动读链**回调接力串行**：A(done) → B(done) → C(done) → 恢复偏好；
2. 读链失败（空 / 解析不过）时**回退 TRIED**，并在 `onShow` 里补漏
   （`!SAMP && !TRIED` 就再试；用 `BOOT_CHAIN` 标志防止串行链还在跑时插队）；
3. 每条索引就绪后都要**重翻一次当前输入**（每个分支都别漏）。

#### 4.6 列表页 / 多页协作的可靠写法（真机验证过）
- **列表**：`list > list-item > (单个 div) > 文字…`，`for="{{rows}}"` 绑在 **list-item** 上。
  ⚠️ **list-item 只能有 1 个子节点**，多行内容必须包一个 div；点击事件绑在这个 div 上。
- ⚠️⚠️ **`list-item` 与普通容器同样严格：子节点是 `div` 时，`width` + `height` 都必须写死。**
  实测对照：主页 `.mi-item` **340×60（两样都有）→ 正常**；
  设置/关于的 `.st-item` / `.ab-item` **只给了 width → 整块空白**。
  注意上游键盘页 `.alert_item { width: 100%; }` 只给宽度也能工作 ——
  那是因为它的子节点是**原子组件 `text`**（能自己撑开）；**一旦子节点是 `div`，两个尺寸都必须给**。
  （上一版 skill 曾据此写成"list-item 只给 width 就够"，属**误判，已修正**。）
  ⇒ **尺寸四条铁律**：
  ① 普通 div 容器要 `width` + `height`；
  ② `.page` / `.bg-*` 的尺寸由 HML `style` 注入，CSS 里别再写；
  ③ **`list-item` 的子节点是 div 时，也要 width + height**；
  ④ **圆屏底部元素：宽度 ≤ 2×√(R² − y²)**（R=233），超了会溢出表盘 ——
     症状看着像"没居中"，实际是物理宽度不够（实测 y≈169 时只剩 ~320px）。
- ⚠️⚠️ **`list` / `list-item` 自带黑色背景**。页面底色**不是黑**的时候，必须显式写
  `background-color: transparent`（或给具体色），否则整块 list 区域会变成**一片纯黑**、
  内容完全看不见 —— 症状很像「内容没渲染」，极易误判。
  （上游 CrabKeyboard 的 `.alert_list` / `.bar_pyList` 都显式写了 transparent，说明作者也踩过。）
  在纯黑页面上不会有任何异常，所以**只有换浅色底时才会突然爆发**，属于延迟雷。
- ⚠️⚠️ **凡是 div 容器，`width` 和 `height` 都要写死 —— 两个都要，缺一个就可能整块不渲染。**
  实战踩过：一个 `flex-direction: row` 的并排容器只写了 `flex-direction`/`justify-content`、
  没写尺寸，结果**整块连同里面的按钮集体消失**；而同一页里自己写了宽高的按钮全都正常。
  **症状识别**：某个区域里的元素「集体不见」，但同页其他元素正常 → 先怀疑容器尺寸。
  **排查顺序**：**先查尺寸（width + height 是否都在），再查方向（`row > column` 嵌套）**——
  实战中先改方向、没解决问题，白花一轮。
  **审计脚本**（改完 CSS 必跑）：扫 `<div class="...">` 里的每个 class，去 CSS 同名块里
  检查 width/height 是否都存在；注意 `class="pill pill-quad pill-blue"` 这种多 class
  要**合并判断**，只看第一个会误报。
- **事件传参**：`on:click="pick($idx)"` → `pick: function (idx)` —— `$idx` / `$item`
  直接作为第一个参数传入。这是上游 CrabKeyboard 候选词用的写法（真机可用），
  比裸名 `onclick` 更适合需要索引/数据项的场景。
- **并排按钮**：`column(页面) > row > 按钮 ×N`；按钮固定宽度（半宽常配两套文字宽度，
  例如按钮 155px 配文字 135px）。**别用百分比宽度** —— lite 不用百分比。
- **页面间传值 / 回填**：`Router.replace({ uri, params })`，目标页在 `onShow` 里
  从 `data.<key>` 取（params 会按 key 注入同名 data 字段）。
  「历史页点一条 → 带回主页自动重译」就是这么复用的（与键盘回填同一链路）。
- ⚠️⚠️ **「异步写文件 → 立刻跳页读同一个文件」必须用回调串起来。**
  实测踩坑：翻译成功后 `writeText` 落盘是**异步**的，代码却紧接着 `Router.replace` 去详情页，
  详情页 `onInit` 读到的是**旧数据** —— 表现是「搜出来没结果」，极容易被误判成查询逻辑坏了。
  正解 = 把写盘函数改成 `writeXxx(..., cb)`，**写完（或失败）再跳**；
  另挂一个 `setTimeout(..., 300)` 兜底，防止回调不触发时把用户卡在原页。

#### 4.5a ⚠️ CSS 里这些选择器**全部不能用**（硬错 BUILD FAILED）

实测报错形如：
```
Error Code: 00308018 Unknown Error
File: pages/about/about.css:61:1
The `.text_container.icon` selector is not supported.
```

| 禁用写法 | 替代 |
|---|---|
| **复合选择器** `.a.b` | **拆成独立类名** `.a-b`，HML 里 `class="a-b"` |
| 子选择器 `>` / 兄弟 `+` `~` | 拆类名 |
| 属性选择器 `[attr]` | 拆类名 |
| 伪类 `:hover` `:active` `:nth-child()` `:first-child` `:not()` | **同族差异一律用独立 class**（`.item-0` `.item-1`…） |
| `:before` / `:after` | 用真实的子节点 |

> ⚠️ 注意：**`.a.b` 这种复合选择器和「多 class 同时写在一个标签上」不是一回事** ——
> 后者 `class="pill pill-quad pill-blue"` 是**允许**的（lite 会合并命中），
> 只有**在 CSS 里用 `.a.b` 去同时匹配**才不允许。
> `tools/check_code.py` 已内置这条检查（正则 `\.[\w-]+\.[\w-]+\s*[,{]`），改完 CSS 必跑。

#### 4.5a2 ★ 抄原包时注意「带图标行 vs 不带图标行」两套容器宽度

原包同一类名在不同页有**两种值**，抄错就会「文字不居中」：

| 用途 | `.text_container` |
|---|---|
| **右侧有图标/开关**的行（settings 页） | `width: 70%` + **`margin-left: 40px`** ← 给右侧元素留位置 |
| **没有右侧元素**的行（wordbook 页） | `width: 100%`，**无** margin-left |

实测踩坑：整页套了 settings 那套，但本页大多数行没有右侧图标 →
`margin-left: 40px` 把文字往右推 → 看着不居中。
**正解**：默认用 100%；只有确实带右侧图标的行，才给它一个独立类名走 70%+ml40。

#### 4.5a3 ★★ 抄原包的写死尺寸前，先算「本设备上该容器的实际宽度」

**这是「图标/文字被裁」的最大来源。** 本项目同时支持两种屏幕：

| 屏幕 | 卡片 `.background`（宽 90%）| 差 |
|---|---|---|
| 圆表 466 | 419px | |
| 方表 408 | **367px** | **−52px** |

原包（466 设计）里写死的 `icon 92 + text 252 + right 56 = 400`：
在圆表刚好塞下，**在方表直接溢出 33px → 图标被裁**。
同理 `.word { width: 380px }` 在方表卡片（367）里也溢出。

**规矩**：
1. **卡片/容器内的宽度一律用百分比**（`50%` / `56%` / `90%`），只有图标这类
   需要固定视觉尺寸的才写 px，**且按最窄的方表取**（宁小勿大）。
2. 抄完原包后**逐个算一遍**：`Σ(子元素宽度) ≤ 容器实际宽度`（方表口径！）。
3. 字号也降一档（本项目 38 → 34），窄屏才不挤。

> 排查工具：本项目 `tools/check_code.py` 的 **H 检查** ——
> 「卡片内元素写死 `width: NNNpx` 且 > 367」直接报错。
> ⚠️ 写这类检查别用「整段正则匹配类块」（会漏报），**用逐行扫描 + 类名状态机**。

#### 4.5a4 ⚠️ `.background` 这类卡片容器**必须显式写 flex 方向与居中**

```css
/* ✗ 只写尺寸和配色 → 内容无排布规则 → 乱排/被裁 */
.background { width: 90%; height: 140px; background-color: …; border-radius: 30px; }
/* ✓ */
.background { width: 90%; height: 140px; …;
              flex-direction: row; justify-content: center; align-items: center; }
```
本项目踩过：主页/设置/关于三页的卡片漏写 flex → 图标被裁、内容乱排；
而历史/笔记页写对了 `column + center` 就正常。
**卡片里横排用 `row`、竖排用 `column`，两种情况都要带 `justify/align: center`。**

#### 4.5b ★ 方表 / 圆表适配：别只信 `screenShape`，要加宽高比兜底

```js
// ★ 只用几何事实（宽高比）；**不要用 screenShape**
var isRect = (h > w + 10);          // 方表 408×480；圆表 466×466 / 454×454
```
- 方表 **408×480**（高明显大于宽）；圆表 **466×466 / 454×454**（宽高相等）→ 判据很稳。
- ⚠️⚠️ **`screenShape` 不可信 —— 实测预览器在圆形设备（454×454）上返回了 `'rect'`（错的）。**
  所以**绝对不能**写成 `(shape === 'rect') || (h > w + 10)` 这种 **OR** 判定：
  一旦设备报错，OR 左支恒真 → 宽高比兜底**永远轮不到** → 直接误判成方表。
  （我踩过：OR 版本让圆形设备被判成"方表 454×454"，走了方表键盘。）
- 想同时观察原始值，就把 `screenShape` 一起显示在诊断行里（如 `shape=rect`），便于定位设备报错。
  实测后果：方表套用**圆表键盘** —— 两套键盘的确定键位置是各自写死的
  （圆表 `.confirm{top:70;left:360}`，方表 `top:14;left:293`）→ 方屏上确定键贴边且被键盘底图盖住
  → **点不中、按确定没反应**。表现像"输入法坏了"，其实是形态没判对。
- **适配自检**：把检测到的形态+尺寸显示在某页（如"关于"页）上，一眼可验，别靠猜。

#### 4.5c 从 466 圆屏抄来的写死尺寸，方屏会溢出
原包（466 设计）里 `.background { width: 420px }` 这类值，在 **408** 宽的方屏上直接溢出
（420 > 408）。**换算成百分比**即可两边通吃：`466 × 90% = 419.4 ≈ 420` → 写 `width: 90%`
（圆屏数值等价、方屏自动收窄）。**抄原包后一定要全量扫一遍 >408px 的 width/left。**

#### 4.5c2 ⚠️⚠️ `stack` 子节点**不认百分比尺寸** —— 遮罩/浮层必须 HML 注入屏幕尺寸

**铁律再说一遍**：`stack` 的直接子节点用 `width:100%; height:100%` 会解析成 **0** ⇒
整个浮层渲染成 0×0、**等于不存在**（不报错、也看不见，极难查）。

```html
<!-- ✗ 遮罩不显示（100% 无效） -->
<div class="mask" if="{{show}}"> ... </div>
<!-- ✓ 注入真实尺寸 -->
<div class="mask" if="{{show}}"
     style="width: {{screenW}};height: {{screenH}};top: 0px;left: 0px;"> ... </div>
```

**更稳的做法：用「互斥替换」而不是「叠加」**
```html
<list if="{{!loading}}"> …正常内容… </list>
<div class="loading" if="{{loading}}" style="width:{{screenW}};height:{{screenH}};top:0;left:0;"> …加载… </div>
```
互斥渲染还能顺带避开 **`stack` 子节点层叠顺序**的不确定性（叠加时可能被下面的内容盖住）。

⚠️ **连带副作用**：`if` 切换会**重建节点** ⇒ 之前设过的状态会丢。本项目踩到：
加载遮罩收起后 `<list>` 是**新节点**，`rotation({focus:true})`（表冠焦点）失效 ⇒
**必须在新节点出现后重新 `crown(true)`**。做法：把开关收敛成一个 `setLoading(v)`，
在 `v=false` 分支里顺手重设表冠。

#### 4.5c6 ⚠️⚠️ 兜底通道的「一次性文件」必须**消费即清**，否则会误触发死循环

本项目实测的严重 bug（表现：**详情页点返回/右滑 → 又进加载中 → 又跳回详情页，退不出去**）：

**场景**：主页有两条回填通道 —— ① `Router` 的 `params`（主）② `xxx_input.txt` 文件（兜底）。
**坑**：只在「走文件通道」时才清空文件。若 `params` 成功（正常情况），
文件**从未被消费**、一直留着 →

```
详情页返回 → 主页 onShow → params 为空 → 读文件（有残留！）
           → 触发一次翻译 → 加载中 → JUMP 又跳详情页 → 死循环
```

**修法（两道都要）**：
```js
if (paramsValue) {
  this.clearChannelFile();     // ★ 通道成功时也要清，不留残留
  apply(paramsValue);
  return;
}
readChannelFileWithRetry(0);   // 只有 params 为空才走文件
```
```js
// ★ 清两次：来源页是「异步写文件 → 立刻跳转」，
//   若它的写入晚于本次清空落地，文件会被写回 → 残留依旧
clearChannelFile: function () {
  var wipe = function () { writeText({ uri: FILE, text: '' }); };
  wipe();
  setTimeout(wipe, 600);
}
```

**通用原则**：凡是「文件当一次性消息队列」的写法，
**读方必须无条件清空（无论是否走了别的通道）**，且要用「延迟二次清空」盖过
「发送方异步写入 vs 接收方清空」的竞态。

#### 4.5c4 ⚠️ 跨页「写文件 → 立刻跳页」必须让**读方延迟重试**

本项目**踩过两次同一个坑**，位置不同、原因一样：

| 第几次 | 写方 | 读方 | 症状 |
|---|---|---|---|
| 1 | 翻译完写 `nx_last.txt` | 详情页 `onInit` 读 | 「搜出来没结果」 |
| 2 | 历史页写 `nx_tr_input.txt` → 跳主页 | 主页 `onShow` 读 | 「点历史条目卡在主页，什么都没发生」 |

**根因**：`writeText` 是**异步**的，跳转是**立即**的 —— 读方执行时数据还没落盘。

**两种正解（按场景选）**：
1. **写完再跳**：把写盘函数改成 `writeXxx(..., cb)`，`cb` 里再 `Router.replace`
   —— 适合「跳转由写盘结果决定」的场景。
2. **读方延迟重试**（更通用）：
```js
function readWithRetry(attempt) {
  if (attempt > 3) { return; }
  file.readText({ uri: URI, length: 256,
    success: function (res) {
      var v = (res && res.text) ? trimStr(res.text) : '';
      if (!v) { setTimeout(function () { readWithRetry(attempt + 1); }, 140); return; }  // 还没写完
      file.writeText({ uri: URI, text: '' });   // 取到即清空，防重复触发
      apply(v);
    },
    fail: function () { setTimeout(function () { readWithRetry(attempt + 1); }, 140); }
  });
}
readWithRetry(0);      // 4 次 × 140ms ≈ 560ms 覆盖绝大多数情况
```
> 成本极低（几次 256B 小读），收益是**彻底消除这类偶发失败**。
> 凡是跨页的文件传递，读方一律加「延迟重试」。

#### 4.5c5 ⚠️ 抄上游组件时：它的「必填参数」默认值是**空串**，会静默失效

上游 crabKeyboard 的 `data`：
```js
targetPage:'',    // 注释写着"必填"
backPage:'',
targetKey:'',     // 注释写着"必填"
```
平时靠调用方用 `Router.replace({params})` 覆盖；**一旦 params 注入失效，它们就是空串** →
组件内部 `Router.replace({ uri: '' })` **什么都不发生、也不报错**。

⇒ **引入第三方组件时，把这类「必填但默认空」的字段填上本工程的默认值**，
作为 params 失效时的兜底（本项目已填 `/pages/index/index` + `trInput`）。
**这是允许的改动**（与自己写死业务无关，属健壮性加固），记在组件的改动清单里。

#### 4.5c3 ⚠️ 跨页回填别只信 `Router` 的 `params` —— 要加文件兜底

`Router.replace({ uri, params })` 的 **params 注入在部分设备/仿真器上会失效**。
症状：**源页写了、目标页什么也没收到**（表现为"点了没反应、什么都没发生"）。

**双通道写法**（本项目键盘→主页回填就是这么修的）：
- 源页：`Router.replace` **之前**把内容写进 `internal://app/xxx.txt`
- 目标页 `onShow`：params 取不到 → 读该文件；读到后**立刻清空**（防下次重复触发）

#### 4.5d ★ 加载界面「看得见」：**最短显示时间必须同时管住跳转**

需求：输入完先显示加载界面，再出结果。**只做遮罩最短显示是不够的** ——

```js
// ✗ 错误：遮罩安排 500ms 后关，但跳转立刻发生 → 页面切走了，遮罩等于没显示
hideLoading(); openDetail();

// ✓ 正确：跳转也在同一个定时器里、按同一个基准时间延后
var held = LOADING_T0 ? (nowMs() - LOADING_T0) : LOADING_MIN;
var wait = Math.max(0, LOADING_MIN - held);
setTimeout(function () { that.loading = false; that.openDetail(); }, wait);
```

**为什么必须这样**：本地/离线查询只要**几十毫秒**就出结果 ——
不等的话遮罩刚亮（甚至还没绘制）页面就换走了，用户完全看不到加载界面
（实测就是这样被反馈「没有加载界面」的）。

配套要点：
- `LOADING_MIN` 取 **400~600ms**（500 较合适）：足够看见，又不拖沓；
  慢查询（联网 800ms+）自然满足，`wait` 会算成 0、不额外延迟。
- **失败分支**（查不到）：把文案换成提示、停 ~1.2s 再收起遮罩回到主菜单，**不跳详情**。
- 多个异步定时器（最短显示 / 兜底超时 / 失败提示）要加 **序号令牌**防串扰：
  每次查询 `SEQ++`、闭包自己的 `seq`，只有 `seq === SEQ` 时才允许收起 ——
  否则用户快速连查两次，上一次的定时器会把这一次的加载界面误关。

#### 4.6a ★★★ 表冠：官方有**两条**途径，按 API 版本选

**权威依据**：`<SDK>/default/openharmony/js/api/@internal/lite/viewmodel.d.ts` 与 `global.d.ts`

| 途径 | 签名 | since | 适用 |
|---|---|---|---|
| **A. 组件 `rotation()`** | `ListElement.rotation(obj?: FocusParamObj)`<br>`SwiperElement.rotation()` / `PickerElement.rotation()` | **API 4** | ✅ 本项目（API 10）用这条 |
| **B. 全局监听器** | `setMonitorForCrownEvents(handler)`<br>`clearMonitorForCrownEvents()` | **API 24** | 新设备（≥24）；本项目**不适用** |

`FocusParamObj = { focus: boolean }`；官方注明 `rotation` 的 `focus` **可省略，默认 true**。

> ⚠️ 途径 B（API 24）的三个官方约束（将来升级到 24 再参考）：
> ① 只能在页面的 `onShow` 里注册；② **页面被 push/replace 时监听会自动移除**；
> ③ **每个页面只能有一个监听**，后注册的覆盖先注册的；
> ④ **不要在 app.js 里调**（行为未定义）。

**光有 `<list>` 是不会被表冠滚动的** —— 必须显式把表冠焦点交给它。
（这是实测反编译商业应用 Weardict 才拿到的写法，之前一直以为 list 天生支持表冠。）

```hml
<list class="list" ref="list" onswipe="handleSwipe"> ... </list>
```
```js
onShow: function () { this.crown(true); },      // 进入页面：列表接管表冠
onHide: function () { this.crown(false); },     // 离开页面：释放

crown: function (on) {
  var that = this;
  setTimeout(function () {                      // 50ms 等节点就绪
    var el = that.$refs && that.$refs.list;
    if (el && el.rotation) { el.rotation({ focus: !!on }); }
  }, 50);
}
```

**lite 的 `<list>` 有两个方法**（`$refs` 拿到实例后调用）：
| 方法 | 作用 |
|---|---|
| `rotation({ focus: true/false })` | **把表冠焦点交给该 list**（不调就滚不动）|
| `scrollTo({ index: N })` | 滚动到第 N 项 |

- `ref="list"` 是前提；**每个需要表冠滚动的页面都要在 `onShow` 里开、`onHide` 里关**。
- 页面多时建议把 `crown(on)` 抽成公共方法（本项目 6 个页面共用同一份实现）。
- 配套：`slider` 也能拿表冠（`<slider on:change="listenCrown">`，键盘页就是这么用的），
  但**列表用 `rotation` 更省事**，不用自己做位置换算。

#### 4.5c7 ⚠️⚠️ 往 `onShow` 加「会碰文件」的代码前，先确认它是否与启动链并发

**这是本项目最贵的一次事故**：症状「**本地词库用不了、联网正常**」——
离动机（"加个模式同步"）非常远，属于典型**延迟雷**。

**背景**：`onInit` 里有一条严格串行的启动链（lite 的 file I/O 必须串行）：
```
loadPhraseTable → loadDictIdx → loadDictCnIdx → loadHistory → BOOT_CHAIN=false → restoreTrMode
```

**事故**：后续几轮陆续往 `onShow` 里加了三个文件操作，全都**没检查 `BOOT_CHAIN`**：
| 加的调用 | 目的 | 后果 |
|---|---|---|
| `restoreTrMode()` | 从设置页返回同步模式 | 无条件执行，插队读文件 |
| `readTrInput()`→`readTrInputFile()` | 键盘回填的文件兜底 | 每次 onShow 读文件 + 重试 4 次 |
| `loadDictIdx()` + `loadDictCnIdx()`（并列） | 补漏重试 | **两条并发发起**（不是串行） |

⇒ 首次进入时启动链刚起，`onShow` 立刻插进 2~5 个 file 读 → **`dict.idx` / `dict_cn.idx` 读失败**
→ 索引为空 → 本地查词走极小兜底 → 报「未收录」。**联网路径不依赖索引所以完全正常**。

**修法模板**：
```js
onShow: function () {
  if (!BOOT_CHAIN) {                      // ★ 启动链在跑 → 一个文件读都不许发
    if (!DICT_SAMP || !CN_SAMP) {
      this.bootLoad();                    // ★ 索引不全 → 走**完整串行链**（别分散并发！）
    } else {
      this.restoreTrMode();               // 索引齐了才做别的文件操作
    }
  }
  this.readTrInput();                     // 内部：params 路径安全；文件路径需再判 BOOT_CHAIN
}
```
另外两条容易漏的：
- **`onInit` 必须重置 `BOOT_CHAIN = false`** —— 页面重建时清掉旧链标记。
  旧链随页面销毁而中断（`PAGE_ALIVE=false`），不清的话 `bootLoad` 会以为「已在跑」而永不启动。
- **把启动链封装成幂等的 `bootLoad(done)`**，`onInit` 调一次、`onShow` 兜底也调它，
  各 `loadXxx` 内部有 `TRIED` 锁保证重复调用立即返回。

**诊断口诀**：「联网能用、本地不能用」= **索引没加载成功**（索引只服务本地词库）。
再补一条体验细节：**索引未就绪时不要报「未收录」**（那是误报），
应显示「词库加载中…」并等它就绪（`loadXxx` 尾部本来就有「就绪后自动重翻」的逻辑），
超时再报失败。让用户能区分「没加载完」和「真没这个词」。

> 本项目已把这条铁律固化成自动检查：`tools/inspect.py` 的 **⑭ 启动期串行**
> （检查 onShow 守卫 / readTrInput 守卫 / bootLoad 是否嵌套串行 / onInit 是否重置标记）。

#### 4.5c7b 官方可用的**全局函数与常量**（`@internal/lite/global.d.ts`）

```
setInterval / setTimeout / clearInterval / clearTimeout     // since 5
canIUse(syscap: string): boolean                           // since 8
getApp(): object                                           // since 10
setMonitorForCrownEvents / clearMonitorForCrownEvents        // since 24
const STANDARD / LITE                                      // 条件编译常量
```
> `LITE` / `STANDARD` 是**条件编译常量**，可用于「同一份代码兼容 lite 与标准设备」。

另：**`@system.storage` 是官方支持的 lite API**
（`@syscap ...Preferences.Core.Lite` + `@reserved ["liteWearable"]`），
属于官方推荐的轻量持久化手段 —— 但本项目实测在真机上也不稳定，
故仍以「应用级状态为主、文件/存储为辅」为准（见 4.5c8）。

#### 4.5c8 ⚠️⚠️ lite 的文件 I/O 两个致命特性：**不可靠** + **不能频繁**

用户在**真机**上实测确认（不是仿真器局限）：

| 特性 | 后果 | 对策 |
|---|---|---|
| **写入会失败**（真机也偶发）| 状态存不下来（如「选了本地模式、回主页仍是联网」）| **跨页状态放应用级全局**，文件仅作辅助 |
| **频繁/并发调用会卡死页面** | 点一下列表项就卡死 | **严格限制调用时机与次数** |

**(0) 先看官方给的持久化钩子**（`Options<T>` 接口，since 10）：
```js
onSaveData?(data: Object): boolean;    // 需要保存用户数据时调用，返回是否成功
onRestoreData?(data: Object): void;    // 需要恢复用户数据时调用
```
这是官方为「应用级数据存/读」提供的标准钩子，**优先于自己拼文件**。
上游 Weardict 另用 `$app.addAllParams / getAllParams / cleanAllParams` 做运行期跨页共享
（反编译统计各 6 处），可作参考。

**(1) 跨页状态：优先应用级全局，不要只靠文件**
```js
// app.js 的导出对象上挂字段（getApp() 返回它）—— 上游 Weardict 用 $app.addAllParams 同源
export default { trMode: 'net', onCreate() {...} };
// 页面里：
function appModeGet() { try { var a = getApp(); return (a && a.trMode) || ''; } catch (e) { return ''; } }
function appModeSet(m) { try { var a = getApp(); if (a) { a.trMode = m; } } catch (e) {} }
```
读用「全局优先 → 文件降级」，写用「全局必写 + 文件尝试」。

**(2) 文件读写的调用要克制** —— 实测两个卡死来源：
- **分块读的终止条件不能依赖「越界 position 的返回」**：真机对越界 position 的返回不可控
  （可能回容错内容，既不空也不等于上一块）→ 判定 EOF 失败 → **死循环**。
  ⇒ 正解：**先读第一块，长度 < 4096 就是读完了，立即收工**（绝大多数情况零额外 I/O）；
  真要分块时用**累计字节数 / 块数 / 每块超时**三重硬上限兜死。
- **别在「点击列表项」这种高频路径上写文件**：
  本项目 `pick()` 曾同时「写文件 + 跳转」，主页 onShow 又「读文件 + 4 次重试」
  → 频繁 I/O → 卡死。**同进程页面间传值用 `Router` params 就够了**，
  文件兜底只留给真正跨进程/参数不可靠的场景（如系统键盘页），并用标记位严格限定时机。

#### 4.7c ⚠️⚠️ 「脚本打印 ✓」≠「改动生效」—— 必须独立验证

**本项目反复踩的自身坑**（同一类事故发生三次）：
- 批量替换脚本打印「✓ 已改为分块读」，实际文件**根本没改**（旧文本不匹配但没 assert）
- helper 注入「一半成功一半失败」（index 失败、setting 成功），脚本没报错
- 替换 CSS 时**误删了相邻类**（`.settings_tips` 被吃掉）→ HML 有元素、无样式 → **文字不渲染**

**⇒ 铁律：任何文本替换后，用与脚本无关的方式再验一遍**
```bash
# ① 改完 → 数「定义 / 调用」的数量
grep -c '^function appMode' pages/index/index.js pages/setting/setting.js
# ② 删完 → 确认目标确实不存在
grep -n 'nx_tr_input.txt' pages/history/history.js   # 应为空
# ③ 涉及「加样式 / 加方法」时，检查成对存在
grep -c 'settings_tips' pages/setting/setting.hml pages/setting/setting.css   # 两个都要非 0
```
> 本项目已把 ③ 固化为 `tools/inspect.py` 的 **⑲ class 样式定义**：
> HML 里用到的每个 class，CSS 必须有定义 ——
> **「用了但没定义」在 lite 上不报错、只是不渲染**，是最隐蔽的一类 bug。

#### 4.7d ★ 跨页共享状态：多通道 + 闭包兜底，别赌单一通道

**官方定义（`@internal/lite/global.d.ts`）**：
```ts
export declare function getApp(): object;   // since 10
//   "Obtain the objects exposed in app.js" —— 取 app.js 暴露的对象
```
`$app` 则是 lite 的**编译期全局注册对象**（上游 Weardict 用它做跨页共享：
`$app.addAllParams / getAllParams / cleanAllParams` 各 6 处）。

**实践结论**：两者都可用、但**在真机上都可能拿不到**
（本项目实测）⇒ 策略是**多通道 + 闭包兜底**：
写时全都写，读时逐个试，任一命中即可，**且绝不赌文件**。
代码示例（保留 try/catch 作防御 —— 探测式访问静态检查器不会报错）：

```js
var MEM_MODE = '';                                                  // ③ 闭包兜底
function appModeGet() {
  try { var b = $app;  if (b && b.trMode) return b.trMode; } catch (e) {}    // ① Lite 主力
  try { var a = getApp(); if (a && a.trMode) return a.trMode; } catch (e) {} // ② 官方 API（since 10）
  return MEM_MODE;                                                          // ③
}
function appModeSet(m) {
  MEM_MODE = m;
  try { if ($app) $app.trMode = m; } catch (e) {}
  try { var a = getApp(); if (a) a.trMode = m; } catch (e) {}
}
```
顺便再次强调 4.5c8 的结论：**`$app` 还不靠谱时就再兜一层闭包变量** ——
**跨页状态绝不要只靠文件**（lite 文件持久化真机也失败）。

#### 4.6b ★ 右滑返回上一页（真机验证过的写法）

```hml
<list class="list" onswipe="handleSwipe"> ... </list>
```
```js
handleSwipe: function (e) {
  if (e.direction === 'right' && e.distance >= 150) { this.goBack(); }
}
```

- 事件参数：**`direction`（'right'/'left'/'up'/'down'）+ `distance`（像素）**；
  阈值 **150** 是商业应用（Weardict）全页统一的经验值。
- ⚠️ **挂载点必须是 `list` 或 `stack`**，不要挂 `div` ——
  `div` 的 onswipe 在真机上不触发（本工作簿另一工程实测过）。
  有列表的页面挂 `<list>`，无列表的页面（如启动页）挂 `<stack>`。
- 该应用**每个子页都实现了右滑返回**，这是手表应用的用户预期，建议作为标配。

#### 4.7a ⚠️⚠️ 检查脚本必须**落盘成文件**再跑 —— bash heredoc 会吞掉反斜杠

**这是「检查结果不可信」的元凶。** 实测：
```bash
python - << 'PY'
import re
m = re.search(r'data:\s*\{', js)   # ← 真正执行时是 'data:s*{' —— 正则已失效！
PY
```
bash 的 heredoc（**即使加了引号 `<< 'PY'`**）在本环境下会吃掉反斜杠 →
`\s` / `\b` / `\.` 全部失真。后果：
- `data:\s*\{` 匹配不到 → 误报「找不到 data」
- `\b方法名\b` 匹配不到 → **误报一大堆「死方法」**
- 含反斜杠的 Python 三引号字符串甚至会让整个 heredoc 破裂、报一串 `command not found`

⇒ **凡是含正则 / 转义的脚本，一律用 Write 工具写成 `.py` 文件再 `python xxx.py` 运行**，
绝不在 heredoc 里写。没有把握时用不含反斜杠的写法（`[ \t]`、`[^}]*`、`str.find`）。

> 本项目已把检查固化为**落盘脚本**（可信、可重复）：
> - `tools/inspect.py` —— 11 类全面体检：
>   JS 语法 / HML 标签配对 / CSS 禁忌（复合选择器·calc·rgba·position·伪类·gap）/
>   事件方法存在 / HML 绑定字段 ∈ data / 方法重复定义 / **死方法** /
>   容器尺寸（div 宽高、list-item 宽）/ 卡片内固定宽度超方屏 / 路由注册 / 图片资源
> - `tools/check_code.py` —— 轻量版
> - `tools/simulate_flow.js` —— 端到端链路模拟（node 里跑查询链路）
> - `tools/test_dict_idx.js` —— 词库索引回归

#### 4.7b ★ 删方法时注意别吃掉下一行的缩进

写「删除整个方法」的脚本时，清理尾随字符的循环容易写成：
```python
while end < len(s) and s[end] in ',\t\n':    # ✗ 把下一行的前导空格也吃了
    end += 1
```
后果：被删方法的**下一个方法变成顶格**（`openHistory: function` 丢掉两个空格缩进）。
⇒ **只吃 `,` 与换行，不吃空格和 tab**（那些属于下一行的缩进）。
删完务必复查：`grep -n '^[a-zA-Z_$][A-Za-z0-9_$]*: function'` 结果应为空。

#### 4.7 ★ 改完代码先跑两个离线工具（不用真机就能定位大半问题）

**① 静态体检**（本项目 `tools/check_code.py`）—— 一次扫所有页面的 7 类坑：
回调里误用 `this` / HML 绑定了 data 里不存在的字段 / `onclick` 方法没定义或重复 /
CSS 禁忌（`calc()` `rgba()` `position:` 伪类 `gap:` 百分比）/ div 容器缺 width 或 height /
list-item 缺显式背景 / 文案含裸 `|`。

> ⚠️ 脚本自身极易误报，写时注意三点：**data 解析要支持「单行多字段」**；
> `{{$item.x}}` 里的 x 是 `for` 局部变量要整体跳过；`.page` / `.bg-*` 的尺寸由 HML 注入、要白名单。

**② 端到端链路模拟**（本项目 `tools/simulate_flow.js`）—— 把页面 JS 的核心算法
（`dictParseIdx`/`dictSegIndex`/`dictFindInSeg`/`phraseFind`/`hasCjk`/`writeLast`/`loadLast`）
**复刻到 node 里跑一遍**，用若干代表性输入验证「输入 → 判定方向 → 查库 → 写存储 → 目标页解析」全链路，
并断言**字段数对齐**。

> **为什么值得写**：数据/字段层面的 bug（「查不到」「详情页空白」）在真机上只表现为"没结果"，
> 根本看不出断在哪一步；离线模拟能直接打印每一步的值。实测 9 个用例
> （中文短语 / 中文词 / 英文单词 / **英文词组** / 大写词 / 中文句子）全通。

**③ 遇到「查不到」先查数据、再查代码**：先统计数据的实际形态（总条数、含关键特征的条数、样例）。
本项目「英文词组查不到」正是靠数据统计才定位到 —— `含空格的短语 = 0 条`
（合并数据时被一行 `if ' ' in word: continue` 整批跳过，代码本身没问题）。
- **构建被签名卡住**（报 `00303107` / profile 文件不存在）：备份 `build-profile.json5`，
  临时把 `signingConfigs` 清空、并删掉 products 里的 `signingConfig` 引用 →
  即可产出 **unsigned 包**继续验证；恢复时用原 `.p12` + `.csr` 去 AGC 重新申领 p7b/cer。
- **跨页传数据别用路由 params**：长文本/非字符串类型在 params 上不稳（会截断或类型丢失）。
  正解是「写一个应用内小文件（`internal://app/xxx.txt`），目标页 `onInit` 读它」。
  多个页面复用同一份数据时尤其划算（如「详情页读最近一次翻译结果」）。
- **列表页/详情页的滚动**：`list` 是 lite 原生可滚动组件，**表冠滚动是白送的**；
  列表区记得给**固定高度**。底部操作按钮排一行 3 个比排两行省 44px 纵向空间。
- **核对产物只看两样：hap 时间戳 + bin 里的内容特征串**（别只看文件大小）。
- ⚠️⚠️ **lite 打包出的包只增不减：删过资源后必须清 `build` 目录全量重建。**
  实测：删掉 357KB 的壁纸后**增量构建，HAP 字节数毫无变化**（8782401，一模一样，
  很容易误判成「没重新打包」或「固定容量镜像」）；`rm -rf entry/build` 全量重建后
  → **7.15MB（-1.23MB）**，连更早的废弃资源都一起清掉了。
  ⇒ ① **判断包体积必须用全量重建的数据**；
  ② 想瘦包 = 删资源 + clean 重建（把 `clean` 做进构建脚本，别靠人记得）；
  ③ 「改小图标 / 删文件后 HAP 不变」是**增量构建的假象**，不是固定容量镜像。

### 5. 构建产物路径与只读审计
- 编译产物（**API≥10**）：`entry/build/default/intermediates/loader_out_lite/...`（API<10 是 `intermediates/js/release/source/lite`）。
- 只读审计脚本（本 skill 自带）：`scripts/audit_lite_watch_project.ps1`（或 `scripts/project-reviewer/run-reviewer.bat`），参数 `-ProjectPath <项目> -TargetHeapKB 64 -TargetApi 10`（社区脚本原文示例多写 `-TargetApi 6`，**API10 工程请填 10**；`-TargetHeapKB` 按目标设备，64 为最保守档），构建后加 `-BuiltJsPath <loader_out_lite 的 JS 目录>`；命中 `[WARN]/[RELEASE BLOCKER]` 必须回源码逐条核实，不当确定缺陷。

### 6. 本地参考仓库（跨 API 示例，按需取用）
- **本地参考仓库**（按需取用，跨参考以目标 API 为准，勿把高 API 写法套到 lite 10）：`espinr-litewearable`(API6/7 心率+文件+图表)、`gudqs7-first-demo`(API6 入门)、`BestPracticeSnippets/LiteWearable`(**API17+** 官方动态绑定/路由/i18n/crypto)、`yushu-sjtu-gallery-rtos`(**API20** 真机)、`scriptiot-demos`(模拟器)、`barcode-lite`(Code128 组件)。

### 7. 版本差异速查（避免误用旧写法）
- **长按事件**：API10 = `onlongpress`（SDK10 白名单实锤）；API6 = `onlongclick`（旧链）。本 skill 面向 API10，统一 `longpress`。
- **路由方法**：API10 = `replaceUrl`；API6 = `replace`。均无 push/back/clear。
- **border-style**：API6 编译报 WARN（建议省略）；**API10 工程实测 `border-width/border-style/border-color` 三件套可用**（见 HML/CSS 标准写法章节）。
- **rawfile 图片**：API<10 真机不支持 `internal://app/rawfile/img/x.png` 直引；API10 能否直引待真机核实，保守用 `/common/...` 或复制到 `internal://app/`。
- **font-size**：API<10 最佳 30/36px；API≥10 广泛支持（emoji 仍有限）。

---

## 官方能力全景速查（华为文档中心权威归纳，2026-08-24）

> 整理自华为文档中心官方资料（Lite Wearable Development Specifications、通用样式、JS 框架、SysCap 能力清单 V5）。原文档另存为 `LiteWearable官方功能清单.md`。
> 本章写**官方能力边界与权威数值**，与本文「核心硬约束」「跨技能提炼」互补：那两章是实战踩坑根因，本章是官方"能/不能"的基线。

### 1. 概述与适用设备
- Lite Wearable = **FA 模型 + HML/CSS/JS**（兼容 JS 的类 Web 范式，非 ArkTS/ArkUI 声明式）。
- 文件组织：`.hml` 布局 / `.css` 样式 / `.js` 逻辑 / `app.js` 全局 / `pages/` 各页 / `common/` 公共资源。
- 适用设备：早期 GT2 Pro / GT3；GT4 / FIT 等较新设备 target/compatible 多为 API 10+。
- **基准宽度 454px**（逻辑像素）；圆表物理 466×466，方表 408×480（以工程 target 为准）。

### 2. 开发约束（官方硬限制数值）
| 限制项 | 官方/实测值 | 说明 |
|---|---|---|
| JS 运行内存上限 | **49144B ≈ 48KB** | 非 Debug 模式强制；Debug 模式不限制上限 |
| 单页 JS 体积 | ≤ 48KB | 超限真机黑屏风险（详见「SDK与编译方法」章 48KB 红线节） |
| 应用图标 | 114×114 / 80×80，**文件 ≤5KB** | 原始 ~52KB，须最高压缩；纯色块最稳（详见「图标与资源尺寸」） |
| 逻辑像素 | 以 454px 为基准宽度 | CSS 的 px 为逻辑像素 |
| ES6 | 子集 | 见第 5 节 |
| storage key | ≤32 字符，不含 `\/"*+,:;?[]` | @system.storage 硬约束 |
| storage value | ≤128 字节 | 即"128B 红线"官方来源 |
| 路由栈 | 最大 **32** 页 | router push/replace 累积不超过 32 |

### 3. HML 组件全量（官方三大类）
- **容器**：`div`（flex 布局/盒模型）、`stack`（子组件默认绝对层叠，绕过 lite 无 position 限制的常用手段）、`list`/`list-item`、`swiper`（index/loop/autoplay/indicator，change 事件）。
- **基础**：`text`（{{}} 绑定）、`image`（src 本地，不支持 SVG）、`image-animator`、`progress`、`marquee`、`chart`、`animation`。
- **表单**：`input`（type button/text）、`slider`（min/max/value，表冠 rotation focus）、`switch`、`picker-view`（type/text/range，表冠 focus）。
- **Lite Wearable 无 canvas**：绘图用 `chart` 或预生成图片。

### 4. CSS 能力（官方）
- 通用样式：width/height（不设默认 0）/min-/max-、padding/margin/border 系列、background-color、background-image（**仅本地，不支持 SVG**）、opacity、display(flex/none)。
- 颜色格式：`rgb()/rgba()`、`#rrggbb`、`#aarrggbb`；枚举格式 script 中不支持。
  🔴 **8 位 hex 是 `#AARRGGBB`（alpha 在前！不是 web 习惯的 #RRGGBBAA）**——
  写反不会报错，会被当成「高不透明度 + 颜色通道错位」渲染成诡异深色
  （2026-09-25 实测：toast 想要 `#d90b0b10`（6% 红色）实际渲染成 85% 近黑条）。拿不准就用 6 位不透明色。
- 文本样式：font-size/color/weight/family/style、text-align、line-height、letter-spacing 等。
- 布局：flex（flex-direction/ wrap/ justify-content/ align-items）；**`display:flex` 必须显式声明**，否则子元素塌缩 0 高度。
- 动画：`@keyframes` + `animation`、`transform`。
- 注意：通用样式表列了 `[left|top]`，但 lite 引擎 `position` 定位支持极不稳（实测失灵），排版一律用 flex（见「核心硬约束」）。

### 5. JS 框架
- **应用生命周期**（app.js）：`onCreate` / `onDestroy`。
- **页面生命周期**（页 .js）：`onInit`（仅一次，数据初始化完）→ `onReady`（仅一次，页面创建完）→ `onShow` / `onHide` / `onDestroy`。
- **数据绑定**：`data` 模型（名不能以 `$`/`_` 开头，不能用保留字 for/if/show/tid）；`{{ }}` 单向插值；`$refs` 取 DOM/子组件实例。
- **事件绑定**（HML 属性）：`onclick` / `onchange` / `onlongpress` / `onswipe`。
- **ES6 子集**：`let/const`、箭头函数、`class`、默认值、解构、增强对象字面量、`for-of`、rest、模板字符串。**不支持**完整 ES6。
- 🔴🔴 **【硬禁止】JS 里不准出现正则表达式字面量** —— 不是"易黑屏"，是**引擎根本不支持**：
  lite 引擎是裁剪版 JerryScript，编译 profile 直接关掉了正则，实测（引擎本体）：
  ```
  Script Error: SyntaxError: Regexp is not supported in the selected profile.
  ```
  **任意一处正则 → 整个页面的 JS 求值失败 → rootComponent 为 undefined → 整页黑屏**，
  连标题都不显示。而 **ace-loader 与 hvigor 两条链都是 SUCCESS**（它们用 V8 解析，正则对 V8 天经地义）。
  替代写法（2026-09-24 Nexus签到 实战）：
  ```js
  /* 去掉 \r \n \t 和空格 —— 不能用 /[\r\n\t ]/g，用 charCodeAt 逐字符判断 */
  function stripWs(s) {
    var t = String(s === null || s === undefined ? '' : s);
    var out = '';
    for (var i = 0; i < t.length; i++) {
      var c = t.charCodeAt(i);
      if (c === 13 || c === 10 || c === 9 || c === 32) { continue; }
      out += t.charAt(i);
    }
    return out;
  }
  ```
  → **改完 JS 必须跑「引擎级语法体检」**（见下文「★ jerry.exe 引擎级语法验证」）。
- **模块导入**：`import router from '@system.router'` / `import storage from '@system.storage'` / `import utils from '../../common/utils.js'`。

### 6. @system 系统能力全集（SysCap V5）
| SystemCapability | 能力/模块 | 主要接口 |
|---|---|---|
| ArkUI.ArkUI.Lite | UI 组件（第3/4节） | — |
| SystemCapability.Base | 基础/应用上下文 | `@system.app`（getInfo/terminate/globalData） |
| Location.Location.Lite | 地理位置 | `@system.geolocation`.getLocation（需 LOCATION 权限） |
| PowerManager.BatteryManager.Lite | 电池 | `@system.battery` |
| FileManagement.File.FileIO.Lite | 文件 | `@system.file` |
| Startup.SystemInfo.Lite | 设备信息 | `@system.device`.getInfo（brand/model/screenShape…） |
| PowerManager.DisplayPowerManager.Lite | 屏幕亮度 | `@system.brightness` |
| Communication.NFC.CardEmulation | NFC 卡模拟 | NFC |
| Security.Huks.Core | 安全/Huks | @system 安全相关 |
| DistributedDataManager.Preferences.Core.Lite | 数据存储 | `@system.storage`.get/set/clear/delete |
| Sensors.Sensor.Lite | 传感器 | `@system.sensor`.subscribe*/unsubscribe* |
| Sensors.MiscDevice.Lite | 振动 | `@system.vibrator`.vibrate（⚠️ 注意是 **vibrator** 不是 vibration，官方 d.ts 为 `@system.vibrator.d.ts`）|
| Communication.NetStack | 网络 | `@system.fetch` |
| MiscServices.ScreenLock | 屏幕锁 | 屏幕锁 |
| Security.CryptoFramework | 加解密 | 哈希/随机数 |

重点模块：
- `@system.router`：`push({uri,params})` / `replace` / `back` / `clear`；跨页经 params，目标页 onInit 读；栈 ≤32。
- `@system.storage`：get/set/clear/delete；key≤32、value≤128B；**回调在部分环境不可靠**，带超时兜底、不阻塞 UI。
- `@system.sensor`：加速度/罗盘/距离/环境光/计步/气压/心率/佩戴/方向/陀螺仪；subscribe/unsubscribe 成对，onDestroy 取消；部分需权限、仅真机。
- `@system.device`：getInfo 异步，建议 onShow 后调。
- 注：FA+Lite 下 `@system.*` 是正确用法（同名模块在其它设备多已废弃改 `@ohos.*`）。

### 7. 官方-said-能 vs 真机-不能 对照（实战核心坑）
| # | 官方说能 | 真机/lite 实测 | 应对（详见对应章） |
|---|---|---|---|
| 1 | 通用样式有 `[left\|top]` 定位 | `position` 整个失灵，元素退文档流 | 一律 flex（核心硬约束） |
| 2 | HML 支持 for/if 指令 | 实战项目规避，用预计算字段/静态 class | 见跨技能提炼 / 实战模板 |
| 3 | CSS 支持伪类(`:nth-child`)、`>`/`+` 选择器 | Build 失败（Error 00308018） | 同族差异用独立 class |
| 4 | ES6 完整 | **任意正则字面量都会让整页 JS 求值失败→全黑**（引擎实测 `SyntaxError: Regexp is not supported in the selected profile`；曾有项目 `/[\r\n\t ]/g` 一处就黑屏） | **禁所有正则**，改用 `charCodeAt` 循环；改完跑 `tools/jerry-check.py` 兜底 |
| 5 | storage 有 success/fail/complete 回调 | 常不触发或返回 `{value:...}` | 默认渲染+后台刷新+超时兜底 |
| 6 | display 默认 flex | 不显式声明子元素塌缩 0 高 | 显式 `display:flex` |
| 7 | 模拟器字体子集完整 | 大量中文渲染为空（真机正常） | 调试期关键 UI 用英文+数字 |
| 8 | `$app` 可读写 `app.js` 全局（页面 js「直接可用」） | **真机上可用**；仅在**模拟器/预览器**（本平台只有 wearable 模拟器、没有 Lite 模拟器）里 `typeof $app === 'undefined'` | 真机依赖 `$app` 没问题；**但要做模拟器调试就得有文件通道兜底**（`internal://app/*.txt`） |
| 9 | `@system.router` 有 `replaceUrl` | **只有 `replace`**；调 `replaceUrl` → `TypeError: undefined is not callable` → **闪退** | 封装 `goto(uri)`：先试 `replace` 再试 `replaceUrl` |
| 10 | `@system.file` 的 `writeText` 有 success/fail | **回调永不返回**（`readText` 正常） | 写文件 **fire-and-forget**；绝不能等回调（否则页面卡死） |
| 11 | —（文档未提） | 文件写是**异步**的：写完立刻跳页，目标页读到**空** | 写完 `setTimeout(跳转, 300)`；读取端「读空就重试」（≤8×250ms） |
| 12 | —（文档未提） | `<list-item>` 的 click 事件里**没有 `index`**（`e.index` undefined） | `onclick="pick($item.t)"` **直接把值传进回调**（HML 事件支持传参） |
| 13 | HML 支持 `for` | **`for="{{arr}}"` + `tid="id"` 实测可用**，`<list>`+`<list-item>` 可滚动 | 列表/选字页可放心用 `for`（`tid` 必须唯一） |

### 7.1 自研拼音 IME（3500 字单字表，可复用做法，2026-09-26 实证）

要在手表上做「中文拼音输入」，可靠做法：
1. **词表**：`jieba` 的 `dict.txt`（含**中文词频**）→ 取单字条；用 3500 常用字表过滤；`pypinyin` 给拼音。
   两者都能用 ghproxy 直拉：`https://ghproxy.net/https://raw.githubusercontent.com/fxsjy/jieba/master/jieba/dict.txt`。
2. **排序**：按**词频降序** → 每个拼音的**最常用字排第一**（「ni」→ 你，「shi」→ 是）。
3. **紧凑编码省体积**：音节表（~400 个）+ 「汉字 + 2 位 36 进制音节号」，**3500 字仅 ~19KB**；
   解码用自写 `b36()`（别依赖 `parseInt` 的 radix）。
4. **候选交互**：键盘候选**只留 1 排 5 个**；「更多字」按钮 → **独立选字页**（`<list>`+`for` 可滚动），
   点一下回填。跨页传参/现场保存全走文件（见上表 #8/#10/#11）。
5. ⚠️ 单字表 + HML/CSS 都会被编译进**单页 JS**，务必跑 `tools/jerry-check.py` 确认没超 ~55KB 上限。

### 7.2 网络请求与局域网通信（2026-09-27 实证，详见 references/network-and-lan.md）

手表联网、以及「手表 ⇄ 同网段手机/电脑」直连的完整踩坑记录单独成篇（含可直接复制的代码）：

- `fetch` 的 `fail(code)` 里 **`code === 0` 就是「根本没连上」**（不是 HTTP 状态码）——
  判错方向会让排查全跑偏；HTTP 状态码在 `success` 的 `res.code` 里，两层都要判。
- **回调内部绝不能用 `this`**（要用方法体第一层的 `that`）。写错的表现是「某屏数据永远
  加载不出来/永远显示获取失败」，因为异常常被队列的 try/catch 吞掉，极难定位。
- 并发请求要**串行队列**化（小内存设备多请求齐发会丢回调/卡页），
  且**每个请求的 success/fail 都必须调到 `finish()`**，否则队列死锁。
- **局域网地址默认值必须为空字符串**：没配置就直接引导用户去填，
  千万别图快留一个调试 IP —— 用户会看到「连不上」，还会误以为设备坏了。
- 失败路径**不要自动退出**（「失败后 900ms 自动返回」看着友好，实际让用户看不到错误）：
  成功才自动返回，**失败留在页内**并给「改地址 / 重试 / 返回」三个出口。
- 跨页传参 **路由 `params` 优先、文件仅兜底**：`writeText` 是 fire-and-forget，
  「写文件→跳页→目标页读文件」必有竞态，症状是「哪个入口进去都显示同一个内容」。
- **首屏渲染永不等回调**：文件/网络回调在 lite 上可能不触发，放在渲染路径上 = 页面永远空白
  （用户观感就是「点进去卡死/黑屏」）；`fileApi` 必须在 `enter()` 之前 `ensureFile()`。
- 没有 `encodeURIComponent`/`atob`，**不支持正则字面量**：URL 编码与 base64 都要手写实现。

📄 完整代码（getJson 封装 / 串行队列 / 读地址 / 键盘输 IP / 排查顺序表）：
`references/network-and-lan.md`

### 7.3 实战专题（reference，按主题查阅；前 5 篇由唯一源同步，最后一篇 api10 独有）

| 主题 | 文档 | 解决什么 |
|---|---|---|
| **网络与局域网** | `references/network-and-lan.md` | `fetch` 错误码语义（`code=0` = 连不上）、串行队列防并发打爆、**回调内不能用 `this`**、局域网地址必须可配置且默认留空、失败要留出口、params 优先文件兜底 |
| **体积预算与快照闸门** | `references/size-budget-and-snapshot.md` | 两道闸门阈值（快照 ≈46.6KB / 单页 JS ≈55KB）、🔴 **阈值随 SDK 变**（同产物 OH SDK 过、IDE 自带 SDK 可能挂）、手动测快照法、**字节少也可能挂**（函数数/字符串同样决定）、瘦身手段库（拆屏 > 大字符串搬 rawfile > 精简表 > 删死代码）。**⭐§八（2026-10-04 补）**：hvigor 日志**看不到真实原因**——`lib/lite/lite-snapshot-plugin.js` 把 `err` 丢了，只打印 `Failed to convert ...`；必须手动跑 `jerry-snapshot.exe generate -o x.bc <lite_source 那份js>` 才见 `ERR_OUT_OF_MEMORY` 明细；堆上限 **65528**，判定量含**碎片**（bytecode+strings+objects+properties+waste）；另有第二种失败 `Generating snapshot failed`（超大页，需拆页） |
| **页面拆分与重构** | `references/page-splitting-and-refactor.md` | 拆屏 7 步流程、**深度匹配提取**（HML/CSS 都不能靠截断）、批量删 CSS 禁用 `[^}]*`、🔴 **拆/合屏后必须同步屏索引常量 + 总屏数 + 页码初值**、传参双保险 |
| **时序与交互陷阱** | `references/timing-and-interaction-traps.md` | **首屏渲染永不等回调**、`fileApi` 提前初始化、内层函数只用闭包 `that`、`swiper` index **单向绑定**、圆屏安全区（底部按钮 y<400、宽<250）、`{{}}` 只能绑 data、`if` 不用 `show` |
| **验证工作流** | `references/verify-workflow.md` | 三层验证（静态 → **node 模拟每页逻辑** → 模拟器/真机）、交叉一致性四查、模拟器实测手法（截图/swipe 注入/`file recv` 必须 cd）、静默构建不弹窗、排查顺序（**先快照再路由**） |
| **虚拟摇杆** | `references/virtual-joystick.md` | 触摸三事件 + 定时步进的完整模板（死区/最大行程/摇杆跟手/底座跟随手指）、🔴 **事件必须裸名**（`on:touchstart` 会挂）、触摸坐标兜底链（x/localX/globalX）、内部状态用模块变量、定时器必须 onHide/onDestroy 清 + 代数守卫（防切页后角色自己走）、`<stack>` 子节点 left/top 定位（lite 无 position） |
| **构建打包与配置陷阱**（api10 独有，不同步） | `references/build-and-packaging-traps.md` | **先 `ls` 核实工具链路径**（DevEco 升版会整目录换名/删旧目录，照抄旧路径直接 FAIL）；出包须 `NODE_OPTIONS=` 清空（宿主注入的 safe-delete shim 会劫持 unlink → ETIMEDOUT）；`usedScene` 的键是**单数 `ability`**（写 `abilities` → `00303038`）；`.bat` **必须纯 ASCII**（cmd 按 GBK 读，中文注释让批处理跑飞）；**批量删除拦截会静默不删** → 一律 `os.replace` 改名（**必须同盘** + 目标移出 Ability 目录）；资源改动后必须 `clean`（lite 增量只增不减）；出包后**数包内条目数** |

> 🔧 **维护流程（唯一源）**：这 5 篇只在  里编辑，
> 改完跑 
> 把改动同步到其它 lite 技能； 可只校验漂移（不改文件）。

> 🔧 **本批文档由唯一源同步而来**：只改 `litewearable-api10-dev/references/`，改完跑 `python litewearable-api10-dev/scripts/sync-lite-topic-docs.py` 把改动同步到其它 lite 技能（`--check` 只校验漂移）；不要在副本上直接改。

### 8. 一句话速查
Lite Wearable = FA + HML/CSS/JS；UI 用 div/stack/list/swiper + text/image/progress/slider/switch/input/picker-view（**无 canvas**）；样式用 flex + 通用样式；逻辑用生命周期 + {{}} + @system 模块；硬约束 **48KB JS 内存、icon≤5KB、454px 基准、storage 128B、路由栈 32**。

## 实战标准写法模板（实战项目A 实证，可直接套用）

以下模板全部提取自真实工程源码（15 页），是「踩坑铁律」的落地代码。核心理念：**路由 params 闭环传档案为主、storage 仅兜底；注入解析 + require 防御 + 主题双套是每页公共前缀**。

### 模板 1：每页公共 data 前缀（注入位 + 主题色 + onInit 公共段）
```js
var THEMES = {
  dark:  { bg:'#0b0b10', card:'#14141c', main:'#ffffff', sub:'#8a8a99', warn:'#ff5252' },
  light: { bg:'#f2f2f2', card:'#ffffff', main:'#1c1c1e', sub:'#6e6e78', warn:'#cc3333' }
};
export default {
  data: {
    bgColor:'#f2f2f2', cardBg:'#ffffff', textMain:'#1c1c1e', textSub:'#6e6e78', warnColor:'#cc3333',
    dark: null,           // 路由参数注入位（null=未注入；1/0 由框架自动注入同名变量）
    money: null, wins: null, losses: null, winsH: null, lossesH: null,
    winsE: null, lossesE: null, winEarned: null, bestEndless: null, signDay: null
  },
  onInit: function () {
    this.storageApi = null; this.routerApi = null;
    if (this.dark === 1 || this.dark === '1') { this.dark = true; }
    else if (this.dark === 0 || this.dark === '0') { this.dark = false; }
    else if (this.dark === null || this.dark === undefined) { this.dark = false; }
    try { this.storageApi = require('@system.storage'); } catch (e) { this.storageApi = null; }
    try { this.routerApi = require('@system.router'); } catch (e) { this.routerApi = null; }
    var t = this.dark ? THEMES.dark : THEMES.light;
    this.bgColor = t.bg; this.cardBg = t.card; this.textMain = t.main; this.textSub = t.sub; this.warnColor = t.warn;
  }
};
```
注：THEMES 键名可增（如 `cur`/`gold`/`purple`/`idle`），但每页必须定义；主题色统一用 data 绑定 `style="background-color: {{bgColor}};"`。**绝不**写 `width:{{x}}px` 这种字符串内嵌 `{{}}`（编译过、真机渲染异常，黑屏隐患）。颜色语义用 `background-color`+`border-color` 表达（lite 白字默认、color 不可靠）。

### 模板 2：parseNum 注入解析辅助（每页 onInit 内联）
路由注入 number/string 混传，统一解为 number 或 null：
```js
var parseNum = function (v) {
  if (typeof v === 'number') { return v; }
  if (typeof v === 'string' && v !== '' && v !== 'null' && v !== 'undefined') {
    var n = parseInt(v, 10);
    if (!isNaN(n)) { return n; }
  }
  return null;
};
var mVal = parseNum(this.money);
this.moneyVal = (mVal !== null && mVal >= 0) ? mVal : 2000;  // 兜底默认值
```

### 模板 3：normData 解包（lite storage.get 返回包装对象）
**踩坑**：真机某些版本 `storage.get` 成功回调收到 `{value:'...'}` 或 `{data:'...'}` 包装对象，直接 `JSON.parse` 抛错 → 全部档案读取失败（金钱/签到无法持久化的根因）。统一解包：
```js
function normData(d) {
  if (typeof d === 'string') { return d; }
  if (d && typeof d === 'object') {
    if (typeof d.value === 'string') { return d.value; }
    if (typeof d.data === 'string') { return d.data; }
    try { return JSON.stringify(d); } catch (e) { return ''; }
  }
  return '';
}
```

### 模板 4：跨页档案 params 闭环（profileParams + 注入位）
每页 `data` 声明同名注入位（见模板 1），跳转时整体带回；home 用 `profileParams()` 打包：
```js
profileParams: function () {
  var p = this.profile || PROFILE_DEFAULTS;
  return {
    money: (typeof p.money === 'number') ? p.money : 2000,
    wins:  (typeof p.winsN === 'number') ? p.winsN : 0,
    // ...全部字段同理
    signDay: (typeof p.lastSigninDay === 'number' && p.lastSigninDay >= 0) ? p.lastSigninDay : -1
  };
}
```
**铁律**：目标页 `data` 必须声明注入位（null=未注入），否则框架不注入该字段（参数丢/主题不跟随）；**已注入字段会无条件覆盖**目标页同名变量（见下条坑）。

### 模板 5：storage 拆 key + 写后校验 saveProfile（_saveToken 版本号）
```js
var PROFILE_KEYS = ['money','winsN','lossesN','winsH','lossesH','winsE','lossesE','winEarned','bestEndless','lastSigninDay','eggClaimed'];
var PROFILE_DEFAULTS = { money:2000, winsN:0, lossesN:0, winsH:0, lossesH:0, winsE:0, lossesE:0, winEarned:0, bestEndless:0, lastSigninDay:-1, eggClaimed:0 };
saveProfile: function (cb) {
  var that = this;
  if (!this.storageApi || !this.profile) { if (cb) cb(); return; }
  var my = (this._saveToken = (this._saveToken || 0) + 1);   // 版本号：更新的保存链接管后旧链作废
  var doSet = function () {
    if (my !== that._saveToken) { return; }
    for (var i = 0; i < PROFILE_KEYS.length; i++) {
      try { that.storageApi.set({ key:'br_p_'+PROFILE_KEYS[i], value:String(that.profile[PROFILE_KEYS[i]]||0) }); } catch (e) {}
    }
    setTimeout(function () {                 // 写后校验：300ms 读回比对，未落盘则重试
      if (my !== that._saveToken) { return; }
      var left = PROFILE_KEYS.length, bad = false;
      var fin = function () { if (bad) doSet(); else if (cb) cb(); };
      for (var j = 0; j < PROFILE_KEYS.length; j++) {
        (function (name) {
          that.storageApi.get({ key:'br_p_'+name, default:'',
            success:function (d) { if (normData(d) !== String(that.profile[name]||0)) bad = true; if (--left === 0) fin(); },
            fail:function () { bad = true; if (--left === 0) fin(); } });
        })(PROFILE_KEYS[j]);
      }
    }, 300);
  };
  doSet();
}
```
value 必须 `<128B`：拆短 key（`br_p_<字段名>`，每 key 一个数字串）是必做项，不是优化项。> 注：key 前缀按项目自定即可——示例里用过 `br_p_` 和 `wl_` 两种，语义相同（前缀 + 字段名），换项目改前缀即可，不要误以为某个前缀是唯一标准。

### 模板 6：loadProfile 冷启动竞态防护（ended 守卫 + ready(cb)）
```js
loadProfile: function (cb) {
  var that = this;
  if (this.profile) { if (cb) cb(); return; }      // 内存已有档案：保留，不重读覆盖
  var p = {}, left = PROFILE_KEYS.length, ended = false;
  var fin = function () {
    if (ended) return; ended = true;
    var o = {}; for (var k in PROFILE_DEFAULTS) o[k] = PROFILE_DEFAULTS[k];
    for (k in p) if (typeof p[k] === 'number') o[k] = p[k];
    that.commitProfile(o); if (cb) cb();
  };
  for (var i = 0; i < PROFILE_KEYS.length; i++) {
    (function (name) {
      that.storageApi.get({ key:'br_p_'+name, default:'',
        success:function (d) { var v = normData(d), n = parseInt(v, 10); if (v !== '' && !isNaN(n)) p[name] = n; if (--left === 0) fin(); },
        fail:function () { if (--left === 0) fin(); } });
    })(PROFILE_KEYS[i]);
  }
},
ready: function (cb) {                 // 所有依赖档案的入口必须经此：档案未就绪先加载完再执行
  if (this.profile) { cb(); return; }
  this.loadProfile(cb);
}
```
**踩坑**：入口（开始/签到）若直接用默认 `this.profile` 开新局，会覆盖真实存储档案 → 退出重进数据重置。务必 `ready()` 等待就绪。

### 模板 7：游戏页启动链路（防直达 + coldCheck 会话标志）
```js
onInit: function () {
  // ...注入解析/require 后：
  this.gO = false;          // gO = gameOver 锁
  if (this.game !== 1 && this.game !== '1' && this.rA) {
    this.rA.replaceUrl({ uri:'pages/home/home', params:{ dark:this.dark?1:0 } });  // 防直达/恢复闪对局
  }
},
onShow: function () { this.coldCheck(); },
coldCheck: function () {
  var that = this;
  if (this.cCD) return; this.cCD = true;       // 防重入
  if (this.game === 1 || this.game === '1') { this.afterColdCheck(); return; }  // 会话标志直通（最可靠）
  if (!this.sA) { this.cS = true; this.afterColdCheck(); return; }
  this.sA.get({ key:'br_gamestart', default:'', success:function (d) {
    var v = normData(d), ts = parseInt(v, 10), now = 0; try { now = Date.now(); } catch (e) {}
    that.cS = !(ts > 0 && !isNaN(now) && now - ts < 18e5);   // 30 分钟内的旧局视为恢复
    that.afterColdCheck();
  }, fail:function () { that.cS = true; that.afterColdCheck(); } });
},
afterColdCheck: function () {
  if (this.cS) {                              // 非本会话/恢复失败：踢回主菜单
    this.gO = true; this.setStatus('已返回主菜单','#ffd700');
    setTimeout(function () { if (this.rA) this.rA.replaceUrl({ uri:'pages/home/home', params:{ dark:this.dark?1:0 } }); }.bind(this), 300);
    return;
  }
  this.startStage(1);
}
```
**铁律**：进入对局页必须带 `params {game:1}`（框架同步注入，最可靠）；storage `br_gamestart` 时间戳仅作恢复场景兜底，且 `Date.now()` 需 try/catch 防御（lite 可能返回 0/NaN）。退出/结算必须把 `br_gamestart` 置 `'0'`，否则下次冷启动被误判为恢复对局。

### 模板 8：防重锁家族
每页用布尔锁防重复触发（lite 真机回调/手势可能多次触发）：
- `startLocked`：开始游戏防连点
- `agreed`：生死状扣款防重复扣
- `jumped`/`done`：跳转/返回防双触发
- `checked`：首次检查防重
- `cCD`：coldCheck 防重入
- 游戏内 `lk`（回合锁）+ `gO`（gameOver 锁）：开枪/用道具期间锁输入
- settings.onBack 用 `done` 标志 + `setTimeout(goBack,600)` 兜底，防止 storage.set 回调异常导致不跳转

### 本项目专属巧法（实战项目A 实证）
1. **不同模式拆独立页 + 入场费按页扣**（48KB 治本）：`waiver` 页按 `mode` 跳 `index / index_easy / index_hard / index_endless / pvp_normal / pvp_hard` 六个游戏页，每个页固定一种模式、代码更小，避开单页 48KB 上限。比"一个页 if 分支塞全部模式"可靠得多。
2. **disclaimer 跳转只带 `{dark}` 不带档案**：冷启动免责声明同意后进主菜单，**绝不能** params 传默认 `money/wins`，因为 home 注入会无条件覆盖 storage 真实档案（只签到因 `signDay>=0` 检查不覆盖才保留）。冷启动应让 home 纯读 storage 恢复。
3. **每日签到用天数序号 `todayDay()`**：`Math.floor(Date.now()/86400000)` 避免 Date 字符串格式化依赖；`Date.now()` 全程 try/catch 防御。
4. **setStatus 主题色重映射**：深/浅两套主题下同一语义色不同，helper 里按 `!this.dark` 把白/金/灰重映射到对应暗色，避免浅色主题下白字看不见。
5. **预计算字段渲染（替 for+if 嵌套）**：子弹格 UI 用 `c0..c5 / b0..b5 / s0..s5` 六个 data 键存颜色/可见性，`updateBulletUI()` 里 `this['c'+k]` 赋值、HML 直接绑定，**避开 lite 不支持的 list+for / 嵌套 for+if**。
6. **屏幕常亮**：游戏页 `require('@system.brightness')` → `setKeepScreenOn({keepScreenOn:true})`（try/catch 防御），防止对局中熄屏。
7. **i18n 目录仅占位**：工程 `i18n/zh-CN.json` 存在（lite 初始化强依赖该目录），但 HML 实际用字面中文串、未接 `{{$t()}}`。保留目录、别删，但别指望它驱动文案。
8. **near-limit 页可紧凑命名**：`index.js` 用单字母 api 变量（`sA/bA/rA/vA`）与单字母状态（`gO/lk/cCD`）省体积；可读页用 `storageApi/routerApi`。两者都合法，临近 48KB 时前者是保命手段。

### HML 标准写法（实证）
- 容器根：`<div class="container">` 包裹所有内容。
- 按钮 = `div.onclick` + `class="结构类 修饰类"` 组合（见下 CSS 章节）。
- **禁止 `class="{{x}}"` 数据绑定**（ace-loader 编译报错 `class selector does not support data binding`）；状态样式用 `if` 条件渲染 + 静态 class，动态颜色用 inline `style="..."` 绑定。
- 主菜单网格：`menu-grid(column, 固定 height) > menu-row(row, 固定 height) > menu-btn`，三层固定高，避开 row>column 嵌套不渲染的坑。
- swiper 屏内只放文字，可点按钮放 swiper **外**，用 `if="{{page1}}"`/`if="{{page2}}"` 切换；`onSwiperChange`+`onswipe` 都调幂等 `showPage(idx)`。
- 任何 div 容器（尤其带 `if` 的）必须给固定 `height`，否则整区不渲染。

### CSS 样式表标准写法（模板 + 踩坑，全 15 页实证）

> 提炼自真实工程全部 15 个 `.css`（home/mode/index 系/pvp 系/settings/stats/result/about/disclaimer/waiver/tutorial），可直接套用。

#### A. `.container` 固定根模板（每页必写，一字不改）
```css
.container {
  width: 100%;
  height: 100%;
  flex-direction: column;
  justify-content: center;
  align-items: center;
  background-color: #0b0b10;   /* 深主题底；浅主题由 JS applyTheme/setStatus 重设根背景 */
}
```
- **`width:100%; height:100%` 是特例，必须保留**：这两行相对「页面根视图」撑满全屏（整屏 466×466），是 lite 唯一稳妥的百分号用法。**不要因为它和下方「E. 固定尺寸铁律（内部元素绝不写百分比）」冲突就改成固定 px**——根用 100% 才能自适应不同设备分辨率、标准且稳妥；改成 `466px` 反而非标准写法。
- **与 E 铁律不矛盾**：E 的「不用百分比」指的是**内部子元素**（list/row/卡片等嵌套层）；根容器这层 100% 是唯一例外，二者分工明确。
- 全页**不可滚动、不可拖动**。justify/align **永远 center，不用 flex-start**。
- 背景色写死在根（深色态 = `#0b0b10`）。浅色主题需 JS 在 setStatus/applyTheme 里重设根背景（见模板章节 setStatus 重映射）。

#### B. 全局配色系统（照搬，别自创色值）
- 背景层：页面底 `#0b0b10` / 卡片底 `#14141c`、`#1e1e28`
- 强调金（标题/货币/行动方高亮）：`#ffd700`
- 玩家绿：边 `#34c759` / 底 `#1c3a2a` 危险红（恶魔）：边 `#ff3b30` / 底 `#3a1c1c`
- 次要文字灰：`#8a8a99`（常规灰字）、`#6b6b7a`、`#5f5f6e`、`#4a4a56`（边框灰，由浅到深）
- 危险红字：`#ff5252` 双模式专属：蓝 `#3a8edb`/`#34c7c7`、紫 `#6e5a8e`/`#d45ad4`/`#8e8eff`
- 这些是工程验证过的「深色表盘」调性，直接复用保证全应用观感统一。

#### C. 按钮「结构类 + 修饰类」分离（核心套路，全工程通用）
```css
/* 结构类：管尺寸/布局/圆角，只声明 border-width/border-style（边框粗细+实线），color 留给修饰类 */
.target-btn {
  width: 155px; height: 44px;
  flex-direction: column; justify-content: center; align-items: center;
  border-width: 2px; border-style: solid;
  border-radius: 22px;
}
/* 修饰类：只写背景+边框色（可叠加），不重复声明布局 */
.btn-self   { background-color: #1c3a2a; border-color: #34c759; margin-right: 7px; }
.btn-dealer { background-color: #3a1c1c; border-color: #ff3b30; margin-left: 7px; }
```
- **要点**：结构类声明 `border-width/border-style`（**拆开写，不写 `border` 聚合简写**），`border-color` 只在修饰类写。同形状按钮换色只换修饰类，HML 里 `class="target-btn btn-self"` 组合。
- **状态切色用 inline style 绑定**（lite 不支持 `class="{{x}}"` 数据绑定）：如 home 签到按钮「未签到=红、已签到=灰」用 `<div class="sign-btn" style="background-color:{{c}};border-color:{{bc}};">`，CSS 里 `.sign-btn` 仅管布局，颜色全交给 data 绑定（home.css 注释实锤）。
- 圆角惯例：大按钮 22~30px（半圆形 pill）、卡片 9~20px、小道具卡 9px。

#### D. 文本类标签
```css
.stage-text { width: 357px; font-size: 17px; color: #ffd700; text-align: center; }
```
- 文本类：width 跟随父容器（357/360/380/400）、font-size + color + text-align:center + 可选 margin-top（行距 1~16px）。
- **兄弟间距一律用 margin-top**（不用 gap——lite 对 flex gap 支持不稳，工程全用 margin 系列）。

#### E. 固定尺寸铁律（lite 硬约束）
- **所有 width/height 用固定 px，绝不写百分比**（lite 不支持百分比尺寸）。
- 内容区基准宽度：357 / 360 / 380 / 400px（466 圆屏留安全边距，避四角被裁）。
- **任何带 `if` 的容器、任何列表区必须给固定 height**，否则整区不渲染（实证踩坑）。
- 容器高度按内容反推固定值（如 HP 卡 92+6 边框 ≈ 94 区高）。

#### F. 踩坑注释范式（务必写进 CSS 注释，防后人改坏）
工程每个 CSS 头部都有文件头注释 + 分区 `/* ── xxx ── */` + 踩坑 `/* 注意：... */`。重点踩坑写进注释：
1. **lite 的 list/滚动组件真机渲染不可靠 → 回退 div 网格**（index 两排 9 道具全用 div，不用 list；index.css 头注释实锤）。
2. **lite row 嵌套渲染不稳 → 复杂卡片用 column 纵向全宽按钮**（disclaimer/waiver.css「纵向全宽按钮」注释）。
3. **lite 中文字体行高约字号×1.5** → 多行文本容器高度必须按 `行数×字号×1.5` 预留，否则首行被上方遮挡（index.css status-area 124px 预留 5 行的注释实锤）。
4. **swiper 屏内只放文字**，按钮放 swiper 外（屏内 click 被手势吞）。
5. **固定宽度区防位移**：如枪膛槽位区固定 258px（6×43），标签/槽位在其中居中，装弹数变化时标签位置不漂移（index.css chamber-slot-area 注释）。

#### G. 主题切换与可见性
- 浅色主题下白字/金字可能看不见 → 文字默认色按 `this.dark` 在 JS 层 setStatus 重映射（见模板章节）；CSS 只管深色态默认色。
- swiper 默认黑底 → 必须 inline style 跟随主题背景（见 swiper 章节第 4 条）。

#### H. 文件头注释模板（每页 CSS 顶部照抄）
```css
/*
 * <页面名>样式：居中布局，<布局描述>，适配 466x466。
 * 配色：背景 #0b0b10；强调金 #ffd700；玩家绿 #34c759；恶魔红 #ff3b30。
 * 踩坑：<本页特有踩坑，如 lite list 回退 div / row 嵌套用 column>。
 */
```

## 🔴🔴 HML 事件前缀：**必须用裸名 `onclick`**（2026-09-25 设备实测，第二次血亏）

**症状**：页面能渲染、滑动正常，但**所有按钮点了毫无反应**（含「设置 Token → 打开键盘」这类关键入口）。
**两条编译链都不报**（HML 语法完全合法），只在运行时静默失效。

**实测对照**（HarmonyOS 6.1 wearable 运行时 / API 24，`uitest` 注入验证）：

| 写法 | 布局树 `clickable` | 注入点击 | 结论 |
|---|---|---|---|
| `onclick="fn"` | **true** | **生效** | ✅ 唯一可用 |
| `grab:click="fn"` | **false** | 毫无反应 | ❌ 事件根本没注册 |
| `on:click="fn"` | false | 毫无反应 | ❌ 事件根本没注册 |

同样规律适用于 `onlongpress` / `onswipe` / `ontouchstart` / `ontouchmove` / `ontouchend` / `onchange`。

**铁律**：
- **全工程统一裸名**：`onclick` / `onchange` / `onlongpress` / `onswipe` / `ontouchstart|move|end`。
- 搬第三方组件时**必须把 `grab:` / `on:` 前缀全局改掉**（crabKeyboard 就是 `grab:` 重灾区，
  它是 API 6 时代的写法）——否则整块 UI 变装饰品。
- 静态拦截已内置：`tools/precheck.py` 会扫出任何 `(grab|on):(click|longpress|swipe|touch...)` 属性并报 FAIL。
  > 注意：**HML 注释里的举例也会被扫到** → 写注释时别写完整前缀字面量。

> 补充：早期社区资料（含本技能库旧版）写过「`onclick` 按冒泡处理，建议改 `grab:click`」——
> **在当前运行时上正好相反**，`grab:click` 完全不注册。以实测为准。

## 🔴 用 `show` 隐藏 swiper = 幽灵组件抢点击（2026-09-25 实测）

做「页内多视图切换」（主界面 + 若干覆盖式子视图）时，如果把主 swiper 写成
`show="{{vMain}}"` 隐藏：**它仍留在布局树里且可命中**——子视图里点按钮/卡片，
触摸会穿透到这个幽灵 swiper，触发它的 `onclick` 兜底，把子视图的状态搅乱
（实测：列表视图点卡片 → 详情没开，反而被兜底逻辑切回主视图）。

**正确做法：用 `if` 彻底移除**，返回主界面时用 `index` 绑定恢复屏位：

```html
<swiper if="{{vMain}}" index="{{swiperIdx}}" ...>
```
```js
showView: function (v) {
  if (v === 0) { this.swiperIdx = this.curIdx; }   /* 回主界面：重建到离开前的屏位 */
  this.vMain = (v === 0); ...
}
```

**排查手段**：`uitest dumpLayout` 看布局树——`if=false` 的节点**不在树里**，
`show=false` 的节点**还在**（且 clickable=true 会抢触摸）。

## 滑动 + 点击交互（swiper 实战技巧）

0. 🔴 **`swiper` 里绝对不能放 `list`（整页黑屏的头号根因，2026-09-24 血亏实证）**：
   官方父子结构约束原文「**`swiper` 不支持包含 `list`**」——违反后**页面整页不渲染，只剩黑底**，
   而 **ace-loader 与 hvigor 两条编译链都不报错**（既非语法错也非资源错），只能靠自检或真机发现。
   叠加另一条铁律「**lite 的 list/滚动组件真机渲染本就不可靠**（index 页道具全用 div）」→
   **结论：lite 工程干脆零 `list`，列表内容一律 `div` 卡片堆叠**（固定 width+height + `margin-top`）。
   swiper 屏内可以放 `div`/`text`/`image`，就是不能放 `list`。
   > 黑屏往往**多条叠加**，2026-09-24 那次是四条：① swiper 含 list（主因）② swiper 默认黑底未显式设色
   > ③ 部分 `text` 只给 width 没给 height（算 0 尺寸，文字不可见）④ 内容宽 440px 超出圆屏安全弦长。
   > **排查黑屏按这四条顺次过一遍，比瞎猜快得多。**
1. **滑动切换一律用官方 `swiper` 组件**（div `onswipe` 真机不触发，社区实锤）。
2. **swiper 内部子元素 div `click` 会被滑动手势吞掉**（点按钮没反应）——按钮可放屏内做视觉，点击走 **swiper 组件自身 `onclick`**；`onchange` 里记录 `curIdx`（`e.index`，兼容 `e.currentIndex`），点击时 `curIdx===1` 才执行动作。
3. **swiper 外部兄弟元素也可能被拦截**——不要依赖"移出 swiper 就能点"。
4. **swiper 默认黑色背景** → 必须显式给色。**无主题切换时直接写死** `style="background-color: #0b0b10;"`（比 data 绑定更稳：`{{}}` 嵌进颜色/尺寸串有真机渲染异常的先例）；另在 CSS `.swiper` 里写同色**双保险**。
5. 无提示场景：`indicator="false"` + `loop="false"`。
6. 双路径兜底：按钮 div onclick + swiper onclick 接同一入口（eggDone/claiming 锁防重复触发）。
7. **多按钮整页滑动场景（每屏多个可点项，无法用组件级 onclick 区分）**：**`tabs`/`tab-bar`/`tab-content` 编译能过但 lite 真机渲染异常（mode 页整页直接不显示，已实证）——不要用于真机交付**。可靠做法：**swiper 滑动导航条 + 内容区外置**——swiper 屏内只放标题文字（大字+页码提示，不放可点元素），按钮列表放 swiper **外**，`onchange` 维护 `curIdx`（e.index 兼容 e.currentIndex），内容区按布尔字段 `if="{{pA}}"/if="{{pB}}"` 切换（`===` 数值比较无先例，别赌）；可再加 container `onswipe` 整页兜底（onSwipe: `e.direction==='left'/'right'`，与 swiper change 共用幂等 showPage，真机不触发也不影响 swiper 主通道）。mode 页单人/双人实战：swiper 90px 条 + 按钮外置，21 项测试 + 编译 SUCCESS。
8. **但「按钮外置」只是保底方案 —— 用户往往要求按钮随屏滑动**（外置时滑动屏幕按钮不动，观感割裂，2026-09-24 被用户明确否掉）。
   要「按钮在屏内跟着滑」时用这个组合（本次实证）：
   - 按钮放进 `.screen`，每个按钮自己绑 **`onclick`（裸名！`grab:click` 不注册）**（主路径）；
   - **`swiper` 组件自身同时绑 `onclick`**（兜底路径），被手势吞掉时按 `curIdx` 执行该屏主操作；
   - 两条路接**同一批动作函数**，函数内有 `busy` 锁防重复触发；
   - **一屏两按钮**的兜底分派：用状态判断择一，如
     `var notYet = this.checkinBtn.indexOf('立即') >= 0;` → 未签到走签到、已签到走抽奖。
     ⚠️ 用 `indexOf`，**不能用正则**（lite 不支持正则）。
   - 这样既满足「随屏滑动」，又不会因为 click 被吞而完全点不动。
9. **「从哪来回哪去」：lite 没有 push/back，只能靠传参把屏位带回来**（2026-09-24 实证）。
   `@system.router` 在 lite 上**只有 `replaceUrl`**；d.ts 里的 `push`/`back`/`clear` 标着
   `SystemCapability.ArkUI.ArkUI.Full` —— **那是 Full 版，lite 用不了**。
   而 `replaceUrl` 会让**源页重建**（`onInit` 重跑、`data` 回默认值），
   于是「从第 4 屏进子页 → 返回 → 掉回第 1 屏」，用户观感就是**「怎么老是跳回第一页」**。
   标准做法：
   ```
   源页跳转： replaceUrl({ uri:'pages/child/child', params:{ ..., backIdx: this.curIdx } })
   子页返回： obj['backIdx'] = this.backIdx;   // 在 data 里声明 backIdx 作为注入位
              replaceUrl({ uri:'pages/home/home', params: obj })
   源页 onInit： 读 this.backIdx（number 或 string 都要兼容）→ applyScreen(backIdx)
   ```
   ⚠️ **两个细节**：
   (a) 子页 `data` 里必须声明 `backIdx` 作为注入位，否则框架不注入；
   (b) 用 `swiper` 做导航时，**index 要绑一个"只在初始化/返回时设一次"的变量**（如 `swiperIdx`），
       **不要直接绑跟随滑动更新的 `curIdx`** —— 否则 index 与滑动互相打架（回声），滑动会发涩甚至卡住。
10. **HML 里给事件传常量参数，会挤掉事件对象**（2026-09-24 实证，键盘 `touchStart` 案例）。
    原写法 `grab:touchstart="touchStart(true)"` 依赖「框架把事件对象追加为第 2 个参数」这个**隐式约定**；
    API 10 上不保证 → `e` 为 undefined → `e.globalX` **抛异常** → 整条触摸链路（拖动/点击）都受影响。
    **可靠写法：为每个"参数值"各写一个不传参的入口函数**，让 `e` 永远是第 1 个参数：
    ```js
    touchStartKeyboard(e){ this.beginTouch(true, e); },
    touchStartText(e){     this.beginTouch(false, e); },
    beginTouch(target, e){ if(!e||e.globalX===undefined){return;} /* 兜底，绝不抛异常 */ ... }
    ```
    同理，**凡是读触摸坐标的回调（click/press/touchMove）开头都加一行坐标兜底**：
    坐标缺失时直接 `return` —— 否则比较全是 `NaN`，会一路穿透成 `arr[NaN][NaN] = undefined`，
    表现是「输入了奇怪的东西」或「点了没反应」。
11. **第三方组件的"默认布局值"要按本工程实际能力改**（键盘 `keyType` 案例）。
    键盘 `keyType` 默认 0 = 中文布局；若本工程不带拼音词典、且删了 `0.png`，
    一旦路由 params 注入失败（lite 上 params 不可靠），`keyType` 停 0 → **显示空白键盘**。
    → 把默认值改成**本工程一定能渲染的那档**（如 2 = 大写布局，一个布局覆盖 JWT 全字符）。

## 数据持久化架构（退出重进不丢）

- **params 闭环为主**：跨页档案用路由 params 传递（`replaceUrl({uri, params})` → 自动注入目标页 data 同名变量，onInit 前完成），比 storage 可靠得多。**正常业务路径用 params 直通，storage 只作兜底**。
- **写后校验保存**：set → 300ms 后 get 读回比对 → 未落盘重试；`_saveToken` 版本号隔离并发。
- **每个拿到最新档案的入口都要立即写回 storage**（home 的 applyProfile 末尾统一 saveProfile）。
- **冷启动竞态**：档案异步加载，所有操作入口（开始/签到/统计等）必须等就绪（`ready(cb)` 模式）再执行，防止默认值污染真实数据。
- **"仅一次"防重**（彩蛋/每日奖励）：读标记确认未领 → **写标记并确认落盘 → 才放款**；get 失败宁可不发不可误发；标记由生命周期长的页面（home）持久化，业务页只做 params 闭环。
- **冷启动恢复对局**：waiver 跳转带 `game:1` → 游戏页 coldCheck 对 game:1 **直接放行**（不依赖 storage 时间戳——写入可能失败）；时间戳仅作恢复场景防御；游戏页 onInit 里 `game!==1` → 立即回主菜单（防直达/恢复闪对局）。
- **免责声明等"首次必显"逻辑**要挂在必经汇合点（主菜单），不能只挂首页（lite 恢复/直达会绕过首页）。

### ★ 替代方案：`@system.file` 落文本文件（2026-08-29 逆向商业工程实证）

一个商业级 lite 工程（20 页）**持久化主力是 `@system.file`，不是 storage**。
数值/开关直接写 `internal://app/xxx.txt`：

| 用途 | 文件 | 内容 |
|---|---|---|
| 货币余额 | `internal://app/money.txt` | 纯文本数字（初始 100000） |
| 战绩列表 | `internal://app/stats.txt` | JSON 数组，上限 50 条 |
| 各类开关 | `keepalive.txt` / `screenon.txt` / `vibe.txt` | 纯文本标记 |

**必须配串行队列**，否则连点会造成「读→改→写」异步竞争丢数据：

```js
var queue = [], running = false;
function enqueue(task){ queue.push(task); if(running) return; running = true; drain(); }
function drain(){
  if(!queue.length){ running = false; return; }
  var t = queue.shift();
  t(function(){ drain(); });   // 任务内部：readText → 改 → writeText → 回调
}
```

- 队列设上限（实测用 50 / 64），溢出时 `shift()` 丢最旧并 `console.error` 告警
- `readText` / `writeText` 的 **success 和 fail 都要调用回调**（lite 上 fail 可能不触发，要防死锁）
- 解析存量内容要 try-catch + `isNaN` 校验，异常则重置为初始值，绝不把脏值写回

> 结论：**单值/小 JSON 用 `@system.file` + 串行队列，比 `@system.storage` 稳**；
> 跨页传递仍以 params 为主，两者不冲突。

## 三角洲开箱模拟器工程实战经验（API 10 FA，与 实战项目A 同范式）

> 工程：三角洲开箱模拟器（API 10 FA / HML+CSS+JS，DevEco 5.0+）。7 页：index(主菜单) / containers(容器选择) / box(开箱棋盘) / settle(结算) / stats(统计) / settings / about。业务流 `index→containers→box→settle→index`，状态经 `router.replaceUrl` 的 params 全程携带，全局共享走 `getApp().data.g`。**完全自包含铁律（零 import / 零 for·if 指令 / 零正则），与 实战项目A 同源但更强调。**

### A. getApp() 全局状态主通道 + 三通道降级（最核心）
lite 上 params/storage 均可能因设备差异不可靠，**全局对象 `getApp().data.g` 最稳**（app.js 注释原话："全局共享状态：跨页状态的主通道，params/storage 均可能因设备差异不可靠，全局对象最稳"）。
- **app.js** 定义全局 `g`（不要写在页面 data 里）：
```js
export default {
  data: {
    g: { vib: true, dark: true, opp: 5, curContainer: 0, runTotal: 0, cnt: 0,
         statMax: 0, statMin: 0, statTotal: 0, statCount: 0 }
  },
  onCreate() { console.info('App onCreate'); },
  onDestroy() {}
};
```
- **每页 helper**（放在 `export default` 外，与 THEMES/normData 同级）：
```js
function getGlobal() {
  try {
    var app = getApp();
    if (app && app.data && app.data.g) { return app.data.g; }
  } catch (e) {}
  return null;   // 失败返回 null → 退化为 params/storage 通道
}
```
- **onInit 读取优先级**：params 注入位（如 `this.vib===0`→false）→ `this._g = getGlobal()` 补充 → storage 兜底（`storage.get({key:'df_settings', success:...})`，读不到用默认）。每页顶部注释固定为"失败返回 null（退化为 params/storage 通道）"。
- **写回**：结算页 `settle.js` 直接改全局对象 `this._g.statMax = ...; this._g.statTotal += ...`，下次任意页 `getGlobal()` 即拿到最新值，**省去 storage 回读**。
- ⚠️ 两种风格差异：一种以 storage + params 闭环为主；另一种显式把 `getApp()` 作第一主通道，更稳、更少 storage 抖动。
- 📝 与附录 A 第 789 行的 `$app` 写法区别：`$app` 是早期文档写法；本工程（API 10）用官方 `getApp()`，二者同源（都是读 app.js 的 export default），优先用 `getApp()`。

### B. lite 不支持 position → 用 `<stack>` 子元素默认绝对定位（关键解法）
- box.hml：`4x4 棋盘（stack + 绝对定位，官方 sample 同款写法）` → `<stack class="board">` 内 16 个 `<div class="cell" style="left:{{g0.x}}px; top:{{g0.y}}px;">`。
- box.css 原注：`stack 子元素默认绝对定位，无需 position 属性`（.cell / .slot / .magspin 全靠 left/top 定位，**不写 position**）。
- ✅ 这破解了「核心硬约束：lite 引擎不支持 position 属性」——**凡需重叠/坐标布局，用 `<stack>` 包裹，子元素天然绝对定位**。（详见下方 G 节 HML 模板）

### C. content-box 盒模型（算固定像素尺寸必须减边框）
- box.js：`var B = 4; // 2px 边框 × 2 边（lite content-box，尺寸需减去边框）` → `w: it.w * CELL - B`。
- ⚠️ lite box model 是 **content-box**（非 border-box），border 占额外空间。元素固定像素尺寸 = 内容区，border 在外叠加；算坐标/宽高时减掉左右（上下）边框之和，否则偏大被裁或错位。

### D. 禁用正则（**黑屏级，不是"高级正则"而是"所有正则"**）
- **任意**正则字面量（`/.../ `）都会让整个页面的 JS 求值失败 → 整页黑屏。
- 引擎实测（2026-09-24，Nexus签到）：`/[\r\n\t ]/g` 一处即触发
  ```
  Script Error: SyntaxError: Regexp is not supported in the selected profile.
  ```
- `formatMoney` 必用纯字符串循环（从个位往前每 3 位插逗号）；清理空白用 `charCodeAt`。
- 原因（settle.js 注释原话）："lite 引擎为裁剪版 JerryScript，不支持 lookahead 断言，正则会致页面 js 编译失败黑屏"。
  **补充实测：实际比这更狠 —— 连最简单的字符类 `[\r\n\t ]` 都不支持。**
- **验证手段**：`<SDK>/<API>/js/build-tools/ace-loader/bin/jerry.exe --parse-only <产物.js>`
  （真机同款引擎，V8 能过它不一定能过）。
```js
function formatMoney(n) {
  var s = String(n), out = '', cnt = 0;
  for (var i = s.length - 1; i >= 0; i--) {
    out = s[i] + out; cnt++;
    if (cnt % 3 === 0 && i > 0) { out = ',' + out; }
  }
  return out;
}
```

### E. 棋盘/开箱业务：坐标静态预计算 + display 显隐（对齐 zero for/if）
- 物品槽 4 个、背景格 16 个、放大镜 4 个全部**静态手写**（g0..g15 / s0..s3 / m0..m3），**不用 for 渲染**（对齐 Buckshot 模式）。
- 显隐用 `display: {{d0}}`（none/flex）数据绑定，不用 if 指令。
- 坐标由 JS 预计算进 data：`x: it.c * CELL, y: it.r * CELL`，HML 只绑定 left/top。
- 参考尺寸：CELL=75（85% 缩放，原 88px）；棋盘 `.board { width:300px; height:300px }`。

### F. 配色系统（多工程通用，直接照搬）
```js
var THEMES = {
  dark:  { bg:'#000000', main:'#ffffff', sub:'#999999', card:'#1e1e28', border:'#4a4a56' },
  light: { bg:'#f2f2f2', main:'#1c1c1e', sub:'#6e6e78', card:'#e8e8ee', border:'#b8b8c2' }
};
```

### G. 图片
- 物品图 `/common/images/<quality>/itemNN.png`（官方 Demo 同款，编译期自动转位图）。
- `<image>` **必须显式 width/height**（lite 不认百分比、不认隐式尺寸）；方块用 `.png` 源路径，不用 base64。

### 可复用 HML 片段：stack 棋盘 + 绝对定位
```html
<stack class="board">
  <div class="cell" style="left:{{g0.x}}px; top:{{g0.y}}px; background-color:{{cellBg}}; border-color:{{cellBorder}};"></div>
  <!-- ... 静态写满 g1..g15 -->
  <div class="slot" style="display:{{d0}}; left:{{s0.x}}px; top:{{s0.y}}px; width:{{s0.w}}px; height:{{s0.h}}px; background-color:{{s0.bgColor}}; border-color:{{s0.borderColor}};" onclick="onCollect0">
    <image src="{{s0.img}}" style="display:{{s0.imgShow}}; width:{{s0.imgW}}px; height:{{s0.imgH}}px;"></image>
  </div>
  <!-- ... s1..s3 静态手写 -->
</stack>
```
```css
.board { width:300px; height:300px; }
.cell  { width:75px; height:75px; border-width:1px; border-style:solid; } /* stack 子元素默认绝对定位，无需 position */
.slot  { border-width:2px; border-style:solid; }  /* 同 */
```

## SDK 与编译方法（5.0.4 vs 6.1.1；release vs ace-loader）

### 核心结论（先说清，避免被旧铁律误导）
- **DevEco 6.1.1（hvigor 6.x）不一定非要把工程升到 `6.0.0`**。两条路都通：
  - **A. release 法（hvigor 6.x 构建）**：`modelVersion` 写 `6.0.0` 或 `5.0.4` 均可（6.x 向下兼容，三处一致即可），**不强制 `6.0.0`**。→ 实测用 `5.0.4` 也能 release 构建。
  - **B. ace-loader 法（命令行 webpack 编译）**：**保持 `modelVersion: "5.0.4"` 也能编**，因为 ace-loader 是 SDK 自带的**独立老式编译器**，只吃 `aceModuleRoot`（JS 源码）+ `manifest.json`，**完全不读 hvigor 的 modelVersion/schema**，所以不触发 00303038/00303190。→ 实测做法。
- **5.0.4 SDK（DevEco 5.0.4 + hvigor 5.x）**：只有 hvigor legacy 构建一途，`modelVersion: "5.0.4"`，IDE Build 选 debug/release（DevEco 5.0.4 的 SDK 目录已删，现统一用外部 ace-loader 替代）。

> ⚠️ **环境路径变更（2026-10-10 实测，长期有效）**：本机用户目录已从 `C:/Users/小聋虾/` 变为 **`C:/Users/maodou/`**，且 `D:/OpenHaymony_SDK_6.1.1/`、`D:/DevEco Studio 5.0.4/` 均已不存在。当前可用：
> - **ace-loader**：`D:/DevEco Studio 26.0.0/DevEco Studio/sdk/default/openharmony/js/build-tools/ace-loader`（DevEco 26.0.0 自带，★推荐）；备用 `D:/OpenHarmony_SDK/26.0.0/js/build-tools/ace-loader`；老版本另有 `E:/SDK/openharmony/8`（API 8）、`E:/SDK/hmscore/3.0.0_7`（API 7）、`E:/SDK/hmscore/2.2.0`（API 6）。
> - **node（managed）**：`C:/Users/maodou/.workbuddy/binaries/node/versions/22.22.2-6/node.exe`（旧 `22.22.2` 目录名已变，带 `-6` 后缀）。
> - **python（managed）**：`C:/Users/maodou/.workbuddy/binaries/python/versions/3.13.12/python.exe`。
> - **manifest 来源**：`entry/build/default/intermediates/lite_source/default/assets/js/MainAbility/manifest.json`（仍有效）。
> - 用 DevEco 26.0.0 的 ace-loader 编 API 10 工程 release 实测 **SUCCESS、产物与 6.1.1 同量级**（如 pvp_hard 29113B），可放心替代。

### 一、5.0.4 SDK（DevEco 5.0.4 + hvigor 5.x）编译方法
- 前提：`modelVersion: "5.0.4"`（根 `oh-package.json5` + `hvigor/hvigor-config.json5`），`entry/oh-package.json5` 无该字段。
- 编译入口：DevEco IDE → **Build → Build Hap(s)/APP(s)** → 选 **debug** 或 **release**。
- 走 hvigor `legacyAppTasks` / `legacyHapTasks`（见「工程骨架」章节）。
- 产物位置与形态：
  - **debug**：`entry/build/default/intermediates/.../debug/`（**不压缩**，含 ~16KB 框架运行时；源码建议压在 ~31KB 内，详见「三、48KB 红线」）
  - **release**：`entry/build/default/outputs/.../release/`（**压缩**；典型小页面 release 产物 ≈31KB，大页面（hard/endless）可逼近 48KB 极限、余量极小）
- 体积红线：单页产物 ≤48KB（49152B），超限真机黑屏。

### 二、6.1.1 SDK（DevEco 6.1.1 + hvigor 6.x）编译方法

#### 方法 A：release 法（hvigor 6.x 流水线，需 6.0.0）
- 前提：**三处 `modelVersion` 全改 `"6.0.0"`**（根 `oh-package.json5` + `hvigor/hvigor-config.json5` + `entry/oh-package.json5`，见「版本差异备注」表）。不改会 schema 校验失败。
- 编译入口：IDE Build → **release**（或命令行 `hvigor assembleHap --mode module -p product=default -p buildMode=release`）。
- 适用：想走 IDE 标准 hvigor 6.x 流水线、且工程已升 6.0.0 时。
- 坑：6.0.0 工程在老 5.x 环境打不开；升级后部分 FA 写法需复核（重点是 modelVersion 三处一致）。

#### 方法 B：ace-loader 法（命令行 webpack，保持 5.0.4，实战项目A 实测 ★推荐）
- 前提：`modelVersion` 保持 `"5.0.4"` **不动**——ace-loader 与 hvigor schema 解耦，不校验它。
- 编译器位置（SDK 自带，非工程文件）：`<SDK_ROOT>/js/build-tools/ace-loader/`（内含 `webpack.lite.config.js`）；node 用 managed `22.22.2-6`（当前完整路径见上方「环境路径变更」块）。
- 完整命令：
```bash
# 1) 复制 JS 工程到临时目录（不要 rm -rf 旧目录，会被 safe-delete 拦截导致编译失败——换全新目录名）
export TMP_BR="$TMPDIR/br_lite_build2"
mkdir -p "$TMP_BR/MainAbility"
cp -r "<工程>/entry/src/main/js/MainAbility/." "$TMP_BR/MainAbility/"

# 2) 生成 manifest.json（pages 列表必须含全部页面，与 config.json 的 js.pages 一致）
cat > "$TMP_BR/MainAbility/manifest.json" <<'EOF'
{"appID":"com.example.buckshotroulette","versionName":"1.0.0","versionCode":1000000,
 "minPlatformVersion":10,"pages":["pages/disclaimer/disclaimer","pages/home/home", ... ]}
EOF

# 3) 进 SDK 的 ace-loader 目录跑 webpack（路径必须正斜杠；cachePath 指可写 temp）
cd "<SDK_ROOT>/js/build-tools/ace-loader" && unset NODE_OPTIONS && \
aceManifestPath="$TMP_BR/MainAbility/manifest.json" \
"node" \
  node_modules/webpack/bin/webpack.js --config webpack.lite.config.js \
  --env aceModuleRoot="$TMP_BR/MainAbility" --env aceModuleBuild="$TMP_BR/out" \
  --env cachePath="$TMP_BR/cache" --env deviceType=liteWearable --env buildMode=debug
```
- 关键参数：`--env buildMode=debug`（ace-loader **不区分 IDE release**，产物形态等同 debug/不压缩；单页源码要压在 31KB 内）、`--env deviceType=liteWearable`、`--env cachePath` 必须指可写临时目录（DevEco 安装目录无写权限）。
- 为什么能在 6.1.1 环境编 5.0.4 工程：ace-loader 直接吃 `aceModuleRoot` + `manifest.json`，与 hvigor 的 modelVersion/schema 完全解耦——**这是 6.1.1 环境下保留 5.0.4 工程、免升级的最稳做法**。
- 产物检查：`ls -la $TMP_BR/out/pages/xxx/xxx.js` 必须 <49152（48KB）；编译报错去 `$TMP_BR/out/.../compile_error.log` 看真实错误（外层 `build js failed` 看不到）。

### 三、48KB 红线在两种编译下的表现
- 红线本质：**真机加载的 JS 产物 ≤ 48KB**（lite 真机 JS 引擎加载上限）。
  - 其中约 **16KB 是 ace-loader 注入的框架运行时固定开销**（无论 debug/release 都在，压缩对它影响很小），所以**业务代码（压缩后）安全上限 ≈ 48−16 = 32KB，约 31KB** —— 这就是"31KB 安全线"的来历。
- 同一份源码、两种编译的产物体积差异（实测量级对比）：
| 编译方式 | 压缩 | 产物体积量级 | 真机是否加载 | 备注 |
|---|---|---|---|---|
| 5.0.4 SDK debug（hvigor） | 否 | ≈53KB（16KB框架+~37KB未压缩业务） | 否（仅开发跑） | 不压缩膨胀，仅参考 |
| 5.0.4 SDK release（hvigor） | 是 | ≈31KB（16KB框架+~15KB压缩业务） | **是** | ★按此评估红线 |
| 6.1.1 release 法（hvigor 6.x） | 是 | ≈31KB（产物） | **是** | 需 6.0.0 |
| 6.1.1 ace-loader 法（buildMode=debug） | 否 | ≈53KB（等同 debug） | 否（开发验证） | 必做体积验证，另算 release 产物 |
- **结论：release 确实会显著减小编译产物体积（同一源码 ≈53KB→≈31KB，约 −40%）。** 但注意三点：
  1. 减的是**编译后产物**，不是你写的 .js 源码文本（源码不会因选 release 变短）。
  2. 红线按 **release 产物**算（真机跑的就是它）；debug 的 53KB 只是开发参考，不代表真机黑屏。
  3. **光靠 release 不能让一份本身远超源码上限的页面「合法化」**：源码写太大，release 压到 45KB 仍在 48KB 红线边缘，真机照样黑屏。正确做法是把**源码规模压在 ~31KB 内**，使 release 产物远小于 48KB 红线。
- **node 逻辑测试跑的是源文件，不受 48KB 限制会漏检体积** → 改完必做 ace-loader 编译验证（见下章 §2）。

### 四、怎么选
- 在 6.1.1 IDE 里只想快速编/验 5.0.4 工程 → **ace-loader 法**（不必改 modelVersion，最稳）。
- 要正式 release 走 hvigor 6.x 流水线、且工程已升 6.0.0 → **release 法**。
- 纯 5.0.4 SDK 环境（已删）→ 直接用 6.1.1 SDK + **ace-loader 法** 替代 IDE 构建。

## 验证流程（每次改完必做）

### 1. node 逻辑测试（页面模块直接加载）

页面 JS 是 `export default { data, methods }`，可被 node 直接 import 测试：

```js
// 模板：mock require + 加载页面 + 调用方法断言
globalThis.require = (name) => {
  if (name === '@system.storage') return mockStorage;
  if (name === '@system.router') return mockRouter;
  if (name === '@system.vibrator' || name === '@system.brightness') throw new Error('no ' + name);
};
const mod = (await import(pathToFileURL('.../pages/xxx/xxx.js').href)).default;
const inst = Object.assign({}, mod.data);
for (const k of Object.keys(mod)) if (k !== 'data') inst[k] = mod[k];
```

要点：
- **onInit 内部会先置 `storageApi=null` 再 require** → mock 注入必须在 onInit 之后二次注入（或用 patch require 让 onInit 内拿到 mock）。
- **完整启动测试必做**（防"卡加载"类 bug）：注入 game:1 + 档案 → onInit → onShow → 等 setTimeout（开局延时 ~1400ms）→ 断言 `turnText` 更新、`gO===false`、未跳主菜单。
- 只测局部函数会漏掉启动链路的 ReferenceError（如删配置后残留 `cfg` 引用）。

### 2. SDK ace-loader 编译验证（产物大小 + 编译错误）

```bash
# 临时目录（注意：rm -rf 会被 safe-delete 拦截导致编译失败——换全新目录名，别删旧的）
export TMP_BR="$TMPDIR/br_lite_build2"
mkdir -p "$TMP_BR/MainAbility"
cp -r "<工程>/entry/src/main/js/MainAbility/." "$TMP_BR/MainAbility/"
# 生成 manifest.json（pages 列表必须含全部页面）
cat > "$TMP_BR/MainAbility/manifest.json" <<'EOF'
{"appID":"com.example.xxx","versionName":"1.0.0","versionCode":1000000,
 "minPlatformVersion":10,"pages":["pages/xxx/xxx",...]}
EOF
cd "<SDK_ROOT>/js/build-tools/ace-loader" && unset NODE_OPTIONS && \
aceManifestPath="$TMP_BR/MainAbility/manifest.json" "node" \
  node_modules/webpack/bin/webpack.js --config webpack.lite.config.js \
  --env aceModuleRoot="$TMP_BR/MainAbility" --env aceModuleBuild="$TMP_BR/out" \
  --env cachePath="$TMP_BR/cache" --env deviceType=liteWearable --env buildMode=debug
```

- **⚠️ SDK 路径（2026-08-18 起）**：API 10 ace-loader 在 **`<SDK_ROOT>/js/build-tools/ace-loader`**（旧版 DevEco SDK 内置路径已不再适用）；node 用 22.x 版本。

- **路径必须正斜杠**（Git Bash 反斜杠传 Windows node 会 EPERM/missing app.js）。
- **必须 --env cachePath 指向可写临时目录**（DevEco 安装目录无写权限）。
- 检查产物：`ls -la $TMP_BR/out/pages/xxx/xxx.js` 必须 <49152；编译报错去产物 `compile_error.log` 看真实错误。

### 3. 产物检查

- 页面 JS 产物 ≤49152B（hard/endless 类大页面余量常 <200B，加功能前先想压缩）。
- 绑定是否编译进产物：`grep -o "onClick\|字段名" out/pages/xxx/xxx.js`。

## 常见症状 → 根因速查

| 症状 | 根因 |
|------|------|
| 页面黑屏 | ① 产物 >48KB（看 DevEco debug 产物）；② onInit 抛异常；③ **HML style 里"字符串内嵌 {{}}"**：`width:{{expBarW}}px` 编译过但真机渲染异常 → 必须 data 里拼完整字符串（`expBarW:'70px'`）再 `style="width:{{expBarW}}"`；④ **路由注入字段未在 data 声明**：lite 官方机制是"data 同名变量注入"，目标页 data 里必须声明 `dark:null, money:null, ...` 注入位（null=未注入），未声明字段框架不注入（参数丢/主题不跟随），异常场景可能黑屏 → 实测各工程 home 页已全部声明。**启动页铁律：onInit/onShow 整体 try/catch 兜底（任何异常回退默认浅色主题），页面必不黑屏** |
| 卡在"加载中" | 启动链路抛异常（如 grantItems 引用未定义 cfg）；setTimeout 未触发；**storage 并发 get 丢回调**（loadProfile 批量读无超时 → done 计数不到 N → cb 永不触发 → 启动页卡死）→ 每个 getCore 必须 250ms 超时兜底 + 批量读加整体 2s 超时（已修） |
| 进不去对局/扣费被踢回主菜单 | coldCheck 依赖 storage 时间戳失败 → game:1 必须直通 |
| 数据退出重进重置 | 档案 JSON >128B 未拆 key；入口未写回 storage；冷启动竞态 |
| 可重复领取 | 防重标记未先落盘就放款；标记由销毁快的页面写 |
| 点击/滑动没反应 | div onswipe 真机不可靠；swiper 内部 click 被吞 → 用组件级事件 |
| 按钮/文字不显示 | flex-start；无固定 height 的 column 容器；后代选择器 |
| 🔴 **整页黑屏（连标题都没有）** | **按这四条顺次查**：① `swiper` 里放了 `list`（整页不渲染，最常见）② `swiper` 默认黑底没显式设色 ③ 容器/`text` 缺固定宽高（算 0 尺寸）④ 内容宽超圆屏安全弦长（466 圆屏内接矩形仅 ~330px）。**两条编译链都不报** → 跑 `tools/precheck.py`。2026-09-24 Nexus签到 首版真机全黑即此四因叠加 |
| 主菜单按钮消失 | row>column 嵌套不渲染 → 用 column>row>按钮 + 固定高度 |
| **底部按钮被裁/"遮挡"** | **页面静态内容超高**。圆表适配仅 336×306px，任何页总高（padding+title+sub+tab+内容+back+status）必须 ≤306。内容行 >4 行 → 拆 tab（if 双页）或压缩行高 ≤38px。已全部按此修复（如 fish RESULT 块、shop 竿/饵 tab、farm 田/种子 tab） |

## 布局高度硬约束（踩坑记录，2026-08-19）
- 圆表适配分辨率 **336×306**（GT3/GT4）、方表 **336×396**（FIT3/FIT4）——布局一律按 306 核算
- 页面总高预算：padding(10-12) + title(~24) + sub(~16) + tab(28) + 内容块 + back(28) + status(13) ≤ 306
- 垂直居中（justify-content:center）+ 内容超高 → 上下都溢出（顶部内容被裁 + 底部按钮被裁，表现为"遮挡"且按钮点不到）
- 修复套路：① 超高内容块单独加高（如 RESULT 用专属 class 200px）② 精简字号/行高 ③ 行数多拆 tab（page1/page2 + onTab + 选中态颜色切换，仿 swiper 外置按钮模式）

### ★★ 圆屏「横向可用宽度」随 y 变化（2026-09-24 实证，顶部按钮被裁的根因）

**圆屏不是把所有元素都显示出来 —— 靠上下边缘处，横向可用宽度骤减。**
半径 r=233（466 圆屏），**y 处的可见半宽 = √(r² − (r−y)²)**：

| y（距顶） | 可见横向区间 | 可用宽 |
|---|---|---|
| 24 | x∈[130,336] | **206** |
| 40 | x∈[115,351] | 236 |
| 68 | x∈[84,382] | 298 |
| 100 | x∈[42,424] | 382 |
| 233（中心） | x∈[0,466] | **466** |
| 387 | x∈[58,408] | 350 |
| 422 | x∈[97,369] | 272 |

**血亏案例**：螃蟹键盘顶部「取消 / 完成」按钮原本在 `left 35` 与 `left 372`（y=10~39），
**两个都在圆外** → 用户完全看不到，反馈「没有完成编辑的按钮」。
修法：下移到 `top 16`（y16~45，可见 x∈[115,351]）+ 内收到 `left 120 / 280`。

**规律（直接照用）**：
- **y < 80 或 y > 420 的区域，横向只能用中间 200px 以内，别放可点元素**（可用宽 <150px）；
- 需要**靠边**的元素（左右按钮、角标）一律放在 **y 100~400** 这段（可用宽 ≥380）；
- 排完版用上面的表核一遍**顶部/底部元素**的 x 区间是否落在可见区内。
- ⚠️ 这与「页面总高 ≤306」是**两回事**：高度约束管的是纵向不溢出，这里的弦长管的是横向被裁。

**两个实战数值（可直接抄）**：
- 键盘**空格/回车**按钮：定在全局 y≈360~402（140×42，left 90/236），**不要贴面板底部** ——
  贴底（y>416）会掉进窄区被裁。
- 键盘**顶部取消/完成**按钮：`top ≥ 30`。因为 y=14 时可见区只有 x∈[153,313]（放不下 88+12+76 的按钮组），
  y=30 时扩到 x∈[128,338] 才够 → 按 `cancel left145 / confirm left245` 摆。
- 反例（血亏）：曾把按钮放到 `left 35 / 372`（y10~39），**两个都在圆外** → 用户反馈「没有完成按钮」。

### ★★ 圆表 / 方表自适配（**写死一个尺寸必崩另一个**，2026-09-24 实证）

**两套逻辑尺寸是不同的**：圆表 **466×466**、方表 **408×480**
（技能库旧记录里的「适配 336×306 / 336×396」是另一套口径，动手前先用 `@system.device` 实测确认）。
**按 466 写死的页面放到 408 方表上必然溢出**（用户原话：「列表没有适配方表」）。

**正确策略：容器动态 + 内容固定**

| 层 | 策略 |
|---|---|
| **容器级**（背景图 / 遮罩 / swiper / 每屏容器 / 居中元素的 left） | **JS 算**：`@system.device`.getInfo → `windowWidth` / `windowHeight` / `screenShape('rect'\|'circle')`，通过 HML 内联 style 绑定 |
| **内容级**（文字宽度 / 卡片 / 按钮） | **固定值**，取**两种表都安全**的尺寸（如内容 300px、按钮 280px） |

```js
/* JS：值里**自带单位** */
applyMetrics: function () {
  var that = this;
  try {
    require('@system.device').getInfo({
      success: function (d) { that.buildMetrics(d); }
    });
  } catch (e) {}
},
buildMetrics: function (d) {
  var w = (d && d.windowWidth) ? d.windowWidth : 466;
  var h = (d && d.windowHeight) ? d.windowHeight : 466;
  this.screenW = w + 'px';
  this.screenH = h + 'px';
  this.swiperH = (h - 60) + 'px';                    /* 顶部页码 + 底部余量 */
  this.pagebarLeft = Math.round((w - 200) / 2) + 'px';
}
```
```html
<!-- HML：整串替换，没有拼接 -->
<image style="width: {{screenW}};height: {{screenH}};top: 0px;left: 0px;" src="..."></image>
<div class="screen" style="width: {{swiperW}};height: {{swiperH}};"></div>
```

**🔴 关键陷阱：单位必须放进变量里**
- ✅ `style="width: {{screenW}};"` + JS 里 `this.screenW = w + 'px'`
- ❌ `style="width: {{screenW}}px;"` —— 技能库实证：**字符串内嵌 `{{}}` 会真机渲染异常（黑屏隐患）**
- ❌ `.screen { width: 100%; }` —— 内部子元素**绝不写百分比**（只有根容器 100% 是特例）
- ⇒ **每个 `.screen` 都要写内联尺寸**，别偷懒用 100%（HML 会略啰嗦，但这是唯一稳妥做法）

**内容宽度怎么取**：取圆表的安全值，方表自然满足（方表是矩形不裁切）。
圆表最窄处（y≈60）可见区间约 [78,388] → **内容宽 ≤300 两种表都安全**。

## 社区规范补充（2026-08-17 整合 AlanLinYu/huawei-lite-watch-development，MIT）

完整专题文档已存 `references/` 子目录（11 篇：device-compatibility / memory-and-runtime / jerryscript-syntax / hml-lite-syntax / file-and-storage / sensors / vibrator / audio / resource-layout-and-paths / sdk-and-sources / review-output-template），以下为浓缩要点：

### 设备档位（heap 分档 + 适配分辨率）
- JS heap 档位：GT2 系列 64KB、GT3 42/46mm 256KB、GT3 Pro 512KB、FIT3/FIT2 512KB；GT4/GT5/GT6 等社区普遍报 512KB 但**按未知档处理，默认按 64KB 保守设计**。模型相似不代表 heap 相同（GT3 与 GT3 Pro 就不同）。
- **适配分辨率 ≠ 物理分辨率**：GT3/GT4 圆表物理 466×466、适配 336×306；FIT3/FIT4 方表物理 408×480、适配 336×396；GT2 46mm 物理 454×454、适配 336×306。按适配分辨率布局、按物理分辨率核对素材清晰度，别在 466×466 模拟器上宣称兼容所有屏幕。
- API：GT4/GT5/GT6、FIT3/FIT4 等较新设备 target/compatible 为 API 10+；GT2 常见 API 6/3；GT3 常见 API 9（用户 2026-08-22 确认，纠正此前 API7/API6 说法）。

### 内存模型（JS heap 与图片池分开算）
- 图片解码池独立于 JS heap，估算单张 `宽×高×4` 字节 RGBA：466×466≈0.83MiB、454×454≈0.79MiB、408×480≈0.75MiB、390×390≈0.58MiB、336×396≈0.51MiB。图片池经验上限"十几 MB"不是保证。
- 素材必须预缩放到显示尺寸，别靠表端缩放大原图；限制同屏/动画帧/隐藏层并发解码数；换图页面若真机图片池不回落，保存最小状态后用 `router.replaceUrl` 重建页面。
- 峰值风险：`readText` 全量读回再 `JSON.parse`（源字符串+对象树双份）；字符串 `+=` 中间副本；`map/filter/reduce/slice/concat/spread` 新数组；页面跳转旧页+参数+新页同时存活。

### 语法白名单（JerryScript）
- `.js` 源码允许：`let/const`、箭头函数、`class`、默认参数、解构、增强对象字面量、`for...of`、剩余参数（rest）、模板字符串、`import/export`。**不得扩张成完整 ES6**。
- **HML `{{...}}` 表达式不支持任何 ES6**（箭头函数/模板字符串/解构都不行）→ 保持 ES5 短表达式，复杂逻辑移 .js 方法。
- 禁止：`async/await`、生成器、spread（`...value`，仅列了 rest 没列 spread）、动态 `import()`、可选链 `?.`、空值合并 `??`、类字段、BigInt、`eval`/`Function`、Promise（需构建+真机证明）。
- 新增表端代码保守风格：`var` + 普通函数 + 传统循环（减少转译 helper/闭包/临时对象）。

### HML 组件白名单（lite 全量）
- 内置标签仅：`div canvas stack qrcode list list-item swiper tabs tab-bar tab-content image-animator image img progress text marquee analog-clock clock-hand chart input slider switch picker-view`。按钮用 `<input type="button">`，没有 `button/span/p/section/video/audio/svg`。
- 公共属性：`id style class ref if elif else for tid show` + `data-*`。`if` 和 `for` 禁止同元素；`tid` 是数组唯一字段名不支持表达式；页面 data 键名不能以 `$`/`_` 开头、不能叫 `for/if/show/tid`。
- 事件：`click longpress touchstart touchmove touchcancel touchend key swipe`（比实测宽泛，真机仍以 click/longpress/swipe 为准）。
- 父子约束：`list` 子只能是 `list-item`；`tabs` 子只能是 `tab-bar/tab-content`；`tab-bar` 子只能是 `text`；`clock-hand` 父必须 `analog-clock`；`text` 是原子组件不能嵌套组件；`swiper` 不能包含 `list`。

### @system.file / @system.storage 关键参数
- file 12 方法：`move copy list get delete writeText writeArrayBuffer readText readArrayBuffer access mkdir rmdir`，全部回调式（无 Promise，禁止 await）。
- 错误码：`202` 参数错、`300` I/O、`301` 文件/目录不存在、`302` 文本超接口限制。`access` 判"存在"时只把 `code===301` 当不存在。
- `readText` 默认长度 4096（>4KB 可能报 302）；`readArrayBuffer` 必须给受控 length；`mkdir recursive` 最多 5 层；`rmdir recursive` 高风险。
- 禁止对 `internal://app/rawfile/...` 写/删/rmdir/move 目标；URI ≤128 字符、只用 ASCII+`_`+`-`。
- storage：key ≤32 字符、value <128B；`get` 成功回调直接收 value 字符串；`storage.delete/clear` 谨慎。file 从 API 3 提供、SDK 标 API 10 起不再维护，storage API 6 起标 deprecated——**Lite FA 工程别因此乱迁 @ohos.file.fs / Preferences**，以工程 SDK+真机为准。

### @system.sensor 速查（Lite 真机可用性）
- 加速度（ACCELEROMETER 权限）、罗盘、计步（ACTIVITY_MOTION）、气压、心率（READ_HEALTH_DATA，~5s 一次、`255` 无效）、佩戴状态、陀螺仪（GYROSCOPE，API6+）。
- **Lite 无效果接口（官方标注，别依赖）**：`subscribeProximity` 距离、`subscribeLight` 环境光、`subscribeDeviceOrientation` 设备方向。
- interval：`normal`~200ms / `ui`~60ms / `game`~20ms，默认 normal，别为 UI 每帧用 game。
- 每个 `subscribeXxx` 必须配对 `unsubscribeXxx`（onDestroy 清理；同种传感器重复订阅通常只最后生效）。

### @system.audio 完整规范（shalu2 方案，与第 10 条互补）
- `config.json` 需声明 `ohos.permission.MODIFY_AUDIO_SETTINGS`（带 reason/usedScene）。
- `playList` 格式明确：`文件名,启用标志,保留字段,时长秒;`，例 `bgm.mp3,1,0,120;click.mp3,1,0,1;`；`cur_playlist` 内容就是 `playList`。
- 首次复制**必须逐个顺序 file.copy**（等 success 再下一个），全部完成并 `file.access` 校验关键文件后才写完成标记；**禁止"发起所有异步 copy 后立即 rmdir"竞态**（shalu2 的坑）。
- 播放：`audio.stop()` → `audio.src` → `audio.play()`；**单活动音源**：BGM 与音效不并发，音效播完按已知时长+余量恢复 BGM；新音效先清旧的恢复定时器。
- MP3 校验：文件头 `49 44 33`（ID3）或 `FF Ex`（MPEG 帧同步）；出现 `ftyp` 是 M4A/MP4 必须转码。经验上限：128/192kbps、单文件 ≤5MB、总音频 ≤50MB。
- `rawfile/audio/get.js` 是电脑端 Node 生成工具，绝不能进表端执行。

### 资源目录规范
- `js/<Ability>/common` 需手动创建：固定图片放这里用 `/common/...` 绝对路径（HML/CSS 都行）；公共 JS 用**相对** `import '../../common/utils.js'`（不能 `/common/utils.js`）。
- **图片/资源文件名硬性格式 `^[A-Za-z0-9][A-Za-z0-9_-]*\.(png|jpg|jpeg|bmp|gif|webp)$`**，禁止中文/空格/全角/emoji；子目录同名约束；大小写与磁盘完全一致。
- rawfile 打包区只读，运行时 `internal://app/rawfile/...`；需写的数据复制到 `internal://app/`。

### 模拟器/预览器限制
- **`@system.file` **真机可用**；部分 DevEco 5.0/API 10 预览器和 wearable 模拟器调不通**（社区实证）→ file/rawfile 复制流程必须打包上真机验证，模拟器成功/失败都不算数。
- 模拟器不证明：传感器行为、功耗、图片释放、内存上限、音频解码。

### 分支增量（2026-08-18 整合 kqakqakqa/hmlwskill，MIT，存 references/hmlwskill/）

主仓库的迭代分支，新增完整 @system.* 签名、MVVM/CSS 细节与 Node 版评审工具：

#### @system.* API 签名要点（references/hmlwskill/system-api.md）
- **import 机制**：`import "@system.*"` 编译转译为 `requireNative("system.*")`，两种写法等效；只解析绑定、**不嵌入产物、不增加产物大小**。本地 JS 相对 `import` 则**静态嵌入引用方**（产物 = 引用方 + 被引用之和，公共模块被多页引用各嵌一份）→ 48KB 超限要查公共 JS 引用链。
- **@system.fetch 存在**（网络）：GET/POST/PUT/DELETE，回调 `{data, code}`；**`code` 是 HTTP 状态码，`data` 可能是对象也可能是字符串**（必须双分支处理）；没有 window/document/XMLHttpRequest。调第三方 Web API 的完整套路（鉴权头 / CSRF 双提交 / 排错顺序）见文末「联网调第三方 Web API」。
- **@system.app**：`getInfo`（name/versionName/versionCode）、`terminate()`。
- **@system.battery**：`getStatus` → `{level, charging}`；**@system.device**：`getInfo` → `{brand, model, osVersion, platform}`；**@system.geolocation**：`getLocation` → `{latitude, longitude, accuracy}`。
- **@system.storage**：`set` 空字符串值 = 删除该 key；key ≤32 字符，禁 `\/"*+,:;<=>?[]|\x7F`。
- **@system.router**：uri 传 `/` 显示首页（`/pages/index/index`）；每次跳转新 JS 实例（页面≠单例）。
- **@system.file**：`FileResponse = {uri, length, lastModifiedTime, type, subFiles?}`，**轻量穿戴 lastModifiedTime 固定 0**、dir 时 length 固定 0；`writeText` 无「空串删除」语义（删用 `delete`）。
- **@system.sensor**：`subscribeProximity`/`subscribeLight`/`subscribeDeviceOrientation` 标 `-`（无效果）；**罗盘目前真机暂不支持**（此分支说法，主仓库标"需校准验证"）。

#### MVVM / HML / CSS 细节（references/hmlwskill/viewmodel-style.md）
- **没有响应式系统**：data 键在 `onInit` 后、`onShow` 前挂到 `this`（直接 `this.xxx`，无需 `this.data.xxx`）；HML `{{xxx}}` 默认从 `this` 读。
- **`if=false` 不构建节点不占内存；`show=false` 仍构建 VDOM 占内存**——能用 if 就不用 show。
- **`$app` 全局引用**：页面直接读写 `app.js` 的 `export default`（`$app.func()`、`$app.value=1`），页面切换不销毁 app.js，跨页共享可用（getApp() 用法同源）。
- **页面根元素必须且只能是 `div` 或 `stack`**。
- **CSS**：仅 `.class` 和 `#id` 选择器；单位仅 px + 百分比；未设宽高默认为 0（text 唯一自动算高、未设宽度默认一行）；仅支持 `top`/`left` 不支持 `bottom`/`right`；不支持 `gap`/`align-self`/`position`/`calc()`；`border`/`background` 聚合写法不行要拆开（`border-width`/`border-style`/`border-color` 三件套——**API10 工程实测 border-style 可用**；API6 才报 WARN 建议省略）；除 input 外不支持 `background-image`；背景默认黑。
- **font-size**：API<10 支持最好的是 **30px 和 36px**，其余有限；API≥10 广泛支持、emoji 支持有限。
- **事件**：绑定形式 `@click`/`onclick`/`on:click`/`grab:click` + `.bubble`/`.capture`。⚠️ **实测更正（2026-09-25）**：当前运行时上 `on:click` / `grab:click` **完全不会注册事件**（布局树 clickable=false，点了没反应），**必须用裸名 `onclick`**，详见前文「HML 事件前缀」章节。`{{Math.random()}}`、`{{new Number()}}` 是无效绑定。

#### 文件系统（references/hmlwskill/file-system.md）
- **真机目录模型**：应用资源根 `/`（app.js/pages/common，`@system.file` 不可访问）+ 应用沙盒 `internal://app/`（file API 唯一可访问）；rawfile 图片可用 `<image src="internal://app/rawfile/img/x.png">` 但 **API<10 真机不支持此方法**。
- 文件名硬性格式含扩展名：`^[a-zA-Z0-9][a-zA-Z0-9_-]*\.[a-zA-Z0-9]+$`。

#### JS 语法清单冲突（两仓库说法不同，以 SDK+真机为准）
- 主仓库（AlanLinYu）：**spread/可选链/空值合并 未列入支持**；分支（hmlwskill）：**允许 spread/可选链/??/Function()**（放"仅证明后使用"：eval()、string.replace()）。
- 分支新增**禁止项：正则表达式**；`string.replace()` 需构建+真机证明（暗示 JerryScript 正则 replace 不稳）→ **别依赖字符串.replace(正则) 逻辑**。
- 两仓库一致禁止：async/await、Promise、生成器、动态 import、类字段、BigInt、QuickJS 嵌入、Node 的 require/fs/Buffer。

#### Node 版评审脚本（scripts/project-reviewer/，比 PS1 新）
```bat
scripts\project-reviewer\run-reviewer.bat -ProjectPath <项目目录> -TargetHeapKB 64 -TargetApi 6
```
自动发现 node（local.properties 的 nodejs.dir → DevEco tools\node → PATH）；纯 JS 解析图片头（无需 System.Drawing）；检查 9 项（工程定位/源码清单/JS 语法/构建产物/HML 白名单/资源路径/音频/图片池/API 声明）。旧 PS1 版 `scripts/audit_lite_watch_project.ps1` 仍可用。

### 审计脚本（新增工具）
```powershell
powershell -ExecutionPolicy Bypass -File <skill>\scripts\audit_lite_watch_project.ps1 `
  -ProjectPath <项目目录> -TargetHeapKB 64 -TargetApi 6 `
  -SdkApiPath <当前SDK的js/api目录> [-SkipImageDimensions]
# 构建后追加：-BuiltJsPath <项目>\entry\build\default\intermediates\loader_out_lite\default\js
```
只读启发式扫描（heap/图片尺寸/ES6/HML 白名单/@system 接口），不修改项目；命中注释/字符串要回源码确认。

## Resources

- `scripts/compile_check.sh`：一键 SDK 编译验证脚本（临时目录 + manifest + webpack，输出产物大小）。
- `scripts/audit_lite_watch_project.ps1`：只读审计脚本（来自社区 skill，MIT）。
- `scripts/project-reviewer/`：Node 版评审脚本（run-reviewer.bat + cli.js，来自 hmlwskill 分支，MIT）。
- `references/`：社区规范 11 篇专题文档 + LICENSE（来源 AlanLinYu/huawei-lite-watch-development）。
- `references/hmlwskill/`：分支 9 篇专题文档 + LICENSE（来源 kqakqakqa/hmlwskill，含完整 @system.* API 签名）。

## 附录 A：系统大版本 vs API Level 权威映射（群聊答疑 / 版本纠结用，多源核实）

**核心铁律：系统大版本号（HarmonyOS 3.1 / 4.0 / 4.1…）≠ API Level（9 / 10 / 11…），但官方有明确映射。**

**通用（手机 / 平板 / 标准设备）映射**（OpenHarmony Release 时间线 + 华为开发者联盟论坛 + 官方知识库一致）：
- HarmonyOS **3.1** = **API 9**
- HarmonyOS **4.0** = **API 10**
- HarmonyOS **4.1** = **API 11**
- HarmonyOS **5.0 / NEXT** = **API 12**
- （后续 5.0.1→13、5.0.2→14、6.0→20+ 等按官方映射表类推）

⚠️ **常见误说纠正**："4.0 对应 API 9 起步"是**错的**。正确是 3.1=API 9、4.0=API 10。若应用要同时覆盖 3.1 与 4.0 设备，应配 `compatibleSdkVersion=9, targetSdkVersion=10`，**不是**说"4.0 兼容最低是 9"（4.0 设备本身的 API 就是 10）。

**三个版本字段机制（官方，build-profile.json5 的 app.products[]）**：
- `compatibleSdkVersion`（打包为 module 的 `minAPIVersion`）：应用**可安装的最低 API**；设备 API 低于此值无法安装。
- `targetSdkVersion`（打包为 `targetAPIVersion`）：应用**运行的目标行为版本**；系统以该版本呈现 API 行为（高版本设备的 API 变更不影响本应用，除非 target ≥ 变更引入版本）。
- `compileSdkVersion`：编译所用 SDK 版本，决定可联想的 API 范围。
- **约束**：`compatibleSdkVersion ≤ targetSdkVersion ≤ compileSdkVersion`，违反报错。

**可复用答疑话术（已纠正版本号，群聊直接甩）**：
"系统版本号（比如 4.0）和 API Level（比如 10）不是等号，但官方有映射：HarmonyOS 3.1=API 9、4.0=API 10、4.1=API 11。应用靠三个独立字段控制兼容范围：compatible（最低可装）≤ target（目标行为）≤ compile（编译用）。想用 API 10 开发又让 API 9 老设备也能装，就配 compatible=9、target=10——前提是不碰 API 10 独有特性，否则在 9 上会缺能力。简单说：系统大版本和 API Level 各是各的旋钮，config.json / build-profile 里 compatible ≤ target 配好，就能一次覆盖多档设备。"

⚠️ **手表（liteWearable）边界**：本 skill 针对 **WATCH GT 等 lite 设备**，它们跑 **LiteOS 轻量系统（liteWearable profile）**，并不跑手机那种完整的 HarmonyOS 4.0 大版本；此处的"API 10"指 **lite 能力等级**，与手机 HarmonyOS 4.0=API 10 的映射**不是同一套逻辑**。群里若有人拿手机 4.0 / API 10 大版本说事，别直接套到手表 lite 工程——手表看的是 liteWearable 设备能力 + DevEco FA 工程的 API level，不是手机的 HarmonyOS 系统大版本。

---

## 附录 B：逆向商业工程学到的实战套路（2026-08-29 实证）

> 来源：完整逆向一个商业 `.app`（**20 页**，
> API 10 / target 26，compileSdk **26.0.0.23 Beta1 = DevEco 6.x**，代码零混淆）。
> 逆向方法本身见配套 skill **`lite-wearable-hap-reverse`**。
> ⚠️ 该工程编译链比你手上的 API 10 / SDK 3.1 新，下列写法**照抄前必须真机验证**。

### B1. `host` 页挂载公共模块（绕开跨页共享不可靠）

用一个**没有 UI 的 `host` 页**做装配：`onInit` 里把公共模块挂到 `getApp()`，然后 `router.replace` 跳转。

```js
onInit() {
  var app = (typeof getApp === 'function') ? (function(){ try { return getApp(); } catch(e){ return null; } })() : null;
  if (app) {
    app['toast']   = unwrap(toastMod);   // 见下方双形态兼容
    app['bounce']  = unwrap(bounceMod);
    app['stats']   = unwrap(statsMod);
    app['money']   = unwrap(moneyMod);
    app['gmMulti'] = unwrap(engineMod);
  }
  router.replace({ uri: 'pages/boot/boot' });
}
```

- **双形态兼容**：`m.default` 与 `m.default.default` 都要试，用特征方法判断：
  `var x = m.default && typeof m.default.show === 'function' ? m.default : (m.default && m.default.default);`
- 挂载后逐个 `console.info` 打出 `ok / NULL`，便于真机排查
- 后续页面统一 `getApp().xxx` 取用，**不再各自 require**

### B2. 音频：rawfile 不能直接播

1. 先用 `@system.file.copy()` 把 `internal://app/rawfile/audio/x.mp3`
   复制到 `internal://app/music/x.mp3`，**再播 internal 路径**
2. 启动做**完整性门禁**：逐个 `access()` 检查，缺文件就**整体禁止播放**
   （商业工程注释原话：`音频文件缺失, 将禁止播放避免音频服务崩溃`）
3. **懒加载**：按需单文件 copy，同名请求入队合并
4. **SFX 打断 BGM 后自动恢复**：
   - `playSfx` 前记录当前 BGM，播完 `onended` 里自动 `playBgm` 恢复
   - **必须有超时兜底**（实测 3200ms）—— lite 上 `onended` 可能不触发，没有兜底就会**永久静音**
   - 播放中再来 SFX 则入队（上限 4）
5. **单一 Audio 实例复用**：`stop() → 改 src → loop=false → volume → play()`
6. 音量持久化用 storage key=`volume`，写入 **300ms 防抖**
7. 错误提示**节流**：10 秒窗口内最多 3 条

### B3. 零 if / 零 for 的 UI 写法（该工程 render 里三元表达式数量 = 0）

- 条件渲染全靠 **`opacity` 字段**（`pO / shvO / trayO / monO / crtO / vigO…`）+ `show="{{x}}"` 属性
- **列表用预置固定槽位**：8 个弹壳位（`s1Sr…s8Sr` + `s1O…s8O`）、5 个 toast 位（`toastP0…toastP4`），
  一次性铺满节点，用数据切换 —— 因为 lite 不能动态增删节点
- **按钮用 `<input type="button">`** + `value` + `onclick`（不是 `div`）
- **按压缩放动效**：`b_xxx` 数据字段 + `@keyframes press-down / press-up`，
  由统一 `bounce.trigger(vm, key)` 驱动 `[[20,"press-down"],[200,"press-up"],[220,""]]` 时序
- **⚠️ 动效串扰（2026-10-01 fetch-read 实证）**：lite 任意 data 变化会**整页重渲染并重启所有
  `animation-name` 非空元素**——A 按钮点击后其余按钮跟着缩放。修法：加
  `@keyframes pressNone {0%{transform:scale(1);}100%{transform:scale(1);}}` 作为所有按钮的
  **默认 animation-name**（重渲染重启也看不见），点击才把该按钮切到 pressA/pressB（双帧交替强制
  重播），并在 250ms 后 `setTimeout` 回落 pressNone（带 per-key timer 清理防连点抖动）。
  备选：回调后把 animation-name 置空串 `''`（等效无动画）。

### B4. 延迟任务池上限（防 setTimeout 泄漏）

游戏引擎里所有 `setTimeout` 统一走一个 `delay(fn, ms)`，
句柄入池，**池上限 32**，超限 `shift()` 丢最旧并 `console.error` 告警；
页面切换/重开局时 `clearAllDelays()` 全清。

### B5. 打包垃圾：`.png.bin`

`common/*.png.bin` 是**构建期图片缓存，几乎全 0 字节**。
实测占 HAP **37.6%（6.47 MB / 17.2 MB）**，大小非常规整（262152 / 868632 字节）。
**打包后务必检查产物里有没有这类文件漏进去。**

### B6. 该工程用到但你需验证的写法

| 写法 | 你的环境风险 |
|---|---|
| `width: calc(100% - 8px)` | 你的记录里 lite **不支持 `calc()`** |
| `:active` 状态样式（编译为 `prop:active`） | 你实测伪类会触发 **00308018 硬错** |
| `left` / `top` 定位背景层 | 你的记录里 lite **不支持 `position`** |
| 单页 JS 最大 47KB（game 页） | 你有 **≤48KB** 硬约束，已贴线 |

---

## C. API 23（HarmonyOS 6.1.0）Lite Wearable 新事实（2026-08-30 实测，EnglishDict 工程）

### C1. API 版本事实（官方文档确认）

- **API 23 = HarmonyOS 6.1.0(23)**（2026-04 发布，DevEco Studio 6.1.0+）；API 24 = 6.1.1
- **Lite Wearable 仍是 FA 模型**（HML+CSS+JS，config.json + js.pages 注册）；官方 healthFields 新 API
  也标注 "Model restriction: This API can be used only in the FA model" + Lite Wearable 标记
- 官方智能穿戴最佳实践（bpta-smartwatch）确认：儿童智能表 API 不低于 23 时工程级
  build-profile.json5 写法为 `"targetSdkVersion": "6.1.0(23)", "compatibleSdkVersion": "6.1.0(23)"`
- 本机 DevEco 6.1.1 SDK 位置：`D:/Devceo Studio 6.1.1/DevEco Studio/sdk/default/`
  （sdk-pkg.json 里 apiVersion=24），js/api 下 @system.* Lite 系列完整保留

### C2. API 23 build-profile.json5 标准写法（照抄，本工程实测可用）

```json5
// 根 build-profile.json5
{
  "app": {
    "signingConfigs": [],
    "products": [
      {
        "name": "default",
        "signingConfig": "default",
        "compileSdkVersion": "6.1.0(23)",
        "targetSdkVersion": "6.1.0(23)",
        "compatibleSdkVersion": "4.0.0(10)",   // 兼容 GT3/GT4/FIT 系列真机
        "runtimeOS": "HarmonyOS",
        "buildOption": { "strictMode": { "caseSensitiveCheck": true, "useNormalizedOHMUrl": false } }
      }
    ],
    "buildModeSet": [ { "name": "debug" }, { "name": "release" } ]
  },
  "modules": [
    { "name": "entry", "srcPath": "./entry", "targets": [ { "name": "default", "applyToProducts": ["default"] } ] }
  ]
}
```
- oh-package.json5 与 hvigor/hvigor-config.json5 的 modelVersion 用 **"6.1.0"**（不是 5.0.4）
- entry/build-profile.json5 仍是 `"apiType": "faMode"`；hvigorfile.ts 仍是 legacyAppTasks/legacyHapTasks

### C3. Lite 接口状态（API 24 SDK 的 d.ts 实测）

| 接口 | 状态 | 说明 |
|---|---|---|
| `@system.router` | ✅ Lite 专用 | 只有 `replace`/`getParams`/`back` 等；@ohos.router 是 `ArkUI.Full` **不支持 Lite** |
| `@system.storage` | ✅ FAModelOnly | Lite 唯一键值存储；get 返回 `{value:...}` 包装需 unwrap |
| `@system.brightness` | ✅ 有 `setKeepScreenOn({keepScreenOn})` | 屏幕常亮开关实现 |
| `@system.file` | ✅ | rawfile 读取 internal://app/rawfile/... |
| `@ohos.settingsLite` | ⚠️ since 24 | 只能打开系统设置页（PIN/NFC/双击键），不用于应用内设置 |
| `@system.device` / `@system.vibrator` | ✅ | 键盘振动反馈等 |

### C4. crabKeyboard 开源输入法集成法（MIT，crabPangXie/crabKeyboard，2026-08-29）

原始工程是 **API 7 老 Gradle 体系**（compileSdkVersion 7），不能直接用；**只复制源码资产**到新工程：

```text
# 要复制的三样东西（保持目录/文件名不变）
entry/src/main/js/default/common/keyboard/            → js/MainAbility/common/keyboard/
    ├── lookupDictV5.js          # 拼音字典查询（分层 key*.dat 索引）
    ├── circle/ rect/ common/    # 键盘图片素材
entry/src/main/js/default/pages/keyboard_rect/        → pages/keyboard_rect/
entry/src/main/js/default/pages/keyboard_circle/      → pages/keyboard_circle/
entry/src/main/resources/rawfile/pinyinDictV5_20260416/  → resources/rawfile/  （41 文件 3.9MB）
```

业务页面打开键盘（Router.replace 传参）：

```javascript
Router.replace({
  uri: '/pages/keyboard_rect/keyboard',   // 方表盘；圆表盘用 keyboard_circle
  params: {
    targetPage: '/pages/index/index',     // 输入完成后回跳页面
    backPage: '/pages/index/index',       // 取消时返回
    targetKey: 'query',                   // 回写目标页 data 字段名
    prompt: '输入英文或中文', maxLen: 20,
    allowNewline: false,
    keyType: 1                            // 0中文拼音 1英文小写 2大写 3符号
  }
});
```
键盘完成时 `Router.replace({uri: targetPage, params: {targetKey: 文本}})` 回写；
目标页在 onShow 用 `Router.getParams().query` 接收。键盘内置偏好记忆/剪切板（internal://app/*.json）。

### C5. Lite CSS 白名单新实测（ace-loader 编译 ERROR 直接报）

用 SDK 自带 ace-loader（`<SDK>/js/build-tools/ace-loader/`）独立编译 FA 工程可精确定位错误：
`node node_modules/webpack/bin/webpack.js --config webpack.lite.config.js --env aceModuleRoot=<js/MainAbility 目录> --env aceModuleBuild=<输出> --env cachePath=<缓存>`
（注意 aceModuleRoot 下需临时放一个 manifest.json 列 pages；编译成功后删除）

实测报错项（一律 ERROR 阻断）：
- **`height: auto` 不支持**（只接受数字 px）→ 列表项给固定高度
- **`align-items: baseline` 不支持**（只支持 stretch|flex-start|flex-end|center）→ 用 center
- **`.a.b` 复合类选择器不支持**（如 `.searchText.filled`）→ 用 `if/else` + 内联 `style="color:...;font-weight:bold"` 代替
- **`list-item` 只能有一个子节点**（DevEco 6.1.1 新链阻断，旧 ace-loader 不报！）→ 多个并列 `<text>` 必须外包一层 `<div>`；
  报错形如 `The list-item tag can have only one child node.` + hvigor 00308018
- `transform: translateY(380)` 缺单位 → WARNING，必须写 `translateY(380px)`（4 处 keyframes 都要改）
- `grey` 等颜色名会被自动修正为 `#808080`（NOTE 不阻断）；`line-height` 内联为 WARN；
  `border`/`font-weight`/`line-height`/`max-width` 会提示 "is not a standard attribute name"（WARN 不阻断）
- **重要：验证编译必须用与用户 IDE 相同版本的 SDK ace-loader**（旧 SDK ace-loader 规则宽松，
  可能漏报 list-item 单子节点等新构建链错误）

### C6. A/B 双词库 + 双向查询 + 多释义（词典类应用可复用）

- **方案A（完整词库）**：rawfile 按首字母分片 JSON（`dictA/a.json`...）+ 中文反向索引 `zh.json`；
  File.readText + JSON.parse，慢但全（音标/词性/多义/例句）
- **方案B（快速词库）**：common/dict/dictB.js 常量对象（200 高频词），随 JS 内联，O(1) 内存直查
- **切换机制**：设置存 defaultDict='Auto'|'A'|'B'；Auto = [A→B] 顺序，A 未命中/读失败自动落 B
- **双向判定**：词含 CJK（0x4e00-0x9fff）→ 中译英查 zh.json 反向索引；否则英译中查首字母分片
- **多释义**：senses.length>1 → Router.replace 到 choose 页选择 → JSON.stringify(picked) 回 result 渲染
- 词库生成工具用 Python（system python 有 Pillow）；A 词库 396 词 / B 200 词 / zh 索引 641 条

## 联网调第三方 Web API（`@system.fetch` 联调 + 鉴权 / CSRF，2026-09-24 实证）

> 案例：手表端调站点 `/api` 的签到 / 幸运大转盘接口。

### 0. 总原则
手表端的网络问题，**99% 能先在 PC 上用 `curl` / Node 复现并定位**。先在电脑上把「鉴权 + CSRF + 请求体」
调通拿到 `code:0`，再把同一套 header 搬进 `@system.fetch`，真机一次过的概率大幅提高。

### 1. 先逆向出接口契约，再写手表代码
1. `curl` 取页面 HTML —— 若为 SPA（Vite/Webpack），从 `<script type="module" src="/assets/index-xxx.js">` 拿 bundle。
2. **压缩成一行的大 bundle 用 Grep 工具无效**（整行超长会被省略）→ 用 Python 正则抽 `["'`]/path["'`]`
   或关键词前后 300 字符上下文。
3. 找路由分包名（搜 `path:"checkin"` → `Checkin--QUc2Gr5.js`），再顺 `import{...}from "./xxx.js"`
   找到真正的 API 模块（**接口清单通常独立成一个小分包，如 `points-XXXX.js`**）。
4. 在 index bundle 里找 axios 实例（`Dn.create({baseURL:...})`、请求拦截器加 `Authorization`、
   **响应拦截器 `e=>e.data` —— 返回的是 JSON body，不是 axios response**）。

### 2. 回调式封装（直接照抄）
```js
request: function (method, path, body, cb) {
  if (!this.ensureApi()) { cb(false, '联网模块不可用(@system.fetch)'); return; }
  var header = { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + TOKEN };
  if (method === 'POST') { header['X-CSRF-Token'] = CSRF; header['Cookie'] = 'csrf_token=' + CSRF; }
  var options = {
    url: BASE + path, method: method, header: header,
    success: function (res) {
      var raw = res ? res.data : null, obj = null;
      if (raw && typeof raw === 'object') { obj = raw; }
      else { try { obj = JSON.parse(String(raw)); } catch (e) { obj = null; } }
      obj ? cb(true, obj) : cb(false, 'HTTP ' + (res ? res.code : 0) + ' 响应无法解析');
    },
    fail: function (data, code) { cb(false, '网络失败 code=' + code); }
  };
  if (body && method !== 'GET') { try { options.data = JSON.stringify(body); } catch (e) {} }
  try { this.fetchApi.fetch(options); } catch (e) { cb(false, '请求异常'); }
}
```
- `res.code` = **HTTP 状态码**；业务码在 `res.data.code`（自己解析后判断）。
- `require('@system.fetch')` 必须 `try/catch` + **`ensureApi()` 懒加载**（`onInit` 偶发不触发，别只在 onInit 缓存模块）。
- **联网入口放 `onShow`**，不放 `onInit`。
- `header` 可下发自定义头（`Authorization` / `Cookie` / `X-CSRF-Token` 都实测可下发）。

### 3. 鉴权两件套
| 项 | 做法 | 注意 |
|---|---|---|
| `Authorization: Bearer <token>` | token 通常在浏览器 `localStorage['token']`，手表端取不到 → **源码里填常量** | 登录接口带图形/极验验证码的，**手表端根本无法登录**，别浪费时间去实现登录页 |
| **CSRF 双提交**（仅 POST） | `Cookie: csrf_token=V` **且** `X-CSRF-Token: V`，两值必须完全一致 | 见下方关键发现 |

**★ 关键发现（能省一大步）**：若服务端只做「双提交一致性校验」（**不校验 V 是否由它自己下发过**），
手表端就可以**自造一个固定的 32 位十六进制值**直接用，**完全不必先 GET 一次去读 `Set-Cookie`**。
判定方法：PC 上 `curl` 带一对自造值发 POST —— 若错误从 `csrfRequired` / `csrfFailed`
变成「未登录」之类的业务错误，就说明 CSRF 已过、可以自造。

**★ 头名别猜**：Express/Node 侧通常取 `req.headers['x-csrf-token']`，所以 `X-CSRF-Token` 可用；
而 `csrf-token`、`CSRF-Token`、`X-XSRF-TOKEN`（axios 默认名）会 403。**照抓包抄，不要按惯例猜。**

### 4. HTTPS
`<SDK>/js/api/@system.fetch.d.ts` 权威声明里 `url: string` **没有任何协议限制**，官方 skill 示例本身就用 https。
社区流传的「Lite Wearable 只支持 HTTP、不支持 HTTPS」**未经真机证实**，勿当定论。
工程里把 `ORIGIN` 提成常量，http/https 一键切换，真机失败时立刻二分定位。

### 5. 排错顺序（照这个顺序查，别乱试）
| 现象 | 定位 |
|---|---|
| `http.createHttp` / `@ohos.net.http` 是 `undefined` | 正常：lite 没这个模块，换 `@system.fetch` |
| 服务端说 **CSRF 缺失** | 没带 Cookie（或网络栈剥离了手工 `Cookie` 头） |
| 服务端说 **CSRF 失败** | Cookie 与请求头两值不一致，或头名写错 |
| 服务端说 **未登录** | ✅ CSRF 已通过，只是 token 无效/过期 |
| `fail` 回调 code 非 0 | 网络层失败：DNS / TLS / 超时 → 先怀疑 https 与域名可达性 |

### 6. 配套工具（可复用）
- **PC 端 Node 自测脚本**：`node check-api.js <TOKEN> [--checkin] [--spin]`，上表接口一把过，省掉真机瞎试。
- **纯标准库 PNG 圆形图标生成器（不需要 Pillow）**：`zlib` + `struct` 手写 IHDR/IDAT/IEND，
  按 RGBA 逐像素画圆 + 对勾，**4× 超采样再降采样**做抗锯齿，一次产出 114×114 `icon.png`
  与 80×80 `icon_small.png`。适合 managed venv 装不上 Pillow 的环境。

### 7. 让普通用户自己取 token：**只能用书签脚本（Bookmarklet）**
手表端无法登录（登录多带图形/极验验证码），必须让用户自己从浏览器里把 token 抠出来。
**面向手机用户时这是唯一的可行路径** —— 站点一般不会在任何界面上展示 token（它只存在 `localStorage`）。

**★ 三个必须写进教程的硬事实（2026-09-24 核实，漏了任何一条用户都会卡住）**

1. **手机上调书签的方式和电脑完全不同**：安卓**从「书签菜单」里点书签不会执行**（浏览器拿不到当前页面
   上下文），**必须「点地址栏 → 输入书签名字 → 点跳出来的带 ★ 的建议」**。这是"点了没反应"的头号原因。
   （Chrome Web/DevRel lead Paul Kinlan 的发现，多家转载；Edge 安卓同一套。）
2. **手机书签 URL 长度限制约 2KB～8KB** → 书签脚本**务必压在 2KB 以内**（去掉冗余内联样式、
   用 `innerHTML` 一次建面板、`javascript:!function(){...}();` 起手；本项目从 2222 字符压到 1645）。
   另外 **CSP 严格的站点可能拦书签脚本**。
3. **按浏览器逐个分诊，并给用户一个自测手段**：
   - ✅ Chrome 安卓 / Edge 安卓 / Firefox 安卓 / 三星浏览器 —— 地址栏调用法
   - ✅ **Via 浏览器** —— 支持 `javascript:` 书签，**地址栏直接粘贴 `javascript:` 回车也能跑**；
     还有「脚本管理」（设置 → 更多/高级工具）可指定匹配网址 `*` 自动执行，比书签更省事
   - ⚠️ 夸克 / UC / QQ 浏览器 —— 部分版本拦截 `javascript:`
   - ❌ 微信 / QQ 内置浏览器 —— 没有书签功能，要「⋯ → 在浏览器打开」
   - ⚠️ **iPhone 上 Safari / Edge / Chrome / Firefox 全是同一套 WebKit 内核，限制一致**
     → Safari 不行就别换浏览器，直接走电脑方案
   - 🧪 **最稳的招：教程里给一个「30 秒自测书签」** `javascript:alert('书签脚本可用')`，
     让用户自己点一下就知道能不能用 —— 比列一堆不确定的兼容表可靠得多。

**其它写法要点**
- 读 `localStorage.getItem('token')`，失败就遍历 localStorage 找 `eyJ` 开头的值兜底；
- 用 `document.createElement` + `innerHTML` 造全屏面板 + `textarea` + 「一键复制」
  （`document.execCommand('copy')` 失败再退 `navigator.clipboard.writeText`）；
- 教程里**必须反复强调「Token = 账号钥匙，别发群、别发帖、别截图」**。
- 电脑用户最省事的一招：`F12` → Console → `copy(localStorage.token)`，一行直接进剪贴板。
- 分发形态：单文件 HTML（手机浏览器打开、带一键复制）＋ 纯文字 Markdown（发群/发帖）＋
  单独一份 `bookmarklet.txt`（注意三处代码必须完全一致，改一处要同步）。

> ⚠️ **设计层面要提前想清楚**：Lite Wearable 没有键盘，用户拿到 token 之后**怎么送进手表**？
> 常见三条路：A 用户私聊发 token、作者定制打包；B 表端自带键盘让用户自己输入（见下节）；
> C 表端显示设备码、用户在网页绑定（需站点配合）。
> 做「需要账号」的手表 app 时，这个问题比取 token 更早需要拍板。

---

## ★ 图片体积铁律：每张图进包 = 宽 × 高 × 4 字节（2026-09-24 实测，血亏过）

**lite 编译产物里，每张 PNG 旁边必定生成一份未压缩位图 `xxx.png.bin`，大小 = 宽×高×4。**

实测证据（ace-loader 产物）：一张 466×466 的壁纸 PNG **只有 12.3 KB**，它的 `.bin` 是 **848.3 KB**。

| 图 | PNG | 实际进包(.bin) | 倍数 |
|---|---|---|---|
| 466×466 壁纸 | 12.3 KB | **848.3 KB** | 69× |
| 570×180 键盘布局图 | ~100 KB | **400.8 KB** | 4× |
| 240×240 壁纸 | 29 KB | **225.0 KB** | 7.8× |

**后果**：6 张全屏壁纸 = 5.09 MB；一个 4 布局的键盘 = 2.10 MB。整个包能轻松膨胀到 7.5 MB。

**做法**：
1. 每加一张图，先算 `W×H×4`，再决定要不要。
2. **降低源图分辨率是唯一有效手段**（`.bin` 是解码后的位图，跟 PNG 压缩率无关）：
   壁纸 466² → 240²，单张 848KB → 225KB。
3. **删掉不可达的图**：例如键盘只用到 keyType 1/2/3，就把 `0.png`(中文布局 400KB) 删掉。
4. UI 上尽量用**纯色 / 边框 / 文字**表达，而不是贴图。
5. 已知二次放大：真机 HAP 里同一张图会存 **png + 2 个 .bin**（DevEco 链），预算再乘 1.5 倍看。

## ★ 真机网络卡死三件套（2026-09-25 实证）

**症状**：真机进页面 / 进应用市场直接卡死无响应，模拟器（rich 引擎）一切正常。

1. **串行队列**：lite 真机网络栈扛不住并发/连发 fetch。`fetchQueued/pumpQueue`
   一次只放一个 fetch 出队 + **20s `setTimeout` 看门狗**（fail/finish 双兜底，防单请求挂了把整条队列锁死）。
2. **finish 里必须异步放行**：`setTimeout(function(){ that.pumpQueue(); }, 50)`——
   lite 的 fetch 回调可能是**同步调用**，在回调里同步 pump 会递归连发，把 JS 栈打爆（表现为卡死）。
3. **响应体积即内存**：大 JSON 会撑爆弱小 JS 堆（全量 `/app/list` 131KB 是卡死主因）。
   → 分页拉取（`pageSize=20` ≈ 26KB/页，本地翻完再拉下一页）；推荐位改用小接口（`/app/hot` 13KB 替代全量列表）。
4. **启动懒加载**：`onInit` **零网络请求**，读到 token 后走 `bootstrap()` 按落点视图拉最小数据集，
   其余视图**进入时**才拉（`loaded*` 守卫防重入）。进页瞬间排满 5 个请求，即使串行也会把首屏拖死。

**顺带教训（视图切换）**：切换函数的参数类型必须一致——`showView('ord')` 传字符串而函数按
`v === 2` 数字比较，四个视图布尔标志全 false → **整页空白且不报错**（最难查的一类 bug）。


## ★ lite 不能直接加载网络图片，但 **base64 data URI 可以**（2026-09-25 实证修正）

> **原表述「`<image src>` 只支持本地路径」不准确，已修正。** 正确结论：不接受**网络 URL**，但**接受 base64 data URI**。

- `<image src>` **不支持网络 URL（http/https）**，也不支持 SVG。
- ✅ **支持 base64 data URI**：`data:image/jpeg;base64,...`，**必须带 `data:image/<type>;base64,` 前缀**（纯 base64 串不行）。
- `@system.fetch` 的 `responseType` 文档原文**只有 `text` 或 `json`** → **拿不到二进制**，自己下载图片这条路不通。

### ✅ 可行方案：服务端把图片转 base64，用 JSON 通道拉回来（fetchbilibili 项目实证）

四步链路：

1. `fetch` 业务 API（`responseType: 'json'`）→ 拿到图片的**网络 URL**
2. 请求「URL → base64」转换服务，例如 `https://uapis.cn/api/v1/image/tobase64?url=<encodeURL(imgUrl)>`
3. `fetch` 该服务（`responseType: 'json'`）→ 拿到 `{"base64":"data:image/jpeg;base64,/9j/4AAQ..."}`
4. `<image src="{{base64}}">` 直接显示

**实测证据（2026-09-25 / DevEco 6.1.1 / API 24 模拟器 466×466）**：

- B 站 API 返回 `pic = http://i0.hdslb.com/bfs/archive/xxx.jpg`
- 转换服务返回 `{"base64":"data:image/jpeg;base64,...","msg":"success"}`，**4227 字符，带完整 data URI 前缀**
- 模拟器截屏确认：**封面图 + 文字全部正常渲染**（不只是"编译通过"，是真跑起来了）

**拼接技巧（B 站图床为例）**：`encodeURL(pic) + '@240w_240h_0e_50q.jpg'`
—— `@缩略图后缀` 拼在**编码串外面**，服务端只解码 `url` 参数的值，解码后正好还原成 `...jpg@240w_240h_0e_50q.jpg`（B 站缩略图语法）。

**局限**：

- 依赖第三方服务可用性 → 生产环境建议**自建**转换接口，别长期依赖公共 API
- base64 比原图膨胀约 33%，几 KB 小图无压力，**大图不适合塞进 data 绑定**
- 尺寸受服务端参数控制（上面固定 240×240）

**配套：lite 没有 `encodeURIComponent`，要自己写**：

```js
function encodeURL(str) {
  var hex = "0123456789ABCDEF", out = "";
  for (var i = 0; i < str.length; i++) {
    var c = str.charCodeAt(i);
    if ((c >= 48 && c <= 57) || (c >= 65 && c <= 90) || (c >= 97 && c <= 122) ||
        c === 45 || c === 46 || c === 95 || c === 126) { out += str.charAt(i); }
    else { out += "%" + hex[(c >> 4) & 0xF] + hex[c & 0xF]; }
  }
  return out;
}
```

> 注：`<image>` 用 base64 时**仍必须显式写 width/height**（lite 不认百分比、不认隐式尺寸）。

### 🚫 客户端自己下载图片：已实测封死（2026-09-25）

在模拟器（API 24 wearable）上**同一进程、同一时刻**做对照：

| 请求 | 结果 |
|---|---|
| 拉 B 站业务 JSON | ✅ 完整（`code:0` + 全字段） |
| 拉 base64 JSON | ✅ 完整（数千字符） |
| 拉图片 `responseType:'text'` | ❌ `code=200 type=string len=2` |
| 拉图片 `responseType:'arraybuffer'` | ❌ `code=200 type=string len=2`（**类型仍是 string，不是 ArrayBuffer**） |
| 拉图片 不传 responseType | ❌ `code=200 type=string len=2` |

- 已排除防盗链干扰：同一 URL 用 node 直拉是 **656 字节真 JPEG**（魔数 `255,216,255,224`）。
- 结论：**不是网络问题，是 lite 引擎丢弃了 `image/*` 响应体**，三种 `responseType` 都拿不到字节。
- ⇒ 「fetch 下载图片 → 写盘 → image 指向文件」这条路彻底封死（与后文 `writeArrayBuffer` 写 0 字节的实测互相印证）。

### 📦 完全无服务器的可行路线：图片预置 + 本地驱动

`<image>` 的合法来源只有两类：**本地资源** 与 **base64 data URI**。不想碰服务器就只能走"预置"：

1. **图片打包进应用**（✅ 本项目实测可用）：放 `entry/src/main/js/MainAbility/common/images/xxx.png`，HML 里写 `src="/common/images/xxx.png"`，**显式给 width/height**。
   - 注意 `common/` 在真机文件系统里对 `@system.file` **不可见**，它只是编译期资源；引用一律用绝对路径 `/common/...`。
2. **动态性靠"选哪张"**：
   - **零服务器**：本地日期算索引轮换（`天数 % 图片张数`）—— 图集固定，但每天/每周自动换
   - **要远程可控**：接口只返回一个**数字**（选第几张），不传图 → 服务端成本趋近于零
3. **包体积权衡**：图片资源会进 HAP（编译期转位图），数量与尺寸要压（参考「图标占 HAP 近 31%」那条）。
4. 若必须"每天真正换新图"，就绕不开服务端 —— 但可以是最小的一个云函数（收 URL → 转 base64 → 返回 JSON），比依赖公共 API 可靠得多。

### 💡 免费方案：`wsrv.nl` 的 `&encoding=base64`（✅ 设备实测跑通，无需注册/无需自己搭）

**目前最省事的免费方案 —— 不注册、不写后端、不维护服务器。**

```
https://wsrv.nl/?url=<encodeURIComponent(图片URL)>&w=240&h=240&fit=cover&output=jpg&encoding=base64
```

- 返回 **`Content-Type: text/plain`**，body 就是完整的 `data:image/jpeg;base64,/9j/2wBD...`
- **关键**：Content-Type **不是** `image/*`，所以**不会被 lite 引擎丢弃二进制** —— 这正是它能成的根本原因
- 客户端只写：`fetch(url, { responseType: 'text' })` → 把 `res.data` 直接丢给 `<image src>`

**设备实测（2026-09-25 / API 24 模拟器）**：

| 项 | 结果 |
|---|---|
| `code` | `200` |
| `type` | `string` |
| `len` | **8859**（对比：直接拉 `image/*` 只有 `len=2`） |
| `head` | `data:image/jpeg;base64,/9j/2wBDAAYEBQYFB` |
| 截屏 | ✅ 封面图 + 文字全部正常渲染 |

`&fit=cover&w=240&h=240` 顺带做了等比裁剪，不必再靠图床自带的缩略图后缀。

**服务对比（本机 node 实测）**：

| 服务 | CT | 长度 | 耗时 | 备注 |
|---|---|---|---|---|
| `wsrv.nl?...&encoding=base64` | text/plain | 8859 | 2.7s | Cloudflare 支撑，老牌免费图片代理 |
| `images.weserv.nl?...&encoding=base64` | text/plain | 6111 | 1.7s | 同源域名，同一家 |
| `uapis.cn/api/v1/image/tobase64` | application/json | 4256 | **0.18s** | 国内快，但要解 JSON，小众服务 |

- `uapis.cn` 返回 `{"base64":"..."}` → 取 `res.data.base64`；**wsrv.nl 返回裸文本 → 直接 `res.data`**。
- wsrv.nl 走 Cloudflare，**国内可能偏慢**；uapis.cn 国内快但可靠性未知。**两个都留着互为 fallback 最稳。**
- 生产环境最稳的仍是自建 20 行云函数，但**做个人项目/原型，wsrv.nl 足够且零成本**。

## ⛔ 表端自带键盘（crabKeyboard）—— **已判定不可行，别再走这条路**（2026-09-25）

> **结论先说**：在「手表上让用户自己输一长串 token」这个需求上，
> **crabKeyboard 方案已判定不可行并撤除**。真机表现为「**按不动**」，原因两条：
> ① 它全量使用 **`grab:` 前缀事件**，当前运行时**根本不注册**（见前文「HML 事件前缀」章节）；
> ② 它依赖 `stack` + 写死坐标的绝对定位，在非 lite 引擎上布局与命中判定都不可靠。
>
> **替代方案（推荐）**：让用户把 token 私聊发给作者，作者用脚本把 token 注入源码后打包
> （「源码注入 + 定制打包」模式）——零输入、零依赖，用户侧最省事。
> 若坚持要表端输入，请先做**最小验证**：一个 `onclick` 按钮 + 一个 `input`，
> 确认事件能注册（`uitest dumpLayout` 里 `clickable=true`）再投入。
>
> 以下为历史调研记录，仅在「明确知道自己在干什么」时参考。

### 历史接入清单（crabKeyboard，MIT · crabKun）

面向「用户在手表上自己输入一长串文本（token / 账号 / 服务器地址）」的场景。
参考实现：[crabKeyboard](https://github.com/crabPangXie/crabKeyboard)（MIT · crabKun），**Gradle/API 6 时代工程**，
搬到 hvigor API 10 要处理这几件事：

| # | 改动 | 说明 |
|---|---|---|
| 1 | `Router.replace(...)` → **`Router.replaceUrl(...)`** | 原工程是 API 6 写法，API 10 会静默不跳转 |
| 2 | 在「确认」分支里**额外把结果写进 `internal://app/xxx.txt`** | **lite 真机路由 params 注入不可靠**，文件通道才稳；取消分支要清空它 |
| 3 | 键盘布局循环 `(keyType±1)%4` → **只在 1/2/3 之间循环** | 原版能滑到 `keyType=0`（中文布局）；不带拼音词典时滑过去是**一片空白** |
| 4 | 删掉不可达的布局图（如 `0.png`） | 省体积（一张 570×180 = 400KB .bin） |
| 5 | 拼音词典 `rawfile/pinyinDictV5_*/`（**3.9MB**）可不带 | `lookupDictV5.js` 读取失败会 `then("", null)` **静默降级不崩**（读源码确认）；纯 ASCII 输入用不上 |
| 6 | 目录结构要平移 | 原 `js/default/pages|common` → 本工程 `js/MainAbility/pages|common`；资源路径 `/common/...` 不变（产物确认资源输出到应用根 `common/`） |
| 7 | `config.json` 注册键盘页 + 加 `ohos.permission.VIBRATE` | 键盘按键有振动反馈 |

**字符覆盖规律**（读源码得出）：字母直接点、**长按 = Shift**。所以「大写」布局一个就能覆盖
`A-Za-z0-9 - _ .` 全集（点=字母，长按 `q~p`=数字 1-0，长按其它位=常见符号）。
调用时把 `keyType` 设成 2 最省事，并给用户一句提示。

**交互约束**：`swiper` 内部 div 的 click 会被滑动手势吞掉 → **点按统一绑 swiper 组件自身的 onclick**，
再按当前屏序号分派动作（一屏一个主操作）。见上文「滑动 + 点击交互」。

**🔴 已实测（2026-09-25）**：原键盘大量用 **`grab:` 前缀事件**（`grab:click` / `grab:longpress` / `grab:swipe` / `grab:touchstart|move|end`），
在当前运行时上**全部不注册**（`uitest dumpLayout` 显示 `clickable=false`，注入点击无反应）——
**这就是「按键盘没反应」的根因**。若哪天要恢复此方案，第一步就是把这 17+ 处前缀全改成裸名，
并用 `uitest` 验证 `clickable=true` 之后再谈别的。

## 🔴 `@system.file.writeArrayBuffer` 会「成功」地写出 **0 字节文件**（2026-09-25 实测）

**场景**：fetch 下载图片二进制 → `writeArrayBuffer` → `image.src` 指向该文件。
**实测**（HarmonyOS 6.1 wearable / API 24）：`responseType:'arraybuffer'` **拿不到二进制**
（回调 `data` 是空对象），`writeArrayBuffer` 却**回调 success** 并写出一个 **0 字节文件**；
于是 `image` 加载失败 → **界面空白**，而且没有任何报错。

**铁律：写盘前先验证字节，验证不过就绝不切换显示源。**

```js
/* 长度 + 图片魔数逐字节比对（不能用正则） */
isImageBuffer: function (buf) {
  if (!buf) { return false; }
  var len = (typeof buf.byteLength === 'number') ? buf.byteLength
          : ((typeof buf.length === 'number') ? buf.length : 0);
  if (len < 512) { return false; }              /* 真图片不可能这么小 */
  var b = null;
  try { b = new Uint8Array(buf); } catch (e) { b = null; }
  if (!b || b.length < 8) { return true; }      /* 取不到视图但长度够 → 放行 */
  var b0 = b[0], b1 = b[1], b2 = b[2], b3 = b[3];
  if (b0 === 255 && b1 === 216 && b2 === 255) { return true; }            /* JPEG */
  if (b0 === 137 && b1 === 80 && b2 === 78 && b3 === 71) { return true; } /* PNG  */
  if (b0 === 71 && b1 === 73 && b2 === 70 && b3 === 56) { return true; }  /* GIF  */
  if (b0 === 66 && b1 === 77) { return true; }                            /* BMP  */
  if (b0 === 82 && b1 === 73 && b2 === 70 && b3 === 70) { return true; }  /* WEBP */
  return false;
}
```

兜底通道：不带 `responseType` 拿**原始字符串**，`charCodeAt(i) & 255` 逐字符还原成 `Uint8Array`
（循环里不能有正则），再过一遍魔数校验。校验不过 → **保持内置默认图**，绝不切到空文件。

**配套事实**：FA 模型里 `internal://app/` 实际落在
**`/data/app/el2/100/base/<bundleName>/haps/entry/files/`**（不是 base 下的 `files/`），
`hdc shell ls -la` 直接能看文件尺寸，是排查「写没写成功」的最快手段。

## ★ ace-loader 编译验证的正确路径

`<SDK_ROOT>/js/build-tools/ace-loader` 这条旧路径**会找不到**——本机实际在 **`<SDK_ROOT>/10/js/build-tools/ace-loader`**
（即 SDK 根的 API 号子目录下）。命令模板见本项目 README「编译验证」一节，
本机可复现路径：`D:/OpenHaymony_SDK_6.1.1/10/js/build-tools/ace-loader`。
实测一次完整编译（含 HML/CSS 校验）约几秒，**改完 HML/CSS 后先跑它，比上真机快得多**。

> ⚠️ **但 ace-loader 规则比 hvigor 松：它 SUCCESS ≠ DevEco 能过。**
> 已知至少 `list-item` 单子节点（00308018）它不报。**交付前必须再过一遍真 hvigor 链**，见文末「★ 用真正的 hvigor 链验证」。

### ★ 静态自检脚本 `precheck.py`（黑屏类问题唯一能在上机前抓住的手段）

**关键认知：有一类错误两条编译链都不报 —— 它们不是语法错也不是资源错，只是"渲染不出来"，
真机表现就是黑屏/元素消失。**（典型：`swiper` 里放 `list`。）所以必须有一个静态检查兜底。

脚本放在工程 `tools/precheck.py`，`python tools/precheck.py <工程目录>`，退出码 0 = 干净。检查项：

| 类别 | 检查项 |
|---|---|
| 两条链会报 | `list-item` 直接子节点 > 1 ／ 复合类选择器 `.a.b` ／ 选择器列表 `.a, .b` ／ `auto` 尺寸 ／ `align-items: baseline` ／ 伪类与子选择器 ／ `transform` 缺单位 |
| **两条链都不报** | 🔴 `swiper` 内含 `list` ／ `list` 子节点非 `list-item` ／ `list-item` 父非 `list` ／ 容器（`div`/`stack`/`list`/`list-item`）缺固定 `width`+`height` ／ `text` 缺固定 `width` ／ 根元素不是 `div`/`stack` ／ 标签不在白名单 |

**写检查规则时的两条经验（避免把它做成误报机器）**：
- 尺寸检查**只对"用 class 的元素"生效**：完全靠 inline style 布局的元素（螃蟹键盘风格，`left/top` + 父容器定位，
  真机已验证）不套用"flex 居中下缺尺寸"规则；写了 `left/top` 的元素也跳过。
- **`text` 只要求 `width`，`height` 由内容决定；容器（`div` 等）才强制 height** ——
  技能库 CSS 模板 D 的 `.stage-text` 本身也只写 width。一刀切会对键盘页产生大量误报。
- 写完一定要**用一份故意写坏的 HML 反向验证**（造个 `swiper > list` + 缺 height 的 div），
  确认真能抓出来；否则工具就是摆设。

### ★★ jerry.exe 引擎级语法验证（**排查 JS 黑屏的终极手段**）

**重大发现：SDK 里自带引擎本体。** 路径：

```
<SDK>/<API>/js/build-tools/ace-loader/bin/jerry.exe      （本机 D:/OpenHaymony_SDK_6.1.1/10/...）
```

`ace-loader/bin/` 下还有 `jerry-snapshot.exe`。它就是真机/预览器里跑 JS 的那套 JerryScript。

用法（`--parse-only` = 只解析不执行，不会有依赖问题）：

```bash
jerry.exe --parse-only <编译产物.js>
```

**为什么必须用它**（三层解析器的能力差异）：

| | ace-loader | hvigor | **jerry.exe** | 真机/预览器 |
|---|---|---|---|---|
| 解析器 | Node/V8 | Node/V8 | **JerryScript（同引擎）** | JerryScript |
| 发现正则问题 | ❌ | ❌ | ✅ | ✅（但只表现为黑屏） |

⇒ **V8 能过 ≠ lite 能过。** 凡是"编译全 SUCCESS 但一跑就黑屏"的 JS 问题，都用它定位。
已封装为工程脚本 `tools/jerry-check.py`（自动找 SDK → 编译 → 逐个产物 `--parse-only` → 汇总）。

### ★★ 黑屏排查的正确顺序（2026-09-24 血亏，不要再猜）

**第一步永远是读日志，不是改代码**：

| 日志 | 路径 |
|---|---|
| 构建日志 | `<工程>/.hvigor/outputs/build-logs/build.log` |
| **预览器日志** | `C:\Users\<你>\AppData\Local\Huawei\DevEcoStudio6.1\log\previewer.log` |
| IDE 日志 | `C:\Users\<你>\AppData\Local\Huawei\DevEcoStudio6.1\log\idea.log` |

日志是 **UTF-16 / 含 NUL 字节**，`grep` 会当二进制跳过 → 用 python 读时先 `raw.replace(b'\x00', b'')`。

**看到这四行 = 确诊「JS 求值失败」，与 HML/CSS 无关，别去查布局**：

```
[ACELite][ERROR]:Eval JS file failed
[ACELite][ERROR]:Nothing to render as it is undefined.
[ACELite][ERROR]:Scroll Layer: AppendScrollLayer function parameter rootComponent error.
[ACELite][ERROR]:[Error message too long]        ← 真错误被截断 → 用 jerry.exe 复现
```

**分诊表**：

| 日志特征 | 根因方向 | 处理 |
|---|---|---|
| `Eval JS file failed` + `Nothing to render` | **JS 层**（正则最常见） | 跑 `jerry-check.py`；正则改 charCodeAt |
| 只有 `Nothing to render`，无 Eval 失败 | `export default` 结构 / 页面路径 | 查 config.json pages 与 export |
| Eval 正常但仍无内容 | HML/CSS 层 | 查 `swiper` 含 `list`、容器缺固定宽高 |
| `current state(N) is invalid when changing ...` | 生命周期状态机（**是结果不是原因**） | 先修上面几条 |

**教训**：这次一开始只查 HML/CSS（改了 4 处真问题），但真凶是 JS 里的 3 处正则。
**`Eval JS file failed` 里的 "JS" 说明是 JS 问题，不是布局。**

---

## ★★ 把设备当调试器：`hdc` + `uitest` 注入法（2026-09-25 实证，**强烈推荐**）

**痛点是「盲改」**：改完只能让用户装上肉眼看、口头描述现象，来回好几轮。
其实设备/模拟器连着 `hdc` 时，**布局树、截图、触摸注入全都能自己来**，一轮定位。

```bash
# hdc 在 DevEco SDK 里；模拟器与真机都能连
HDC="<DevEco>/sdk/default/openharmony/toolchains/hdc.exe"

"$HDC" list targets                                   # 设备列表（模拟器常见 127.0.0.1:5555）
"$HDC" shell param get const.product.devicetype       # ★ 设备类型：wearable / liteWearable
"$HDC" shell param get const.ohos.apiversion          # API 版本
"$HDC" shell bm dump -a                               # 已安装包名
"$HDC" shell bm dump -n <bundleName>                  # 该包的 ability / deviceTypes / package
"$HDC" shell aa start -a <ability全名> -b <bundleName> # 启动
"$HDC" shell aa force-stop <bundleName>                # 先杀掉再启动，保证走 onInit
"$HDC" install -r <path>/entry-default-unsigned.hap    # ★ 自己装未签名包（debug 设备可装）
"$HDC" shell uitest dumpLayout -p /data/local/tmp/a.json   # ★★ 抠布局树（含 clickable / bounds / text）
"$HDC" file recv /data/local/tmp/a.json a.json
"$HDC" shell uitest screenCap -p /data/local/tmp/s.png      # 截图
"$HDC" file recv /data/local/tmp/s.png s.png
"$HDC" shell uitest uiInput click 233 300                  # ★ 注入点击
"$HDC" shell uitest uiInput swipe 233 420 233 130 800      # ★ 注入滑动（含速度）
"$HDC" shell uitest uiInput longClick 233 300              # 长按
```

**这套方法能回答的问题**（都是以前只能靠猜的）：

| 问题 | 怎么看 |
|---|---|
| 元素到底渲染了没 / 在哪 | `dumpLayout` 的 `bounds` |
| **事件到底注册了没** | `dumpLayout` 的 **`clickable`**（这就是抓到 `grab:` 不注册的关键） |
| 点了有没有反应 | `uiInput click` 后重新 `dumpLayout`，对比 **文本变化** |
| 布局树里有没有违规容器 | 直接在树里看到 `swiper`/`list`/`div` 的真实嵌套 |
| 页面是不是压根没起来 | `dumpLayout` 只有极少节点 / 无内容 |

**踩坑注意**：
- `hdc file recv` 的目标路径**别写 `C:/...`**——它会把盘符当相对路径拼到 cwd 上，
  报 `open path:C://Temp//C:/...` 这种怪错。**先 `cd` 过去再用纯文件名**，或写完整 Windows 反斜杠路径。
- Git Bash 里 `DUMP` 之类变量赋值要注意引号，路径含空格（`Devceo Studio 6.1.1`）必须整段加引号。
- `uitest` 在真机上可能报 `i18n_param_config.xml: Permission denied` —— **无害**，命令照样成功。
- **设备类型会决定装哪个变体**：`config.json` 同时声明 `["liteWearable","wearable"]` 时，
  构建会产出两份 hap，DevEco 按设备 `const.product.devicetype` 选。
  于是**在 `wearable` 设备上测的是「非 lite 引擎」**——`grab:` 前缀、`list` 嵌套、
  `.bin` 图片这些 lite 专属规则**表现完全不同**，别把模拟器结论当 lite 真机结论。
- 该变体的 hap 里 `module.package` 可能是模板默认值（如 `com.example.myapplication`），
  于是 **ability 全名 = `<module.package>.MainAbility`**；`aa start -a MainAbility` 会报
  「ability does not exist」，必须用全名。

## ★ 给「图片 + 写死命中判定」的组件改尺寸（通用套路，别只缩图）

很多第三方 lite 组件是**用写死的像素做点击判定**的（键盘最典型）。
把图片缩小但不同步改判定常量 → **点下去全按到隔壁键**。改尺寸必须成组改：

| 类别 | 要同步的东西 |
|---|---|
| 命中判定 | 行高、键距/步长、每行偏移、**键区顶边的全局 y**、键区左侧留白 |
| 图片尺寸 | 每个布局图各自的宽高（宽窄不同的布局**不能共用一个宽度常量**） |
| CSS | 容器高度、图片 top，以及面板里所有子元素的 width/height/left/top |
| HML 内联几何 | 按钮 left、图标位置、进度条位置，以及**这些表达式里参与运算的常量** |
| 动画 / 滑动 | 可滑距离 maxLimit、滑入距离、"内容宽度" |

**两个具体坑（都踩过）**

1. **`maxLimit` 变成 0 会导致除零 → NaN**。
   形如 `left: {{base + 100*keyPos/(keyType==3?-333:-162)}}` 的进度圆点表达式，
   若把字母档 maxLimit 改成 0，分母就是 0 → 圆点被甩出屏幕。
   → 给一个**非零的"虚拟范围"**当除数（如 `-9999`），因为那一档根本不会滑动。
2. **同级 `stack` 子元素的位置换算**。给 A 改了 `left` 后，原本"看起来在 A 里面"的 B
   （其实 B 是 A 的**兄弟节点**，只是靠坐标叠在 A 上）也必须按 A 的新位置同步偏移，否则 B 会跑到 A 外面。
3. **🔴 组件主体的 width/height 常常写在 HML 内联里 —— 这是最容易漏的一处**（2026-09-24 实证）。
   螃蟹键盘缩小后：图片素材改了、CSS 的 `.keyboard{height:132}` 改了、JS 判定常量（步长 42）改了，
   **唯独 HML 里 `<image class="keyboard" style="width: {{keyType==3?741:570}}">` 没改**
   （图实际已经缩到 466/592）→ 图被**拉伸 1.22 倍**显示 → **视觉键位与判定完全对不上，按哪儿都错**。
   **改尺寸前必做**：把旧数值**全局搜一遍**，包括
   `grep -rn "旧宽度\|旧高度" **/*.hml **/*.css **/*.js`，
   以及 HML 里 `{{...}}` 表达式内部的常量（`{{keyType==3?592:466}}`、`{{keyPos+(keyType==3?620:494)}}`）。
   > 一句话：**图片 / CSS / HML 内联几何 / JS 判定常量，四处必须同时改。**

**★ 验证手段：扫像素段核对网格（千万别靠肉眼）**
用 Pillow 逐行扫描图片的**非透明像素段**，看首键起点 / 键宽 / 步进 / 行高是否与判定常量一致。
实测（键盘缩到 42px/键后）：row0 首键起于 `x=23`、键宽 40~41、步进 **42**；
row1 起于 **45**、row2 起于 **65**（= 23 + 21×2）；纵向正好 **44px** 一行 —— 与常量完全吻合。
> 反过来也有用：真机若表现为"按到隔壁键 / 半个键"，先查常量是否同步，别急着怀疑引擎。

**图像处理工具**：`C:\Program Files\PyManager\python.exe`（system Python）**自带 Pillow 12.x**，
缩放/滤波/解码任意 PNG 直接用；只有装不上 Pillow 的 managed venv 才需要手写 zlib 解码器。

---

## ★ 用真正的 hvigor 链验证（ace-loader 之外的必做一步）

**ace-loader 是 SDK 自带的老式独立编译器，规则更松。** 已实证：HML 里 `<list-item>` 有 4 个子节点，
ace-loader 编译 `SUCCESS`，DevEco/hvigor 直接 `BUILD FAILED` + `00308018`。
所以**交付前必须用 DevEco 自带的 hvigor CLI 再跑一遍**：

```powershell
# ⚠️ 下面的 DevEco 路径只是「当时那台机器」的样例！每次开工先 ls 一遍确认目录名，
#    DevEco 升版会把整个安装目录换名并删掉旧目录（已实测：6.1.1 → 26.0.0，旧目录消失）。
#    照抄旧路径 = hvigor/ace-loader 直接 not found。
$env:NODE_HOME       = "<node 目录>"
$env:DEVECO_SDK_HOME = "<DevEco 根>\sdk"   # 不设 → 00303217 Invalid value of 'DEVECO_SDK_HOME'
$env:JAVA_HOME       = "<DevEco 根>\jbr"   # 不设 → spawn java ENOENT
$env:NODE_OPTIONS    = ""                  # ★ 必须清空，否则宿主注入的 safe-delete shim 劫持 unlink
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
Set-Location "<工程目录>"     # ← 路径不能含中文，见下
& "<DevEco 根>\tools\hvigor\bin\hvigorw.bat" `
    assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
```

- 成功标志：`> hvigor BUILD SUCCESSFUL in ...`。关键任务链：
  `LegacyBuildJS` → `LegacyCompileLiteJS` → `LegacyGenerateLiteCode` → `LegacyPackageHap`。
- `signingConfigs` 为空时会 `WARN: Will skip sign`，产出 **unsigned** hap —— **正常**（DevEco 里配了签名才会签）。
- 产物路径：`entry/build/default/outputs/default/entry-default-lite-unsigned.hap`（实测约 2.9 MB）。

### 🔴 hvigor **不接受中文工程路径**
报 `00306003 Specification Limit Violation` + `Invalid project path`，提示
「路径只能含字母、数字、`-` `_` `.` 英文括号、空格、`@`」。
⇒ **中文路径（如 `G:\系统文件存放\文档\...`）下 DevEco/hvigor 直接拒绝构建**。
**做法**：源码/文档可以放在中文路径，但**构建前把工程拷到纯 ASCII 路径**（如 `H:\ProjectName\`）。
给用户的交付工程也要在 README 里写明这一条。

### 配套：`tools/precheck.py`（hvigor 专有硬错预检，几秒出结果）
上机前先扫一遍，把 ace-loader 抓不到、hvigor 会阻断的问题提前挑出来：

```bash
python tools/precheck.py <工程目录>
```

检查项：`list-item` 直接子节点 >1、复合类选择器 `.a.b`、选择器里的伪类 / 子选择器 / 兄弟选择器 /
属性选择器、`height|width: auto`、`align-items: baseline`、`transform` 里 translate/rotate 缺单位。

> 教训：**从第三方工程搬 HML 进来时，第一件事就是查每个 `<list-item>` 的直接子节点数**。
> 旧工程能跑不代表新链能过。
