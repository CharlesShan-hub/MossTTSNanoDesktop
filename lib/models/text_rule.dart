/// 文本替换规则
class TextRule {
  String from;
  String to;
  bool enabled;

  TextRule({
    required this.from,
    required this.to,
    this.enabled = true,
  });

  Map<String, dynamic> toJson() => {
    'from': from,
    'to': to,
    'enabled': enabled,
  };

  factory TextRule.fromJson(Map<String, dynamic> json) => TextRule(
    from: json['from'] as String? ?? '',
    to: json['to'] as String? ?? '',
    enabled: json['enabled'] as bool? ?? true,
  );

  TextRule copyWith({String? from, String? to, bool? enabled}) => TextRule(
    from: from ?? this.from,
    to: to ?? this.to,
    enabled: enabled ?? this.enabled,
  );
}
