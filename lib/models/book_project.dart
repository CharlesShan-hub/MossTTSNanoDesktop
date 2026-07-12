import 'dart:convert';

/// 有声书的一个片段
class BookSegment {
  String id;
  String text;
  String voiceId; // 使用的音色 ID

  BookSegment({
    required this.id,
    required this.text,
    this.voiceId = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'voiceId': voiceId,
      };

  factory BookSegment.fromJson(Map<String, dynamic> json) => BookSegment(
        id: json['id'] as String,
        text: json['text'] as String,
        voiceId: json['voiceId'] as String? ?? '',
      );

  BookSegment copyWith({String? text, String? voiceId}) => BookSegment(
        id: id,
        text: text ?? this.text,
        voiceId: voiceId ?? this.voiceId,
      );
}

/// 有声书项目
class BookProject {
  String name;
  List<BookSegment> segments;
  Map<String, dynamic> defaultParams;
  final int createdAt;

  BookProject({
    required this.name,
    required this.segments,
    this.defaultParams = const {},
    int? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toJson() => {
        'name': name,
        'segments': segments.map((s) => s.toJson()).toList(),
        'defaultParams': defaultParams,
        'createdAt': createdAt,
      };

  factory BookProject.fromJson(Map<String, dynamic> json) => BookProject(
        name: json['name'] as String? ?? '',
        segments: (json['segments'] as List?)
                ?.map((e) => BookSegment.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        defaultParams: json['defaultParams'] as Map<String, dynamic>? ?? {},
        createdAt: json['createdAt'] as int?,
      );

  /// 按句号、问号、感叹号、分号、换行等切分文本为片段
  static List<BookSegment> splitText(String text) {
    if (text.trim().isEmpty) return [];
    final segments = <BookSegment>[];
    // 先按换行分段
    final paragraphs = text.split('\n');
    for (final para in paragraphs) {
      final trimmed = para.trim();
      if (trimmed.isEmpty) continue;
      // 再按中文/英文标点拆分
      final buffer = StringBuffer();
      for (int i = 0; i < trimmed.length; i++) {
        final ch = trimmed[i];
        buffer.write(ch);
        if (_isSentenceEnd(ch)) {
          final sentence = buffer.toString().trim();
          if (sentence.isNotEmpty) {
            segments.add(BookSegment(
              id: 'seg_${segments.length + 1}',
              text: sentence,
            ));
          }
          buffer.clear();
        }
      }
      final remaining = buffer.toString().trim();
      if (remaining.isNotEmpty) {
        segments.add(BookSegment(
          id: 'seg_${segments.length + 1}',
          text: remaining,
        ));
      }
    }
    return segments;
  }

  static bool _isSentenceEnd(String ch) {
    return '。！？；.!?;\n'.contains(ch);
  }

  /// 重新编号所有片段
  void renumber() {
    for (int i = 0; i < segments.length; i++) {
      segments[i] = segments[i].copyWith();
      // 用 private field 不改 id 的话直接用新对象
    }
  }
}
