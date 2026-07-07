import 'dart:typed_data';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:onnxruntime_v2/onnxruntime_v2.dart';

/// TTS 推理编排
///
/// 对位 Python:
///   build_voice_clone_request_rows → prefill → decode loop → decode_full_audio
class TtsInferencer {
  final Map<String, OrtSession> sessions;
  final Map<String, dynamic> ttsMeta;
  final Map<String, dynamic> manifest;
  final Map<String, dynamic> codecMeta;
  final Random _rng;

  TtsInferencer({
    required this.sessions,
    required this.ttsMeta,
    required this.manifest,
    required this.codecMeta,
    int? seed,
  }) : _rng = Random(seed ?? 1234);

  // ─── helpers ── 与 Python self.manifest["tts_config"] / model_config 对应

  int get _nVq => _int(ttsMeta['model_config']['n_vq']);
  int get _pad => _int(ttsMeta['model_config']['audio_pad_token_id']);
  int get _audioStart => _int(ttsMeta['model_config']['audio_start_token_id']);
  int get _audioEnd => _int(ttsMeta['model_config']['audio_end_token_id']);
  int get _slotAsst => _int(ttsMeta['model_config']['audio_assistant_slot_token_id']);
  int get _slotUser => _int(ttsMeta['model_config']['audio_user_slot_token_id']);
  Map<String, dynamic> get _gen => manifest['generation_defaults'] as Map<String, dynamic>;
  List<int> get _pre => (manifest['prompt_templates']['user_prompt_prefix_token_ids'] as List).cast<int>();
  List<int> get _ref => (manifest['prompt_templates']['user_prompt_after_reference_token_ids'] as List).cast<int>();
  List<int> get _asst => (manifest['prompt_templates']['assistant_prompt_prefix_token_ids'] as List).cast<int>();

  // ─── build ── 严格对应 Python build_text_rows / build_audio_prefix_rows / build_voice_clone_request_rows

  List<List<int>> buildTextRows(List<int> ids) {
    final rows = <List<int>>[];
    final width = _nVq + 1;
    for (final id in ids) {
      final row = List.filled(width, _pad);
      row[0] = id;
      rows.add(row);
    }
    return rows;
  }

  List<List<int>> buildAudioRows(List<List<int>> codes, {int? slot}) {
    final s = slot ?? _slotUser;
    final rows = <List<int>>[];
    final width = _nVq + 1;
    for (final codeRow in codes) {
      final row = List.filled(width, _pad);
      row[0] = s;
      for (var i = 0; i < codeRow.length && i < _nVq; i++) {
        row[i + 1] = codeRow[i];
      }
      rows.add(row);
    }
    return rows;
  }

  Map<String, dynamic> buildRequest(List<List<int>> promptCodes, List<int> textIds) {
    // Python: prefix = [*user_prompt_prefix_token_ids, audio_start_token_id]
    final prefix = [..._pre, _audioStart];
    // Python: suffix = [audio_end_token_id, *user_prompt_after_reference_token_ids, *text_token_ids, *assistant_prompt_prefix_token_ids, audio_start_token_id]
    final suffix = [_audioEnd, ..._ref, ...textIds, ..._asst, _audioStart];
    final rows = [
      ...buildTextRows(prefix),
      ...buildAudioRows(promptCodes),
      ...buildTextRows(suffix),
    ];
    return {'inputIds': rows, 'attentionMask': [List.filled(rows.length, 1)]};
  }

  // ─── prefill → decode loop → generate frames ──

