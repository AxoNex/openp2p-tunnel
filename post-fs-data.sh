#!/system/bin/sh
# openp2p-tunnel post-fs-data
# 模块挂载后立即执行: 修复可执行权限 + 提前创建系统级 TUN 设备节点
# 需求 #2: root 直连 TUN (非 VPN service), 与 ebpf/tproxy/tun2socks 兼容

MODDIR=${0%/*}

# 修复 unzip 解压后丢失的执行权限
chmod 755 "${MODDIR}"/*.sh "${MODDIR}"/openp2pctl "${MODDIR}"/openp2p 2>/dev/null

# 系统级虚拟网卡: 确保 /dev/net/tun 存在
# wireguard-go 的 tun.CreateTUN 会打开 /dev/net/tun 并做 TUNSETIFF
mkdir -p /dev/net 2>/dev/null
if [ ! -e /dev/net/tun ]; then
    if [ -e /dev/tun ]; then
        ln -sf /dev/tun /dev/net/tun 2>/dev/null
    else
        # tun 设备主次号: major 10, minor 200
        mknod /dev/net/tun c 10 200 2>/dev/null
    fi
fi
chmod 666 /dev/net/tun 2>/dev/null
chmod 666 /dev/tun 2>/dev/null

# 打开 IPv4 转发 (openp2p 二进制 optun.Start 也会写 /proc/sys/net/ipv4/ip_forward=1, 这里兜底)
echo 1 > /proc/sys/net/ipv4/ip_forward 2>/dev/null
