# OpenP2P Tunnel

基于 [OpenP2P](https://github.com/OpenP2P-cn/openp2p) 的 KernelSU 模块，在原有内网穿透能力之上新增**系统级虚拟网卡（SDWAN 组网）**与**基于 Miuix 的图形化 WebUI**。

## 功能

1. **OpenP2P 内网穿透** — 与上游 `openp2p-magisk` 一致：启动 `openp2p` 守护进程，将设备接入 OpenP2P 网络。
2. **系统级虚拟网卡（optun）** — 使用 root 直连 TUN 设备（`/dev/net/tun`），**不依赖 Android VPN Service**。设备加入 OpenP2P 控制台的虚拟网络后，`openp2p` 会自动创建 `optun` 网卡、写入路由与 NAT 规则，实现点到点的 SDWAN 组网。
3. **Miuix 图形化 WebUI** — 参考 KernelSU 生态的 `miuix-vue` 组件库实现，提供状态 / 配置 / 日志 / 关于四个页面。

## 兼容性

- **root 直连 TUN**：本模块打包的是 `linux-arm64` 构建（`GOOS=linux`），走 `optun` 的 `wireguard-go` TUN 路径，而非 `android` 构建的 VPN-Service 桩。
- **与其他透明代理共存**：`openp2p` 仅写入 `filter/FORWARD`（`optun` ACCEPT）与 `nat/POSTROUTING`（独立的 `OPSDWAN` 链），不触碰 `mangle`、`OUTPUT`、`PREROUTING`，因此与 tproxy / eBPF / tun2socks 等透明代理**天然兼容**。
- **仅支持 arm64**（上游仅提供 arm64 产物）。

## 下载

| 类型 | 说明 | 链接 |
|------|------|------|
| **正式版（Release）** | 稳定版本，打 `v*` tag 时自动构建并发布 | <https://github.com/AxoNex/openp2p-tunnel/releases/latest> |
| **测试版（Canary）** | 每次推送到 `main` 分支自动构建，对应最新开发进度，**不稳定**，仅用于测试 | <https://github.com/AxoNex/openp2p-tunnel/actions> |

> 正式版在 Release 页面下载 `openp2p-tunnel-<版本>.zip`；Canary 不再发布 Release，改为在 GitHub Actions 页面下载构建产物（Artifact）：点开最新一次 run，在页面底部「Artifacts」区下载 `openp2p-tunnel-canary`，解压后得到 `openp2p-tunnel-canary.zip`。

## 安装

1. 用 KernelSU 管理器安装从上方「下载」获取的 zip（正式版或 canary）。
2. 获取 OpenP2P 控制台的 Token，填入配置（三种方式任选其一）：
   - **WebUI**：打开模块的「配置」页填写 Token，保存后重启服务。
   - **配置文件**：编辑 `/data/adb/openp2p-tunnel/config.json` 的 `network.Token`。
   - **命令行**：`su -c "/data/adb/modules/openp2p-tunnel/openp2pctl config import <base64>"`。
3. 回到「状态」页点击「启动」。

配置独立存储于 `/data/adb/openp2p-tunnel/config.json`（模块更新不会清除；卸载时由 `uninstall.sh` 一并清理）。

## 虚拟网络（SDWAN）接入

在 OpenP2P 控制台将本设备（节点名默认为「品牌-型号」，可用 `network.Node` 自定义）加入虚拟网络，并配置好 `Gateway`（如 `10.9.0.0/24`）。`openp2p` 收到 SDWAN 配置后会自动：

1. 创建 `optun` TUN 网卡并配置 IP；
2. 开启 IPv4 转发（`/proc/sys/net/ipv4/ip_forward`）；
3. 写入 `filter/FORWARD` 放行规则；
4. 在 `nat` 表建立 `OPSDWAN` 链做 MASQUERADE；
5. 为虚拟网络内每个对端节点的 `Resource` CIDR 写入路由。

> 若内核缺少 TUN 驱动（`/dev/tun` 不存在且 `mknod` 失败），系统级虚拟网卡无法建立，但穿透功能不受影响。

## 构建 WebUI

WebUI 源码位于 `webui/`（Vue 3 + Vite + `miuix-vue`）。需在**联网**机器上构建：

```sh
cd webui
pnpm install        # 首次会更新 pnpm-lock.yaml
pnpm build          # 产物输出到 ../webroot
```

或直接运行根目录 `sh build.sh`（构建 WebUI 并打包 zip）。`build.sh` 会先检查 `openp2p` 核心二进制是否存在，缺失时请先运行 `sh fetch-openp2p.sh` 下载；CI 环境可用 `sh build.sh --fetch-binary` 自动下载，`--canary` 输出固定文件名的 canary 包。

模块的 shell 层（服务 / 配置 / 控制）不依赖 WebUI，未构建时仍可正常使用。

## 控制脚本 openp2pctl

WebUI 通过 KernelSU 的 `ksu.exec` 调用本脚本，输出 JSON 到 stdout：

```text
openp2pctl status                 # 运行状态 JSON
openp2pctl start|stop|restart|toggle
openp2pctl config get             # 输出完整 config.json
openp2pctl config import <b64>    # base64 覆盖 config.json
openp2pctl log [N]                # 日志末尾 N 行
openp2pctl tun                    # optun 网卡状态 JSON
openp2pctl version
openp2pctl diag                   # 完整诊断 (网络/路由/iptables/进程/日志)
openp2pctl netfix                 # 修复跨设备连通性 (子网路由 + FORWARD/SNAT)
openp2pctl netpin                 # 固定服务器连接走物理接口 (诊断 unexpected EOF 断连, 实验性)
openp2pctl netunpin               # 撤销 netpin 钉路由
openp2pctl update [<版本>]         # 更新核心 (异步: 立即返回, 后台执行; 加 --human 则同步)
openp2pctl update-status           # 读取后台更新进度 JSON (WebUI 轮询)
```

加 `--human` 输出人类可读文本（供终端 / `action.sh` 使用）。

### 排查跨设备连通性

如果本机 `optun` 已上线、能 ping 通自己的虚拟 IP，但 ping 不通虚拟网络内其他设备，按顺序执行：

```sh
su
cd /data/adb/modules/openp2p-tunnel

# 1. 先看诊断 (把输出发出来即可定位)
sh openp2pctl diag --human

# 2. 手动补齐子网路由 + FORWARD/SNAT 规则 (运行时生效, 重启自动恢复, 不改系统文件)
sh openp2pctl netfix --human

# 3. 再验证
ping <其他设备的虚拟IP>
```

`netfix` 做的事与 openp2p 内核 (`core/iptables.go` + `core/optun_linux.go`) 一致，只是当内核侧因 Android 环境（SELinux / 路由策略）未生效时手动兜底：`ip_forward=1`、把子网路由 `ip route add <子网> dev optun table 100` 放进 netd 不管理的独立表 100，再加一条高优先级策略路由 `ip rule add to <子网> lookup 100 pref 100`（这是关键 —— Android 策略路由无 `lookup main`，未打标流量实际走 `wlan0`/`rmnet_data*` 等 per-network 表，openp2p 内核只写 `main` 表所以路由从不被命中；`to <子网> lookup 100` 只劫持虚拟子网流量，不影响其它网络）、`iptables -t filter -I FORWARD -i/-o optun -j ACCEPT`、`iptables -t nat` 的 `OPSDWAN` MASQUERADE 链。这些全部是运行时改动（内存态），重启手机即还原，不修改任何系统文件。

守护脚本 `openp2p_core.sh` 会在 `optun` 上线后**自动调用 `netfix`**（幂等，约每 10 秒一次），无需手动执行；手动执行 `openp2pctl netfix --human` 用于即时修复或验证。

### 排查与服务器断连（unexpected EOF）

日志若反复出现 `ReadMessage error: websocket: close 1006 ... unexpected EOF`，说明到 `api.openp2p.cn:27183` 的 WebSocket 长连接被中途掐断。openp2p 建连用的是 `net.Dialer`（只设 `Timeout`，未打 `SO_MARK`、未绑物理接口），socket 归属 Android 的「默认网络」——逻辑网络切换、后台网络节流（doze）时 `netd` 会直接销毁这个 socket。

`diag` 里新增了「到服务器的连接」一段（`ip route get <服务器IP>` 实际选路 + `ss` 里到 `27183` 的 TCP 状态）。手动把这条连接固定到物理接口：

```sh
su
cd /data/adb/modules/openp2p-tunnel
sh openp2pctl netpin --human
```

`netpin` 解析服务器 IP，用独立表 100 + 高优先级规则 `ip rule add to <服务器IP>/32 lookup 100 pref 50` 把到服务器的流量直接钉到**当前**物理接口（`wlan0`/`rmnet_data*`），绕过 per-network 查表。全部运行时改动、重启还原。

> **局限**：`netpin` 是「钉到当前接口」，若之后切换网络（WiFi ↔ 移动网），钉路由会指向已下线的旧接口导致断连，需重跑 `netpin` 或 `netunpin` 撤销。它仅作为判断「是否 Android 网络管理杀 socket」的一次性诊断手段，不建议长期开启——多网络设备建议用 `netunpin` 还原。

若 `netpin` 后断连消失，说明确属 Android 网络管理所致；若依旧断连，则更可能是服务端或运营商 NAT/中间盒所致，可继续用 `diag` 观察断连时 `ss` 的 TCP 状态（`unexpected EOF` 是对端发 FIN 关闭，通常指向服务端/中间盒而非本机 netd）。

### 进程保活（切后台就断连）

症状：设备亮屏 / 前台时一切正常，但一旦切到其它 App（尤其从 KernelSU 管理器切走），openp2p 就“假死”——其它设备 ping 本机超时、控制台显示离线，切回来又恢复。

根因：openp2p 进程是由模块经 `su`（KernelSU 的 `ksu.exec` / `action.sh`）拉起的，会继承**启动它的 App 的 cgroup**。当那个 App（通常是 KernelSU 管理器）退到后台后，Android 的 freezer 会冻结它的 cgroup，导致 openp2p 整个进程被挂起，而不是被杀（所以 `pgrep` 还看得到、`renice` 也没用）。

解法（参考 NetProxy 的 `ensureSingBoxRootCgroup`）：把 openp2p 进程与守护循环迁出应用 cgroup、放进 cgroup v2 根组。`openp2p_core.sh` 已内置该保活逻辑——每个监控周期（约 10s）把自身和 openp2p 的 PID 写入 `/sys/fs/cgroup/cgroup.procs`（根组 procs 文件），并同时 `renice -20` 提优先级；`openp2pctl start` 也会在拉起守护循环的瞬间先迁一次，避免首轮窗口内被冻结。该操作运行时生效、重启还原、不改系统文件；`/sys/fs/cgroup/cgroup.procs` 不可写时自动跳过（无副作用）。

## 更新 OpenP2P 核心

本模块打包的 `openp2p` 二进制是固定版本，控制台有更新时可升级到最新核心（如 3.25.14）。**最方便的方式是打开 WebUI 的「配置」页，点「更新到最新核心」按钮**；也可用命令行：

```sh
su -c "/data/adb/modules/openp2p-tunnel/openp2pctl update --human"    # 下载 latest, 替换并重启
su -c "/data/adb/modules/openp2p-tunnel/fetch-openp2p.sh"             # 等价底层脚本
su -c "/data/adb/modules/openp2p-tunnel/fetch-openp2p.sh --ver 3.25.14 --no-restart"
```

`openp2pctl update`（WebUI 按钮走的就是它）在 JSON 模式下为**异步**：立即返回 `{started:true}`，真正的下载/替换/重启在后台 worker 中进行，阶段进度写入 `update.state`，由 `openp2pctl update-status` 轮询读取（`stage: checking → downloading → restarting`，完成后 `{done:true, ok, up_to_date, message}`）。后台 worker 先调用 `fetch-openp2p.sh --check` 下载并读取最新版本号，与当前版本比较——已是最新则直接结束并标记 `up_to_date`，跳过后续替换重启；有新版本才调用 `fetch-openp2p.sh --no-restart` 下载替换再重启。加 `--human` 则走同步路径（终端使用）。WebUI 会展示进度转圈 + 阶段文字，出错时弹窗可复制错误信息且不自动关闭。

脚本从官方源 `https://openp2p.cn/download/v1/<ver>/openp2p-<ver>.linux-arm64.tar.gz` 下载 `linux-arm64`（真 TUN 路径）核心，备份旧二进制为 `openp2p.bak` 后替换，默认重启服务。失败自动回退 `console.openpxp.com` 备用域名。

## 透明代理必须设置（sing-box 等）

**如果你在使用 sing-box / v2rayNG 等透明代理并开启了 hijack dns（fake-ip），必须把 openp2p 的域名设为直连，否则服务会无法与 API 通信。**

原因：hijack dns 会把 `api.openp2p.cn` 解析成 fake-ip（如 `198.18.x.x` / `28.x.x.x` / 私网段）并当作「正常」响应返回。openp2p 连接服务器时会用系统 DNS 解析出的 IP 直连，解析到 fake-ip 就会连错地址 → API 通信失败、服务表现为不稳定（控制台超时 / 反复重连）。

在 sing-box 的 `route.rules` 里加一条直连规则即可（DNS 与流量同时直连）：

```json
{
  "route": {
    "rules": [
      { "domain_suffix": ["openp2p.cn"], "outbound": "direct" }
    ]
  }
}
```

若你的 DNS 服务器是 `fakeip` 类型，还需把该域名排除出 fake-ip，让它解析回真实 IP（具体写法随 sing-box 版本略有差异，通常是在 `dns.rules` 里把 `openp2p.cn` 指到 `local` 或其它真实解析服务器）。`user_id` / `process_name` 等更细粒度的直连规则亦可，以上 `domain_suffix` 为最通用写法。

模块侧处理（无需你干预）：

- `network.ServerHost` 完全以 WebUI / 配置为准，模块不自动改写、也不传 IP 直连，TLS SNI 始终是域名本身；`-insecure` 仅在 `TLSInsecureSkipVerify=true` 时由你显式开启。
- `network.ServerIP` 由守护循环在启动服务时自动补全（解析 ServerHost 写回 `config.json`），仅供 WebUI 展示与诊断参考；openp2p 运行时会自己重新解析并覆盖内存值。

所有行为均为运行时内存态，不改系统文件，重启即恢复；与 tproxy/ebpf/tun2socks 互不干扰（openp2p 只触碰 `filter/FORWARD` 与 `nat/POSTROUTING`，不碰 mangle）。openp2p 登录后会写回它自己管理的字段（`apps`、`User` 等），属正常行为，本模块不干预。

## 目录结构

```text
openp2p-tunnel/
├── module.prop          # 模块元信息 (id=openp2p-tunnel)
├── service.sh           # 启动脚本 (等待开机 → 准备 TUN → 启动守护)
├── post-fs-data.sh      # 早期挂载 (权限 + TUN 设备节点 + ip_forward)
├── openp2p_core.sh      # 守护循环 (监控/拉起 openp2p)
├── action.sh            # 管理器动作按钮
├── openp2pctl           # JSON 控制脚本 (WebUI 后端)
├── fetch-openp2p.sh     # 下载并替换最新 openp2p 核心
├── uninstall.sh
├── openp2p              # linux-arm64 二进制 (系统级 TUN, 由 fetch-openp2p.sh 下载)
├── config/config.json   # 默认配置模板
├── webroot/             # 构建后的 WebUI (icon.svg + index.html + assets, 由 pnpm build 生成)
├── webui/               # WebUI 源码 (Vue3+Vite+miuix-vue)
├── build.sh             # 构建 WebUI 并打包 zip
├── scripts/fetch-binary.sh   # CI 辅助: 下载 openp2p 二进制
├── .github/workflows/        # GitHub Actions (ci.yml + release.yml)
├── CHANGELOG.md         # 变更日志
└── README.md
```

## 配置项

| 字段 | 说明 | 默认 |
|------|------|------|
| `network.Token` | OpenP2P 控制台 Token | `YOUR_TOKEN_HERE` |
| `network.Node` | 节点名称（留空自动「品牌-型号」） | 空 |
| `network.ServerHost` | 服务器地址 | `api.openp2p.cn` |
| `network.ServerIP` | 服务器公网 IP（守护循环自动补全，仅供展示/诊断，可留空） | 空 |
| `network.ShareBandwidth` | 共享带宽 (Mbps) | `3` |
| `network.ServerPort` | 服务器端口 | `27183` |
| `network.PublicIPPort` | 公网 IP 端口 | `7037` |
| `TLSInsecureSkipVerify` | 跳过 TLS 校验 | `false` |
| `LogLevel` | 日志级别 | `1` |
| `MonitorInterval` | 守护检查间隔 | `10s` |
| `Timezone` | 时区 | `Asia/Shanghai` |
| `AutoClearLog` | 服务启动时自动清空日志 | `false` |

## 关于

- **作者**：AxoNex
- **源码仓库**：<https://github.com/AxoNex/openp2p-tunnel>（如实际地址不同请以发布为准）

## License

本模块封装与 WebUI 采用 [Apache-2.0](https://www.apache.org/licenses/LICENSE-2.0)；核心 `openp2p` 遵循其上游许可。
