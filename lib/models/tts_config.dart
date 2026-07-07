class TtsConfig {
  final String checkpointPath;
  final TtsModelFiles files;
  final Map<String, List<String>> externalDataFiles;
  final ModelConfig modelConfig;
  final OnnxConfig onnx;

  const TtsConfig({
    required this.checkpointPath,
    required this.files,
    required this.externalDataFiles,
    required this.modelConfig,
    required this.onnx,
  });

  factory TtsConfig.fromJson(Map<String, dynamic> json) {
    return TtsConfig(
      checkpointPath: json['checkpoint_path'] as String? ?? '',
      files: TtsModelFiles.fromJson(json['files'] as Map<String, dynamic>? ?? {}),
      externalDataFiles: (json['external_data_files'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, (v as List).cast<String>())) ??
          {},
      modelConfig: ModelConfig.fromJson(json['model_config'] as Map<String, dynamic>? ?? {}),
      onnx: OnnxConfig.fromJson(json['onnx'] as Map<String, dynamic>? ?? {}),
    );
  }
}

class TtsModelFiles {
  final String prefill;
  final String decodeStep;
  final String localDecoder;
  final String localCachedStep;
  final String localFixedSampledFrame;

  const TtsModelFiles({
    required this.prefill,
    required this.decodeStep,
    required this.localDecoder,
    required this.localCachedStep,
    required this.localFixedSampledFrame,
  });

  factory TtsModelFiles.fromJson(Map<String, dynamic> json) {
    return TtsModelFiles(
      prefill: json['prefill'] as String? ?? '',
      decodeStep: json['decode_step'] as String? ?? '',
      localDecoder: json['local_decoder'] as String? ?? '',
      localCachedStep: json['local_cached_step'] as String? ?? '',
      localFixedSampledFrame: json['local_fixed_sampled_frame'] as String? ?? '',
    );
  }
}

class ModelConfig {
  final int nVq;
  final int rowWidth;
  final int hiddenSize;
  final int globalLayers;
  final int globalHeads;
  final int headDim;
  final int localLayers;
  final int localHeads;
  final int localHeadDim;
  final int vocabSize;
  final List<int> audioCodebookSizes;
  final int audioPadTokenId;
  final int padTokenId;
  final int imStartTokenId;
  final int imEndTokenId;
  final int audioStartTokenId;
  final int audioEndTokenId;
  final int audioUserSlotTokenId;
  final int audioAssistantSlotTokenId;

  const ModelConfig({
    required this.nVq,
    required this.rowWidth,
    required this.hiddenSize,
    required this.globalLayers,
    required this.globalHeads,
    required this.headDim,
    required this.localLayers,
    required this.localHeads,
    required this.localHeadDim,
    required this.vocabSize,
    required this.audioCodebookSizes,
    required this.audioPadTokenId,
    required this.padTokenId,
    required this.imStartTokenId,
    required this.imEndTokenId,
    required this.audioStartTokenId,
    required this.audioEndTokenId,
    required this.audioUserSlotTokenId,
    required this.audioAssistantSlotTokenId,
  });

  factory ModelConfig.fromJson(Map<String, dynamic> json) {
    return ModelConfig(
      nVq: json['n_vq'] as int? ?? 16,
      rowWidth: json['row_width'] as int? ?? 17,
      hiddenSize: json['hidden_size'] as int? ?? 768,
      globalLayers: json['global_layers'] as int? ?? 12,
      globalHeads: json['global_heads'] as int? ?? 12,
      headDim: json['head_dim'] as int? ?? 64,
      localLayers: json['local_layers'] as int? ?? 1,
      localHeads: json['local_heads'] as int? ?? 12,
      localHeadDim: json['local_head_dim'] as int? ?? 64,
      vocabSize: json['vocab_size'] as int? ?? 16384,
      audioCodebookSizes: (json['audio_codebook_sizes'] as List?)?.cast<int>() ?? List.filled(16, 1024),
      audioPadTokenId: json['audio_pad_token_id'] as int? ?? 1024,
      padTokenId: json['pad_token_id'] as int? ?? 3,
      imStartTokenId: json['im_start_token_id'] as int? ?? 4,
      imEndTokenId: json['im_end_token_id'] as int? ?? 5,
      audioStartTokenId: json['audio_start_token_id'] as int? ?? 6,
      audioEndTokenId: json['audio_end_token_id'] as int? ?? 7,
      audioUserSlotTokenId: json['audio_user_slot_token_id'] as int? ?? 8,
      audioAssistantSlotTokenId: json['audio_assistant_slot_token_id'] as int? ?? 9,
    );
  }
}

