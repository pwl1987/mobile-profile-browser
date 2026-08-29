# Profile 模型

## 1. 身份

每个 Profile 使用稳定、随机生成的 `profile_id`。显示名称可以修改，绝不能作为存储目录或安全边界的唯一标识。

```text
Profile
├── profile_id
├── name
├── created_at
├── updated_at
├── browser_state_ref
├── device_profile_id
├── network_route_id
├── status
└── schema_version
```

## 2. 生命周期

```text
CREATED → STARTING → ACTIVE → STOPPING → STOPPED
                       │
                       └────────────→ ERROR
```

同一时刻只能有一个生命周期所有者修改 Profile Runtime。状态转换必须幂等，并能够安全处理重复启动、停止和切换请求。

## 3. 隔离契约

每一份持久化数据都必须明确所有权。数据只能属于以下四类之一：

- `PROFILE`：仅由一个 Profile 所有；
- `APP_GLOBAL`：应用明确设计为共享的数据；
- `EPHEMERAL`：仅存在于运行时，结束后丢弃；
- `SECRET`：加密并单独保护的敏感数据。

Cookie、网站存储、浏览会话、权限等默认属于 `PROFILE`。如果底层引擎只能提供更粗粒度的隔离，必须记录例外、影响和验证方式。

## 4. Profile 与浏览器 Runtime

Profile 数据模型不等于 Gecko Runtime。必须通过 `BrowserRuntimeAdapter` 管理：

```text
Profile
  ↓
BrowserRuntimeAdapter
  ↓
Gecko / GeckoView
```

这样后续更换上游实现或调整 Runtime 生命周期时，不需要让 UI 直接了解 Gecko 内部存储结构。

## 5. 并发策略

V0.1 默认一次只运行一个活动浏览器 Runtime。数据模型允许创建多个 Profile，但多个 Gecko Runtime 同时运行必须等目标设备完成内存、CPU、电量和后台限制测试后再开放。

## 6. 删除策略

删除 Profile 必须是显式操作，并定义：

1. Profile 元数据删除；
2. 浏览器数据删除；
3. 缓存删除；
4. 网络配置引用解除；
5. Secret 引用销毁；
6. 是否保留用户主动导出的加密备份。

删除操作应支持失败恢复，避免出现“列表里不存在但磁盘数据仍残留”的未定义状态。

## 7. 导入 / 导出

暂不实现。未来实现时必须携带 `schema_version`，默认加密，并明确禁止把 App 全局状态、其他 Profile 数据或未授权 Secret 静默导入。
