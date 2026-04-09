import 'dart:convert';

class BodyMeasurementEntry {
  BodyMeasurementEntry({
    required this.id,
    required this.date,
    required this.weight,
    this.waist,
    this.chest,
    this.hips,
    this.biceps,
    this.thigh,
  });

  final String id;
  final DateTime date;
  final double weight;
  final double? waist;
  final double? chest;
  final double? hips;
  final double? biceps;
  final double? thigh;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'weight': weight,
      'waist': waist,
      'chest': chest,
      'hips': hips,
      'biceps': biceps,
      'thigh': thigh,
    };
  }

  factory BodyMeasurementEntry.fromMap(Map<String, dynamic> map) {
    return BodyMeasurementEntry(
      id: map['id'] as String,
      date: DateTime.parse(map['date'] as String),
      weight: (map['weight'] as num).toDouble(),
      waist: (map['waist'] as num?)?.toDouble(),
      chest: (map['chest'] as num?)?.toDouble(),
      hips: (map['hips'] as num?)?.toDouble(),
      biceps: (map['biceps'] as num?)?.toDouble(),
      thigh: (map['thigh'] as num?)?.toDouble(),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory BodyMeasurementEntry.fromJson(String source) =>
      BodyMeasurementEntry.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