class OnnxConfig {
  final int opset;
  final List<String> prefillOutputNames;
  final List<String> decodeInputNames;
  final List<String> decodeOutputNames;
  final List<String> localCachedInputNames;
  final List<String> localCachedOutputNames;
  final List<String> localFixedSampledFrameInputNames;
  final List<String> localFixedSampledFrameOutputNames;
  final FixedSampledFrameConstants fixedSampledFrameConstants;

  const OnnxConfig({
    required this.opset,
    required this.prefillOutputNames,
    required this.decodeInputNames,
    required this.decodeOutputNames,
    required this.localCachedInputNames,
    required this.localCachedOutputNames,
    required this.localFixedSampledFrameInputNames,
    required this.localFixedSampledFrameOutputNames,
    required this.fixedSampledFrameConstants,
  });

  factory OnnxConfig.fromJson(Map<String, dynamic> json) {
    return OnnxConfig(
      opset: json['opset'] as int? ?? 17,
      prefillOutputNames: (json['prefill_output_names'] as List?)?.cast<String>() ?? [],
      decodeInputNames: (json['decode_input_names'] as List?)?.cast<String>() ?? [],
      decodeOutputNames: (json['decode_output_names'] as List?)?.cast<String>() ?? [],
      localCachedInputNames: (json['local_cached_input_names'] as List?)?.cast<String>() ?? [],
      localCachedOutputNames: (json['local_cached_output_names'] as List?)?.cast<String>() ?? [],
      localFixedSampledFrameInputNames: (json['local_fixed_sampled_frame_input_names'] as List?)?.cast<String>() ?? [],
      localFixedSampledFrameOutputNames: (json['local_fixed_sampled_frame_output_names'] as List?)?.cast<String>() ?? [],
      fixedSampledFrameConstants: FixedSampledFrameConstants.fromJson(
          json['fixed_sampled_frame_constants'] as Map<String, dynamic>? ?? {}),
    );
  }
}

class FixedSampledFrameConstants {
  final double textTemperature;
  final double textTopP;
  final int textTopK;
  final double audioTemperature;
  final double audioTopP;
  final int audioTopK;
  final double audioRepetitionPenalty;

  const FixedSampledFrameConstants({
    required this.textTemperature,
    required this.textTopP,
    required this.textTopK,
    required this.audioTemperature,
    required this.audioTopP,
    required this.audioTopK,
    required this.audioRepetitionPenalty,
  });

  factory FixedSampledFrameConstants.fromJson(Map<String, dynamic> json) {
    return FixedSampledFrameConstants(
      textTemperature: (json['text_temperature'] as num?)?.toDouble() ?? 1.0,
      textTopP: (json['text_top_p'] as num?)?.toDouble() ?? 1.0,
      textTopK: json['text_top_k'] as int? ?? 50,
      audioTemperature: (json['audio_temperature'] as num?)?.toDouble() ?? 0.8,
      audioTopP: (json['audio_top_p'] as num?)?.toDouble() ?? 0.95,
      audioTopK: json['audio_top_k'] as int? ?? 25,
      audioRepetitionPenalty: (json['audio_repetition_penalty'] as num?)?.toDouble() ?? 1.2,
    );
  }
}
