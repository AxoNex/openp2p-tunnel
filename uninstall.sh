#!/system/bin/sh
# openp2p-tunnel 卸载脚本

MODDIR=${0%/*}
DATA_DIR="/sdcard/Documents/openp2p-tunnel"

# 停止所有 openp2p 进程
pkill -9 -x openp2p 2>/dev/null

# 清理模块数据目录(不含用户配置, 保留 /sdcard 下的 config.json 供重装复用)
rm -rf /data/adb/openp2p-tunnel 2>/dev/null
rm -f /data/adb/modules/openp2p-tunnel/openp2p.pid 2>/dev/null

echo "OpenP2P Tunnel 已卸载 (用户配置保留在 ${DATA_DIR})"
