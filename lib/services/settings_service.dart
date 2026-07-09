import 'package:shared_preferences/shared_preferences.dart';

/// 持久化应用设置
class SettingsService {
  static const _kModelPath = 'model_path';
  static const _kTemperature = 'temperature';
  static const _kTopK = 'top_k';
  static const _kTopP = 'top_p';
  static const _kRepetitionPenalty = 'repetition_penalty';
  static const _kMaxFrames = 'max_frames';
  static const _kSeed = 'seed';
  static const _kThemeMode = 'theme_mode';
  static const _kLanguage = 'language';
  static const _kDefaultVoiceId = 'default_voice_id';

  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ─── 模型 ───

  static String get modelPath => _prefs.getString(_kModelPath) ?? '';

  static Future<void> setModelPath(String v) => _prefs.setString(_kModelPath, v);

  // ─── 生成参数 ───

  static double get temperature => _prefs.getDouble(_kTemperature) ?? 0.8;

  static Future<void> setTemperature(double v) => _prefs.setDouble(_kTemperature, v);

  static int get topK => _prefs.getInt(_kTopK) ?? 25;

  static Future<void> setTopK(int v) => _prefs.setInt(_kTopK, v);

  static double get topP => _prefs.getDouble(_kTopP) ?? 0.95;

  static Future<void> setTopP(double v) => _prefs.setDouble(_kTopP, v);

  static double get repetitionPenalty => _prefs.getDouble(_kRepetitionPenalty) ?? 1.2;

  static Future<void> setRepetitionPenalty(double v) =>
      _prefs.setDouble(_kRepetitionPenalty, v);

  static int get maxFrames => _prefs.getInt(_kMaxFrames) ?? 375;

  static Future<void> setMaxFrames(int v) => _prefs.setInt(_kMaxFrames, v);

  static int get seed => _prefs.getInt(_kSeed) ?? 0;

  static Future<void> setSeed(int v) => _prefs.setInt(_kSeed, v);

  // ─── 外观 ───

  static String get themeMode => _prefs.getString(_kThemeMode) ?? 'light';

  static Future<void> setThemeMode(String v) => _prefs.setString(_kThemeMode, v);

  // ─── 语言 ───

  static String get language => _prefs.getString(_kLanguage) ?? 'zh';

  static Future<void> setLanguage(String v) => _prefs.setString(_kLanguage, v);

  // ─── 默认音色 ───

  static String get defaultVoiceId => _prefs.getString(_kDefaultVoiceId) ?? '';

  static Future<void> setDefaultVoiceId(String v) => _prefs.setString(_kDefaultVoiceId, v);
}
