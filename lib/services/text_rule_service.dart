import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/text_rule.dart';

/// 文本替换规则管理
class TextRuleService {
  static final ChangeNotifier notifier = ChangeNotifier();
  static List<TextRule> _rules = [];

  static Future<File> get _configFile async {
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '/tmp';
    final dir = Directory(Platform.isMacOS
        ? '$home/Library/Application Support/com.example.mossTtsNano'
        : '${home}/.local/share/com.example.mossTtsNano');
    dir.createSync(recursive: true);
    return File('${dir.path}/text_rules.json');
  }

  /// 加载规则
  static Future<List<TextRule>> loadRules() async {
    if (_rules.isNotEmpty) return _rules;
    final file = await _configFile;
    if (!file.existsSync()) {
      _rules = _defaultRules();
      return _rules;
    }
    try {
      final raw = await file.readAsString();
      final list = jsonDecode(raw) as List;
      _rules = list.map((e) => TextRule.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      _rules = _defaultRules();
    }
    return _rules;
  }

  /// 保存规则
  static Future<void> saveRules(List<TextRule> rules) async {
    _rules = rules;
    final file = await _configFile;
    await file.writeAsString(jsonEncode(rules.map((r) => r.toJson()).toList()));
    notifier.notifyListeners();
  }

  /// 添加规则
  static Future<void> addRule(TextRule rule) async {
    _rules.add(rule);
    await saveRules(_rules);
  }

  /// 更新规则
  static Future<void> updateRule(int index, TextRule rule) async {
    if (index < 0 || index >= _rules.length) return;
    _rules[index] = rule;
    await saveRules(_rules);
  }

  /// 删除规则
  static Future<void> deleteRule(int index) async {
    if (index < 0 || index >= _rules.length) return;
    _rules.removeAt(index);
    await saveRules(_rules);
  }

  /// 应用规则到文本
  static String apply(String text) {
    var result = text;
    for (final rule in _rules) {
      if (!rule.enabled || rule.from.isEmpty) continue;
      result = result.replaceAll(rule.from, rule.to);
    }
    return result;
  }

  /// 默认规则（生成时应用，文案不变）
  static List<TextRule> _defaultRules() => [
    TextRule(from: '，', to: ','),
    TextRule(from: '。', to: '.'),
    TextRule(from: '、', to: ','),
    TextRule(from: '；', to: ';'),
    TextRule(from: '：', to: ': '),
    TextRule(from: '？', to: '?'),
    TextRule(from: '！', to: '!'),
  ];
}
