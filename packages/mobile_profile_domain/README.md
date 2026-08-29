# Mobile Profile 领域包

这是 Mobile Profile Browser 自己的核心领域层，保持纯 Dart，不依赖 Flutter、GeckoView、WebLibre 或具体代理实现。

## 为什么独立

WebLibre 的 Profile 对象服务于浏览器自身的数据与认证上下文。本项目需要的 `MobileProfile` 是更高层的完整运行身份，因此采用组合而不是直接扩展上游实体。

```text
MobileProfile
├── browserProfileRef
├── deviceProfileRef
├── networkRouteRef
└── security policy（后续）
```

## 当前对象

- `MobileProfile`：完整移动 Profile 身份。
- `DeviceProfile`：设备/浏览器能力配置。
- `NetworkRoute`：网络出口逻辑配置。
- `DeviceProfileValidator`：设备配置结构校验。
- `NetworkRouteValidator`：网络线路结构校验。

## 设计约束

- 不持有 Gecko、Flutter、Android Context 等运行时对象。
- 不持有 SSH 私钥或代理密码。
- 不直接创建 socket、VPN 或 sing-box runtime。
- 不实现指纹伪装。
- 所有跨基础设施操作通过 Adapter/Service 实现。

这样可以先用纯 Dart 单元测试验证核心规则，再接入 WebLibre。
