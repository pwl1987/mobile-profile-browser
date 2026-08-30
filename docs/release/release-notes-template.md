# Release Notes 中文模板

> 自 M3 起，开发版 Release 一律使用本模板（docs/standards/i18n.md）。
> tag 形如 `m3-runtime-dev-202609xx`；APK 文件名保持英文。

```markdown
## 独立浏览器 · 开发版

多 Profile 隔离浏览环境 · <Gate 名称>

### 本版本

- <能力 1（以"经过真实测试的能力"口径描述，不写"实现了 XX 代码"）>
- <能力 2>
- <能力 3>

### 已知限制

- 当前 Gecko Runtime 单实例：同一时刻仅一个浏览环境可运行（ADR-004）
- 暂不支持多个浏览环境同时运行
- <如实列出：SSH 代理尚未完成 / 指纹配置尚未完成 / …>

### 验证环境

- 设备：OPPO Find N3（PHN110）
- Android：<版本>
- 构建：<commit> / CI Run <id> / WebLibre b4721ae6

### 下载与校验

- app-debug.apk（<大小>）
- SHA-256：<校验值>
```

要求：

1. 「本版本」只写经验证的能力，禁止把"代码已写"当完成；
2. 「已知限制」必须包含 Gecko 单实例约束（ADR-004）；
3. 必须给出 SHA-256 与构建来源（commit + CI Run）；
4. 历史构建基线（m1-baseline-*）不回改。
