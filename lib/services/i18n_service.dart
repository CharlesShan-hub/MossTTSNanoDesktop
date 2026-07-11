import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class I18n {
  static Map<String, dynamic> _strings = {};
  static List<String> supportedLocales = ['zh', 'en'];
  static String _currentLocale = 'zh';

  /// 语言变更通知，页面通过 addListener 订阅后自动重建
  static final ChangeNotifier notifier = ChangeNotifier();

  static String get currentLocale => _currentLocale;

  static Future<void> load(String locale) async {
    _currentLocale = locale;
    try {
      final raw = await rootBundle.loadString('assets/i18n/$locale.json');
      _strings = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      _strings = {};
    }
    notifier.notifyListeners();
  }

  /// Translate a key using dot notation, e.g. t('single.generate')
  static String t(String key, {Map<String, dynamic>? params}) {
    final parts = key.split('.');
    dynamic value = _strings;
    for (final p in parts) {
      if (value is Map) {
        value = value[p];
      } else {
        value = null;
        break;
      }
    }
    if (value == null) return key;
    String result = value.toString();
    if (params != null) {
      for (final e in params.entries) {
        result = result.replaceAll('{${e.key}}', e.value.toString());
      }
    }
    return result;
  }

  /// Convenience getter for current locale name
  static String get localeName => _currentLocale;
}
