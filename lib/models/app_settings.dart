import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'generation_params.dart';

class AppSettings extends ChangeNotifier {
  static const String _key = 'app_settings';
  
  String _language;
  bool _darkMode;
  bool _closeToTray;
  bool _autoStart;
  String? _defaultVoiceId;
  bool _showAnimBg;
  double _orbOpacity;
  GenerationParams _generationParams;

  AppSettings({
    String language = 'zh',
    bool darkMode = false,
    bool closeToTray = true,
    bool autoStart = true,
    String? defaultVoiceId,
    bool showAnimBg = true,
    double orbOpacity = 0.6,
    GenerationParams? generationParams,
  })  : _language = language,
        _darkMode = darkMode,
        _closeToTray = closeToTray,
        _autoStart = autoStart,
        _defaultVoiceId = defaultVoiceId,
        _showAnimBg = showAnimBg,
        _orbOpacity = orbOpacity,
        _generationParams = generationParams ?? GenerationParams();

  String get language => _language;
  bool get darkMode => _darkMode;
  bool get closeToTray => _closeToTray;
  bool get autoStart => _autoStart;
  String? get defaultVoiceId => _defaultVoiceId;
  bool get showAnimBg => _showAnimBg;
  double get orbOpacity => _orbOpacity;
  GenerationParams get generationParams => _generationParams;

  set language(String value) {
    if (_language != value) {
      _language = value;
      _save();
      notifyListeners();
    }
  }

  set darkMode(bool value) {
    if (_darkMode != value) {
      _darkMode = value;
      _save();
      notifyListeners();
    }
  }

  set closeToTray(bool value) {
    if (_closeToTray != value) {
      _closeToTray = value;
      _save();
      notifyListeners();
    }
  }

  set autoStart(bool value) {
    if (_autoStart != value) {
      _autoStart = value;
      _save();
      notifyListeners();
    }
  }

  set defaultVoiceId(String? value) {
    if (_defaultVoiceId != value) {
      _defaultVoiceId = value;
      _save();
      notifyListeners();
    }
  }

  set showAnimBg(bool value) {
    if (_showAnimBg != value) {
      _showAnimBg = value;
      _save();
      notifyListeners();
    }
  }

  set orbOpacity(double value) {
    if (_orbOpacity != value) {
      _orbOpacity = value;
      _save();
      notifyListeners();
    }
  }

  set generationParams(GenerationParams value) {
    _generationParams = value;
    _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(toJson()));
  }

  static Future<AppSettings> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_key);
      if (jsonString != null) {
        return AppSettings.fromJson(jsonDecode(jsonString));
      }
    } catch (e) {
      debugPrint('Failed to load settings: $e');
    }
    return AppSettings();
  }

  void updateGenerationParams({
    double? audioTemperature,
    int? audioTopK,
    double? audioTopP,
    double? audioRepetitionPenalty,
    int? maxNewFrames,
    int? seed,
    bool? enableTextNormalization,
    bool? enableNormalizeTtsText,
  }) {
    _generationParams = _generationParams.copyWith(
      audioTemperature: audioTemperature,
      audioTopK: audioTopK,
      audioTopP: audioTopP,
      audioRepetitionPenalty: audioRepetitionPenalty,
      maxNewFrames: maxNewFrames,
      seed: seed,
      enableTextNormalization: enableTextNormalization,
      enableNormalizeTtsText: enableNormalizeTtsText,
    );
    notifyListeners();
  }

  Map<String, dynamic> toJson() {
    return {
      'language': _language,
      'darkMode': _darkMode,
      'closeToTray': _closeToTray,
      'autoStart': _autoStart,
      'defaultVoiceId': _defaultVoiceId,
      'showAnimBg': _showAnimBg,
      'orbOpacity': _orbOpacity,
      'generationParams': _generationParams.toJson(),
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      language: json['language'] as String? ?? 'zh',
      darkMode: json['darkMode'] as bool? ?? false,
      closeToTray: json['closeToTray'] as bool? ?? true,
      autoStart: json['autoStart'] as bool? ?? true,
      defaultVoiceId: json['defaultVoiceId'] as String?,
      showAnimBg: json['showAnimBg'] as bool? ?? true,
      orbOpacity: (json['orbOpacity'] as num?)?.toDouble() ?? 0.6,
      generationParams: json['generationParams'] != null
          ? GenerationParams.fromJson(
              json['generationParams'] as Map<String, dynamic>)
          : null,
    );
  }
}
