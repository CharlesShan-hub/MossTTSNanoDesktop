import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:onnxruntime_v2/onnxruntime_v2.dart';

import 'onnx_engine.dart';

/// 将音频文件编码为 prompt_audio_codes（用于非内置音色）。
/// 替代 Python 的 encode_reference_audio。
///
/// [assetPath] Flutter asset 路径，如 'assets/audio/zh_6.wav'
Future<List<List<int>>?> encodeAudioToCodes({
  required String assetPath,
  required OnnxEngine engine,
  required Map<String, dynamic> codecMeta,
}) async {
  final codecSession = engine.sessions['codec_encode'];
  if (codecSession == null) {
    debugPrint('[encode] codec_encode session not found');
    return null;
  }

  try {
    // 1. 加载并解析 WAV
    final byteData = await rootBundle.load(assetPath);
    final data = byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);
    if (data.length < 44) return null;

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
          pcm[i] = sum / channels;
        }
      }
    } else if (bitsPerSample == 32) {
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
      return null;
    }

    // 3. 重采样到 48000
    final targetRate = _int(codecMeta['codec_config']['sample_rate']);
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
    final wavLen = resampled.length;
    final stereo = Float32List(2 * wavLen);
    for (int i = 0; i < wavLen; i++) {
      stereo[i] = resampled[i];
      stereo[wavLen + i] = resampled[i];
    }
    final wavTensor = OrtValueTensor.createTensorWithDataList(stereo, [1, 2, wavLen]);
    final lenTensor = OrtValueTensor.createTensorWithDataList(Int32List.fromList([wavLen]), [1]);
    final ropts = OrtRunOptions();
    try {
      final out = await codecSession.runAsync(ropts, {
        'waveform': wavTensor, 'input_lengths': lenTensor,
      });
      final names = codecSession.outputNames;
      final named = _named(names, out);
      final codesVal = named['audio_codes']!.value;
      final codeLengthVal = named['audio_code_lengths']!.value;
      final codeLength = _read1dInt(codeLengthVal);
      final nQ = _int(codecMeta['codec_config']['num_quantizers']);

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

// ─── ONNX 输出读取辅助 ──────────────────────────────────────────────────

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
