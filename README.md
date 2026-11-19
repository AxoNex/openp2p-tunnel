<div align="center">
  <img src="webroot/icon.svg" width="112" alt="openp2p-tunnel">
  <h1>OpenP2P Tunnel</h1>
  <p>基于 OpenP2P 的 KernelSU 模块，在原有内网穿透能力之上新增系统级虚拟网卡（SDWAN 组网）</p>

  [![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/AxoNex/openp2p-tunnel/ci.yml)](https://github.com/AxoNex/openp2p-tunnel/actions)
  [![GitHub Downloads (all assets, all releases)](https://img.shields.io/github/downloads/AxoNex/openp2p-tunnel/total)](https://github.com/AxoNex/openp2p-tunnel/releases)
  [![License](https://img.shields.io/github/license/AxoNex/openp2p-tunnel)](LICENSE)

  中文 · [English](README.en.md)
</div>

本项目基于 OpenP2P 内网穿透，支持通过 root 直连 TUN 创建 optun 系统级虚拟网卡（不依赖 Android VPN Service）完成 SDWAN 组网，并提供基于 miuix-vue 的状态、配置、日志、关于四页 Miuix/MD3 图形化 WebUI。

## 兼容性

- **root 直连 TUN**：本模块打包的是 `linux-arm64` 构建（`GOOS=linux`），走 `optun` 的 `wireguard-go` TUN 路径，而非 `android` 构建的 VPN-Service 桩。
- **与其他透明代理共存**：`openp2p` 仅写入 `filter/FORWARD`（`optun` ACCEPT）与 `nat/POSTROUTING`（独立的 `OPSDWAN` 链），不触碰 `mangle`、`OUTPUT`、`PREROUTING`，因此与 tproxy / eBPF / tun2socks 等透明代理**天然兼容**。
- **仅支持 arm64**（上游仅提供 arm64 产物）。

## 下载

| 类型 | 链接 |
|------|------|
| **正式版** | [Github Releases](https://github.com/AxoNex/openp2p-tunnel/releases/latest) |
| **测试版（Canary）** | [Github Actions](https://github.com/AxoNex/openp2p-tunnel/actions) |

## 安装

1. 用 KernelSU 管理器安装从上方「下载」获取的 zip（正式版或 canary）。
2. 获取 OpenP2P 控制台的 Token，填入配置（三种方式任选其一）：
   - **WebUI**：打开模块的「配置」页填写 Token，保存后重启服务。
   - **配置文件**：编辑 `/data/adb/openp2p-tunnel/config.json` 的 `network.Token`。
   - **命令行**：`su -c "/data/adb/modules/openp2p-tunnel/openp2pctl config import <base64>"`。
3. 回到「状态」页点击「启动」。

## 原理

- **SDWAN 接入**：在 OpenP2P 控制台将设备加入虚拟网络并配置 `Gateway` 后，`openp2p` 自动创建 `optun` TUN 网卡、配置 IP、开启 IPv4 转发、写入 `filter/FORWARD` 放行规则、在 `nat` 表建立 `OPSDWAN` MASQUERADE 链，并为对端 `Resource` CIDR 写入路由。
- **Android 路由兜底**：`netfix` 手动补齐 `ip_forward`、子网路由到独立表 100、高优先级策略路由 `to <子网> lookup 100`、FORWARD/SNAT 规则。原因是 Android 策略路由无 `lookup main`，内核只写 `main` 表时路由可能不命中。
- **守护机制**：`openp2p_core.sh` 在 `optun` 上线后约每 10 秒自动调用幂等 `netfix`。
- **进程保活**：将 openp2p 与守护循环迁出应用 cgroup，写入 `/sys/fs/cgroup/cgroup.procs` 根组并 `renice -20`，避免切后台被 freezer 冻结。
- **控制脚本**：WebUI 通过 KernelSU `ksu.exec` 调用 `openp2pctl`，输出 JSON；支持状态、启停、配置、日志、TUN、诊断、netfix、netpin、更新等。
- **更新核心**：`openp2pctl update` JSON 模式异步执行，阶段写入 `update.state`，由 `update-status` 轮询；从官方源下载 linux-arm64 核心，备份旧二进制为 `openp2p.bak`，失败回退备用域名。
- **WebUI**：源码在 `webui/`，联网机器 `pnpm install && pnpm build`，产物到 `../webroot`；shell 层不依赖 WebUI。

## 错误排查

- **跨设备不通**：本机 `optun` 上线且能 ping 自己虚拟 IP，但 ping 不通其他设备时，依次执行：
  - `sh openp2pctl diag --human`
  - `sh openp2pctl netfix --human`
  - 再 ping 其他设备虚拟 IP。
- **与服务器断连 `unexpected EOF`**：
  - 日志反复出现 `websocket: close 1006 ... unexpected EOF`，说明到 `api.openp2p.cn:27183` 的长连接被中断。
  - 可用 `sh openp2pctl netpin --human` 将服务器连接钉到当前物理接口，判断是否 Android 网络管理杀 socket。
  - `netpin` 后断连消失 → 多为 Android 网络管理；仍断连 → 更可能是服务端或运营商 NAT/中间盒。
- **切后台假死/断连**：亮屏正常、切后台后其他设备 ping 超时且控制台离线，根因是进程继承启动 App 的 cgroup 被冻结；`openp2p_core.sh` 已内置迁根组与 `renice -20` 保活。
- **透明代理导致 API 不稳定**：sing-box/v2rayNG 开启 hijack dns/fake-ip 时，`api.openp2p.cn` 可能被解析为 fake-ip，导致连接错误、控制台超时或反复重连。需将 `openp2p.cn` 设为直连并排除出 fake-ip。

## 注意事项

- 内核缺少 TUN 驱动时系统级虚拟网卡无法建立，但穿透功能不受影响。
- `netfix`、`netpin` 均为运行时内存态改动，重启还原，不修改系统文件。
- `netpin` 是实验性诊断手段，仅钉到当前接口；切换 WiFi/移动网后可能指向旧接口导致断连，不建议长期开启，可用 `netunpin` 撤销。
- `openp2pctl update` 默认异步；终端需同步输出时加 `--human`。
- 使用 sing-box 等透明代理并开启 fake-ip 时，**必须**将 `openp2p.cn` 设为直连，必要时在 DNS 规则中排除 fake-ip。
- 模块不自动改写 `network.ServerHost`，TLS SNI 始终为域名；`-insecure` 仅在显式配置时开启。
- openp2p 只触碰 `filter/FORWARD` 与 `nat/POSTROUTING`，不碰 mangle，与 tproxy/ebpf/tun2socks 互不干扰。

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
