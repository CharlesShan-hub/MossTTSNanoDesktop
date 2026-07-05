#!/usr/bin/env bash
set -euo pipefail
# ─────────────────────────────────────────────────────────────────────────────
# build-linux.sh — Linux 构建：先打包 Python 后端，再打包 Electron → .AppImage
#
# 前置条件:
#   1. Linux (x86_64)
#   2. 已安装 Node.js 18+
#   3. 已安装 Python 3.12+ 和 pip (建议 pixi)
#
# 用法:
#   bash desktop/scripts/build-linux.sh
#
# 输出:
#   desktop/dist/MossTTS-1.0.0-linux-x64.AppImage
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ELECTRON_DIR="${REPO_ROOT}/desktop/electron"

echo "==> Step 1: Build Python server binary"
bash "${SCRIPT_DIR}/build-server.sh"

echo ""
echo "==> Step 2: Install Electron dependencies"
cd "$ELECTRON_DIR"
npm install

echo ""
echo "==> Step 3: Build Electron → .AppImage"
npm run build-linux

echo ""
echo "==> Done! 安装包位于:"
ls -lh "${REPO_ROOT}/desktop/dist/"*.AppImage 2>/dev/null || echo "    (检查 ${REPO_ROOT}/desktop/dist/ 目录)"
