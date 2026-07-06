import 'dart:convert';

class Voice {
  final String id;
  final String name;
  final String? language;
  final String? description;
  final String audioPath;
  final bool isHidden;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Voice({
    required this.id,
    required this.name,
    this.language,
    this.description,
    required this.audioPath,
    this.isHidden = false,
    required this.createdAt,
    this.updatedAt,
  });

  Voice copyWith({
    String? id,
    String? name,
    String? language,
    String? description,
    String? audioPath,
    bool? isHidden,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Voice(
      id: id ?? this.id,
      name: name ?? this.name,
      language: language ?? this.language,
      description: description ?? this.description,
      audioPath: audioPath ?? this.audioPath,
      isHidden: isHidden ?? this.isHidden,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'language': language,
      'description': description,
      'audioPath': audioPath,
      'isHidden': isHidden,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory Voice.fromJson(Map<String, dynamic> json) {
    return Voice(
      id: json['id'] as String,
      name: json['name'] as String,
      language: json['language'] as String?,
      description: json['description'] as String?,
      audioPath: json['audioPath'] as String,
      isHidden: json['isHidden'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  @override
  String toString() => jsonEncode(toJson());

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Voice &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
