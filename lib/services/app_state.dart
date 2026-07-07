import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'onnx_engine.dart';
import 'tokenizer.dart';
import 'tts_inferencer.dart';
import 'voice_service.dart';

/// 全局 TTS 控制器，管理模型加载和合成
class TtsController extends ChangeNotifier {
  OnnxEngine? _engine;
  MossTokenizer? _tokenizer;
  Map<String, dynamic>? _manifest;
  Map<String, dynamic>? _codecMeta;
  bool _loading = false;
  String _status = '就绪';
  bool _loaded = false;

  OnnxEngine? get engine => _engine;
  MossTokenizer? get tokenizer => _tokenizer;
  Map<String, dynamic>? get manifest => _manifest;
  Map<String, dynamic>? get codecMeta => _codecMeta;
  bool get loaded => _loaded;
  bool get loading => _loading;
  String get status => _status;

  set status(String s) {
    _status = s;
    notifyListeners();
  }

  Future<void> loadModels() async {
    if (_loaded || _loading) return;
    _loading = true;
    status = '加载 ONNX 模型中...';

    try {
      _engine = OnnxEngine();
      await _engine!.load(bundleBasePath: 'assets/models');

      status = '加载分词器中...';
      _tokenizer = MossTokenizer();
      await _tokenizer!.load(assetPath: 'assets/models/MOSS-TTS-Nano-100M-ONNX/tokenizer.model');

      final raw = await rootBundle.loadString(
        'assets/models/MOSS-TTS-Nano-100M-ONNX/browser_poc_manifest.json',
      );
      _manifest = jsonDecode(raw) as Map<String, dynamic>;

      final cr = await rootBundle.loadString(
        'assets/models/MOSS-Audio-Tokenizer-Nano-ONNX/codec_browser_onnx_meta.json',
      );
      _codecMeta = jsonDecode(cr) as Map<String, dynamic>;

      _loaded = true;
      status = '就绪 · 模型加载完成';
    } catch (e) {
      status = '模型加载失败: $e';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// 执行 TTS 合成，返回 WAV 文件路径
  /// 模仿 Python OnnxTtsRuntime.synthesize：
  ///   1. 按 token 预算 (75) 切分文本
  ///   2. 每个块独立推理 → 解码
  ///   3. 立体声合并为单声道
  ///   4. 块间加 0.4s 静音拼接
  Future<String?> synthesize({
    required String voiceId,
    required String text,
    required Map<String, dynamic> params,
  }) async {
    if (!_loaded || _engine == null || _tokenizer == null) return null;

    final allVoices = await VoiceService.loadVoices();
    final voice = allVoices.where((v) => v.id == voiceId).firstOrNull;
    if (voice == null) return null;

    try {
      status = '合成中...';

      // 通过文件名匹配 manifest 中的 prompt_audio_codes
      final audioFileName = voice.file.split('/').last;
      final builtin = (_manifest!['builtin_voices'] as List?)?.where(
        (v) => (v['audio_file'] as String?) == audioFileName,
      ).firstOrNull;
      List<List<int>> promptCodes;
      if (builtin != null) {
        promptCodes = (builtin['prompt_audio_codes'] as List)
            .map((e) => (e as List).cast<int>())
            .toList();
      } else {
        status = '用户音色合成暂未支持';
        return null;
      }

      final inferencer = TtsInferencer(
        sessions: _engine!.sessions,
        ttsMeta: _engine!.ttsMetaRaw!,
        manifest: _manifest!,
        codecMeta: _codecMeta!,
      );

      // ── 1. 按 token 预算切分文本 ──
      const int maxTokens = 75;
      final textChunks =
          _tokenizer!.splitTextByTokenBudget(text, maxTokens: maxTokens);
      status = '分块 ${textChunks.length} 段 ...';

      // ── 2. 逐块推理 ──
      final allSamples = <double>[];
      const int sampleRate = 48000;
      final int pauseSamples = (sampleRate * 0.4).round(); // 0.4s 静音

      for (int ci = 0; ci < textChunks.length; ci++) {
        final chunk = textChunks[ci];
        if (chunk.trim().isEmpty) continue;

        if (textChunks.length > 1) {
          status = '分块 ${ci + 1}/${textChunks.length} ...';
        } else {
          status = '推理中...';
        }

        final textIds = _tokenizer!.encodeText(chunk);
        // buildRequest 用相同的 promptCodes（每次都用同一段参考音频）
        final req = inferencer.buildRequest(promptCodes, textIds);

        final frames = await inferencer.generate(req);
        if (frames.isEmpty) continue;

        status = '解码音频中 (${frames.length} 帧)...';
        final audioResult = await inferencer.decode(frames);
        if (audioResult.audioLength <= 0) continue;

        // 合并立体声为单声道
        final numChannels = audioResult.waveforms.length;
        for (int i = 0; i < audioResult.audioLength; i++) {
          double sum = 0;
          for (int c = 0; c < numChannels; c++) {
            if (i < audioResult.waveforms[c].length) {
              sum += audioResult.waveforms[c][i];
            }
          }
          allSamples.add(sum / numChannels);
        }

        // 块间加静音（最后一块不加）
        if (ci < textChunks.length - 1) {
          for (int i = 0; i < pauseSamples; i++) {
            allSamples.add(0.0);
          }
        }
      }

      if (allSamples.isEmpty) {
        status = '合成失败: 无音频输出';
        return null;
      }

      // ── 3. 写入 WAV ──
      final outDir = Directory('${Directory.systemTemp.path}/moss_tts_output');
      if (outDir.existsSync()) outDir.deleteSync(recursive: true);
      outDir.createSync();
      final wavPath = '${outDir.path}/output.wav';
      _writeWav(wavPath, allSamples, sampleRate);

      status = '合成完成';
      return wavPath;
    } catch (e) {
      status = '合成失败: $e';
      return null;
    }
  }

  void _writeWav(String path, List<double> samples, int sampleRate) {
    final file = File(path);
    final buffer = <int>[];
    void w32(int v) {
      buffer.add(v & 0xFF);
      buffer.add((v >> 8) & 0xFF);
      buffer.add((v >> 16) & 0xFF);
      buffer.add((v >> 24) & 0xFF);
    }
    void w16(int v) {
      buffer.add(v & 0xFF);
      buffer.add((v >> 8) & 0xFF);
    }
    buffer.addAll('RIFF'.codeUnits);
    w32(36 + samples.length * 2);
    buffer.addAll('WAVE'.codeUnits);
    buffer.addAll('fmt '.codeUnits);
    w32(16);
    w16(1);
    w16(1);
    w32(sampleRate);
    w32(sampleRate * 2);
    w16(2);
    w16(16);
    buffer.addAll('data'.codeUnits);
    w32(samples.length * 2);
    for (final s in samples) {
      final clamped = (s * 32767).clamp(-32768, 32767).toInt();
      w16(clamped & 0xFFFF);
    }
    file.writeAsBytesSync(buffer);
  }

  @override
  void dispose() {
    _engine?.dispose();
    super.dispose();
  }
}

/// InheritedWidget 访问控制器
class AppState extends InheritedWidget {
  final TtsController controller;
  const AppState({
    super.key,
    required this.controller,
    required super.child,
  });

  static TtsController of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppState>()!.controller;
  }

  @override
  bool updateShouldNotify(AppState old) => controller != old.controller;
}
