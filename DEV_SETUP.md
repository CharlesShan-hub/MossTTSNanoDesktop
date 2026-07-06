# 开发环境设置指南

## 目录
1. [Flutter 安装](#flutter-安装)
2. [项目开发](#项目开发)

---

## Flutter 安装

### Windows 安装步骤

#### 方法 1：官方安装包（推荐）
1. 访问 https://flutter.dev/docs/get-started/install/windows
2. 下载 Flutter SDK zip 压缩包
3. 解压到 `C:\flutter` 或其他位置
4. 配置环境变量：
   - 右键「此电脑」→「属性」→「高级系统设置」→「环境变量」
   - 在用户变量的 `Path` 中添加：`C:\flutter\bin`
5. 重新打开 PowerShell，运行：
   ```powershell
   flutter --version
   flutter doctor
   ```

#### 方法 2：使用 winget
```powershell
winget install Flutter.Flutter
```

### macOS/Linux 安装
请访问 https://flutter.dev/docs/get-started/install 查看相应平台的说明。

---

## 项目开发

### 1. 安装 Flutter 依赖
```bash
flutter pub get
```

### 2. 运行应用
```bash
# Windows
flutter run -d windows

# macOS
flutter run -d macos

# Linux
flutter run -d linux

# Android
flutter run -d <device-id>
```

### 3. 检查 Flutter 环境
```bash
flutter doctor
```

### 4. 常见问题

**问题：Windows 上找不到 Visual Studio**
- 下载安装 Visual Studio 2022（Community 免费版即可）
- 安装时勾选「使用 C++ 的桌面开发」工作负载

**问题：Android 工具链缺失**
- 下载安装 Android Studio
- 安装 Android SDK 28 或以上

---

## 开发工作流

1. 安装 Flutter SDK（首次）
2. 运行 `flutter pub get` 安装依赖
3. 运行 `flutter run -d windows` 启动应用
