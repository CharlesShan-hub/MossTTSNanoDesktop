#!/usr/bin/env bash
set -euo pipefail
# ─────────────────────────────────────────────────────────────────────────────
# build-server.sh — 用 PyInstaller 打包 Python 后端为单文件二进制
#
# 用法:
#   bash desktop/scripts/build-server.sh
#
# 输出:
#   desktop/binaries/<os>/moss-tts-server  (或 .exe)
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

PLATFORM="$(uname -s)"
case "$PLATFORM" in
  Darwin)  OS="mac";  BIN_NAME="moss-tts-server" ;;
  Linux)   OS="linux"; BIN_NAME="moss-tts-server" ;;
  MINGW*|MSYS*|CYGWIN*) OS="win"; BIN_NAME="moss-tts-server.exe" ;;
  *) echo "Unsupported platform: $PLATFORM"; exit 1 ;;
esac

OUTPUT_DIR="${REPO_ROOT}/desktop/binaries/${OS}"
mkdir -p "$OUTPUT_DIR"

echo "==> Building server binary for ${OS}..."
echo "    Output: ${OUTPUT_DIR}/${BIN_NAME}"

# 注意:
#   --onefile         = 单文件二进制
#   --add-data assets  = 附带音频资源
#   --hidden-import   = 确保 uvicorn 子模块不被遗漏
cd "$REPO_ROOT"

pip install pyinstaller

pyinstaller --clean --noconfirm \
  --name "moss-tts-server" \
  --onefile \
  --add-data "assets:assets" \
  --hidden-import "uvicorn.logging" \
  --hidden-import "uvicorn.loops" \
  --hidden-import "uvicorn.protocols.http.auto" \
  --hidden-import "uvicorn.protocols.websockets.auto" \
  --hidden-import "sentencepiece" \
  --hidden-import "onnxruntime" \
  --hidden-import "soundfile" \
  --distpath "$OUTPUT_DIR" \
  src/app.py

# 清理临时构建文件
rm -rf "${REPO_ROOT}/build" "${REPO_ROOT}/moss-tts-server.spec"

echo "==> Done! Binary: ${OUTPUT_DIR}/${BIN_NAME}"
echo "    Size: $(du -h "${OUTPUT_DIR}/${BIN_NAME}" | cut -f1)"
