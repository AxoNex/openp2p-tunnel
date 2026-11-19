#!/system/bin/sh
# openp2p-tunnel: 下载并替换最新 openp2p 核心 (linux-arm64, 真 TUN 路径)
# 用法: fetch-openp2p.sh [--ver <版本>] [--no-restart]
#   默认下载 latest (当前控制台最新 3.25.14), 需要 root + 网络
# 参考官方 Linux 安装脚本: https://openp2p.cn 控制台下载的 install.sh

ver="latest"
domain="openp2p.cn"
restart=1
check=0
while [ $# -gt 0 ]; do
    case "$1" in
        --ver)       shift; ver="$1"; shift ;;
        --domain)    shift; domain="$1"; shift ;;
        --no-restart) restart=0; shift ;;
        --check)     check=1; shift ;;
        --help)      echo "用法: $0 [--ver <版本>] [--no-restart] [--check]"; exit 0 ;;
        *)           shift ;;
    esac
done

# 兼容相对路径调用 (sh fetch-openp2p.sh): 用 dirname 解析脚本所在目录
MODDIR="$(cd "$(dirname "$0")" && pwd)"
OPENP2P="${MODDIR}/openp2p"

# 回退: 若从非模块目录相对调用, 改用标准模块安装路径
if [ ! -x "$OPENP2P" ]; then
    MODDIR="/data/adb/modules/openp2p-tunnel"
    OPENP2P="${MODDIR}/openp2p"
fi

if [ ! -x "$OPENP2P" ]; then
    echo "未找到 openp2p 二进制: $OPENP2P" >&2
    echo "请在模块目录内运行, 或用绝对路径: sh /data/adb/modules/openp2p-tunnel/fetch-openp2p.sh" >&2
    exit 1
fi

# 确定架构
arch=$(uname -m)
case "$arch" in
    aarch64|arm64) sysType="linux-arm64" ;;
    arm*)          sysType="linux-arm" ;;
    x86_64|amd64)  sysType="linux-amd64" ;;
    i*86)          sysType="linux-386" ;;
    *) echo "不支持的架构: $arch" >&2; exit 1 ;;
esac

TMPDIR="${TMPDIR:-/data/local/tmp}"
WORKDIR="${TMPDIR}/openp2p-dl"
mkdir -p "$WORKDIR" 2>/dev/null
cd "$WORKDIR" || exit 1
rm -f openp2p.tar.gz openp2p

url="https://${domain}/download/v1/${ver}/openp2p-${ver}.${sysType}.tar.gz"
echo "下载: $url" >&2

dl() {
    if command -v curl >/dev/null 2>&1; then
        curl -kL --max-time 60 -o openp2p.tar.gz "$1"
    else
        wget --timeout=60 --no-check-certificate -O openp2p.tar.gz "$1"
    fi
}

dl "$url"
if [ ! -s openp2p.tar.gz ]; then
    echo "下载失败, 重试备用域名..." >&2
    url="https://console.openpxp.com/download/v1/${ver}/openp2p-${ver}.${sysType}.tar.gz"
    rm -f openp2p.tar.gz
    dl "$url"
fi
[ -s openp2p.tar.gz ] || { echo "下载失败" >&2; exit 9; }

tar -xzf openp2p.tar.gz 2>/dev/null || { echo "解压失败" >&2; exit 9; }
[ -f openp2p ] || { echo "压缩包内未找到 openp2p 二进制" >&2; exit 9; }
chmod 755 openp2p

# 读取新版本号 (在可写的临时目录执行 -v, 避免日志写权限问题)
newver=$(./openp2p -v 2>/dev/null | head -1)
oldver=$("$OPENP2P" -v 2>/dev/null | head -1)
echo "当前版本: ${oldver:-未知} → 新版本: ${newver:-未知}" >&2

# --check: 仅下载并返回最新版本号 (不替换/不重启, 供 webui 检查更新)
if [ "$check" = 1 ]; then
    echo "latest=${newver}"
    rm -f openp2p.tar.gz openp2p
    exit 0
fi

# 停服务: 先杀守护循环再杀 openp2p。
# 否则替换正在运行的二进制会报 "Text file busy" (ETXTBSY)
pkill -9 -f "openp2p_core\.sh" 2>/dev/null
pkill -9 -x openp2p 2>/dev/null
sleep 1

# 备份并替换
cp "$OPENP2P" "${OPENP2P}.bak" 2>/dev/null
cp openp2p "$OPENP2P" || { echo "替换失败" >&2; exit 9; }
chmod 755 "$OPENP2P"
rm -f openp2p.tar.gz openp2p

echo "已更新: $OPENP2P → ${newver:-unknown}" >&2

if [ "$restart" = 1 ]; then
    "${MODDIR}/openp2p_core.sh" >/dev/null 2>&1 &
    echo "已重启服务" >&2
fi
exit 0
