# 实施路线图

## 总体目标

最终交付一个可安装在真实 Android 手机上的多 Profile 浏览器：

```text
一台 Android 手机
       ↓
Mobile Profile Browser
       ↓
Profile A / B / C / ...
       ↓
浏览器状态 + 设备配置 + 网络线路独立管理
```

## 阶段 0：工程基线

- 中文项目文档统一；
- WebLibre 上游 commit 固定；
- 许可证与第三方依赖清单建立；
- 纯 Dart 领域包建立；
- 基础 CI 与静态检查建立。

完成标准：代码结构可重复构建，关键领域规则有单元测试。

## 阶段 1：浏览器底座

- 导入固定 WebLibre 快照；
- Android Debug APK 构建；
- 真机安装；
- 启动、普通浏览、退出与恢复；
- 记录 GeckoView / Android / Flutter 实际版本。

禁止在这一阶段加入指纹伪装逻辑。

## 阶段 2：Profile 编排

- `MobileProfile` 与 WebLibre Profile 建立映射；
- 创建、重命名、启动、停止、切换、删除；
- 数据目录生命周期；
- 崩溃恢复；
- Cookie / Storage / 权限隔离验收。

完成标准：两个以上 Profile 能在真机上长期保存且互不串数据。

## 阶段 3：网络线路

- `NetworkRoute` 接入 WebLibre/sing-box；
- SOCKS5 / HTTP 路由；
- 每 Profile 网络线路引用；
- 线路健康状态；
- Fail Closed；
- DNS / IPv6 / WebRTC 验证。

完成标准：不同 Profile 可验证不同公网出口，并且关闭代理后不会发生隐式直连。

## 阶段 4：SSH

- SSH Dynamic Forward；
- SSH 凭据安全存储；
- 自动重连；
- keepalive；
- 健康检查；
- SSH → SOCKS5 / sing-box；
- 断线 Fail Closed。

SSH 实现采用成熟库或已有运行时能力，不自己实现 SSH 协议。

## 阶段 5：设备配置

- DeviceProfile 管理；
- Android 设备预置；
- 能力兼容验证；
- 与 Gecko 实际能力绑定；
- 记录 controlled / derived / observed / unsupported。

## 阶段 6：指纹一致性

这一阶段才研究：

- Navigator；
- Screen / DPR；
- Touch；
- Locale / Timezone；
- Client Hints；
- WebGL；
- Canvas；
- Audio；
- Fonts；
- WebRTC。

原则：先判断 Gecko 是否可以可靠控制，再决定是否实现；不使用大量临时 JavaScript 覆盖冒充完整方案。

## 阶段 7：产品化

- Profile 搜索、标签、排序；
- 复制 Profile；
- 加密备份与恢复；
- 导入导出；
- 日志与诊断；
- 崩溃恢复；
- 性能优化；
- Release APK / F-Droid 等分发方案。

## Gate 规则

任何阶段必须通过前一阶段验收才能继续扩大功能范围。

涉及隔离、网络、秘密保护的功能必须有实测证据；不能只通过 UI 演示判定完成。