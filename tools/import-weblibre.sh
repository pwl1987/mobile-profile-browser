#!/usr/bin/env bash
set -euo pipefail

# 初始化已经锁定的 WebLibre Git Submodule。
# 该脚本只用于开发环境；应用运行时绝不下载或更新第三方源码。

UPSTREAM_URL="https://github.com/FaFre/WebLibre.git"
UPSTREAM_COMMIT="dc74be456efab51823bfc913114abb77af5c231c"
SUBMODULE_PATH="vendor/weblibre"

if ! command -v git >/dev/null 2>&1; then
  echo "错误：未找到 git。" >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ ! -f .gitmodules ]]; then
  echo "错误：未找到 .gitmodules，请确认仓库已完成上游基线提交。" >&2
  exit 1
fi

configured_url="$(git config --file .gitmodules --get "submodule.${SUBMODULE_PATH}.url" || true)"
if [[ "$configured_url" != "$UPSTREAM_URL" ]]; then
  echo "错误：$SUBMODULE_PATH 的上游地址不是预期值：$UPSTREAM_URL" >&2
  exit 1
fi

git submodule sync --recursive
git submodule update --init --recursive "$SUBMODULE_PATH"

actual_commit="$(git -C "$SUBMODULE_PATH" rev-parse HEAD)"
if [[ "$actual_commit" != "$UPSTREAM_COMMIT" ]]; then
  echo "错误：WebLibre 子模块当前为 $actual_commit，预期为 $UPSTREAM_COMMIT。" >&2
  echo "不要继续构建，请先完成上游升级审计。" >&2
  exit 1
fi

echo "WebLibre 上游基线校验通过：$actual_commit"
