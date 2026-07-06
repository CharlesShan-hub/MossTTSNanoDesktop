class GenerationParams {
  final double audioTemperature;
  final int audioTopK;
  final double audioTopP;
  final double audioRepetitionPenalty;
  final int maxNewFrames;
  final int seed;
  final bool enableTextNormalization;
  final bool enableNormalizeTtsText;

  GenerationParams({
    this.audioTemperature = 0.8,
    this.audioTopK = 25,
    this.audioTopP = 0.95,
    this.audioRepetitionPenalty = 1.2,
    this.maxNewFrames = 375,
    this.seed = 0,
    this.enableTextNormalization = true,
    this.enableNormalizeTtsText = true,
  });

  GenerationParams copyWith({
    double? audioTemperature,
    int? audioTopK,
    double? audioTopP,
    double? audioRepetitionPenalty,
    int? maxNewFrames,
    int? seed,
    bool? enableTextNormalization,
    bool? enableNormalizeTtsText,
  }) {
    return GenerationParams(
      audioTemperature: audioTemperature ?? this.audioTemperature,
      audioTopK: audioTopK ?? this.audioTopK,
      audioTopP: audioTopP ?? this.audioTopP,
      audioRepetitionPenalty: audioRepetitionPenalty ?? this.audioRepetitionPenalty,
      maxNewFrames: maxNewFrames ?? this.maxNewFrames,
      seed: seed ?? this.seed,
      enableTextNormalization: enableTextNormalization ?? this.enableTextNormalization,
      enableNormalizeTtsText: enableNormalizeTtsText ?? this.enableNormalizeTtsText,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'audioTemperature': audioTemperature,
      'audioTopK': audioTopK,
      'audioTopP': audioTopP,
      'audioRepetitionPenalty': audioRepetitionPenalty,
      'maxNewFrames': maxNewFrames,
      'seed': seed,
      'enableTextNormalization': enableTextNormalization,
      'enableNormalizeTtsText': enableNormalizeTtsText,
    };
  }

  factory GenerationParams.fromJson(Map<String, dynamic> json) {
    return GenerationParams(
      audioTemperature: (json['audioTemperature'] as num?)?.toDouble() ?? 0.8,
      audioTopK: (json['audioTopK'] as num?)?.toInt() ?? 25,
      audioTopP: (json['audioTopP'] as num?)?.toDouble() ?? 0.95,
      audioRepetitionPenalty: (json['audioRepetitionPenalty'] as num?)?.toDouble() ?? 1.2,
      maxNewFrames: (json['maxNewFrames'] as num?)?.toInt() ?? 375,
      seed: (json['seed'] as num?)?.toInt() ?? 0,
      enableTextNormalization: json['enableTextNormalization'] as bool? ?? true,
      enableNormalizeTtsText: json['enableNormalizeTtsText'] as bool? ?? true,
    );
  }
}
