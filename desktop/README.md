# 桌面打包

MOSS-TTS-Nano 的桌面应用打包工具，支持 macOS 和 Windows。

## 目录结构

```
desktop/
├── electron/           ← Electron 桌面壳
│   ├── package.json    ← 依赖 & electron-builder 配置
│   ├── main.js         ← 主进程（服务管理、系统托盘、窗口）
│   ├── preload.js      ← 预加载脚本
│   ├── index.html      ← 启动页（内嵌 Web 界面前）
│   └── icons/          ← 应用图标
├── scripts/            ← 构建脚本
│   ├── build-server.sh ← PyInstaller 打包 Python 后端
│   ├── build-mac.sh    ← macOS 完整构建（.dmg）
│   └── build-win.bat   ← Windows 完整构建（.exe）
├── binaries/           ← 构建产物（gitignored）
└── dist/               ← Electron 安装包输出（gitignored）
```

## 构建流程

### macOS

```bash
# 一键构建（Python 后端 + Electron → .dmg）
bash desktop/scripts/build-mac.sh

# 或分步执行：
bash desktop/scripts/build-server.sh    # ① 打包 Python 后端
cd desktop/electron
npm install                              # ② 安装依赖
npm run build-mac                        # ③ 打包 .dmg
```

### Windows

```batch
REM 在 Windows 上执行：
desktop\scripts\build-win.bat
```

## 输出

| 平台 | 文件 | 说明 |
|------|------|------|
| macOS | `desktop/dist/MossTTS-1.0.0-mac-arm64.dmg` | 双击安装 |
| Windows | `desktop/dist/MossTTS-1.0.0-win-x64.exe` | NSIS 安装包 |

## 前置依赖

- **Node.js 18+** + npm
- **Python 3.12+** (推荐 pixi)
- **macOS**: Xcode Command Line Tools (`xcode-select --install`)
- **Windows**: 建议 [ImageMagick](https://imagemagick.org/)（图标生成）

## 开发模式

```bash
# 先手动启动 Python 后端
pixi run serve-onnx

# 再启动 Electron（会自动连 localhost:18083）
cd desktop/electron
npm install
npm start
```