  Future<List<List<int>>> generate(Map<String, dynamic> req) async {
    final inputIds = (req['inputIds'] as List).cast<List<int>>();
    // Python: attentionMask = [[1 for _ in rows]]  即 List<List<int>>
    final attn2d = (req['attentionMask'] as List).cast<List<int>>();
    final attnFlat = attn2d[0];
    // Python: prefill_ids, prefill_dims = _flatten3d_int32([request_rows["inputIds"]])
    // prefill_mask, prefill_mask_dims = _flatten2d_int32(request_rows["attentionMask"])
    final seqLen = inputIds.length;
    final rowWidth = inputIds[0].length;
    final flat = Int32List(seqLen * rowWidth);
    for (var r = 0; r < seqLen; r++) {
      for (var c = 0; c < rowWidth; c++) {
        flat[r * rowWidth + c] = inputIds[r][c];
      }
    }

    final pin = OrtValueTensor.createTensorWithDataList(flat, [1, seqLen, rowWidth]);
    final pmsk = OrtValueTensor.createTensorWithDataList(Int32List.fromList(attnFlat), [1, seqLen]);
    final ropts = OrtRunOptions();
    try {
      // ── prefill ──
      // Python: outputs = self.sessions["prefill"].run(None, {input_ids, attention_mask})
      final pout = await sessions['prefill']!.runAsync(ropts, {'input_ids': pin, 'attention_mask': pmsk});
      final pnames = sessions['prefill']!.outputNames;
      final pnamed = _named(pnames, pout);

      // Python: global_hidden = _extract_last_hidden(named_outputs["global_hidden"])
      final gh = _lastHidden(pnamed['global_hidden']!.value, _int(ttsMeta['model_config']['hidden_size']));

      // Python: past_by_name = {output_name.replace("present_", "past_"): named_outputs[output_name] for output_name in self.tts_meta["onnx"]["prefill_output_names"][1:]}
      var pastByKey = <String, OrtValue>{};
      for (final n in (ttsMeta['onnx']['prefill_output_names'] as List).skip(1)) {
        pastByKey[_replacePresent(n as String)] = pnamed[n] as OrtValue;
      }

      // Python: past_valid_length = sum(int(item) for item in request_rows["attentionMask"][0])
      var pastLen = attnFlat.fold(0, (a, b) => a + b);

      // ── decode loop ──
      final frames = <List<int>>[];
      // Python: previous_tokens_by_channel = [[] for ...]
      // Python: previous_token_sets_by_channel = [set() for ...]
      final seen = [for (var c = 0; c < _nVq; c++) <int>{}];
      final maxFrames = _int(_gen['max_new_frames']);
      final hiddenSize = _int(ttsMeta['model_config']['hidden_size']);
      final codebookSize = _int((ttsMeta['model_config']['audio_codebook_sizes'] as List)[0]);

      for (var step = 0; step < maxFrames; step++) {
        // Python: repetition_seen_mask = np.zeros((1, n_vq, audio_codebook_size), dtype=np.int32)
        final rflat = Int32List(_nVq * codebookSize);
        for (var c = 0; c < _nVq; c++) {
          for (final t in seen[c]) {
            if (t >= 0 && t < codebookSize) rflat[c * codebookSize + t] = 1;
          }
        }

        List<int> frame;
        if (sessions.containsKey('local_fixed_sampled_frame')) {
          // Python: run_local_fixed_sampled_frame(global_hidden, previous_token_sets_by_channel)
          final gho = OrtValueTensor.createTensorWithDataList(gh, [1, hiddenSize]);
          final rpo = OrtValueTensor.createTensorWithDataList(rflat, [1, _nVq, codebookSize]);
          // Python: assistant_random_u = np.asarray([min(0.99999994, max(0.0, float(self.rng.random())))], dtype=np.float32)
          final aro = OrtValueTensor.createTensorWithDataList(Float32List.fromList(
            [min(0.99999994, max(0.0, _rng.nextDouble()))],
          ), [1]);
          // Python: audio_random_u = np.asarray([[min(0.99999994, max(0.0, float(self.rng.random()))) for _ in range(n_vq)]], dtype=np.float32)
          final auo = OrtValueTensor.createTensorWithDataList(Float32List.fromList(
            List.generate(_nVq, (_) => min(0.99999994, max(0.0, _rng.nextDouble()))),
          ), [1, _nVq]);
          try {
            final lout = await sessions['local_fixed_sampled_frame']!.runAsync(ropts, {
              'global_hidden': gho, 'repetition_seen_mask': rpo,
              'assistant_random_u': aro, 'audio_random_u': auo,
            });
            final lnames = sessions['local_fixed_sampled_frame']!.outputNames;
            final lnamed = _named(lnames, lout);
            // Python: should_continue = bool(int(np.asarray(named_outputs["should_continue"]).reshape(-1)[0]))
            final scVal = _read1dInt(lnamed['should_continue']!.value);
            if (scVal != 1) break;
            // Python: frame_token_ids = np.asarray(named_outputs["frame_token_ids"]).reshape(-1).tolist()
            frame = _read1dIntList(lnamed['frame_token_ids']!.value);
            debugPrint('[tts_inferencer] step=$step should_continue=$scVal frame_len=${frame.length}');
          } finally { gho.release(); rpo.release(); aro.release(); auo.release(); }
        } else {
          throw UnimplementedError('only fixed mode');
        }
        frames.add(frame);
        for (var c = 0; c < _nVq; c++) { seen[c].add(frame[c]); }

        // decode step: Python sessions["decode"].run with next_row
        // Python: next_row = np.full((1, 1, row_width), audio_pad_token_id, dtype=np.int32)
        //          next_row[0, 0, 0] = audio_assistant_slot_token_id
        final nr = Int32List(_nVq + 1);
        nr[0] = _slotAsst;
        for (var i = 0; i < frame.length && i < _nVq; i++) nr[i + 1] = frame[i];
        final nro = OrtValueTensor.createTensorWithDataList(nr, [1, 1, _nVq + 1]);
        // Python: "past_valid_lengths": np.asarray([past_valid_length], dtype=np.int32)
        final plo = OrtValueTensor.createTensorWithDataList(Int32List.fromList([pastLen]), [1]);
        try {
          // Python: decode_feeds = {"input_ids": next_row, "past_valid_lengths": past_valid_length, **past_by_name}
          final dout = await sessions['decode']!.runAsync(ropts, {
            'input_ids': nro, 'past_valid_lengths': plo, ...pastByKey,
          });
          final dnames = sessions['decode']!.outputNames;
          final dnamed = _named(dnames, dout);
          // Python: global_hidden = _extract_last_hidden(named_decode_outputs["global_hidden"])
          final dgh = _lastHidden(dnamed['global_hidden']!.value, hiddenSize);
          gh.setRange(0, hiddenSize, dgh);
          // Python: past_valid_length += 1
          pastLen++;
          // Python: past_by_name = {output_name.replace("present_", "past_"): ... for output_name in ...}
          // 先释放旧的 pastByKey OrtValue，防止 C 侧内存泄漏
          final oldPast = pastByKey;
          pastByKey = {};
          for (final n in (ttsMeta['onnx']['decode_output_names'] as List).skip(1)) {
            pastByKey[_replacePresent(n as String)] = dnamed[n] as OrtValue;
          }
          // dnamed['global_hidden'] 已通过 _lastHidden 读取完毕，不需要保留
          // 主动释放未保留在 pastByKey 中的 decode 输出
          for (final entry in dnamed.entries) {
            final name = entry.key;
            final value = entry.value;
            if (name != 'global_hidden' && !pastByKey.containsValue(value)) {
              value.release();
            }
          }
          // 释放旧的 pastByKey 中所有 OrtValue
          for (final v in oldPast.values) {
            v.release();
          }
        } finally { nro.release(); plo.release(); }
      }
      return frames;
    } finally { pin.release(); pmsk.release(); ropts.release(); }
  }

