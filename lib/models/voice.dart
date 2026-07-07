class Voice {
  final String id;
  final String name;
  final String file;
  final String language;
  final String description;
  final bool hidden;
  final bool isUserVoice;

  const Voice({
    required this.id,
    required this.name,
    required this.file,
    required this.language,
    required this.description,
    required this.hidden,
    this.isUserVoice = false,
  });

  factory Voice.fromJson(String id, Map<String, dynamic> json, {bool isUserVoice = false}) {
    return Voice(
      id: id,
      name: json['name'] as String? ?? id,
      file: json['file'] as String? ?? '',
      language: json['language'] as String? ?? '',
      description: json['description'] as String? ?? '',
      hidden: json['hidden'] as bool? ?? false,
      isUserVoice: isUserVoice,
    );
  }

  Voice copyWith({
    String? name,
    String? file,
    String? language,
    String? description,
    bool? hidden,
  }) {
    return Voice(
      id: id,
      name: name ?? this.name,
      file: file ?? this.file,
      language: language ?? this.language,
      description: description ?? this.description,
      hidden: hidden ?? this.hidden,
      isUserVoice: isUserVoice,
    );
  }
}
