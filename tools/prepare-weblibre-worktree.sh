#!/usr/bin/env bash
set -euo pipefail

# 准备 WebLibre 工作树：M1 只验证纯上游 Android 基线，不注入本项目业务包。
# 业务层将在 APK 基线成立后，通过独立集成阶段接入。

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WEBLIBRE_DIR="$ROOT_DIR/vendor/weblibre"
APP_DIR="$WEBLIBRE_DIR/apps/weblibre"
LOCKED_COMMIT="dc74be456efab51823bfc913114abb77af5c231c"

actual_commit="$(git -C "$WEBLIBRE_DIR" rev-parse HEAD)"
if [[ "$actual_commit" != "$LOCKED_COMMIT" ]]; then
  echo "错误：WebLibre 基线不匹配。期望 $LOCKED_COMMIT，实际 $actual_commit" >&2
  exit 1
fi

# 上游仓库通过空目录承载可选静态资源；确保 Flutter 资源声明不会因缺目录失败。
mkdir -p "$APP_DIR/assets/quotes" "$APP_DIR/assets/sites" "$APP_DIR/assets/ublock"

echo "WebLibre M1 纯上游工作树准备完成：$LOCKED_COMMIT"
