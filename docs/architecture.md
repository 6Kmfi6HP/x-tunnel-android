# Android 客户端架构

本仓库承接 `x-tunnel/docs/android-vpn-client-plan.md` 的实现阶段。当前已放置可构建的 Android shell、`VpnService` 声明、x-tunnel sidecar supervisor、首个 profile 编辑器、tun2socks JNI 数据路径、CI 和 release workflow；仍需要真机 smoke 和多 profile 管理才能标记为稳定可用。

## 目标形态

| 组件 | 职责 |
| --- | --- |
| Compose UI | profile 编辑、连接状态、诊断和设置 |
| `XTunnelVpnService` | VPN 权限、前台通知、TUN 生命周期、runtime supervision |
| x-tunnel sidecar | 现有 Go core，client mode，本地 SOCKS5/control API |
| tun2socks sidecar | TUN fd 到本地 SOCKS5 的 TCP/UDP 转换 |

## 当前边界

- 首个 ABI 只承诺 `arm64-v8a`。
- `x86_64` 和 `armeabi-v7a` 需要 NDK/cgo 构建验证后再加入矩阵。
- App 不默认申请 `QUERY_ALL_PACKAGES`。
- Release workflow 已预留签名和 GitHub Release 上传路径。
- 当前 UI 已有可持久化的首个 profile 表单，覆盖 profile name、server URL、token、本地 SOCKS、连接数和 insecure TLS。
- 当前 service 启动前台通知，启动 bundled x-tunnel sidecar，等待 ready file，并记录 control URL。
- 当前 service 已有 `VpnDataPathController`，在缺少 `libhev-socks5-tunnel.so` 时不会建立 TUN，避免黑洞默认路由。
- 当前 service 建立 TUN 后通过 `hev-socks5-tunnel` 的 Android JNI API 传入 TUN fd，并转发到本地 x-tunnel SOCKS5 监听。
- `VpnService.Builder.addDisallowedApplication()` 排除本 app UID，避免 x-tunnel sidecar 和 tun2socks 自身连接被默认路由重新捕获。

## 下一阶段

1. 把单 profile 扩展为多 profile 列表，并补上导入/导出。
2. 通过 control API 读取 `/v1/status` 和 `/v1/stats`，并把结构化状态显示到 UI。
3. 增加 tun2socks 统计读取、错误回传和 DNS/IPv6 策略。
4. 在真机上验证 `VpnService.Builder` 的 TUN、路由、DNS、per-app 排除和后台保活行为。
5. 完成 arm64 真机 smoke 后再标记为稳定 preview。

## Tun2socks 决策记录

`gh` 查询 `heiher/hev-socks5-tunnel` 后确认：项目为 MIT license，最新 release `2.15.0` 发布于 2026-05-10，支持 Linux/Android，README 提供 NDK `ndk-build` 构建路径。当前 release assets 主要是源码包和桌面/Linux 二进制，不应直接把 Linux arm64 asset 当 Android 产物使用。

CI 中 clone `heiher/hev-socks5-tunnel`，使用 Android NDK 构建 `arm64-v8a` native artifact。Android 侧直接复用该项目内置的 `hev/htproxy/TProxyService` JNI 注册名，新增 Kotlin 包装类，避免维护额外 C/C++ bridge。Release 校验会检查 APK/AAB 内同时包含 `libxtunnel.so` 和 `libhev-socks5-tunnel.so`。
