# 上游源码说明

本目录用于保存第三方浏览器底座的上游引用。

当前正式上游为 WebLibre，采用 Git Submodule 固定到经过审计的 commit，而不是把第三方源码直接复制进本仓库。

- 上游仓库：https://github.com/FaFre/WebLibre
- 当前 V0.1 审计基线：`dc74be456efab51823bfc913114abb77af5c231c`

实际初始化方式：

```bash
git submodule sync --recursive
git submodule update --init --recursive
```

除非经过上游升级评审，不要随意移动子模块 commit。