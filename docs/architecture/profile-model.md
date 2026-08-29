# Profile 模型

## 1. 身份

每个 Profile 使用稳定、随机的 `profile_id`。显示名称可以修改，绝不能作为存储目录或其他持久化资源的唯一标识。

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

同一时间只能由一个生命周期管理者修改 Profile 的运行时状态。状态转换必须具备幂等性。

## 3. 隔离契约

每一项持久化数据都必须有明确的所有权分类：

- `PROFILE`：只属于一个 Profile；
- `APP_GLOBAL`：应用明确允许共享；
- `EPHEMERAL`：仅运行时存在，运行结束后丢弃；
- `SECRET`：加密保存并受到单独保护。

Cookie、站点存储、浏览会话和权限默认属于 `PROFILE`。如果上游浏览器引擎只能提供更窄或不同的隔离边界，必须记录例外原因和验证方法。

## 4. 并发策略

V0.1 默认一次只运行一个活动浏览器运行时。数据模型可以管理多个 Profile，但多个 Gecko Runtime 同时常驻暂缓，必须先在目标 Android 设备上测量内存、CPU、电量和稳定性。

## 5. 导入/导出

V0.1 暂不实现导入/导出。后续实现时，导出文件必须包含 schema 版本，并且不得无提示地导入 SSH 私钥等秘密或应用全局状态。

## 6. 删除

删除 Profile 必须经过明确的生命周期操作：

```text
ACTIVE
  ↓
STOPPING
  ↓
STOPPED
  ↓
DELETE_PENDING
  ↓
DATA_PURGED
```

删除失败不能伪装成成功；必须能够报告残留数据类型和清理状态。

## 7. 运行时恢复

应用崩溃或 Android 进程被回收后，启动恢复逻辑必须从持久化状态重新确认活动 Profile，而不是依赖内存中的 UI 状态。