#!/usr/bin/env bash
set -euo pipefail

# 在不修改 WebLibre 子模块 Git 历史的前提下，把本项目维护的补丁应用到
# 本地工作树。适用于开发环境与 CI；所有补丁都必须可审计、可重复应用。

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WEBLIBRE_DIR="$ROOT_DIR/vendor/weblibre"
PATCH_DIR="$ROOT_DIR/patches/weblibre"

if [[ ! -d "$WEBLIBRE_DIR/.git" ]]; then
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
  elif git diff --quiet --exit-code -- apps/weblibre/pubspec.yaml; then
    echo "补丁无法应用：$(basename "$patch")" >&2
    exit 1
  else
    # 已经应用过时，允许重复执行；若工作树存在其它相关改动则拒绝继续，
    # 避免把用户修改误判成“补丁已应用”。
    if git diff -- apps/weblibre/pubspec.yaml | grep -q 'mobile_profile_domain'; then
      echo "补丁已应用：$(basename "$patch")"
    else
      echo "补丁存在冲突：$(basename "$patch")" >&2
      exit 1
    fi
  fi
done
