# ADR-002：Profile 隔离架构

日期：2026-08-30 · 状态：已接受

## 决策

Profile 隔离通过**四层独立机制**保证，而不是依赖单一实现：

```text
Domain      MobileProfile.browserProfileRef = browser-<uuid>（创建/复制时新生成）
映射层      WebLibreProfileMapper：uuid → weblibre_profiles/profile-<uuid> 目录
数据层      browser_profiles 表：UNIQUE(browser_profile_id)，一对一绑定
运行时层    目录即边界 + Gecko 进程一次性绑定（一个进程一个活跃 Profile）
```

## 关键约束（来自上游事实）

1. WebLibre 的浏览器 Profile 是文件系统目录
   （`{filesDir}/weblibre_profiles/profile-<uuid>/files/mozilla/`），
   目录名即身份。
2. **Gecko runtime 与进程一次性绑定**（上游 core/filesystem.dart）：
   绑定后不能重定向，二次激活会让 Dart 与 Gecko 读取不同 Profile 且
   无法调和。因此 `WebLibreRuntimeManager` 强制单绑定槽位：切换
   Profile 必须 stop → launch。

## 规则

- Domain 不 import WebLibre；真实引擎可达性通过 Adapter 契约反转
  （未来可换 GeckoView 自建 / Chromium Android）。
- 复制 Profile 必须生成全新 browserProfileRef 与全新绑定——复制的是
  配置身份，不继承浏览数据。
- 绑定与 profile 引用漂移时，启动编排直接拒绝，不尝试"修复"。
- 隔离契约以 `browser_profile_isolation_test` 常驻 CI；真机 GeckoView
  验收以同一断言结构执行（M3 Gate 收口条件）。

## 后果

- 同一时刻一个进程只有一个活跃浏览环境；"多 Profile 并发浏览"需要
  进程隔离（未来决策，参考上游多进程能力后再评估）。
