import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'onnx_engine.dart';
import 'tokenizer.dart';
import 'tts_inferencer.dart';
import 'tts_server.dart';
import 'voice_service.dart';
import 'settings_service.dart';
import 'audio_encoder.dart';
import 'wav_writer.dart';
import 'i18n_service.dart';

/// 全局 TTS 控制器，管理模型加载和合成
class TtsController extends ChangeNotifier {
  OnnxEngine? _engine;
  MossTokenizer? _tokenizer;
  Map<String, dynamic>? _manifest;
  Map<String, dynamic>? _codecMeta;
  bool _loading = false;
  String _status = '';
  bool _loaded = false;
  TtsServer? _apiServer;

  OnnxEngine? get engine => _engine;
  MossTokenizer? get tokenizer => _tokenizer;
  Map<String, dynamic>? get manifest => _manifest;
  Map<String, dynamic>? get codecMeta => _codecMeta;
  bool get loaded => _loaded;
  bool get loading => _loading;
  String get status => _status.isNotEmpty ? _status : I18n.t('app.ready');
  TtsServer? get apiServer => _apiServer;
  bool get apiRunning => _apiServer?.isRunning ?? false;

  TtsController() {
    I18n.notifier.addListener(_onLangChanged);
  }

  void _onLangChanged() {
    // 语言切换后，清除静态状态使其重新翻译
    if (_loading || _status.isEmpty) return;
    _status = '';
    notifyListeners();
  }

  set status(String s) {
    _status = s;
    notifyListeners();
  }

  Future<void> loadModels() async {
    if (_loaded || _loading) return;
    _loading = true;
    status = I18n.t('app.loadingModel');

    try {
      _engine = OnnxEngine();
      await _engine!.load(bundleBasePath: 'assets/models');

      status = I18n.t('app.loadingTokenizer');
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
      status = I18n.t('app.modelReady');
      // 自动启动 API 服务
      if (SettingsService.apiEnabled) {
        await startApiServer();
      }
    } catch (e, st) {
      debugPrint('[TtsController] 加载失败: $e\n$st');
      status = I18n.t('app.modelFailed', params: {'e': '$e'});
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
      status = I18n.t('app.apiRunning', params: {'port': '${_apiServer!.port}'});
      notifyListeners();
    } catch (e) {
      status = I18n.t('app.apiFailed', params: {'e': '$e'});
      _apiServer = null;
      notifyListeners();
    }
  }

  /// 停止 API 服务器
  Future<void> stopApiServer() async {
    if (_apiServer == null) return;
    await _apiServer!.stop();
    _apiServer = null;
    status = I18n.t('app.apiStopped');
    notifyListeners();
  }

  /// 执行 TTS 合成，返回 WAV 文件路径
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
      status = I18n.t('app.synthesizing');

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
        status = I18n.t('single.encodingVoice');
        final codes = await encodeAudioToCodes(
          assetPath: voice.file,
          engine: _engine!,
          codecMeta: _codecMeta!,
        );
        if (codes == null || codes.isEmpty) {
          status = I18n.t('single.encodeFailed', params: {'file': voice.file});
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
      status = I18n.t('single.chunkInfo', params: {'n': textChunks.length.toString()});

      // ── 2. 逐块推理 ──
      final allSamples = <double>[];
      const int sampleRate = 48000;
      final int pauseSamples = (sampleRate * 0.4).round();

      for (int ci = 0; ci < textChunks.length; ci++) {
        final chunk = textChunks[ci];
        if (chunk.trim().isEmpty) continue;

        if (textChunks.length > 1) {
          status = I18n.t('single.chunkProgress', params: {'current': (ci + 1).toString(), 'total': textChunks.length.toString()});
        } else {
          status = I18n.t('single.inferring');
        }

        final textIds = _tokenizer!.encodeText(chunk);
        final req = inferencer.buildRequest(promptCodes, textIds);
        final frames = await inferencer.generate(req);

        status = I18n.t('single.decodingAudio', params: {'n': frames.length.toString()});
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

        if (ci < textChunks.length - 1) {
          for (int i = 0; i < pauseSamples; i++) {
            allSamples.add(0.0);
          }
        }
      }

      if (allSamples.isEmpty) {
        status = I18n.t('single.noAudioOutput');
        return null;
      }

      // ── 3. 写入 WAV ──
      final outDir = Directory('${Directory.systemTemp.path}/moss_tts_output');
      if (outDir.existsSync()) outDir.deleteSync(recursive: true);
      outDir.createSync();
      final wavPath = '${outDir.path}/output.wav';
      writeWav(wavPath, allSamples, sampleRate);

      status = I18n.t('app.success');
      return wavPath;
    } catch (e) {
      status = I18n.t('app.failed', params: {'e': '$e'});
      return null;
    }
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
