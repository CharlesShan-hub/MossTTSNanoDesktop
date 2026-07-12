import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:onnxruntime_v2/onnxruntime_v2.dart';
import 'package:path/path.dart' as p;

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
  static int _instanceCount = 0;

  TtsConfig? ttsConfig;
  Map<String, dynamic>? ttsMetaRaw;
  Map<String, dynamic>? codecMetaRaw;
  Map<String, OrtSession> sessions = {};
  String? _tempDir;

  OnnxEngine() {
    _instanceCount++;
  }

  /// 释放所有 Session 和环境（仅最后一个实例真正释放 ORT 环境）
  void dispose() {
    for (final s in sessions.values) {
      s.release();
    }
    sessions.clear();
    ttsConfig = null;
    _instanceCount--;
    if (_instanceCount <= 0) {
      OrtEnv.instance.release();
      _envInitialized = false;
    }
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
    debugPrint('[ONNX] ====== 开始加载模型 ======');
    _initEnv();
    debugPrint('[ONNX] 环境初始化完成');

    // ── 1. 读取 browser_poc_manifest.json ──
    final manifestPath = '$bundleBasePath/MOSS-TTS-Nano-100M-ONNX/browser_poc_manifest.json';
    debugPrint('[ONNX] 读取 manifest: $manifestPath');
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

    // ── 4. 复制模型文件到临时目录（仅首次执行） ──
    final tmp = tempDir ?? p.join(Directory.systemTemp.path, 'moss_onnx_cache');
    _tempDir = tmp;
    final cachedFlag = p.join(tmp, '.cache_done');
    final ttsDir = p.join(tmp, 'MOSS-TTS-Nano-100M-ONNX');
    final codecDir = p.join(tmp, 'MOSS-Audio-Tokenizer-Nano-ONNX');

    if (!File(cachedFlag).existsSync()) {
      // 清空旧缓存（如有），重新解压
      if (Directory(tmp).existsSync()) {
        try { Directory(tmp).deleteSync(recursive: true); } catch (_) {}
      }
      debugPrint('[ONNX] 临时目录: $tmp');
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
      debugPrint('[ONNX] TTS onnx 文件: $ttsModelFiles');
      // 外部 .data 文件
      final ttsDataFiles = <String>{};
      for (final paths in ttsConfig!.externalDataFiles.values) {
        for (final p in paths) {
          ttsDataFiles.add(p);
        }
      }
      debugPrint('[ONNX] TTS data 文件: $ttsDataFiles');
      for (final f in [...ttsModelFiles, ...ttsDataFiles]) {
        debugPrint('[ONNX] 复制 $f ...');
        await _copyAssetToFile(
          '$bundleBasePath/MOSS-TTS-Nano-100M-ONNX/$f',
          p.join(ttsDir, f),
        );
      }
      debugPrint('[ONNX] TTS 文件复制完成');

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
      debugPrint('[ONNX] Codec 文件: ${[...codecModelFiles, ...codecDataFiles]}');
      for (final f in [...codecModelFiles, ...codecDataFiles]) {
        debugPrint('[ONNX] 复制 $f ...');
        await _copyAssetToFile(
          '$bundleBasePath/MOSS-Audio-Tokenizer-Nano-ONNX/$f',
          p.join(codecDir, f),
        );
      }
      debugPrint('[ONNX] Codec 文件复制完成');
      // 标记缓存完成
      File(cachedFlag).writeAsStringSync('ok');
      debugPrint('[ONNX] 缓存标记完成');
    } else {
      debugPrint('[ONNX] 缓存已就绪，跳过解压');
    }

    // ── 5. 创建 Session（Python: ort.InferenceSession with SessionOptions） ──
    debugPrint('[ONNX] 开始创建 Session ...');
    final sessionOptions = OrtSessionOptions();
    sessionOptions.setIntraOpNumThreads(4);
    sessionOptions.setInterOpNumThreads(1);
    sessionOptions.setSessionGraphOptimizationLevel(GraphOptimizationLevel.ortEnableAll);
    sessionOptions.appendCPUProvider(CPUFlags.useArena);

    sessions = {
      'prefill': await _createSession(p.join(ttsDir, ttsConfig!.files.prefill), sessionOptions),
      'decode': await _createSession(p.join(ttsDir, ttsConfig!.files.decodeStep), sessionOptions),
      'local_decoder': await _createSession(p.join(ttsDir, ttsConfig!.files.localDecoder), sessionOptions),
      'local_cached_step': await _createSession(p.join(ttsDir, ttsConfig!.files.localCachedStep), sessionOptions),
      'local_fixed_sampled_frame':
          await _createSession(p.join(ttsDir, ttsConfig!.files.localFixedSampledFrame), sessionOptions),
      'codec_encode': await _createSession(p.join(codecDir, rawCodecMeta['files']['encode'] as String), sessionOptions),
      'codec_decode': await _createSession(p.join(codecDir, rawCodecMeta['files']['decode_full'] as String), sessionOptions),
      'codec_decode_step': await _createSession(p.join(codecDir, rawCodecMeta['files']['decode_step'] as String), sessionOptions),
    };
    debugPrint('[ONNX] ====== 所有 Session 创建完成 ======');
  }

  /// 从文件创建 ONNX Session（必须用 fromFile，因为 .onnx 依赖外部 .data 文件）
  Future<OrtSession> _createSession(String modelPath, OrtSessionOptions options) async {
    debugPrint('[ONNX] 创建 Session: $modelPath');
    try {
      final session = OrtSession.fromFile(File(modelPath), options);
      debugPrint('[ONNX] Session 创建成功: $modelPath');
      return session;
    } catch (e) {
      debugPrint('[ONNX] Session 创建失败: $modelPath → $e');
      rethrow;
    }
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
