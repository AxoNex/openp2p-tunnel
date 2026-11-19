#!/system/bin/sh
# openp2p-tunnel 卸载脚本

# 停止所有 openp2p 进程
pkill -9 -x openp2p 2>/dev/null

# 清理旧版本遗留的数据目录 (新版本配置/日志已随模块目录一并删除)
rm -rf /data/adb/openp2p-tunnel 2>/dev/null
rm -rf /sdcard/Documents/openp2p-tunnel 2>/dev/null

echo "OpenP2P Tunnel 已卸载 (配置与日志随模块一并删除)"