  // ─── decode_full_audio ──

  /// Python: def decode_full_audio(self, generated_frames):
  ///   audio_codes, dims = _flatten3d_int32([generated_frames])
  ///   outputs = self.sessions["codec_decode"].run(None, {audio_codes, audio_code_lengths})
  ///   audio_length = int(named_outputs["audio_lengths"].reshape(-1)[0])
  ///   return _slice_channel_major_audio(named_outputs["audio"], 0, audio_length), audio_length
  Future<DecodeAudioResult> decode(List<List<int>> frames) async {
    if (frames.isEmpty) return DecodeAudioResult(waveforms: [], audioLength: 0);
    final flat = Int32List(frames.length * _nVq);
    for (var r = 0; r < frames.length; r++) {
      for (var c = 0; c < _nVq; c++) flat[r * _nVq + c] = frames[r][c];
    }
    final co = OrtValueTensor.createTensorWithDataList(flat, [1, frames.length, _nVq]);
    final lo = OrtValueTensor.createTensorWithDataList(Int32List.fromList([frames.length]), [1]);
    final ropts = OrtRunOptions();
    try {
      final out = await sessions['codec_decode']!.runAsync(ropts, {'audio_codes': co, 'audio_code_lengths': lo});
      final names = sessions['codec_decode']!.outputNames;
      final named = _named(names, out);
      // Python: audio = named_outputs["audio"]  shape [1, channels, samples]
      final rawAudio = named['audio']!.value;
      // Python: audio_length = int(named_outputs["audio_lengths"].reshape(-1)[0])
      final audioLength = _read1dInt(named['audio_lengths']!.value);
      // Python: _slice_channel_major_audio(audio, 0, audio_length)
      final channels = _int(codecMeta['codec_config']['channels']);
      final waveforms = <Float64List>[];
      final audio3d = _to3dDouble(rawAudio);
      for (var c = 0; c < channels; c++) {
        final channelData = audio3d[0][c];
        final end = audioLength.clamp(0, channelData.length);
        waveforms.add(Float64List.fromList(channelData.sublist(0, end)));
      }
      return DecodeAudioResult(waveforms: waveforms, audioLength: audioLength);
    } finally { co.release(); lo.release(); ropts.release(); }
  }

