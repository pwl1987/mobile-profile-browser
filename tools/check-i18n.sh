#!/usr/bin/env bash
set -euo pipefail

# 中文优先检查（docs/standards/i18n.md）：
# README 与 docs/**/*.md 剥离代码块/行内代码后，中文占比须 ≥ 阈值。
# 例外文件登记在下方白名单。
#
# 统计方法与 locale 无关：CJK 基本区（U+4E00–U+9FFF）的 UTF-8 编码
# 首字节落在 0xE4–0xE9，且续字节在 0x80–0xBF，因此统计首字节即统计
# 汉字个数，不依赖 grep 的 collation。

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THRESHOLD_PERCENT=15

# 有意保留英文的文件（必须写明理由）
ALLOWLIST=(
  # 暂无
)

count_cjk() {
  { LC_ALL=C grep -o $'[\xe4-\xe9]' "$1" || true; } | wc -l | tr -d ' '
}

count_ascii_letters() {
  { LC_ALL=C grep -o '[A-Za-z]' "$1" || true; } | wc -l | tr -d ' '
}

strip_code_to() {
  # 移除 fenced code block（``` 或 ~~~），再移除行内 `code`
  sed -e '/^```/,/^```/d' -e '/^~~~/,/^~~~/d' "$1" | sed -e 's/`[^`]*`//g' > "$2"
}

is_allowed() {
  local rel="$1"
  for entry in "${ALLOWLIST[@]}"; do
    [[ "$rel" == "$entry" ]] && return 0
  done
  return 1
}

failed=0
checked=0
prose_file="$(mktemp)"
trap 'rm -f "$prose_file"' EXIT

while IFS= read -r file; do
  rel="${file#"$ROOT_DIR"/}"
  if is_allowed "$rel"; then
    echo "跳过（白名单）：$rel"
    continue
  fi
  checked=$((checked + 1))
  strip_code_to "$file" "$prose_file"
  cjk="$(count_cjk "$prose_file")"
  letters="$(count_ascii_letters "$prose_file")"
  total=$((cjk + letters))
  if (( total == 0 )); then
    echo "警告：$rel 无可统计文本（空或纯代码文档），视为通过"
    continue
  fi
  percent=$(( cjk * 100 / total ))
  if (( percent < THRESHOLD_PERCENT )); then
    echo "不合规：$rel 中文占比 ${percent}% < ${THRESHOLD_PERCENT}%（剔除代码块后 CJK=${cjk}, ASCII=${letters}）" >&2
    failed=1
  else
    echo "通过：$rel 中文占比 ${percent}%"
  fi
done < <(find "$ROOT_DIR/README.md" "$ROOT_DIR/docs" -name '*.md' -type f 2>/dev/null | sort)

echo "----"
echo "检查文件数：$checked，阈值：${THRESHOLD_PERCENT}%"

if (( failed )); then
  echo "中文优先检查未通过；如属有意保留英文，请将文件加入本脚本白名单并写明理由。" >&2
  exit 1
fi
echo "中文优先检查通过。"
