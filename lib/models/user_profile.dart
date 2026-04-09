import 'dart:convert';

class UserProfile {
  UserProfile({
    required this.fullName,
    required this.birthDate,
    required this.heightCm,
    this.profileImagePath,
  });

  final String fullName;
  final DateTime birthDate;
  final double heightCm;
  final String? profileImagePath;

  UserProfile copyWith({
    String? fullName,
    DateTime? birthDate,
    double? heightCm,
    String? profileImagePath,
  }) {
    return UserProfile(
      fullName: fullName ?? this.fullName,
      birthDate: birthDate ?? this.birthDate,
      heightCm: heightCm ?? this.heightCm,
      profileImagePath: profileImagePath ?? this.profileImagePath,
    );
  }

  int ageAt(DateTime date) {
    var age = date.year - birthDate.year;
    final birthdayAlreadyPassed =
        date.month > birthDate.month ||
        (date.month == birthDate.month && date.day >= birthDate.day);
    if (!birthdayAlreadyPassed) {
      age -= 1;
    }
    return age;
  }

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'birthDate': birthDate.toIso8601String(),
      'heightCm': heightCm,
      'profileImagePath': profileImagePath,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      fullName: map['fullName'] as String,
      birthDate: DateTime.parse(map['birthDate'] as String),
      heightCm: (map['heightCm'] as num).toDouble(),
      profileImagePath: map['profileImagePath'] as String?,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory UserProfile.fromJson(String source) =>
      UserProfile.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
