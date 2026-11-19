<div align="center">
  <img src="webroot/icon.svg" width="112" alt="openp2p-tunnel">
  <h1>OpenP2P Tunnel</h1>
  <p>A KernelSU module based on OpenP2P that adds a system-level virtual network interface (SDWAN networking) on top of the existing NAT traversal capabilities</p>

  [![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/AxoNex/openp2p-tunnel/ci.yml)](https://github.com/AxoNex/openp2p-tunnel/actions)
  [![GitHub Downloads (all assets, all releases)](https://img.shields.io/github/downloads/AxoNex/openp2p-tunnel/total)](https://github.com/AxoNex/openp2p-tunnel/releases)
  [![License](https://img.shields.io/github/license/AxoNex/openp2p-tunnel)](LICENSE)

  [中文](README.md) · English
</div>

This project is based on OpenP2P NAT traversal. It supports creating the `optun` system-level virtual network interface via root direct TUN (without relying on Android VPN Service) to achieve SDWAN networking, and provides a four-page (Status, Config, Logs, About) Miuix/MD3 graphical WebUI based on miuix-vue.

## Compatibility

- **Root direct TUN**: This module packages the `linux-arm64` build (`GOOS=linux`), using `optun`'s `wireguard-go` TUN path rather than the VPN-Service stub of the `android` build.
- **Coexistence with other transparent proxies**: `openp2p` only writes to `filter/FORWARD` (`optun` ACCEPT) and `nat/POSTROUTING` (a dedicated `OPSDWAN` chain), and does not touch `mangle`, `OUTPUT`, or `PREROUTING`. It is therefore **naturally compatible** with transparent proxies such as tproxy / eBPF / tun2socks.
- **arm64 only** (upstream only provides arm64 artifacts).

## Download

| Type | Link |
|------|------|
| **Stable release** | [Github Releases](https://github.com/AxoNex/openp2p-tunnel/releases/latest) |
| **Canary (testing)** | [Github Actions](https://github.com/AxoNex/openp2p-tunnel/actions) |

## Installation

1. Install the zip obtained from the Download section above (stable or canary) using the KernelSU manager.
2. Obtain a token from the OpenP2P console and fill it into the configuration (choose one of the following three methods):
   - **WebUI**: Open the module's Config page, enter the token, save, and restart the service.
   - **Config file**: Edit `network.Token` in `/data/adb/openp2p-tunnel/config.json`.
   - **Command line**: `su -c "/data/adb/modules/openp2p-tunnel/openp2pctl config import <base64>"`.
3. Go back to the Status page and click Start.

## How It Works

- **SDWAN access**: After adding the device to the virtual network and configuring `Gateway` in the OpenP2P console, `openp2p` automatically creates the `optun` TUN interface, configures the IP, enables IPv4 forwarding, writes the `filter/FORWARD` allow rule, creates the `OPSDWAN` MASQUERADE chain in the `nat` table, and writes routes for the peer `Resource` CIDRs.
- **Android routing fallback**: `netfix` manually fills in `ip_forward`, subnet routes into a dedicated table 100, a high-priority policy route `to <subnet> lookup 100`, and FORWARD/SNAT rules. The reason is that Android policy routing has no `lookup main`; when the kernel only writes the `main` table, routes may not match.
- **Watchdog mechanism**: `openp2p_core.sh` automatically invokes the idempotent `netfix` about every 10 seconds after `optun` comes online.
- **Process keep-alive**: Move `openp2p` and the watchdog loop out of the app cgroup into the root group by writing to `/sys/fs/cgroup/cgroup.procs` and applying `renice -20`, preventing them from being frozen by the freezer when the app goes to the background.
- **Control script**: The WebUI calls `openp2pctl` via KernelSU `ksu.exec` with JSON output; it supports status, start/stop, config, logs, TUN, diagnostics, `netfix`, `netpin`, update, etc.
- **Core update**: `openp2pctl update` runs asynchronously in JSON mode, writes stages to `update.state`, and is polled by `update-status`; it downloads the linux-arm64 core from the official source, backs up the old binary as `openp2p.bak`, and falls back to an alternate domain on failure.
- **WebUI**: Source is in `webui/`; on a networked machine run `pnpm install && pnpm build`, and the output goes to `../webroot`; the shell layer does not depend on the WebUI.

## Troubleshooting

- **Cross-device connectivity failure**: When the local `optun` is up and can ping its own virtual IP but cannot ping other devices, run the following in order:
  - `sh openp2pctl diag --human`
  - `sh openp2pctl netfix --human`
  - Then ping the other devices' virtual IPs again.
- **Disconnection from server: `unexpected EOF`**:
  - Repeated `websocket: close 1006 ... unexpected EOF` in the logs indicates that the long connection to `api.openp2p.cn:27183` is being interrupted.
  - You can use `sh openp2pctl netpin --human` to pin the server connection to the current physical interface and determine whether Android network management is killing the socket.
  - If the disconnection disappears after `netpin` → it is mostly Android network management; if it persists → it is more likely the server or carrier NAT/middlebox.
- **Hang/disconnection after switching to the background**: If it works fine while the screen is on but other devices time out pinging it and the console shows offline after switching to the background, the root cause is that the process inherited the cgroup of the launching app and was frozen; `openp2p_core.sh` already includes root-group migration and `renice -20` keep-alive.
- **Transparent proxy causing API instability**: When sing-box/v2rayNG enables hijack dns/fake-ip, `api.openp2p.cn` may be resolved to a fake-ip, causing connection errors, console timeouts, or repeated reconnections. You need to set `openp2p.cn` to direct connection and exclude it from fake-ip.

## Notes

- If the kernel lacks a TUN driver, the system-level virtual NIC cannot be established, but NAT traversal functionality is unaffected.
- `netfix` and `netpin` are runtime in-memory changes that are reverted on reboot and do not modify system files.
- `netpin` is an experimental diagnostic measure that only pins to the current interface; after switching Wi-Fi/mobile networks it may point to the old interface and cause disconnection, so it is not recommended to leave it enabled long-term; use `netunpin` to undo it.
- `openp2pctl update` is asynchronous by default; add `--human` for synchronous output in a terminal.
- When using a transparent proxy such as sing-box with fake-ip enabled, you **must** set `openp2p.cn` to direct connection, and exclude it from fake-ip in DNS rules if necessary.
- The module does not automatically rewrite `network.ServerHost`; TLS SNI is always the domain name; `-insecure` is only enabled when explicitly configured.
- openp2p only touches `filter/FORWARD` and `nat/POSTROUTING`, not `mangle`, and does not interfere with tproxy/ebpf/tun2socks.

## Directory Structure

```text
openp2p-tunnel/
├── module.prop          # module metadata (id=openp2p-tunnel)
├── service.sh           # startup script (wait for boot → prepare TUN → start watchdog)
├── post-fs-data.sh      # early mount (permissions + TUN device node + ip_forward)
├── openp2p_core.sh      # watchdog loop (monitor/restart openp2p)
├── action.sh            # manager action button
├── openp2pctl           # JSON control script (WebUI backend)
├── fetch-openp2p.sh     # download and replace the latest openp2p core
├── uninstall.sh
├── openp2p              # linux-arm64 binary (system-level TUN, downloaded by fetch-openp2p.sh)
├── config/config.json   # default config template
├── webroot/             # built WebUI (icon.svg + index.html + assets, generated by pnpm build)
├── webui/               # WebUI source (Vue3+Vite+miuix-vue)
├── build.sh             # build WebUI and package zip
├── scripts/fetch-binary.sh   # CI helper: download openp2p binary
├── .github/workflows/        # GitHub Actions (ci.yml + release.yml)
├── CHANGELOG.md         # changelog
└── README.md
```

## Configuration

| Field | Description | Default |
|------|------|------|
| `network.Token` | OpenP2P console token | `YOUR_TOKEN_HERE` |
| `network.Node` | Node name (leave empty for automatic "brand-model") | empty |
| `network.ServerHost` | Server address | `api.openp2p.cn` |
| `network.ServerIP` | Server public IP (automatically filled by the watchdog loop; for display/diagnostics only; may be left empty) | empty |
| `network.ShareBandwidth` | Shared bandwidth (Mbps) | `3` |
| `network.ServerPort` | Server port | `27183` |
| `network.PublicIPPort` | Public IP port | `7037` |
| `TLSInsecureSkipVerify` | Skip TLS verification | `false` |
| `LogLevel` | Log level | `1` |
| `MonitorInterval` | Watchdog check interval | `10s` |
| `Timezone` | Timezone | `Asia/Shanghai` |
| `AutoClearLog` | Automatically clear logs when the service starts | `false` |

## About

- **Author**: AxoNex
- **Source repository**: <https://github.com/AxoNex/openp2p-tunnel> (if the actual address differs, please refer to the published version)

## License

The module wrapper and WebUI are licensed under [Apache-2.0](https://www.apache.org/licenses/LICENSE-2.0); the core `openp2p` follows its upstream license.