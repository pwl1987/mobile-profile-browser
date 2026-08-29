# 工具说明

本目录保存开发、审计和上游同步工具。

## WebLibre 上游初始化

```bash
./tools/import-weblibre.sh
```

脚本只负责把已经锁定的 WebLibre Git Submodule 初始化到本地。实际运行时不从网络动态拉取浏览器源码。

## 重要

执行上游升级前必须完成：

1. 新旧 commit 差异审计；
2. Profile / Storage 隔离审计；
3. Proxy / sing-box / DNS 审计；
4. 第三方许可证审计；
5. Android 构建验证；
6. 真机回归。
