#!/system/bin/sh
# openp2p-tunnel 服务启动脚本 (KernelSU)
# 等待系统启动完成 → 准备系统级虚拟网卡 → 启动核心守护循环

MODDIR=${0%/*}
MODID=$(basename "$MODDIR")
DATA_DIR="/sdcard/Documents/${MODID}"
LOG_DIR="${DATA_DIR}/log"
LOG_FILE="${LOG_DIR}/service.log"

mkdir -p "${LOG_DIR}" 2>/dev/null
touch "${LOG_FILE}" 2>/dev/null
chmod 755 "${MODDIR}"/* 2>/dev/null

log() {
    local msg="$(date "+%Y-%m-%d %H:%M:%S") $1"
    echo "$msg"
    echo "$msg" >> "${LOG_FILE}" 2>/dev/null
}

# 等待系统启动完成
log "等待系统启动完成..."
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 5
done
log "系统启动完成"

# 需求 #2: 系统级虚拟网卡 (root 直连 TUN, 非 VPN service)
mkdir -p /dev/net 2>/dev/null
if [ ! -e /dev/net/tun ]; then
    if [ -e /dev/tun ]; then
        ln -sf /dev/tun /dev/net/tun 2>/dev/null
    else
        mknod /dev/net/tun c 10 200 2>/dev/null
    fi
fi
chmod 666 /dev/net/tun 2>/dev/null
chmod 666 /dev/tun 2>/dev/null

# 打开 IPv4 转发
echo 1 > /proc/sys/net/ipv4/ip_forward 2>/dev/null

# 防止系统挂起
echo "PowerManagerService.noSuspend" > /sys/power/wake_lock 2>/dev/null

# 修改模块描述
sed -i 's/^description=.*/description=[状态]启动中.../' "${MODDIR}/module.prop" 2>/dev/null

# 等待网络就绪
sleep 10

# 启动核心守护循环(后台)
"${MODDIR}/openp2p_core.sh" &

# 释放唤醒锁
sleep 2
echo "PowerManagerService.noSuspend" > /sys/power/wake_unlock 2>/dev/null
log "服务启动完成"
