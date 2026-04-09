import 'dart:convert';

const Object _mealItemImagePathUnset = Object();

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
    final parsedHour = (map['hour'] as num?)?.toInt() ?? 9;
    final parsedMinute = (map['minute'] as num?)?.toInt() ?? 0;
    return MealSchedule(
      id: map['id'] as String,
      title: map['title'] as String,
      hour: parsedHour.clamp(0, 23),
      minute: parsedMinute.clamp(0, 59),
      enabled: map['enabled'] as bool? ?? true,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory MealSchedule.fromJson(String source) =>
      MealSchedule.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

class MealItem {
  MealItem({
    required this.id,
    required this.name,
    required this.baseMassGrams,
    required this.massGrams,
    this.imagePath,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  final String id;
  final String name;
  final double baseMassGrams;
  final double massGrams;
  final String? imagePath;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;

  double get massMultiplier {
    if (baseMassGrams <= 0) return 1;
    return massGrams / baseMassGrams;
  }

  int get scaledCalories => (calories * massMultiplier).round();
  double get scaledProtein => protein * massMultiplier;
  double get scaledCarbs => carbs * massMultiplier;
  double get scaledFat => fat * massMultiplier;

  String get portion => '${_formatMass(massGrams)}g';
  String get basePortion => '${_formatMass(baseMassGrams)}g';

  static String _formatMass(double value) {
    final rounded = value.roundToDouble();
    if ((value - rounded).abs() < 0.001) {
      return rounded.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }

  static double _legacyMassFromPortion(String? portion) {
    if (portion == null || portion.trim().isEmpty) return 100;
    final match = RegExp(
      r'([0-9]+(?:[.,][0-9]+)?)\s*g',
      caseSensitive: false,
    ).firstMatch(portion);
    if (match == null) return 100;
    final raw = match.group(1)?.replaceAll(',', '.');
    final parsed = raw == null ? null : double.tryParse(raw);
    if (parsed == null || parsed <= 0) return 100;
    return parsed;
  }

  MealItem copyWith({
    String? id,
    String? name,
    double? baseMassGrams,
    double? massGrams,
    Object? imagePath = _mealItemImagePathUnset,
    int? calories,
    double? protein,
    double? carbs,
    double? fat,
  }) {
    return MealItem(
      id: id ?? this.id,
      name: name ?? this.name,
      baseMassGrams: baseMassGrams ?? this.baseMassGrams,
      massGrams: massGrams ?? this.massGrams,
      imagePath: imagePath == _mealItemImagePathUnset
          ? this.imagePath
          : imagePath as String?,
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
      'portion': portion,
      'baseMassGrams': baseMassGrams,
      'massGrams': massGrams,
      'imagePath': imagePath,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
    };
  }

  factory MealItem.fromMap(Map<String, dynamic> map) {
    final legacyMass = _legacyMassFromPortion(map['portion'] as String?);
    final parsedBaseMass = (map['baseMassGrams'] as num?)?.toDouble();
    final parsedMass = (map['massGrams'] as num?)?.toDouble();
    final baseMass = (parsedBaseMass != null && parsedBaseMass > 0)
        ? parsedBaseMass
        : legacyMass;
    final mass = (parsedMass != null && parsedMass > 0) ? parsedMass : baseMass;

    return MealItem(
      id: map['id'] as String,
      name: map['name'] as String,
      baseMassGrams: baseMass,
      massGrams: mass,
      imagePath: map['imagePath'] as String?,
      calories: map['calories'] as int,
      protein: (map['protein'] as num).toDouble(),
      carbs: (map['carbs'] as num).toDouble(),
      fat: (map['fat'] as num).toDouble(),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory MealItem.fromJson(String source) =>
      MealItem.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

class MealPlanItem {
  MealPlanItem({
    required this.id,
    required this.name,
    required this.mealItemIds,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  final String id;
  final String name;
  final List<String> mealItemIds;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;

  MealPlanItem copyWith({
    String? id,
    String? name,
    List<String>? mealItemIds,
    int? calories,
    double? protein,
    double? carbs,
    double? fat,
  }) {
    return MealPlanItem(
      id: id ?? this.id,
      name: name ?? this.name,
      mealItemIds: mealItemIds ?? this.mealItemIds,
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
      'mealItemIds': mealItemIds,
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
      mealItemIds: ((map['mealItemIds'] as List<dynamic>?) ?? const [])
          .map((e) => e as String)
          .toList(),
      calories: (map['calories'] as int?) ?? 0,
      protein: (map['protein'] as num?)?.toDouble() ?? 0,
      carbs: (map['carbs'] as num?)?.toDouble() ?? 0,
      fat: (map['fat'] as num?)?.toDouble() ?? 0,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory MealPlanItem.fromJson(String source) =>
      MealPlanItem.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
