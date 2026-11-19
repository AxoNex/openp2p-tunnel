# Changelog

本项目遵循[语义化版本](https://semver.org/lang/zh-CN/)。所有面向用户的变更均记录于此。

## [未发布] - Unreleased

### 新增

- 添加 `LICENSE`（Apache-2.0）文件。
- GitHub Actions 持续集成与发布：
  - `ci.yml`：推送 `main` 分支自动构建 canary 测试版并上传为 Artifact（不再创建 release）。
  - `release.yml`：推送 `v*` tag 自动构建正式版并发布 release（自动校验 tag 与 `module.prop` 版本一致）。
- `scripts/fetch-binary.sh`：CI 辅助脚本，从官方源下载 openp2p 核心二进制。
- `build.sh` 新增 `--fetch-binary`（自动下载二进制）与 `--canary`（输出固定文件名 `openp2p-tunnel-canary.zip`）。

### 文档

- `README.md` 新增「下载」章节（正式版 + canary 链接）与 CI 构建说明。

## [1.1.6] - 2026-11-19

### 新增

- WebUI 新增「关于」页面：展示模块 / 核心版本、节点名、作者与开源仓库外链（在外部浏览器打开）。

### 文档

- 编写完整 `CHANGELOG.md`。
- 重写 `README.md`：核心作用、详细用法、透明代理（sing-box）必须设置。
- 项目初始化为 git 仓库（`.gitignore` 排除构建产物与核心二进制）。

## [1.1.5] - 2026-11-19

### 修复

- 进程保活（切后台即断连）：openp2p 由 `su` 拉起时继承管理器 App 的 cgroup，App 退后台后 freezer 冻结 cgroup 导致进程挂起（非被杀）。修复：监控循环把 openp2p 进程与守护循环迁入 cgroup v2 根组（`/sys/fs/cgroup/cgroup.procs`），参考 NetProxy 的 `ensureSingBoxRootCgroup`。

## [1.1.4] - 2026-11-19

### 新增

- `openp2pctl netunpin`：撤销 `netpin` 的目的地址路由 / 规则。

### 修复

- `get_version` 原取日志里**最旧**的 version 行导致显示旧版本，改为取最新一行。

## [1.1.3] - 2026-11-19

### 新增

- `openp2pctl netpin`：把到服务器的流量固定到当前物理接口（一次性诊断 unexpected EOF 断连，实验性）。

## [1.1.2] - 2026-11-19

### 变更

- 移除快照防篡改与 DNS 劫持检测（会误伤用户在 WebUI 里的 ServerHost 改动）。
- `ServerHost` 完全以 WebUI / 配置为准；新增 `auto_fill_serverip` 自动补全 `network.ServerIP`（仅供展示 / 诊断）。

## [1.1.1] - 2026-11-19

### 变更

- 快照式配置防篡改：首次运行保存 ServerHost / ServerIP / TLSInsecureSkipVerify 三个托管字段的干净快照，之后仅检测并回写这三个被 openp2p 写回的字段（后在 1.1.2 移除）。

## [1.1.0] - 2026-11-19

### 修复

- 配置污染：openp2p 登录后会把 `-serverhost` 传入的 IP 写回 `config.json`，导致 `ServerHost` 永久变成 IP、SNI 变成 IP。先以固定规则复位（后在 1.1.1 改为快照）。

## [1.0.9] - 2026-11-19

### 新增

- 连接健康看门狗：检测到 `ReadMessage error` / `keepAlive error` 且持续超过 60s，强制重启服务。

## [1.0.8] - 2026-11-19

### 新增

- `renice -20` 提升 openp2p 进程优先级。
- 停止 / 启动时同步更新模块描述（KernelSU 模块页状态）。

## [1.0.7] - 2026-11-19

### 修复

- WebUI 按钮卡死：命令改为异步（后台执行 + 轮询状态），界面加转圈。
- `awk -F.` 中 `.` 是正则元字符导致 IP 分段错误、`serverhost` 为空，改为 `-F'[.]'`。

## [1.0.6] - 2026-11-18

### 新增

- DNS 劫持绕过（可信 IP 回退，后在 1.1.2 移除）。
- WebUI 更新功能：阶段进度 + 错误弹窗（可复制、不自动关闭）+ 已是最新则跳过。

## [1.0.5] - 2026-11-18

### 新增

- WebUI「核心更新」功能（`openp2pctl update`）。

## [1.0.4] - 2026-11-18

### 修复

- 跨设备 ping 不通：新增 `normalize_cidr` 规范化子网地址；`netfix` 改用专用 `table 100` + `ip rule add to <子网> lookup 100`（HyperOS 策略路由无 `lookup main`，未打标流量实际走 per-network 表，openp2p 内核只写 main 表所以路由从不命中）。

## [1.0.3] - 2026-11-18

### 修复

- WebUI 版本 / 节点 / 虚拟 IP 显示为 "-"：`json_escape` 使用非 POSIX 的 `\x0a` / `\r` 转义，toybox sed 失败返回空。
- `netfix` 增加 `local_network`(97) 路由表。

## [1.0.2] - 2026-11-18

### 新增

- `openp2pctl diag` / `netfix` 诊断与修复命令。

## [1.0.1] - 2026-11-18

### 新增

- `fetch-openp2p.sh`：下载 / 更新 openp2p linux-arm64 核心。

### 变更

- 默认共享带宽 3Mbps、默认关闭「跳过 TLS 证书校验」。
- 保存配置不再自动重启服务。

### 修复

- 虚拟 IP 点对点地址解析（`inet X peer Y/32` 无掩码）。
- `MODDIR` 相对路径调用 bug。
- 无法停止 + 「Text file busy」（先杀监控循环再替换二进制）。

## [1.0.0] - 2026-11-18

### 新增

- 基于 `openp2p-magisk` 的 KernelSU 模块 `openp2p-tunnel`。
- Miuix 风格图形化 WebUI（Vue 3 + Vite + `miuix-vue`）。
- 系统级虚拟网卡支持：root 直连 TUN（linux-arm64 二进制 + `mknod /dev/net/tun` + `ip_forward`），不依赖 Android VPN Service，与 tproxy / eBPF / tun2socks 等透明代理兼容。
