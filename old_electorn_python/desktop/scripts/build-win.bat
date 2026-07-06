@echo off
REM ─────────────────────────────────────────────────────────────────────────────
REM build-win.bat — Windows 构建：打包 Python 后端 + Electron → .exe
REM
REM 前置条件:
REM   1. Windows 10+
REM   2. 已安装 Node.js 18+
REM   3. 已安装 Python 3.12+ 和 pip (建议 pixi)
REM
REM 用法:
REM   desktop\scripts\build-win.bat
REM
REM 输出:
REM   desktop\dist\MossTTS-1.0.0-win-x64.exe (NSIS 安装包)
REM ─────────────────────────────────────────────────────────────────────────────

setlocal enabledelayedexpansion

set SCRIPT_DIR=%~dp0
set REPO_ROOT=%SCRIPT_DIR%..\..
set ELECTRON_DIR=%REPO_ROOT%\desktop\electron

echo === Step 1: Build Python server binary ===
call "%SCRIPT_DIR%build-server.bat"

echo.
echo === Step 2: Generate Icons ===
REM 将 SVG 转换为 PNG (Windows 上需要 ImageMagick 或其他工具)
REM 如果安装了 ImageMagick:
where magick >nul 2>nul
if %errorlevel% equ 0 (
    magick convert "%ELECTRON_DIR%\icons\icon.svg" -resize 256x256 "%ELECTRON_DIR%\icons\icon.png"
    magick convert "%ELECTRON_DIR%\icons\icon.svg" -resize 256x256 "%ELECTRON_DIR%\icons\icon.ico"
    magick convert "%ELECTRON_DIR%\icons\tray-icon.svg" -resize 22x22 "%ELECTRON_DIR%\icons\tray-icon.png"
) else (
    echo Warning: ImageMagick not found. Create icon.png/icon.ico manually.
    echo Download: https://imagemagick.org/script/download.php
)

echo.
echo === Step 3: Install Electron dependencies ===
cd /d "%ELECTRON_DIR%"
call npm install

echo.
echo === Step 4: Build Electron → .exe ===
call npm run build-win

echo.
echo === Done! ===
echo 安装包位于: %REPO_ROOT%\desktop\dist\
