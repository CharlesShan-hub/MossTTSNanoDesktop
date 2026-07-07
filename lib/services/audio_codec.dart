import 'dart:typed_data';

import 'package:onnxruntime_v2/onnxruntime_v2.dart';

/// 音频编解码器 — 对应 Python CodecStreamingDecodeSession。
///
/// Python:
/// ```python
/// class CodecStreamingDecodeSession:
///     def reset(self):
///         self.state_feeds = {}
///         for spec in self.transformer_specs:
///             self.state_feeds[spec["input_name"]] = np.zeros(shape, dtype=np.int32)
///         ...
///     def run_frames(self, frame_rows):
///         feeds = {"audio_codes": ..., "audio_code_lengths": ...}
///         feeds.update(self.state_feeds)
///         outputs = self.session.run(None, feeds)
///         # 更新 state_feeds
///         return audio, audio_length
/// ```
class StreamingAudioCodec {
  final Map<String, dynamic> codecMeta;
  final OrtSession session; // codec_decode_step

  final List<dynamic> _transformerSpecs;
  final List<dynamic> _attentionSpecs;
  final Map<String, OrtValue> _stateFeeds = {};

  StreamingAudioCodec({
    required this.codecMeta,
    required this.session,
  })  : _transformerSpecs = (codecMeta['streaming_decode']?['transformer_offsets'] as List?) ?? [],
        _attentionSpecs = (codecMeta['streaming_decode']?['attention_caches'] as List?) ?? [];

  /// reset — 对应 Python reset()，重置所有状态缓存到零初始值
  void reset() {
    // 释放旧的 state feeds
    for (final v in _stateFeeds.values) {
      v.release();
    }
    _stateFeeds.clear();

    for (final spec in _transformerSpecs) {
      final shape = (spec['shape'] as List).cast<int>();
      final data = Int32List(shape.fold(1, (a, b) => a * b));
      _stateFeeds[spec['input_name'] as String] =
          OrtValueTensor.createTensorWithDataList(data, shape);
    }
    for (final spec in _attentionSpecs) {
      final offsetShape = (spec['offset_shape'] as List).cast<int>();
      final cacheShape = (spec['cache_shape'] as List).cast<int>();
      final posShape = (spec['positions_shape'] as List).cast<int>();
      final offsetLen = offsetShape.fold(1, (a, b) => a * b);
      final cacheLen = cacheShape.fold(1, (a, b) => a * b);
      final posLen = posShape.fold(1, (a, b) => a * b);

      _stateFeeds[spec['offset_input_name'] as String] =
          OrtValueTensor.createTensorWithDataList(Int32List(offsetLen), offsetShape);
      _stateFeeds[spec['cached_keys_input_name'] as String] =
          OrtValueTensor.createTensorWithDataList(Float32List(cacheLen), cacheShape);
      _stateFeeds[spec['cached_values_input_name'] as String] =
          OrtValueTensor.createTensorWithDataList(Float32List(cacheLen), cacheShape);
      // positions 初始全 -1
      final posData = Int32List(posLen);
      for (var i = 0; i < posLen; i++) posData[i] = -1;
      _stateFeeds[spec['cached_positions_input_name'] as String] =
          OrtValueTensor.createTensorWithDataList(posData, posShape);
    }
  }

  /// run_frames — 对应 Python run_frames(frame_rows)，返回 (waveform, audioLength)
  ///
  /// Python:
  /// ```python
  /// def run_frames(self, frame_rows):
  ///     audio_codes = np.zeros((1, frame_count, num_quantizers), dtype=np.int32)
  ///     for frame_index, frame_row in enumerate(frame_rows):
  ///         for channel_index in range(num_quantizers):
  ///             audio_codes[0, frame_index, channel_index] = frame_row[channel_index]
  ///     feeds = {"audio_codes": audio_codes, "audio_code_lengths": [frame_count]}
  ///     feeds.update(self.state_feeds)
  ///     outputs = self.session.run(None, feeds)
  ///     # 更新 state_feeds
  ///     return audio, audio_length
  /// ```
  Future<StreamingDecodeResult> runFrames(List<List<int>> frameRows) async {
    final numQuantizers = codecMeta['codec_config']['num_quantizers'] as int;
    final frameCount = frameRows.length;

    final codesFlat = Int32List(frameCount * numQuantizers);
    for (var r = 0; r < frameCount; r++) {
      final row = frameRows[r];
      for (var c = 0; c < numQuantizers; c++) {
        codesFlat[r * numQuantizers + c] = (c < row.length) ? row[c] : 0;
      }
    }
    final codesOrt = OrtValueTensor.createTensorWithDataList(
      codesFlat,
      [1, frameCount, numQuantizers],
    );
    final lenOrt = OrtValueTensor.createTensorWithDataList(
      Int32List.fromList([frameCount]),
      [1],
    );

    final runOpts = OrtRunOptions();
    try {
      final feeds = <String, OrtValue>{
        'audio_codes': codesOrt,
        'audio_code_lengths': lenOrt,
        ..._stateFeeds,
      };
      final outputs = await session.runAsync(runOpts, feeds);
      final outputNames = session.outputNames;

      // 构建 named outputs
      final named = <String, OrtValue>{};
      for (var i = 0; i < outputNames.length; i++) {
        final v = outputs![i];
        if (v != null) named[outputNames[i]] = v;
      }

      // 更新 state_feeds（释放旧值 + 保留新值）
      for (final spec in _transformerSpecs) {
        final outName = spec['output_name'] as String;
        final inName = spec['input_name'] as String;
        final old = _stateFeeds.remove(inName);
        old?.release();
        _stateFeeds[inName] = named[outName]!;
      }
      for (final spec in _attentionSpecs) {
        for (final field in [
          ('offset_input_name', 'offset_output_name'),
          ('cached_keys_input_name', 'cached_keys_output_name'),
          ('cached_values_input_name', 'cached_values_output_name'),
          ('cached_positions_input_name', 'cached_positions_output_name'),
        ]) {
          final inName = spec[field.$1] as String;
          final outName = spec[field.$2] as String;
          final old = _stateFeeds.remove(inName);
          old?.release();
          _stateFeeds[inName] = named[outName]!;
        }
      }

      final audioLength = (named['audio_lengths']!.value as List<List<int>>)[0][0];
      return StreamingDecodeResult(
        audio: named['audio']!.value as List<List<List<double>>>,
        audioLength: audioLength,
      );
    } finally {
      codesOrt.release();
      lenOrt.release();
      runOpts.release();
    }
  }

  /// 释放所有状态缓存
  void dispose() {
    for (final v in _stateFeeds.values) {
      v.release();
    }
    _stateFeeds.clear();
  }
}

class StreamingDecodeResult {
  final List<List<List<double>>> audio; // [batch][channels][samples]
  final int audioLength;
  StreamingDecodeResult({required this.audio, required this.audioLength});
}
