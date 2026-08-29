# 安全威胁模型

## 保护资产

- Profile Cookie 与站点数据；
- 保存的凭据与浏览器权限；
- SSH / 代理凭据；
- Profile 元数据；
- DeviceProfile 配置；
- NetworkRoute 配置与运行状态。

## 威胁

1. Profile 之间发生数据泄漏或串数据。
2. 受保护线路故障后静默回落到真实网络。
3. 凭据通过日志、备份或崩溃报告泄漏。
4. 活动 Profile 注册表损坏导致错误恢复或数据归属混乱。
5. 错误地认为浏览器可见配置已经改变了底层引擎特征。
6. 上游依赖变化导致隔离或安全边界被削弱。
7. 删除 Profile 后残留敏感数据。
8. 调试接口、开发日志或诊断页面暴露 Profile 数据。
9. NetworkRoute 与实际网络出口状态不一致。
10. Proxy/TUN/SSH 组件出现故障时发生隐式直连。

## 安全要求

- 秘密使用 Android Keystore 等受保护机制保存；
- Profile 存储边界必须明确并有自动化测试；
- 受保护线路必须支持 Fail Closed；
- Release 构建关闭或严格脱敏调试日志；
- 上游和依赖变更必须在发布前审核；
- DeviceProfile 每个字段必须明确标记为 controlled、derived、observed 或 unsupported；
- 删除操作必须能够验证作用域数据清理结果；
- 日志、诊断和错误报告不得包含私钥、密码、Cookie 或完整敏感 URL；
- 不允许通过网络故障处理逻辑绕过用户明确配置的路由保护；
- NetworkService 必须能够证明当前 Profile 的实际线路状态。

## 安全边界

```text
┌─────────────────────────────────┐
│            Android App          │
│                                 │
│  MobileProfile Domain           │
│      │             │            │
│      ├── DeviceProfile          │
│      ├── NetworkRoute           │
│      └── BrowserProfile Ref     │
│              │                  │
│        Secure Storage           │
│              │                  │
│        Network Service          │
└──────────────┼──────────────────┘
               │
      OS / VPN / Proxy / SSH
```

SSH 私钥等秘密必须停留在安全存储与网络服务边界内，不进入浏览器页面、普通 Profile JSON 或 UI 日志。

## 安全状态机

网络保护状态至少区分：

```text
UNKNOWN
  ↓
STARTING
  ↓
HEALTHY
  ├── DEGRADED
  └── STOPPING
        ↓
      STOPPED
```

`DEGRADED`、`STOPPED` 等非健康状态不能在 Fail Closed 策略下继续放行受保护流量。

## 非目标

本项目不承诺匿名性，不承诺对抗所有网站检测机制，也不声称某一种反指纹配置能够击败特定网站的风险引擎。

项目目标是：**可控的 Profile 隔离，以及一致、可验证的隐私与网络配置。**
