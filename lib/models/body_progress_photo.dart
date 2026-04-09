import 'dart:convert';

class BodyProgressPhoto {
  BodyProgressPhoto({
    required this.id,
    required this.imagePath,
    required this.capturedAt,
  });

  final String id;
  final String imagePath;
  final DateTime capturedAt;

  BodyProgressPhoto copyWith({
    String? id,
    String? imagePath,
    DateTime? capturedAt,
  }) {
    return BodyProgressPhoto(
      id: id ?? this.id,
      imagePath: imagePath ?? this.imagePath,
      capturedAt: capturedAt ?? this.capturedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'imagePath': imagePath,
      'capturedAt': capturedAt.toIso8601String(),
    };
  }

  factory BodyProgressPhoto.fromMap(Map<String, dynamic> map) {
    return BodyProgressPhoto(
      id: map['id'] as String,
      imagePath: map['imagePath'] as String,
      capturedAt: DateTime.parse(map['capturedAt'] as String),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory BodyProgressPhoto.fromJson(String source) =>
      BodyProgressPhoto.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
