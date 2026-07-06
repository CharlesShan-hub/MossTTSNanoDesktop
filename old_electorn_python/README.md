# CTTS — Desktop GUI for MOSS-TTS-Nano

CTTS (Charles TTS) is an **Electron desktop wrapper** for [**MOSS-TTS-Nano**](https://github.com/OpenMOSS/MOSS-TTS-Nano), an open-source multilingual tiny speech generation model (0.1B parameters) capable of real-time voice cloning on CPU.

> **For algorithm details, model training, and finetuning**, visit the upstream repo: [OpenMOSS/MOSS-TTS-Nano](https://github.com/OpenMOSS/MOSS-TTS-Nano)

## Features

- **Cross-platform desktop app** (macOS / Windows / Linux)
- **Voice management** — import, filter, search, preview voices
- **Audiobook mode** — batch generate from TXT chapters
- **ONNX / PyTorch runtime** switching without restart
- **Animated background** with floating orbs and waves
- **Dark mode** and **i18n** (中文 / English)
- **Configurable server port** — no port conflict worries

## Quick Start (Development)

```bash
# 1. Start the Python inference server
pixi run serve-onnx

# 2. Start the Electron app
cd desktop/electron
npm install
npm start
```

The app will auto-connect to `http://localhost:18083`.

## Build (Packaged App)

See [desktop/README.md](desktop/README.md) for build instructions.

## License

This project is licensed under the **Apache 2.0** license — see the [LICENSE](LICENSE) file.

The underlying MOSS-TTS-Nano model is also Apache 2.0.
