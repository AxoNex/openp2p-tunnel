#!/bin/sh
# CI/构建: 下载 openp2p 核心二进制 (linux-arm64, 真 TUN 路径) 到仓库根目录
# 供 build.sh --fetch-binary 在无二进制时调用 (GitHub Actions 等联网环境)
# 用法: sh scripts/fetch-binary.sh [版本] [架构]
set -e

cd "$(dirname "$0")/.." || exit 1
ver="${1:-latest}"
arch="${2:-linux-arm64}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

ok=0
for domain in openp2p.cn console.openpxp.com; do
    url="https://${domain}/download/v1/${ver}/openp2p-${ver}.${arch}.tar.gz"
    echo "下载: $url"
    curl -kL --max-time 120 -o "${tmp}/openp2p.tar.gz" "$url" || true
    if [ -s "${tmp}/openp2p.tar.gz" ]; then
        ok=1
        break
    fi
done

[ "$ok" = 1 ] || { echo "下载失败 (${ver}/${arch})" >&2; exit 1; }

tar -xzf "${tmp}/openp2p.tar.gz" -C "${tmp}" openp2p
[ -f "${tmp}/openp2p" ] || { echo "压缩包内未找到 openp2p 二进制" >&2; exit 1; }
chmod 755 "${tmp}/openp2p"
mv -f "${tmp}/openp2p" ./openp2p
echo "完成: openp2p 已下载 (${ver}/${arch})"
