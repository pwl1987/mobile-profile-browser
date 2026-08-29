#!/usr/bin/env bash
set -euo pipefail

# 在不修改 WebLibre 子模块 Git 历史的前提下，把本项目维护的最小集成改动
# 应用到本地工作树。所有修改都必须基于固定上游 commit，并且幂等、可审计。

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WEBLIBRE_DIR="$ROOT_DIR/vendor/weblibre"
PUBSPEC="$WEBLIBRE_DIR/apps/weblibre/pubspec.yaml"
EXPECTED_COMMIT="dc74be456efab51823bfc913114abb77af5c231c"

if ! git -C "$WEBLIBRE_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "错误：WebLibre 子模块未初始化：$WEBLIBRE_DIR" >&2
  exit 1
fi

ACTUAL_COMMIT="$(git -C "$WEBLIBRE_DIR" rev-parse HEAD)"
if [[ "$ACTUAL_COMMIT" != "$EXPECTED_COMMIT" ]]; then
  echo "错误：WebLibre 基线不匹配：$ACTUAL_COMMIT" >&2
  echo "期望基线：$EXPECTED_COMMIT" >&2
  exit 1
fi

if [[ ! -f "$PUBSPEC" ]]; then
  echo "错误：未找到 WebLibre 应用 pubspec：$PUBSPEC" >&2
  exit 1
fi

python3 - "$PUBSPEC" <<'PY'
from pathlib import Path
import sys

pubspec = Path(sys.argv[1])
text = pubspec.read_text(encoding="utf-8")
anchor = "  flutter_secure_storage: ^11.0.0\n"
insert = (
    "  mobile_profile_domain:\n"
    "    path: ../../../../packages/mobile_profile_domain\n"
    "  mobile_profile_integration:\n"
    "    path: ../../../../packages/mobile_profile_integration\n"
)

if "  mobile_profile_domain:\n" in text or "  mobile_profile_integration:\n" in text:
    if insert in text:
        print("Mobile Profile 依赖已应用")
        raise SystemExit(0)
    raise SystemExit("错误：检测到部分集成依赖，拒绝继续以避免形成半配置状态")

if anchor not in text:
    raise SystemExit("错误：WebLibre pubspec 锚点发生变化，拒绝自动修改")

pubspec.write_text(text.replace(anchor, anchor + insert, 1), encoding="utf-8")
print("已应用 Mobile Profile 依赖集成")
PY
