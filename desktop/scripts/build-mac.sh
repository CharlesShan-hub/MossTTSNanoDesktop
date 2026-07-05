#!/usr/bin/env bash
set -euo pipefail
# ─────────────────────────────────────────────────────────────────────────────
# build-mac.sh — macOS 构建：先打包 Python 后端，再打包 Electron → .dmg
#
# 前置条件:
#   1. macOS (Apple Silicon)
#   2. 已安装 Node.js 18+
#   3. 已安装 Python 3.12+ 和 pixi
#
# 用法:
#   bash desktop/scripts/build-mac.sh
#
# 输出:
#   desktop/dist/MossTTS-1.0.0-mac-arm64.dmg
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ELECTRON_DIR="${REPO_ROOT}/desktop/electron"

echo "==> Step 1: Build Python server binary"
bash "${SCRIPT_DIR}/build-server.sh"

echo ""
echo "==> Step 2: Generate icons"
# SVG → PNG (用于 Electron 图标)
if command -v sips &>/dev/null; then
  # macOS 上 SVG 需要先转 PNG
  echo "    Generating icon.png from icon.svg..."
  # 用 rsvg-convert 如果可用, 否则直接复制 SVG
  if command -v rsvg-convert &>/dev/null; then
    rsvg-convert -w 512 -h 512 "${ELECTRON_DIR}/icons/icon.svg" -o "${ELECTRON_DIR}/icons/icon.png"
    rsvg-convert -w 1024 -h 1024 "${ELECTRON_DIR}/icons/icon.svg" -o "${ELECTRON_DIR}/icons/icon-1024.png"
  else
    echo "    Warning: rsvg-convert not found, installing librsvg..."
    brew install librsvg
    rsvg-convert -w 512 -h 512 "${ELECTRON_DIR}/icons/icon.svg" -o "${ELECTRON_DIR}/icons/icon.png"
    rsvg-convert -w 1024 -h 1024 "${ELECTRON_DIR}/icons/icon.svg" -o "${ELECTRON_DIR}/icons/icon-1024.png"
  fi

  # PNG → ICNS (macOS 图标)
  echo "    Generating icon.icns..."
  mkdir -p "${ELECTRON_DIR}/icons/icns.iconset"
  for size in 16 32 64 128 256 512 1024; do
    sips -z $size $size "${ELECTRON_DIR}/icons/icon.png" \
      --out "${ELECTRON_DIR}/icons/icns.iconset/icon_${size}x${size}.png" &>/dev/null || true
  done
  iconutil -c icns "${ELECTRON_DIR}/icons/icns.iconset" -o "${ELECTRON_DIR}/icons/icon.icns"
  rm -rf "${ELECTRON_DIR}/icons/icns.iconset"

  # Tray PNG
  echo "    Generating tray-icon.png..."
  if command -v rsvg-convert &>/dev/null; then
    rsvg-convert -w 22 -h 22 "${ELECTRON_DIR}/icons/tray-icon.svg" -o "${ELECTRON_DIR}/icons/tray-icon.png"
  fi
fi

echo ""
echo "==> Step 3: Install Electron dependencies"
cd "$ELECTRON_DIR"
npm install

echo ""
echo "==> Step 4: Build Electron → .dmg"
npm run build-mac

echo ""
echo "==> Done! 安装包位于:"
ls -lh "${REPO_ROOT}/desktop/dist/"*.dmg 2>/dev/null || echo "    (检查 ${REPO_ROOT}/desktop/dist/ 目录)"
