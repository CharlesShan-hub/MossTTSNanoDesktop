# MOSS-TTS-Nano Flutter 重构

这是 MOSS-TTS-Nano 的 Flutter 全栈重构版本，不再依赖 Python 后端。

## 项目结构

```
moss_tts_nano_flutter/
├── lib/
│   ├── main.dart                 # 应用入口
│   ├── models/                   # 数据模型
│   │   ├── voice.dart            # 音色数据模型
│   │   ├── generation_params.dart# 生成参数模型
│   │   └── app_settings.dart     # 应用设置模型
│   ├── providers/                # 状态管理
│   │   ├── app_providers.dart    # 提供器集合
│   │   └── theme_provider.dart   # 主题管理
│   ├── services/                 # 核心服务
│   │   ├── tts_service.dart      # 语音合成服务（含 ONNX 推理）
│   │   ├── voice_manager.dart    # 音色管理服务
│   │   └── audio_player_service.dart # 音频播放服务
│   ├── ui/                       # UI 层
│   │   ├── pages/                # 页面
│   │   │   ├── home_page.dart    # 首页（底部导航）
│   │   │   ├── single_generate_page.dart # 单次生成页
│   │   │   ├── audiobook_page.dart     # 有声书页
│   │   │   ├── voices_page.dart         # 音色管理页
│   │   │   └── settings_page.dart       # 设置页
│   │   ├── widgets/              # 自定义组件
│   │   │   ├── voice_card.dart   # 音色卡片
│   │   │   ├── animated_background.dart # 动态背景
│   │   │   └── parameter_slider.dart # 参数滑块
│   │   └── theme/                # 主题配置
│   │       └── app_theme.dart    # 应用主题
│   └── l10n/                     # 国际化
│       └── app_localizations.dart
├── assets/                       # 资源文件
│   └── i18n/                     # 国际化文本
│       ├── en.json               # 英文
│       └── zh.json               # 中文
├── pubspec.yaml                  # 项目配置
└── README_FLUTTER.md            # 本文件
```

## 已完成的功能

✅ 基础项目架构和配置  
✅ 数据模型层（Voice, GenerationParams, AppSettings）  
✅ 状态管理（Provider）  
✅ 服务层骨架（TtsService, VoiceManager, AudioPlayerService）  
✅ UI 层（所有 4 个主要页面）  
✅ 动态背景动画  
✅ 主题系统（亮色/暗黑模式）  
✅ 国际化框架（中/英文）  
✅ 设置持久化（SharedPreferences）  

## 待完成的核心功能

⚠️ **核心功能 - ONNX Runtime 推理集成**  
这是项目最重要的部分，需要实现：

1. **ONNX Runtime Flutter 集成**
   - 集成 ONNX Runtime 到 Flutter（使用 `onnxruntime` 包或 FFI）
   - 实现跨平台支持（Windows, macOS, Linux, Android, iOS）

2. **模型加载和管理**
   - 从 Hugging Face 下载模型（OpenMOSS/MOSS-TTS-Nano-ONNX）
   - 模型缓存管理
   - 模型文件完整性校验

3. **完整 TTS 推理流程**
   - SentencePiece Tokenization
   - 参考音频编码（音色克隆）
   - TTS 模型推理生成
   - 音频解码（WAV 输出）

4. **UI 功能完善**
   - 完整的生成流程（状态反馈）
   - 文件保存功能
   - 有声书批量生成
   - 系统托盘（桌面端）

## 开始使用

### 前置条件

- Flutter SDK 3.0+
- Dart 3.0+
- 各平台开发工具：
  - Windows: Visual Studio
  - macOS: Xcode
  - Linux: 相应的编译工具
  - Android: Android Studio
  - iOS: Xcode

### 安装依赖

```bash
flutter pub get
```

### 运行应用

```bash
# 桌面端
flutter run -d windows  # 或 macos, linux

# 移动端
flutter run -d <device-id>
```

### 构建发布版本

```bash
# Windows
flutter build windows --release

# macOS
flutter build macos --release

# Android
flutter build apk --release

# iOS
flutter build ios --release
```

## ONNX 推理实现指南

### 推荐方案

**方案 1：使用 `onnxruntime` 包（推荐用于快速实现）**
```yaml
dependencies:
  onnxruntime: ^1.1.0
```

**方案 2：使用 FFI 调用原生 ONNX Runtime（推荐用于最佳性能）**
- 为各平台编写原生插件
- 直接调用 ONNX Runtime C API

**方案 3：使用 `flutter_rust_bridge` 调用 Rust 实现**
- 用 Rust 实现完整的 TTS 推理逻辑
- 通过 FFI 与 Flutter 通信

### 关键文件需要重写

1. `lib/services/tts_service.dart`
   - 实现真实的模型加载
   - 实现真实的推理流程
   - 连接音频播放器

2. 新增 `lib/services/onnx_engine.dart`
   - 封装 ONNX Runtime 操作
   - 处理模型输入输出
   - 优化推理性能

## 贡献指南

欢迎提交 Issue 和 Pull Request！

## 许可证

Apache-2.0
