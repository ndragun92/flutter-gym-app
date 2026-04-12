class StepDayEntry {
  const StepDayEntry({
    required this.date,
    required this.steps,
    required this.updatedAt,
  });

  final DateTime date;
  final int steps;
  final DateTime updatedAt;

  StepDayEntry copyWith({DateTime? date, int? steps, DateTime? updatedAt}) {
    return StepDayEntry(
      date: date ?? this.date,
      steps: steps ?? this.steps,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date.toIso8601String(),
      'steps': steps,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory StepDayEntry.fromMap(Map<String, dynamic> map) {
    return StepDayEntry(
      date: DateTime.parse(map['date'] as String),
      steps: (map['steps'] as num?)?.toInt() ?? 0,
      updatedAt: map['updatedAt'] == null
          ? DateTime.parse(map['date'] as String)
          : DateTime.parse(map['updatedAt'] as String),
    );
  }
}
