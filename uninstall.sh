#!/system/bin/sh
# openp2p-tunnel 卸载脚本

# 停止所有 openp2p 进程
pkill -9 -x openp2p 2>/dev/null

echo "OpenP2P Tunnel 已卸载 (配置与日志随模块一并删除)"
