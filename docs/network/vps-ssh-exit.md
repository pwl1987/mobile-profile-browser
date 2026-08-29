# VPS SSH 网络出口方案

## 1. 结论

本项目使用用户自有 VPS 的 SSH 服务作为 Profile 网络出口。

Android 端**不再单独启动 `ssh -D` 本地进程**，优先直接使用 sing-box 的 `ssh` outbound。当前 sing-box 已提供原生 SSH outbound 配置，包括服务器、端口、用户、密码/私钥、主机密钥校验以及 SSH 算法参数。citeturn937870search0turn937870search4

这样可以简化链路：

```text
MobileProfile
      ↓
NetworkRoute
      ↓
sing-box profile instance
      ↓
SSH outbound
      ↓
VPS:22
      ↓
VPS 公网出口
      ↓
Internet
```

## 2. Profile 级网络

每个 Profile 可以引用不同的 NetworkRoute：

```text
Profile A → SSH Route A → VPS A → Internet
Profile B → SSH Route B → VPS B → Internet
Profile C → SSH Route C → VPS C → Internet
```

多个 Profile 如果需要使用同一台 VPS，也可以使用不同 SSH 用户；是否允许共享出口由用户显式配置决定。

## 3. Android 端职责

Android 应用负责：

- 读取 Profile 的 NetworkRoute；
- 从安全存储读取 SSH 凭据；
- 生成或更新 sing-box 对应 outbound；
- 监控线路状态；
- 将线路状态绑定到 Profile 生命周期；
- 在 Fail Closed 模式下阻止故障线路静默变为直连。

浏览器 Runtime 不直接管理 SSH 私钥。

## 4. VPS 端建议

推荐创建专用 SSH 用户，不使用 root 作为应用常驻出口账号。

建议最小权限：

```text
PermitTTY no
X11Forwarding no
AllowTcpForwarding yes
```

还可以根据安全要求使用 `AllowUsers`、源地址限制、单独密钥和主机防火墙限制。

应用侧必须记录并验证 VPS 的 SSH host key，避免生产环境默认信任任意主机密钥。

## 5. 安全存储

Profile 只保存：

```text
credentialRef
hostKeyRef
endpointRef
```

不得保存：

```text
privateKey
password
完整认证材料
```

私钥和口令进入 Android Keystore-backed 安全存储。

## 6. 连通性验收

必须分别验证：

1. SSH TCP 可达；
2. SSH 身份认证成功；
3. host key 校验成功；
4. sing-box SSH outbound 建立；
5. 浏览器请求经过 VPS 出口；
6. DNS 行为符合配置；
7. IPv6 行为符合配置；
8. WebRTC 行为符合配置；
9. SSH 中断后 Fail Closed 生效；
10. App 重启后 Profile 与线路状态能够恢复。

## 7. 重要限制

sing-box 的 SSH outbound 当前主要适合 TCP 流量；SSH 本身不提供通用 UDP 传输，相关问题在 sing-box 社区已有明确讨论。因此不要把“SSH 出口”与“所有 UDP 流量均通过 SSH”画等号。citeturn937870search7

对于浏览器网页访问，V0.x 应优先验证 HTTP/HTTPS、DNS、WebRTC 和实际出口 IP；需要完整 UDP 能力时再设计额外传输层。
