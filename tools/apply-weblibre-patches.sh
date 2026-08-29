#!/usr/bin/env bash
set -euo pipefail

# 在不修改 WebLibre 子模块 Git 历史的前提下，把本项目维护的补丁应用到
# 本地工作树。适用于开发环境与 CI；所有补丁都必须可审计、可重复应用。

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WEBLIBRE_DIR="$ROOT_DIR/vendor/weblibre"
PATCH_DIR="$ROOT_DIR/patches/weblibre"

if ! git -C "$WEBLIBRE_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "错误：WebLibre 子模块未初始化：$WEBLIBRE_DIR" >&2
  exit 1
fi

if [[ ! -d "$PATCH_DIR" ]]; then
  echo "错误：未找到 WebLibre 补丁目录：$PATCH_DIR" >&2
  exit 1
fi

cd "$WEBLIBRE_DIR"

for patch in "$PATCH_DIR"/*.patch; do
  [[ -e "$patch" ]] || continue
  if git apply --check "$patch" >/dev/null 2>&1; then
    git apply "$patch"
    echo "已应用补丁：$(basename "$patch")"
    continue
  fi

  # 对已经应用的补丁使用反向检查判断，而不是依赖某个文件关键词。
  if git apply --reverse --check "$patch" >/dev/null 2>&1; then
    echo "补丁已应用：$(basename "$patch")"
    continue
  fi

  echo "补丁存在冲突或基线不匹配：$(basename "$patch")" >&2
  echo "不要继续构建，请先检查 WebLibre 锁定 commit 与补丁版本。" >&2
  exit 1
done
