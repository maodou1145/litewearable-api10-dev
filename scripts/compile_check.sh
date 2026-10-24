#!/usr/bin/env bash
# Lite Wearable (API 10) SDK ace-loader 编译验证脚本
# 用法: bash compile_check.sh [js根目录] [页面列表文件]
#   - js根目录默认: <工程>/entry/src/main/js/MainAbility
#   - 页面列表文件: 每行一个页面路径 (pages/xxx/xxx)，默认从 config.json 的 js.pages 提取
# 输出: 编译结果 + 每页产物大小（超 49152B 标红）
set -u

# ---------- 可调参数（按本机环境；留空=自动探测）----------
# 2026-09-12 修正：旧版写死 "D:/DevEco Studio 5.0.4"，该目录已不可用（SDK 失效），
# 导致脚本直接退出。现改为按候选列表自动探测，优先本机在用的 DevEco 6.1.1。
ACE_LOADER="${ACE_LOADER:-}"
DEVECO_NODE="${DEVECO_NODE:-}"
if [ -z "$ACE_LOADER" ]; then
  for br in "D:/Devceo Studio 6.1.1/DevEco Studio" "D:/DevEco Studio 6.1.1/DevEco Studio" \
            "D:/DevEco Studio 5.0.4" "D:/DevEco Studio"; do
    if [ -d "$br/sdk/default/openharmony/js/build-tools/ace-loader" ]; then
      ACE_LOADER="$br/sdk/default/openharmony/js/build-tools/ace-loader"; DEVECO_NODE="$br/tools/node/node.exe"; break
    fi
  done
fi
if [ -z "$ACE_LOADER" ] || [ ! -d "$ACE_LOADER" ]; then
  echo "!! 找不到 ace-loader，请设置环境变量 ACE_LOADER / DEVECO_NODE 后重跑"; exit 1
fi
# DevEco 6.x 的 node 需要 --openssl-legacy-provider 才能跑旧版 webpack
NODE_FLAGS="--openssl-legacy-provider"
DEVICE_TYPE="liteWearable"
LIMIT=49152
# ------------------------------------------

JS_ROOT="${1:-}"
if [ -z "$JS_ROOT" ]; then
  # 默认取当前目录下的工程
  for cand in "H:/emlp_api10/BuckshotRoulette/entry/src/main/js/MainAbility" "entry/src/main/js/MainAbility"; do
    if [ -d "$cand" ]; then JS_ROOT="$cand"; break; fi
  done
fi
if [ -z "$JS_ROOT" ] || [ ! -d "$JS_ROOT" ]; then
  echo "!! 找不到 js 根目录，请传入: bash compile_check.sh <js根目录> [页面列表文件]"; exit 1
fi

# 页面列表
PAGES_FILE="${2:-}"
if [ -z "$PAGES_FILE" ]; then
  CFG="$(dirname "$(dirname "$(dirname "$JS_ROOT")")")/config.json"
  if [ -f "$CFG" ]; then
    # 从 config.json 提取 js.pages（兼容缩进/引号）
    PAGES_FILE="$(mktemp)"
    grep -A200 '"pages"' "$CFG" | grep -oE '"pages/[a-z_]+/[a-z_]+"' | tr -d '"' > "$PAGES_FILE"
  fi
fi
if [ -z "$PAGES_FILE" ] || [ ! -s "$PAGES_FILE" ]; then
  echo "!! 页面列表为空，请传入: bash compile_check.sh <js根目录> <页面列表文件>"; exit 1
fi

# 全新临时目录（rm -rf 会被 safe-delete 拦截，用序号递增）
TS=$(date +%s)
TMP_BR="C:/Users/小聋虾/AppData/Local/Temp/br_lite_build_${TS}"
mkdir -p "$TMP_BR/MainAbility"
cp -r "$JS_ROOT/." "$TMP_BR/MainAbility/"

# 生成 manifest.json
{
  echo '{'
  echo '  "appID": "com.example.litecheck",'
  echo '  "appName": "LiteCheck",'
  echo '  "versionName": "1.0.0",'
  echo '  "versionCode": 1,'
  echo '  "minPlatformVersion": "zsdk 1.0.0",'
  echo '  "pages": ['
  FIRST=1
  while IFS= read -r p; do
    [ -z "$p" ] && continue
    if [ "$FIRST" -eq 1 ]; then FIRST=0; else echo '    ,'; fi
    printf '    "%s"' "$p"
  done < "$PAGES_FILE"
  echo ''
  echo '  ]'
  echo '}'
} > "$TMP_BR/MainAbility/manifest.json"

echo "=== 编译: $TMP_BR/MainAbility ==="
cd "$ACE_LOADER" || { echo "!! ace-loader 路径不存在"; exit 1; }
unset NODE_OPTIONS
aceManifestPath="$TMP_BR/MainAbility/manifest.json" "$DEVECO_NODE" $NODE_FLAGS \
  node_modules/webpack/bin/webpack.js --config webpack.lite.config.js \
  --env aceModuleRoot="$TMP_BR/MainAbility" --env aceModuleBuild="$TMP_BR/out" \
  --env cachePath="$TMP_BR/cache" --env deviceType="$DEVICE_TYPE" --env buildMode=debug 2>&1 \
  | grep -E "COMPILE RESULT|ERROR|bigger" | tail -3

echo ""
echo "=== 产物大小（限制 ${LIMIT}B）==="
OVER=0
while IFS= read -r p; do
  [ -z "$p" ] && continue
  F="$TMP_BR/out/$p.js"
  if [ -f "$F" ]; then
    SZ=$(stat -c %s "$F")
    FLAG=""
    if [ "$SZ" -gt "$LIMIT" ]; then FLAG="  <-- 超限!"; OVER=1; fi
    printf "%-40s %6d  %s\n" "$p" "$SZ" "$FLAG"
  else
    printf "%-40s  MISSING\n" "$p"
  fi
done < "$PAGES_FILE"

if [ "$OVER" -eq 1 ]; then
  echo "!!! 存在超限页面（会真机黑屏），需压缩后再构建"
  exit 2
fi
echo "OK：全部页面产物 ≤${LIMIT}B"
