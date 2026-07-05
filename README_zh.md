# CTTS — MOSS-TTS-Nano 桌面客户端

CTTS (Charles TTS) 是基于 [**MOSS-TTS-Nano**](https://github.com/OpenMOSS/MOSS-TTS-Nano) 的 **Electron 桌面封装**，提供可直接安装使用的语音合成桌面应用，支持实时音色克隆，无需 GPU 即可在 CPU 上运行。

> **算法细节、模型训练、微调等内容**，请访问上游仓库：[OpenMOSS/MOSS-TTS-Nano](https://github.com/OpenMOSS/MOSS-TTS-Nano)

## 功能

- **跨平台桌面应用**（macOS / Windows / Linux）
- **音色管理** — 导入、筛选、搜索、试听音色
- **有声书模式** — 批量合成 TXT 章节
- **ONNX / PyTorch 推理引擎** 动态切换
- **动态背景** — 浮动光球 + 波浪动画
- **暗黑模式** 和 **国际化**（中文 / English）
- **可配置服务端口** — 再也不用担心端口冲突

## 快速开始（开发模式）

```bash
# 1. 启动 Python 推理服务
pixi run serve-onnx

# 2. 启动 Electron 应用
cd desktop/electron
npm install
npm start
```

应用会自动连接 `http://localhost:18083`。

## 构建安装包

参见 [desktop/README.md](desktop/README.md) 的构建说明。

## 许可证

本项目基于 **Apache 2.0** 许可证 — 详见 [LICENSE](LICENSE) 文件。

底层 MOSS-TTS-Nano 模型同样基于 Apache 2.0。
