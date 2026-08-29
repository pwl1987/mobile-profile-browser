#!/usr/bin/env bash
set -euo pipefail

# 准备 WebLibre M1 工作树：只验证固定的、可复现的上游 Android 基线。
# 业务层在 APK 基线稳定后再接入，避免把基线问题与产品代码问题混在一起。

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WEBLIBRE_DIR="$ROOT_DIR/vendor/weblibre"
APP_DIR="$WEBLIBRE_DIR/apps/weblibre"
LOCKED_COMMIT="b4721ae6b34aea65e589417b3a64244cc14dbb91"

actual_commit="$(git -C "$WEBLIBRE_DIR" rev-parse HEAD)"
if [[ "$actual_commit" != "$LOCKED_COMMIT" ]]; then
  echo "错误：WebLibre 基线不匹配。期望 $LOCKED_COMMIT，实际 $actual_commit" >&2
  exit 1
fi

# 上游把若干可选静态资源目录声明为 Flutter assets；空目录不会进入 Git，CI 中显式创建。
mkdir -p "$APP_DIR/assets/quotes" "$APP_DIR/assets/sites" "$APP_DIR/assets/ublock"

echo "WebLibre M1 纯上游工作树准备完成：$LOCKED_COMMIT"
