#!/system/bin/sh
# openp2p-tunnel 守护脚本 - 启动并守护 openp2p 进程
# 全部参数从 config.json 读取
# 兼容 busybox ash / toybox sh / POSIX sh

MODDIR=${0%/*}
MODID=$(basename "$MODDIR")
# 配置独立存放, 模块更新/重刷不会重置 (卸载时由 uninstall.sh 一并清理)
CONFIG_DIR="/data/adb/openp2p-tunnel"
CONFIG_FILE="${CONFIG_DIR}/config.json"
LOG_DIR="${MODDIR}/log"
LOG_FILE="${LOG_DIR}/openp2p_core.log"
MODULE_PROP="${MODDIR}/module.prop"
OPENP2P="${MODDIR}/openp2p"

# 兜底默认值(配置缺失时使用)
DEFAULT_MONITOR_INTERVAL="10s"
DEFAULT_LOG_LEVEL=1
DEFAULT_SHARE_BANDWIDTH=3
DEFAULT_SERVER_HOST="api.openp2p.cn"
DEFAULT_INSECURE=false
DEFAULT_TZ="Asia/Shanghai"

mkdir -p "${LOG_DIR}" 2>/dev/null
mkdir -p "${CONFIG_DIR}" 2>/dev/null
touch "${LOG_FILE}" 2>/dev/null

log() {
    local message="$(date "+%Y-%m-%d %H:%M:%S") $1"
    echo "$message"
    echo "$message" >> "${LOG_FILE}" 2>/dev/null
}

# 通用 JSON 字段读取 - 接受字符串/数字/布尔
# 用法: json_get "字段名" "默认值" [type:str|num|bool]
# 优先匹配 "字段": "值", 其次 "字段": 值
json_get() {
    local key="$1"
    local default="$2"
    local type="${3:-str}"
    [ ! -f "$CONFIG_FILE" ] && { echo "$default"; return; }
    local val
    case "$type" in
        str)
            val=$(grep -m1 -oE "\"${key}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$CONFIG_FILE" \
                | sed -E "s/\"${key}\"[[:space:]]*:[[:space:]]*\"([^\"]*)\"/\1/")
            ;;
        num)
            val=$(grep -m1 -oE "\"${key}\"[[:space:]]*:[[:space:]]*-?[0-9]+(\\.[0-9]+)?" "$CONFIG_FILE" \
                | grep -oE -- "-?[0-9]+(\.[0-9]+)?$")
            ;;
        bool)
            val=$(grep -m1 -oE "\"${key}\"[[:space:]]*:[[:space:]]*(true|false)" "$CONFIG_FILE" \
                | grep -oE "(true|false)$")
            ;;
    esac
    if [ -z "$val" ]; then
        echo "$default"
    else
        echo "$val"
    fi
}

get_token() {
    if [ -f "$CONFIG_FILE" ]; then
        # 优先字符串格式
        local t=$(grep -m1 -oE '"Token"[[:space:]]*:[[:space:]]*"[^"]+"' "$CONFIG_FILE" \
            | sed -E 's/.*"Token"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')
        if [ -z "$t" ] || [ "$t" = "YOUR_TOKEN_HERE" ]; then
            t=$(grep -m1 -oE '"Token"[[:space:]]*:[[:space:]]*[0-9]+' "$CONFIG_FILE" \
                | grep -oE '[0-9]+$')
        fi
        echo "$t"
    fi
}

get_monitor_interval() {
    json_get "MonitorInterval" "$DEFAULT_MONITOR_INTERVAL" "str"
}

parse_interval() {
    # 支持 10s / 5m / 1h / 纯数字(秒)
    local interval="$1"
    case "$interval" in
        *s) echo "${interval%s}" ;;
        *m) local n="${interval%m}"; echo $((n * 60)) ;;
        *h) local n="${interval%h}"; echo $((n * 3600)) ;;
        *)  echo "${interval:-10}" ;;
    esac
}

update_module_description() {
    sed -i "/^description=/c\description=[状态]${1}" "${MODULE_PROP}" 2>/dev/null
}

# 需求 #2: 系统级虚拟网卡 - 检查并创建 TUN 设备节点 (root 直连, 非 VPN service)
ensure_tun() {
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
}

# 清理已存在的 openp2p 进程
kill_openp2p() {
    if pgrep -x openp2p >/dev/null 2>&1; then
        log "Stopping existing openp2p processes..."
        pkill -9 -x openp2p 2>/dev/null
        sleep 1
    fi
}

# ===== P0: 网络切换主动检测 (netwatch) =====
# 返回默认路由指纹 "接口|网关hex"。/proc/net/route 里 Destination=00000000 即默认路由;
# 只依赖 procfs, 不依赖 toybox 版 ip, 兼容所有 Android 内核。WiFi↔蜂窝/换 AP/VPN 开关
# 都会改变默认路由(接口或网关), 据此判断物理网络是否切换。
get_net_fingerprint() {
    awk '$2=="00000000" && $1!="*" { print $1 "|" $3; exit }' /proc/net/route 2>/dev/null
}

# ===== 自动补全 ServerIP =====
# openp2p 没有 -serverip 命令行参数, 且运行时会在 init() 里用 resolveServerIP(ServerHost)
# 重新解析域名并覆盖 config.json 的 ServerIP 字段。因此 ServerHost 一律以 WebUI 配置为准
# (不自动改写、不传 IP), 这里只做一件事: 用系统 DNS 把 ServerHost 解析成公网 IP, 补全写入
# config.json 的 network.ServerIP 字段, 供 WebUI 展示与手动诊断参考。

# 用系统 DNS 解析域名 (多工具回退: getent -> nslookup -> ping)
dns_lookup() {
    local host="$1" ip=""
    ip=$(getent hosts "$host" 2>/dev/null | awk 'NR==1 { print $1 }')
    [ -z "$ip" ] && ip=$(nslookup "$host" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | tail -1)
    [ -z "$ip" ] && ip=$(ping -c1 -W2 "$host" 2>/dev/null | grep -oE '\([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\)' | head -1 | tr -d '()')
    echo "$ip"
}

# 自动补全 ServerIP: 解析域名 -> 写入 config.json 的 network.ServerIP (幂等, 仅在有变化时写)
auto_fill_serverip() {
    local host="$1" ip="" cur=""
    [ -z "$host" ] && return 0
    echo "$host" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' && return 0
    ip=$(dns_lookup "$host")
    [ -z "$ip" ] && return 0
    cur=$(json_get "ServerIP" "" "str")
    [ "$cur" = "$ip" ] && return 0
    if grep -q '"ServerIP"' "$CONFIG_FILE" 2>/dev/null; then
        sed -i 's/"ServerIP"[[:space:]]*:[[:space:]]*"[^"]*"/"ServerIP": "'"$ip"'"/' "$CONFIG_FILE" 2>/dev/null
    else
        sed -i 's/\("ServerHost"[[:space:]]*:[[:space:]]*"[^"]*"\)/\1,"ServerIP": "'"$ip"'"/' "$CONFIG_FILE" 2>/dev/null
    fi
    log "已自动补全 ServerIP: ${ip}"
}

ensure_tun
kill_openp2p

# P0 netwatch 状态 (跨监控周期持久于本进程; 脚本重启后重新建立基线, 不触发误重启)
NET_FP=""            # 最近一次稳定采用的默认路由指纹 "接口|网关hex"
NET_PENDING_FP=""    # 去抖中待确认的新指纹
NET_PENDING_SINCE="" # 待确认新指纹首次出现的时间戳(epoch 秒)

while true; do
    MONITOR_INTERVAL=$(get_monitor_interval)
    SLEEP_SECONDS=$(parse_interval "$MONITOR_INTERVAL")

    # 兼容 set -u
    [ -z "$SLEEP_SECONDS" ] && SLEEP_SECONDS=10

    if ls "${MODDIR}" 2>/dev/null | grep -q "^disable$"; then
        update_module_description "已禁用"
        kill_openp2p
    else
        if [ ! -f "$CONFIG_FILE" ]; then
            if [ -f "${MODDIR}/config/config.json" ]; then
                cp "${MODDIR}/config/config.json" "${CONFIG_FILE}" 2>/dev/null
                log "默认配置已复制到 ${CONFIG_FILE}"
            fi
        fi

        TOKEN=$(get_token)
        if [ -z "$TOKEN" ] || [ "$TOKEN" = "YOUR_TOKEN_HERE" ]; then
            update_module_description "请配置 Token"
        else
            DEVICE_NAME="$(getprop ro.product.brand)-$(getprop ro.product.model)"
            [ "$DEVICE_NAME" = "-" ] && DEVICE_NAME="$(getprop ro.product.manufacturer)-$(getprop ro.product.marketname)"
            [ -z "$DEVICE_NAME" ] || [ "$DEVICE_NAME" = "-" ] && DEVICE_NAME="$(getprop ro.product.device)"

            # 全部参数从 config.json 读取
            LOG_LEVEL=$(json_get "LogLevel" "$DEFAULT_LOG_LEVEL" "num")
            SHARE_BANDWIDTH=$(json_get "ShareBandwidth" "$DEFAULT_SHARE_BANDWIDTH" "num")
            SERVER_HOST=$(json_get "ServerHost" "$DEFAULT_SERVER_HOST" "str")
            INSECURE_VAL=$(json_get "TLSInsecureSkipVerify" "$DEFAULT_INSECURE" "bool")
            TZ_VAL=$(json_get "Timezone" "$DEFAULT_TZ" "str")
            NODE_NAME=$(json_get "Node" "" "str")
            AUTO_CLEAR_LOG=$(json_get "AutoClearLog" "false" "bool")
            [ -n "$NODE_NAME" ] && DEVICE_NAME="$NODE_NAME"

            if ! pgrep -x openp2p >/dev/null 2>&1; then
                # 自动补全 ServerIP (解析 ServerHost, 写入 config.json 的 network.ServerIP)
                auto_fill_serverip "$SERVER_HOST"

                # 安全兜底: 绝不能让 -serverhost 传空
                [ -z "$SERVER_HOST" ] && SERVER_HOST="$DEFAULT_SERVER_HOST"

                # 构造额外参数 (TLS 跳过校验仅按用户配置, 不再自动附加)
                EXTRA_ARGS=""
                [ "$INSECURE_VAL" = "true" ] && EXTRA_ARGS="$EXTRA_ARGS -insecure"

                # 启动时自动清除一次日志 (用户可选, 存于 config.AutoClearLog)
                if [ "$AUTO_CLEAR_LOG" = "true" ]; then
                    : > "${MODDIR}/log/openp2p.log" 2>/dev/null
                    : > "${LOG_DIR}/openp2p_console.log" 2>/dev/null
                    log "启动时自动清除日志"
                fi

                log "Starting OpenP2P with token: ${TOKEN:0:8}..."
                log "  server=${SERVER_HOST} loglevel=${LOG_LEVEL} sharebandwidth=${SHARE_BANDWIDTH} tz=${TZ_VAL}"

                cd "${MODDIR}" || cd /
                TZ="${TZ_VAL}" nohup "${OPENP2P}" -d \
                    -token "${TOKEN}" \
                    -node "${DEVICE_NAME}" \
                    -serverhost "${SERVER_HOST}" \
                    -loglevel "${LOG_LEVEL}" \
                    -sharebandwidth "${SHARE_BANDWIDTH}" \
                    ${EXTRA_ARGS} > "${LOG_DIR}/openp2p_console.log" 2>&1 &

                sleep 3

                if pgrep -x openp2p >/dev/null 2>&1; then
                    log "OpenP2P started successfully"
                    update_module_description "运行中 | ${DEVICE_NAME}"
                else
                    log "OpenP2P failed to start"
                    update_module_description "启动失败"
                fi
            fi

            # 进程保活 (参考 NetProxy ensureSingBoxRootCgroup / cgroup.go):
            # 1) renice 提优先级, 降低 OOM / 后台 cgroup 节流被杀概率;
            # 2) 把 openp2p (daemon+worker) 与自身迁出可能被冻结的应用 cgroup ——
            #    root 进程经 KernelSU / ksu.exec 启动时会继承启动它的 App 的 cgroup,
            #    该 App 退后台后 cgroup 被 freezer 冻结, openp2p 随之挂起(切后台就断网)。
            #    把 PID 写入 /sys/fs/cgroup/cgroup.procs (cgroup v2 根组) 可脱离冻结。
            # 幂等, 每监控周期都做一次以覆盖 worker 重启后的新 PID。
            if [ -w /sys/fs/cgroup/cgroup.procs ]; then
                echo "$$" > /sys/fs/cgroup/cgroup.procs 2>/dev/null
            fi
            if pgrep -x openp2p >/dev/null 2>&1; then
                for _p in $(pgrep -x openp2p); do
                    renice -20 "$_p" 2>/dev/null
                    [ -w /sys/fs/cgroup/cgroup.procs ] && echo "$_p" > /sys/fs/cgroup/cgroup.procs 2>/dev/null
                done
            fi

            # 连接健康看门狗: Android 版(linux 构建)的 openp2p keepAlive 因 isAndroid()==true
            # 不会 os.Exit(9) 退出进程, 连接卡死时只能靠 readLoop 40s 超时自愈; 若自愈也失败
            # (进程在但连接已死且一直连不上), 这里按日志判断"错误晚于最近登录成功"即视为离线,
            # 持续离线超过阈值则强制重启 openp2p (pkill 后由本循环下一轮自动拉起)。
            if pgrep -x openp2p >/dev/null 2>&1; then
                _login_n=$(grep -n "login ok" "${MODDIR}/log/openp2p.log" 2>/dev/null | tail -1 | cut -d: -f1)
                _err_n=$(grep -nE "ReadMessage error|keepAlive error" "${MODDIR}/log/openp2p.log" 2>/dev/null | tail -1 | cut -d: -f1)
                _down_file="${MODDIR}/.conn_down"
                if [ -n "$_err_n" ] && { [ -z "$_login_n" ] || [ "$_err_n" -gt "$_login_n" ]; }; then
                    if [ ! -f "$_down_file" ]; then
                        date +%s > "$_down_file" 2>/dev/null
                    else
                        _ds=$(cat "$_down_file" 2>/dev/null)
                        _now=$(date +%s 2>/dev/null)
                        if [ -n "$_ds" ] && [ -n "$_now" ] && [ $((_now - _ds)) -ge 60 ]; then
                            log "看门狗: 连接持续离线超过 60s, 强制重启 openp2p"
                            kill_openp2p
                            rm -f "$_down_file" 2>/dev/null
                        fi
                    fi
                else
                    rm -f "$_down_file" 2>/dev/null
                fi
            fi

            # ===== P0: 网络切换主动检测 (netwatch) =====
            # Android 上 openp2p 死连检测慢(readLoop 40s / readTimeout 60s, keepAlive 因
            # isAndroid() 不退出), 网络切换后要等 40~60s 才自愈。这里嗅探默认路由指纹,
            # 变化稳定(去抖一个监控周期)后立即 netunpin + 强制重启 openp2p, 把检测从
            # 40~60s 压到 ~一个监控周期。去抖避免 DHCP 续租/VPN 短暂抖动误杀。
            if pgrep -x openp2p >/dev/null 2>&1; then
                _net_fp=$(get_net_fingerprint)
                if [ -n "$_net_fp" ]; then
                    if [ -z "$NET_FP" ]; then
                        # 首次采样(或脚本重启), 仅建立基线, 不触发重启
                        NET_FP="$_net_fp"
                        NET_PENDING_FP=""; NET_PENDING_SINCE=""
                    elif [ "$_net_fp" != "$NET_FP" ]; then
                        _net_now=$(date +%s 2>/dev/null)
                        if [ -z "$NET_PENDING_FP" ] || [ "$NET_PENDING_FP" != "$_net_fp" ]; then
                            # 检测到切换(或仍在抖动), 记录新指纹并(重新)计时
                            NET_PENDING_FP="$_net_fp"
                            NET_PENDING_SINCE="$_net_now"
                            log "netwatch: 检测到网络切换 ${NET_FP} -> ${_net_fp}, 去抖中..."
                        elif [ -n "$NET_PENDING_SINCE" ] && [ -n "$_net_now" ] \
                            && [ $((_net_now - NET_PENDING_SINCE)) -ge "$SLEEP_SECONDS" ]; then
                            # 新指纹稳定一个监控周期, 立即重启以快速重连
                            log "netwatch: 网络已切换(${NET_FP} -> ${_net_fp}), 撤销 netpin 并重启 openp2p"
                            "${MODDIR}/openp2pctl" netunpin 2>/dev/null
                            kill_openp2p
                            rm -f "${MODDIR}/.conn_down" 2>/dev/null
                            NET_FP="$_net_fp"
                            NET_PENDING_FP=""; NET_PENDING_SINCE=""
                        fi
                    else
                        # 指纹回到基线(切换未实际发生/已恢复), 清空待定
                        NET_PENDING_FP=""; NET_PENDING_SINCE=""
                    fi
                fi
            fi

            # 需求 #2: 确保 SDWAN 子网路由 (Android 策略路由查 local_network 表而非 main,
            # 见 openp2pctl netfix)。optun 上线后自动补齐, 幂等, 重启后自动恢复。
            if [ -d /sys/class/net/optun ]; then
                "${MODDIR}/openp2pctl" netfix 2>/dev/null
            fi
        fi
    fi

    # 用 for 循环 sleep, 避免 sleep 被信号打断后等待时间不足
    i=0
    while [ $i -lt "$SLEEP_SECONDS" ]; do
        sleep 1
        i=$((i + 1))
    done
done
