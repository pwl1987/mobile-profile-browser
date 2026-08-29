#!/usr/bin/env bash
set -euo pipefail

# M1 目标：先证明固定 WebLibre Android 基线可以重复构建出 Debug APK。
# 业务层与 Provider 注入在基线 Gate 通过后再接入。

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WEBLIBRE_DIR="$ROOT_DIR/vendor/weblibre"
APP_DIR="$WEBLIBRE_DIR/apps/weblibre"
LOCKED_COMMIT="dc74be456efab51823bfc913114abb77af5c231c"

actual_commit="$(git -C "$WEBLIBRE_DIR" rev-parse HEAD)"
if [[ "$actual_commit" != "$LOCKED_COMMIT" ]]; then
  echo "错误：WebLibre 基线不匹配。期望 $LOCKED_COMMIT，实际 $actual_commit" >&2
  exit 1
fi

# 上游把若干可选静态资源目录声明为 Flutter assets；空目录不会进入 Git，CI 中显式创建。
mkdir -p "$APP_DIR/assets/quotes" "$APP_DIR/assets/sites" "$APP_DIR/assets/ublock"

echo "WebLibre M1 纯上游工作树准备完成：$LOCKED_COMMIT"
