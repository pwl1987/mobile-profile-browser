# WebLibre 上游锁定

## 当前锁定

| 项目 | 值 |
|---|---|
| 上游 | `FaFre/WebLibre` |
| 锁定 Commit | `dc74be456efab51823bfc913114abb77af5c231c` |
| 用途 | V0.1 代码审计基线 |

## 引入原则

V0.1 不直接跟踪 WebLibre `main` 的浮动状态。所有代码导入、补丁和构建必须能够回溯到明确的上游 commit。

## 导入策略

优先级：

1. 通过明确的上游依赖或快照复用。
2. 对必须修改的能力建立本项目 Adapter/Facade。
3. 仅在无法隔离时修改上游核心代码，并记录补丁原因。
4. 每次升级上游必须重新执行 Profile、Storage、Proxy、Android Runtime 和许可证审计。

## 当前状态

V0.1 尚未完成完整代码导入；当前仓库仅保存架构与审计基线。不要把“文档完成”视为“WebLibre 已经成功编译并集成”。

## 验收门槛

在以下项目全部通过前，不创建 V0.1 Release：

- Android APK 可重复构建
- 真机启动
- Profile 创建/切换/删除
- Profile Storage 隔离
- Cookie/LocalStorage/IndexedDB 隔离
- Proxy 路由正确
- 代理失败 Fail Closed
- DNS/WebRTC 泄漏测试
- SSH Adapter 基础连通性
- Crash/Restart 后 Profile 恢复
- 第三方许可证清单完整
