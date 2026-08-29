#!/usr/bin/env bash
set -euo pipefail

# 准备 WebLibre 工作树：只修改工作树，不改变 vendor/weblibre 的 Git 历史。
# 该脚本必须针对固定上游 commit 幂等执行。

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WEBLIBRE_DIR="$ROOT_DIR/vendor/weblibre"
APP_DIR="$WEBLIBRE_DIR/apps/weblibre"
PUBSPEC="$APP_DIR/pubspec.yaml"
LOCKED_COMMIT="dc74be456efab51823bfc913114abb77af5c231c"

actual_commit="$(git -C "$WEBLIBRE_DIR" rev-parse HEAD)"
if [[ "$actual_commit" != "$LOCKED_COMMIT" ]]; then
  echo "错误：WebLibre 基线不匹配。期望 $LOCKED_COMMIT，实际 $actual_commit" >&2
  exit 1
fi

python3 - "$PUBSPEC" <<'PY'
from pathlib import Path
import sys

pubspec = Path(sys.argv[1])
text = pubspec.read_text(encoding="utf-8")

if "mobile_profile_domain:" in text or "mobile_profile_integration:" in text:
    if "mobile_profile_domain:" in text and "mobile_profile_integration:" in text:
        print("WebLibre Mobile Profile 依赖已存在，保持不变。")
        raise SystemExit(0)
    raise SystemExit("错误：发现不完整的 Mobile Profile 依赖配置。")

anchor = "  flutter_secure_storage: ^11.0.0\n"
addition = (
    "  mobile_profile_domain:\n"
    "    path: ../../../../packages/mobile_profile_domain\n"
    "  mobile_profile_integration:\n"
    "    path: ../../../../packages/mobile_profile_integration\n"
)

if anchor not in text:
    raise SystemExit("错误：WebLibre pubspec 锚点发生变化，拒绝盲目修改。")

pubspec.write_text(text.replace(anchor, anchor + addition, 1), encoding="utf-8")
print("已注入 Mobile Profile Domain/Integration 依赖。")
PY

mkdir -p "$APP_DIR/assets/quotes" "$APP_DIR/assets/sites" "$APP_DIR/assets/ublock"

echo "WebLibre 工作树准备完成。"
