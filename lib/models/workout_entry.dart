import 'dart:convert';

class WorkoutEntry {
  WorkoutEntry({
    required this.id,
    required this.date,
    required this.exercise,
    required this.sets,
    required this.reps,
    required this.weight,
    this.notes,
  });

  final String id;
  final DateTime date;
  final String exercise;
  final int sets;
  final int reps;
  final double weight;
  final String? notes;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'exercise': exercise,
      'sets': sets,
      'reps': reps,
      'weight': weight,
      'notes': notes,
    };
  }

  factory WorkoutEntry.fromMap(Map<String, dynamic> map) {
    return WorkoutEntry(
      id: map['id'] as String,
      date: DateTime.parse(map['date'] as String),
      exercise: map['exercise'] as String,
      sets: map['sets'] as int,
      reps: map['reps'] as int,
      weight: (map['weight'] as num).toDouble(),
      notes: map['notes'] as String?,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory WorkoutEntry.fromJson(String source) =>
      WorkoutEntry.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

class GymSchedule {
  GymSchedule({
    required this.id,
    required this.title,
    required this.weekday,
    required this.hour,
    required this.minute,
    this.enabled = true,
  });

  final String id;
  final String title;
  final int weekday;
  final int hour;
  final int minute;
  final bool enabled;

  GymSchedule copyWith({
    String? id,
    String? title,
    int? weekday,
    int? hour,
    int? minute,
    bool? enabled,
  }) {
    return GymSchedule(
      id: id ?? this.id,
      title: title ?? this.title,
      weekday: weekday ?? this.weekday,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'weekday': weekday,
      'hour': hour,
      'minute': minute,
      'enabled': enabled,
    };
  }

  factory GymSchedule.fromMap(Map<String, dynamic> map) {
    return GymSchedule(
      id: map['id'] as String,
      title: map['title'] as String,
      weekday: map['weekday'] as int,
      hour: map['hour'] as int,
      minute: map['minute'] as int,
      enabled: map['enabled'] as bool? ?? true,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory GymSchedule.fromJson(String source) =>
      GymSchedule.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
