import 'dart:convert';

class MealEntry {
  MealEntry({
    required this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.ateAt,
  });

  final String id;
  final String name;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final DateTime ateAt;

  MealEntry copyWith({
    String? id,
    String? name,
    int? calories,
    double? protein,
    double? carbs,
    double? fat,
    DateTime? ateAt,
  }) {
    return MealEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      ateAt: ateAt ?? this.ateAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'ateAt': ateAt.toIso8601String(),
    };
  }

  factory MealEntry.fromMap(Map<String, dynamic> map) {
    return MealEntry(
      id: map['id'] as String,
      name: map['name'] as String,
      calories: map['calories'] as int,
      protein: (map['protein'] as num).toDouble(),
      carbs: (map['carbs'] as num).toDouble(),
      fat: (map['fat'] as num).toDouble(),
      ateAt: DateTime.parse(map['ateAt'] as String),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory MealEntry.fromJson(String source) =>
      MealEntry.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

class MealSchedule {
  MealSchedule({
    required this.id,
    required this.title,
    required this.hour,
    required this.minute,
    this.enabled = true,
  });

  final String id;
  final String title;
  final int hour;
  final int minute;
  final bool enabled;

  String get formattedTime {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  MealSchedule copyWith({
    String? id,
    String? title,
    int? hour,
    int? minute,
    bool? enabled,
  }) {
    return MealSchedule(
      id: id ?? this.id,
      title: title ?? this.title,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'hour': hour,
      'minute': minute,
      'enabled': enabled,
    };
  }

  factory MealSchedule.fromMap(Map<String, dynamic> map) {
    return MealSchedule(
      id: map['id'] as String,
      title: map['title'] as String,
      hour: map['hour'] as int,
      minute: map['minute'] as int,
      enabled: map['enabled'] as bool? ?? true,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory MealSchedule.fromJson(String source) =>
      MealSchedule.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

class MealPlanItem {
  MealPlanItem({
    required this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  final String id;
  final String name;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;

  MealPlanItem copyWith({
    String? id,
    String? name,
    int? calories,
    double? protein,
    double? carbs,
    double? fat,
  }) {
    return MealPlanItem(
      id: id ?? this.id,
      name: name ?? this.name,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
    };
  }

  factory MealPlanItem.fromMap(Map<String, dynamic> map) {
    return MealPlanItem(
      id: map['id'] as String,
      name: map['name'] as String,
      calories: map['calories'] as int,
      protein: (map['protein'] as num).toDouble(),
      carbs: (map['carbs'] as num).toDouble(),
      fat: (map['fat'] as num).toDouble(),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory MealPlanItem.fromJson(String source) =>
      MealPlanItem.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
