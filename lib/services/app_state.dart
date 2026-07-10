import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onnxruntime_v2/onnxruntime_v2.dart';

import 'onnx_engine.dart';
import 'tokenizer.dart';
import 'tts_inferencer.dart';
import 'tts_server.dart';
import 'voice_service.dart';
import 'settings_service.dart';

/// 全局 TTS 控制器，管理模型加载和合成
class TtsController extends ChangeNotifier {
  OnnxEngine? _engine;
  MossTokenizer? _tokenizer;
  Map<String, dynamic>? _manifest;
  Map<String, dynamic>? _codecMeta;
  bool _loading = false;
  String _status = '就绪';
  bool _loaded = false;
  TtsServer? _apiServer;

  OnnxEngine? get engine => _engine;
  MossTokenizer? get tokenizer => _tokenizer;
  Map<String, dynamic>? get manifest => _manifest;
  Map<String, dynamic>? get codecMeta => _codecMeta;
  bool get loaded => _loaded;
  bool get loading => _loading;
  String get status => _status;
  TtsServer? get apiServer => _apiServer;
  bool get apiRunning => _apiServer?.isRunning ?? false;

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
      // 自动启动 API 服务
      if (SettingsService.apiEnabled) {
        await startApiServer();
      }
    } catch (e, st) {
      debugPrint('[TtsController] 加载失败: $e\n$st');
      status = '模型加载失败: $e';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// 启动 API 服务器
  Future<void> startApiServer({int? port}) async {
    if (_apiServer != null) return;
    _apiServer = TtsServer(this);
    try {
      await _apiServer!.start(port: port);
      status = 'API 服务运行中 :${_apiServer!.port}';
      notifyListeners();
    } catch (e) {
      status = 'API 服务启动失败: $e';
      _apiServer = null;
      notifyListeners();
    }
  }

  /// 停止 API 服务器
  Future<void> stopApiServer() async {
    if (_apiServer == null) return;
    await _apiServer!.stop();
    _apiServer = null;
    status = 'API 服务已停止';
    notifyListeners();
  }

  int _int(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.round();
    return v as int;
  }

  int _read1dInt(dynamic val) {
    if (val is int) return val;
    if (val is double) return val.round();
    if (val is List) return _firstInt(val);
    return 0;
  }

  int _firstInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is List) return _firstInt(v[0]);
    return 0;
  }

  Map<String, OrtValue> _named(List<String> names, List<OrtValue?>? outs) {
    final result = <String, OrtValue>{};
    if (outs == null) return result;
    for (var i = 0; i < names.length && i < outs.length; i++) {
      final v = outs[i];
      if (v != null) result[names[i]] = v;
    }
    return result;
  }

  List<List<List<int>>> _to3dInt(dynamic val) {
    final result = <List<List<int>>>[];
    if (val is List) {
      for (final v1 in val) {
        if (v1 is List) {
          final row = <List<int>>[];
          for (final v2 in v1) {
            if (v2 is List) {
              row.add(v2.map((e) => (e as num).toInt()).toList());
            } else if (v2 is int) {
              row.add([v2]);
            }
          }
          result.add(row);
        }
      }
    }
    return result;
  }

  /// 将音频文件编码为 prompt_audio_codes（用于非内置音色）。
  /// 替代 Python 的 encode_reference_audio。
  Future<List<List<int>>?> encodeAudioToCodes(String assetPath) async {
    if (_engine == null || _codecMeta == null) return null;
    try {
      // 1. 加载并解析 WAV
      final byteData = await rootBundle.load(assetPath);
      final data = byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);
      if (data.length < 44) return null;

      // 调试：打印 WAV 头前 44 字节
      final headerHex = data.take(44).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
      debugPrint('[encode] header: $headerHex');

      final sampleRate = byteData.getUint32(24, Endian.little);
      final channels = byteData.getUint16(22, Endian.little);
      final bitsPerSample = byteData.getUint16(34, Endian.little);
      // 找到 data chunk
      int dataStart = 44;
      for (int i = 44; i < data.length - 4; i++) {
        if (data[i] == 0x64 && data[i + 1] == 0x61 && data[i + 2] == 0x74 && data[i + 3] == 0x61) {
          dataStart = i + 8;
          break;
        }
      }
      final rawSamples = data.sublist(dataStart);
      debugPrint('[encode] rate=$sampleRate ch=$channels bits=$bitsPerSample dataLen=${rawSamples.length}');

      // 2. 转 float32 PCM，声道合并
      Float32List pcm;
      if (bitsPerSample == 16) {
        final raw = Int16List.view(rawSamples.buffer, 0, rawSamples.length ~/ 2);
        if (channels == 1) {
          pcm = Float32List(raw.length);
          for (int i = 0; i < raw.length; i++) pcm[i] = raw[i] / 32768.0;
        } else {
          final frameCount = raw.length ~/ channels;
          pcm = Float32List(frameCount);
          for (int i = 0; i < frameCount; i++) {
            double sum = 0;
            for (int c = 0; c < channels; c++) sum += raw[i * channels + c] / 32768.0;
            pcm[i] = sum / channels; // stereo → mono
          }
        }
      } else if (bitsPerSample == 32) {
        // float32 WAV
        pcm = Float32List.view(rawSamples.buffer, 0, rawSamples.length ~/ 4);
        if (channels > 1) {
          final frameCount = pcm.length ~/ channels;
          final mono = Float32List(frameCount);
          for (int i = 0; i < frameCount; i++) {
            double sum = 0;
            for (int c = 0; c < channels; c++) sum += pcm[i * channels + c];
            mono[i] = sum / channels;
          }
          pcm = mono;
        }
      } else {
        return null; // 不支持的格式
      }

      // 3. 重采样到 48000
      final targetRate = _int(_codecMeta!['codec_config']['sample_rate']);
      Float32List resampled;
      if (sampleRate != targetRate) {
        final ratio = targetRate / sampleRate;
        final newLen = (pcm.length * ratio).round();
        resampled = Float32List(newLen);
        for (int i = 0; i < newLen; i++) {
          final src = i / ratio;
          final src0 = src.floor();
          final src1 = (src0 + 1).clamp(0, pcm.length - 1);
          final frac = src - src0;
          resampled[i] = pcm[src0] * (1 - frac) + pcm[src1] * frac;
        }
      } else {
        resampled = pcm;
      }

      // 4. 运行 codec_encode — 模型期望 [1, 2, samples] 立体声
      final codecSession = _engine!.sessions['codec_encode'];
      if (codecSession == null) { debugPrint('[encode] codec_encode session not found'); return null; }
      final wavLen = resampled.length;
      // 单声道复制到双声道
      final stereo = Float32List(2 * wavLen);
      for (int i = 0; i < wavLen; i++) {
        stereo[i] = resampled[i];
        stereo[wavLen + i] = resampled[i];
      }
      final wavTensor = OrtValueTensor.createTensorWithDataList(stereo, [1, 2, wavLen]);
      final lenTensor = OrtValueTensor.createTensorWithDataList(Int32List.fromList([wavLen]), [1]);
      final ropts = OrtRunOptions();
      try {
        final out = await _engine!.sessions['codec_encode']!.runAsync(ropts, {
          'waveform': wavTensor, 'input_lengths': lenTensor,
        });
        final names = _engine!.sessions['codec_encode']!.outputNames;
        final named = _named(names, out);
        final codesVal = named['audio_codes']!.value;
        final codeLengthVal = named['audio_code_lengths']!.value;
        final codeLength = _read1dInt(codeLengthVal);
        final nQ = _int(_codecMeta!['codec_config']['num_quantizers']);

        // codesVal shape: [1, frames, num_quantizers]
        final codes3d = _to3dInt(codesVal);
        if (codes3d.isEmpty || codes3d[0].isEmpty) return null;

        final result = <List<int>>[];
        for (int f = 0; f < codeLength && f < codes3d[0].length; f++) {
          final frame = <int>[];
          for (int q = 0; q < nQ && q < codes3d[0][f].length; q++) {
            frame.add(codes3d[0][f][q]);
          }
          result.add(frame);
        }
        return result;
      } finally { wavTensor.release(); lenTensor.release(); ropts.release(); }
    } catch (e) {
      debugPrint('[encode] error: $e');
      return null;
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

      // 通过文件名匹配内置音色的 prompt_audio_codes
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
        // 非内置音色：运行时编码
        status = '编码音色中...';
        final codes = await encodeAudioToCodes(voice.file);
        if (codes == null || codes.isEmpty) {
          status = '音色编码失败: ${voice.file}';
          return null;
        }
        promptCodes = codes;
      }

      // 加载预计算的随机值（seed=1234，与 numpy PCG64 一致）
      List<List<double>> randomValues = [];
      try {
        final raw = await rootBundle.loadString('assets/random_values.json');
        final list = jsonDecode(raw) as List;
        randomValues = list.map((e) => (e as List).map((v) => (v as num).toDouble()).toList()).toList();
      } catch (_) {}

      final inferencer = TtsInferencer(
        sessions: _engine!.sessions,
        ttsMeta: _engine!.ttsMetaRaw!,
        manifest: _manifest!,
        codecMeta: _codecMeta!,
        precomputed: randomValues.isNotEmpty ? randomValues : null,
      );

      // ── 1. 按 token 预算切分文本 ──
      const int maxTokens = 150;
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
    _apiServer?.stop();
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
