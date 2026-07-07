import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:onnxruntime_v2/onnxruntime_v2.dart';

import '../models/tts_config.dart';

/// ONNX Runtime 引擎，负责初始化环境、加载所有子模型 Session。
///
/// 用法：
/// ```dart
/// final engine = OnnxEngine();
/// await engine.load(bundleBasePath: 'assets/models');
/// final prefillSession = engine.sessions['prefill'];
/// ```
class OnnxEngine {
  static bool _envInitialized = false;

  TtsConfig? ttsConfig;
  Map<String, dynamic>? ttsMetaRaw;
  Map<String, dynamic>? codecMetaRaw;
  Map<String, OrtSession> sessions = {};
  String? _tempDir;

  /// 释放所有 Session 和环境
  void dispose() {
    for (final s in sessions.values) {
      s.release();
    }
    sessions.clear();
    ttsConfig = null;
    OrtEnv.instance.release();
    _envInitialized = false;
    if (_tempDir != null) {
      try {
        Directory(_tempDir!).deleteSync(recursive: true);
      } catch (_) {}
    }
  }

  /// 初始化 OrtEnv
  void _initEnv() {
    if (!_envInitialized) {
      OrtEnv.instance.init();
      _envInitialized = true;
    }
  }

  /// 加载所有模型
  ///
  /// [bundleBasePath] Flutter assets 中的模型根目录，如 `'assets/models'`
  /// [tempDir] 临时目录路径，用于解压模型文件供 ONNX Runtime 读取
  Future<void> load({
    required String bundleBasePath,
    String? tempDir,
  }) async {
    _initEnv();

    // ── 1. 读取 browser_poc_manifest.json ──
    final manifestPath = '$bundleBasePath/MOSS-TTS-Nano-100M-ONNX/browser_poc_manifest.json';
    final manifest = jsonDecode(await rootBundle.loadString(manifestPath)) as Map<String, dynamic>;

    // ── 2. 读取 tts_browser_onnx_meta.json ──
    final ttsMetaRel = manifest['model_files']['tts_meta'] as String;
    final rawTtsMeta = jsonDecode(
          await rootBundle.loadString('$bundleBasePath/MOSS-TTS-Nano-100M-ONNX/$ttsMetaRel'),
        ) as Map<String, dynamic>;
    ttsMetaRaw = rawTtsMeta;
    ttsConfig = TtsConfig.fromJson(rawTtsMeta);

    // ── 3. 读取 codec_browser_onnx_meta.json ──
    final rawCodecMetaRel = manifest['model_files']['codec_meta'] as String;
    final rawCodecMetaFilename = rawCodecMetaRel.contains('/')
        ? rawCodecMetaRel.substring(rawCodecMetaRel.lastIndexOf('/') + 1)
        : rawCodecMetaRel;
    final rawCodecMetaAssetPath = '$bundleBasePath/MOSS-Audio-Tokenizer-Nano-ONNX/$rawCodecMetaFilename';
    final rawCodecMeta = jsonDecode(await rootBundle.loadString(rawCodecMetaAssetPath)) as Map<String, dynamic>;
    codecMetaRaw = rawCodecMeta;

    // ── 4. 复制模型文件到临时目录 ──
    final tmp = tempDir ?? '${Directory.systemTemp.path}/moss_onnx_${DateTime.now().millisecondsSinceEpoch}';
    _tempDir = tmp;
    final ttsDir = '$tmp/MOSS-TTS-Nano-100M-ONNX';
    final codecDir = '$tmp/MOSS-Audio-Tokenizer-Nano-ONNX';
    Directory(ttsDir).createSync(recursive: true);
    Directory(codecDir).createSync(recursive: true);

    // TTS 模型文件
    final ttsModelFiles = [
      ttsConfig!.files.prefill,
      ttsConfig!.files.decodeStep,
      ttsConfig!.files.localDecoder,
      ttsConfig!.files.localCachedStep,
      ttsConfig!.files.localFixedSampledFrame,
    ];
    // 外部 .data 文件
    final ttsDataFiles = <String>{};
    for (final paths in ttsConfig!.externalDataFiles.values) {
      for (final p in paths) {
        ttsDataFiles.add(p);
      }
    }
    for (final f in [...ttsModelFiles, ...ttsDataFiles]) {
      await _copyAssetToFile(
        '$bundleBasePath/MOSS-TTS-Nano-100M-ONNX/$f',
        '$ttsDir/$f',
      );
    }

    // Codec 模型文件
    final codecModelFiles = [
      rawCodecMeta['files']['encode'] as String,
      rawCodecMeta['files']['decode_full'] as String,
      rawCodecMeta['files']['decode_step'] as String,
    ];
    final codecDataFiles = <String>{};
    if (rawCodecMeta['external_data_files'] is Map) {
      for (final paths in (rawCodecMeta['external_data_files'] as Map).values) {
        if (paths is List) {
          for (final p in paths) {
            codecDataFiles.add(p as String);
          }
        }
      }
    }
    for (final f in [...codecModelFiles, ...codecDataFiles]) {
      await _copyAssetToFile(
        '$bundleBasePath/MOSS-Audio-Tokenizer-Nano-ONNX/$f',
        '$codecDir/$f',
      );
    }

    // ── 5. 创建 Session（Python: ort.InferenceSession with SessionOptions） ──
    final sessionOptions = OrtSessionOptions();
    sessionOptions.setIntraOpNumThreads(4);
    sessionOptions.setInterOpNumThreads(1);
    sessionOptions.setSessionGraphOptimizationLevel(GraphOptimizationLevel.ortEnableAll);
    sessionOptions.appendCPUProvider(CPUFlags.useArena);

    sessions = {
      'prefill': await _createSession('$ttsDir/${ttsConfig!.files.prefill}', sessionOptions),
      'decode': await _createSession('$ttsDir/${ttsConfig!.files.decodeStep}', sessionOptions),
      'local_decoder': await _createSession('$ttsDir/${ttsConfig!.files.localDecoder}', sessionOptions),
      'local_cached_step': await _createSession('$ttsDir/${ttsConfig!.files.localCachedStep}', sessionOptions),
      'local_fixed_sampled_frame':
          await _createSession('$ttsDir/${ttsConfig!.files.localFixedSampledFrame}', sessionOptions),
      'codec_encode': await _createSession('$codecDir/${rawCodecMeta['files']['encode']}', sessionOptions),
      'codec_decode': await _createSession('$codecDir/${rawCodecMeta['files']['decode_full']}', sessionOptions),
      'codec_decode_step': await _createSession('$codecDir/${rawCodecMeta['files']['decode_step']}', sessionOptions),
    };
  }

  /// 从文件创建 ONNX Session（必须用 fromFile，因为 .onnx 依赖外部 .data 文件）
  Future<OrtSession> _createSession(String modelPath, OrtSessionOptions options) async {
    return OrtSession.fromFile(File(modelPath), options);
  }

  /// 将 Flutter asset 复制到文件系统路径
  Future<void> _copyAssetToFile(String assetPath, String filePath) async {
    try {
      final data = await rootBundle.load(assetPath);
      await File(filePath).writeAsBytes(data.buffer.asUint8List());
    } catch (e) {
      throw Exception('Failed to copy asset $assetPath -> $filePath: $e');
    }
  }
}
