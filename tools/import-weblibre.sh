#!/usr/bin/env bash
set -euo pipefail

# 将指定 WebLibre commit 导入本项目的 vendor/weblibre 快照。
# 注意：此脚本只在开发环境执行，不允许在运行时从网络下载源码。
# 当前锁定版本来自 docs/architecture/upstream-lock.md。

UPSTREAM_URL="https://github.com/FaFre/WebLibre.git"
UPSTREAM_COMMIT="dc74be456efab51823bfc913114abb77af5c231c"
VENDOR_DIR="vendor/weblibre"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

if ! command -v git >/dev/null 2>&1; then
  echo "错误：未找到 git。" >&2
  exit 1
fi

if [[ -e "$VENDOR_DIR" ]]; then
  echo "错误：$VENDOR_DIR 已存在。请先人工确认后再执行。" >&2
  exit 1
fi

echo "正在获取 WebLibre：$UPSTREAM_COMMIT"
git -C "$TEMP_DIR" init -q
git -C "$TEMP_DIR" remote add upstream "$UPSTREAM_URL"
git -C "$TEMP_DIR" fetch --quiet --depth 1 upstream "$UPSTREAM_COMMIT"
git -C "$TEMP_DIR" checkout -q --detach "$UPSTREAM_COMMIT"

mkdir -p "$VENDOR_DIR"
cp -a "$TEMP_DIR"/. "$VENDOR_DIR"/
rm -rf "$VENDOR_DIR/.git" "$VENDOR_DIR/.gitmodules"

cat > "$VENDOR_DIR/UPSTREAM.md" <<EOF
# WebLibre 上游快照

- 上游仓库：$UPSTREAM_URL
- 锁定 Commit：$UPSTREAM_COMMIT
- 导入方式：开发期固定快照
- 说明：本目录是上游源码快照，不在应用运行时动态更新。

请勿直接在此目录实现 Mobile Profile 业务逻辑。业务能力应位于本项目自己的 Domain/Adapter 层。
EOF

echo "WebLibre 快照导入完成：$VENDOR_DIR"
echo "下一步：执行 git diff，检查许可证、第三方依赖和构建文件，然后再开始适配。"
