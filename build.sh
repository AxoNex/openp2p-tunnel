#!/bin/sh
# openp2p-tunnel 构建脚本
# 在联网的机器上执行:
#   1. (可选) 下载 openp2p 二进制
#   2. 构建 WebUI (pnpm install + pnpm build) → webroot/
#   3. 打包模块为 zip
#
# 用法:
#   sh build.sh                  # 本地构建 (openp2p 二进制需已存在)
#   sh build.sh --fetch-binary   # 自动下载 openp2p 二进制 (CI)
#   sh build.sh --canary         # 输出名用固定 openp2p-tunnel-canary.zip (CI canary)
set -e

MODULE_DIR="$(cd "$(dirname "$0")" && pwd)"
MODULE_ID="openp2p-tunnel"

FETCH_BINARY=0
CANARY=0
while [ $# -gt 0 ]; do
    case "$1" in
        --fetch-binary) FETCH_BINARY=1 ;;
        --canary) CANARY=1 ;;
        --help) echo "用法: sh build.sh [--fetch-binary] [--canary]"; exit 0 ;;
        *) echo "未知参数: $1"; exit 1 ;;
    esac
    shift
done

# 版本: 从 module.prop 读取 (单一事实源)
VERSION=$(grep '^version=' "${MODULE_DIR}/module.prop" | cut -d= -f2)
[ -n "$VERSION" ] || { echo "!! 无法从 module.prop 读取 version"; exit 1; }

# openp2p 核心二进制不纳入版本库, 需先获取
if [ "$FETCH_BINARY" = 1 ] && [ ! -f "${MODULE_DIR}/openp2p" ]; then
    echo "==> 下载 openp2p 核心二进制"
    sh "${MODULE_DIR}/scripts/fetch-binary.sh"
fi
if [ ! -f "${MODULE_DIR}/openp2p" ]; then
    echo "!! 缺少 openp2p 核心二进制, 请先运行: sh fetch-openp2p.sh"
    echo "   或加 --fetch-binary 自动下载 (CI)"
    exit 1
fi

echo "==> 构建 WebUI (版本 ${VERSION})"
cd "${MODULE_DIR}/webui"
# 用 --no-frozen-lockfile: 允许依赖新增/升级时自动更新 lockfile。
# (CI 环境默认 --frozen-lockfile 会在 lockfile 落后 package.json 时直接报错)
pnpm install --no-frozen-lockfile
MODULE_ID="${MODULE_ID}" pnpm build
cd "${MODULE_DIR}"

echo "==> 打包模块"
if [ "$CANARY" = 1 ]; then
    OUT="${MODULE_ID}-canary.zip"
else
    OUT="${MODULE_ID}-${VERSION}.zip"
fi
rm -f "${OUT}"

# 仅打包运行时需要的文件, 排除源码与构建脚本
zip -r "${OUT}" \
  module.prop \
  service.sh \
  post-fs-data.sh \
  action.sh \
  openp2p_core.sh \
  uninstall.sh \
  openp2pctl \
  fetch-openp2p.sh \
  openp2p \
  config \
  webroot

echo "==> 完成: ${MODULE_DIR}/${OUT}"
