#!/system/bin/sh
# openp2p-tunnel action 脚本
# KernelSU 管理器 "动作" 按钮触发 (无参数): 切换 启动/停止
# 显式参数: start / stop / restart / status / log / tun

MODDIR="$(cd "$(dirname "$0")" && pwd)"
CTL="${MODDIR}/openp2pctl"

sub="${1:-toggle}"

echo "== OpenP2P Tunnel =="
"${CTL}" "$sub" --human