  // ─── utils ── 安全读取 ONNX 输出，避免 as 强转 ──

  Map<String, OrtValue> _named(List<String> names, List<OrtValue?>? outs) {
    final result = <String, OrtValue>{};
    if (outs == null) return result;
    for (var i = 0; i < names.length && i < outs.length; i++) {
      final v = outs[i];
      if (v != null) result[names[i]] = v;
    }
    return result;
  }

  String _replacePresent(String name) => name.replaceFirst('present_', 'past_');

  /// Python: _extract_last_hidden
  Float32List _lastHidden(dynamic val, int h) {
    // 调试：打印 global_hidden 的实际格式
    debugPrint('[tts_inferencer] _lastHidden type=${val.runtimeType} '
        'isList=${val is List} '
        'len=${val is List ? val.length : "N/A"}');
    if (val is List && val.isNotEmpty) {
      debugPrint('[tts_inferencer] _lastHidden val[0] type=${val[0].runtimeType} '
          'isList=${val[0] is List} '
          'len=${val[0] is List ? (val[0] as List).length : "N/A"}');
      if (val[0] is List && (val[0] as List).isNotEmpty) {
        final inner = val[0] as List;
        debugPrint('[tts_inferencer] _lastHidden val[0][0] type=${inner[0].runtimeType} '
            'isList=${inner[0] is List} '
            'len=${inner[0] is List ? (inner[0] as List).length : "N/A"}');
      }
    }

    // 3D: [1, seq, hidden] → 取 [0, -1, :]
    if (val is List) {
      if (val.isNotEmpty && val[0] is List) {
        if (val[0].isNotEmpty && val[0][0] is List) {
          final last = (val[0] as List).last as List;
          final result = Float32List(h);
          for (var i = 0; i < h && i < last.length; i++) {
            result[i] = (last[i] as num).toDouble();
          }
          return result;
        }
        // 2D: [seq, hidden] → 取最后一行
        final last = (val as List).last;
        if (last is List) {
          final result = Float32List(h);
          for (var i = 0; i < h && i < last.length; i++) {
            result[i] = (last[i] as num).toDouble();
          }
          return result;
        }
      }
    }
    debugPrint('[tts_inferencer] _lastHidden UNEXPECTED format: $val');
    throw ArgumentError('unexpected global_hidden type: ${val.runtimeType}');
  }

  /// 读取标量 int（Python: np.asarray(x).reshape(-1)[0]）
  /// ONNX 输出可能为: 1, [1], [[1]], [[[1]]] 等多种嵌套深度
  int _read1dInt(dynamic val) {
    if (val is int) return val;
    if (val is double) return val.round();
    if (val is List) {
      if (val.isEmpty) return 0;
      // 不管嵌套多深，递归找到第一个非 List 元素
      return _firstInt(val);
    }
    return _toInt(val);
  }

  /// 递归找到 List 中的第一个 int
  int _firstInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is List) {
      if (v.isEmpty) return 0;
      return _firstInt(v[0]);
    }
    return _toInt(v);
  }

  /// 读取 1D int list（Python: np.asarray(x).reshape(-1).tolist()）
  List<int> _read1dIntList(dynamic val) {
    if (val is List<int>) return val;
    if (val is List) {
      final flat = <int>[];
      _flattenInt(val, flat);
      return flat;
    }
    return [val];
  }

  void _flattenInt(dynamic val, List<int> out) {
    if (val is List) {
      for (final v in val) _flattenInt(v, out);
    } else {
      out.add(_toInt(val));
    }
  }

  List<List<List<double>>> _to3dDouble(dynamic val) {
    final result = <List<List<double>>>[];
    if (val is List) {
      for (final v1 in val) {
        if (v1 is List) {
          final row = <List<double>>[];
          for (final v2 in v1) {
            if (v2 is List) {
              row.add(v2.map((e) => (e as num).toDouble()).toList());
            } else if (v2 is double) {
              row.add([v2]);
            }
          }
          result.add(row);
        }
      }
    }
    return result;
  }

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is List) return _firstInt(v);
    print('[tts_inferencer] _toInt unexpected: ${v.runtimeType} = $v');
    return 0;
  }

  int _int(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.round();
    // 打印错误信息到控制台
    print('[tts_inferencer] ERROR _int got ${v.runtimeType} = $v');
    return v as int;
  }
}

class DecodeAudioResult {
  final List<Float64List> waveforms;
  final int audioLength;
  DecodeAudioResult({required this.waveforms, required this.audioLength});
}
