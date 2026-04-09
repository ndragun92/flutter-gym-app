import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/body_measurement_entry.dart';
import '../models/meal_entry.dart';
import '../models/workout_entry.dart';
import '../services/notification_service.dart';

class AppState extends ChangeNotifier {
  AppState() {
    load();
  }

  static const _mealLogsKey = 'meal_logs';
  static const _mealScheduleKey = 'meal_schedule';
  static const _mealPlanKey = 'meal_plan';
  static const _bodyMeasurementKey = 'body_measurements';
  static const _workoutLogsKey = 'workout_logs';
  static const _gymScheduleKey = 'gym_schedule';

  bool isLoading = true;

  List<MealEntry> mealEntries = [];
  List<MealSchedule> mealSchedules = [];
  List<MealPlanItem> mealPlanItems = [];
  List<BodyMeasurementEntry> bodyMeasurements = [];
  List<WorkoutEntry> workoutEntries = [];
  List<GymSchedule> gymSchedules = [];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    mealEntries = _decodeList(
      prefs.getStringList(_mealLogsKey),
      (e) => MealEntry.fromMap(e),
    )..sort((a, b) => b.ateAt.compareTo(a.ateAt));

    mealSchedules =
        _decodeList(
          prefs.getStringList(_mealScheduleKey),
          (e) => MealSchedule.fromMap(e),
        )..sort(
          (a, b) => _toMinutes(
            a.hour,
            a.minute,
          ).compareTo(_toMinutes(b.hour, b.minute)),
        );

    mealPlanItems = _decodeList(
      prefs.getStringList(_mealPlanKey),
      (e) => MealPlanItem.fromMap(e),
    );

    bodyMeasurements = _decodeList(
      prefs.getStringList(_bodyMeasurementKey),
      (e) => BodyMeasurementEntry.fromMap(e),
    )..sort((a, b) => b.date.compareTo(a.date));

    workoutEntries = _decodeList(
      prefs.getStringList(_workoutLogsKey),
      (e) => WorkoutEntry.fromMap(e),
    )..sort((a, b) => b.date.compareTo(a.date));

    gymSchedules =
        _decodeList(
          prefs.getStringList(_gymScheduleKey),
          (e) => GymSchedule.fromMap(e),
        )..sort((a, b) {
          final byDay = a.weekday.compareTo(b.weekday);
          if (byDay != 0) return byDay;
          return _toMinutes(
            a.hour,
            a.minute,
          ).compareTo(_toMinutes(b.hour, b.minute));
        });

    isLoading = false;
    notifyListeners();

    await NotificationService.instance.scheduleMealReminders(mealSchedules);
    await NotificationService.instance.scheduleGymReminders(gymSchedules);
  }

  Future<void> _saveList(String key, List<Map<String, dynamic>> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, data.map(jsonEncode).toList());
  }

  List<T> _decodeList<T>(
    List<String>? raw,
    T Function(Map<String, dynamic>) parser,
  ) {
    if (raw == null || raw.isEmpty) return [];
    return raw
        .map((value) => parser(jsonDecode(value) as Map<String, dynamic>))
        .toList();
  }

  int _toMinutes(int hour, int minute) => hour * 60 + minute;

  String _id() => DateTime.now().microsecondsSinceEpoch.toString();

  Future<void> addMealEntry({
    required String name,
    required int calories,
    required double protein,
    required double carbs,
    required double fat,
    required DateTime at,
  }) async {
    mealEntries.insert(
      0,
      MealEntry(
        id: _id(),
        name: name,
        calories: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
        ateAt: at,
      ),
    );
    await _saveList(_mealLogsKey, mealEntries.map((e) => e.toMap()).toList());
    notifyListeners();
  }

  Future<void> removeMealEntry(String id) async {
    mealEntries.removeWhere((e) => e.id == id);
    await _saveList(_mealLogsKey, mealEntries.map((e) => e.toMap()).toList());
    notifyListeners();
  }

  Future<void> addMealPlanItem({
    required String name,
    required int calories,
    required double protein,
    required double carbs,
    required double fat,
  }) async {
    mealPlanItems.add(
      MealPlanItem(
        id: _id(),
        name: name,
        calories: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
      ),
    );
    await _saveList(_mealPlanKey, mealPlanItems.map((e) => e.toMap()).toList());
    notifyListeners();
  }

  Future<void> updateMealPlanItem({
    required String id,
    required String name,
    required int calories,
    required double protein,
    required double carbs,
    required double fat,
  }) async {
    mealPlanItems = mealPlanItems
        .map(
          (e) => e.id == id
              ? e.copyWith(
                  name: name,
                  calories: calories,
                  protein: protein,
                  carbs: carbs,
                  fat: fat,
                )
              : e,
        )
        .toList();
    await _saveList(_mealPlanKey, mealPlanItems.map((e) => e.toMap()).toList());
    notifyListeners();
  }

  Future<void> removeMealPlanItem(String id) async {
    mealPlanItems.removeWhere((e) => e.id == id);
    await _saveList(_mealPlanKey, mealPlanItems.map((e) => e.toMap()).toList());
    notifyListeners();
  }

  Future<void> createMealLogFromPlan(String mealPlanId, {DateTime? at}) async {
    MealPlanItem? item;
    for (final e in mealPlanItems) {
      if (e.id == mealPlanId) {
        item = e;
        break;
      }
    }
    if (item == null) return;
    await addMealEntry(
      name: item.name,
      calories: item.calories,
      protein: item.protein,
      carbs: item.carbs,
      fat: item.fat,
      at: at ?? DateTime.now(),
    );
  }

  Future<void> addMealSchedule({
    required String title,
    required int hour,
    required int minute,
  }) async {
    mealSchedules.add(
      MealSchedule(id: _id(), title: title, hour: hour, minute: minute),
    );
    mealSchedules.sort(
      (a, b) =>
          _toMinutes(a.hour, a.minute).compareTo(_toMinutes(b.hour, b.minute)),
    );
    await _saveList(
      _mealScheduleKey,
      mealSchedules.map((e) => e.toMap()).toList(),
    );
    await NotificationService.instance.scheduleMealReminders(mealSchedules);
    notifyListeners();
  }

  Future<void> toggleMealSchedule(String id, bool enabled) async {
    mealSchedules = mealSchedules
        .map((e) => e.id == id ? e.copyWith(enabled: enabled) : e)
        .toList();
    await _saveList(
      _mealScheduleKey,
      mealSchedules.map((e) => e.toMap()).toList(),
    );
    await NotificationService.instance.scheduleMealReminders(mealSchedules);
    notifyListeners();
  }

  Future<void> updateMealSchedule({
    required String id,
    required String title,
    required int hour,
    required int minute,
  }) async {
    mealSchedules = mealSchedules
        .map(
          (e) => e.id == id
              ? e.copyWith(title: title, hour: hour, minute: minute)
              : e,
        )
        .toList();
    mealSchedules.sort(
      (a, b) =>
          _toMinutes(a.hour, a.minute).compareTo(_toMinutes(b.hour, b.minute)),
    );
    await _saveList(
      _mealScheduleKey,
      mealSchedules.map((e) => e.toMap()).toList(),
    );
    await NotificationService.instance.scheduleMealReminders(mealSchedules);
    notifyListeners();
  }

  Future<void> removeMealSchedule(String id) async {
    mealSchedules.removeWhere((e) => e.id == id);
    await _saveList(
      _mealScheduleKey,
      mealSchedules.map((e) => e.toMap()).toList(),
    );
    await NotificationService.instance.scheduleMealReminders(mealSchedules);
    notifyListeners();
  }

  Future<void> addBodyMeasurement({
    required DateTime date,
    required double weight,
    double? waist,
    double? chest,
    double? hips,
    double? biceps,
    double? thigh,
  }) async {
    bodyMeasurements.insert(
      0,
      BodyMeasurementEntry(
        id: _id(),
        date: date,
        weight: weight,
        waist: waist,
        chest: chest,
        hips: hips,
        biceps: biceps,
        thigh: thigh,
      ),
    );
    bodyMeasurements.sort((a, b) => b.date.compareTo(a.date));
    await _saveList(
      _bodyMeasurementKey,
      bodyMeasurements.map((e) => e.toMap()).toList(),
    );
    notifyListeners();
  }

  Future<void> removeBodyMeasurement(String id) async {
    bodyMeasurements.removeWhere((e) => e.id == id);
    await _saveList(
      _bodyMeasurementKey,
      bodyMeasurements.map((e) => e.toMap()).toList(),
    );
    notifyListeners();
  }

  Future<void> addWorkoutEntry({
    required DateTime date,
    required String exercise,
    required int sets,
    required int reps,
    required double weight,
    String? notes,
  }) async {
    workoutEntries.insert(
      0,
      WorkoutEntry(
        id: _id(),
        date: date,
        exercise: exercise,
        sets: sets,
        reps: reps,
        weight: weight,
        notes: notes,
      ),
    );

    workoutEntries.sort((a, b) => b.date.compareTo(a.date));
    await _saveList(
      _workoutLogsKey,
      workoutEntries.map((e) => e.toMap()).toList(),
    );
    notifyListeners();
  }

  Future<void> removeWorkoutEntry(String id) async {
    workoutEntries.removeWhere((e) => e.id == id);
    await _saveList(
      _workoutLogsKey,
      workoutEntries.map((e) => e.toMap()).toList(),
    );
    notifyListeners();
  }

  Future<void> addGymSchedule({
    required String title,
    required int weekday,
    required int hour,
    required int minute,
  }) async {
    gymSchedules.add(
      GymSchedule(
        id: _id(),
        title: title,
        weekday: weekday,
        hour: hour,
        minute: minute,
      ),
    );
    gymSchedules.sort((a, b) {
      final byDay = a.weekday.compareTo(b.weekday);
      if (byDay != 0) return byDay;
      return _toMinutes(
        a.hour,
        a.minute,
      ).compareTo(_toMinutes(b.hour, b.minute));
    });
    await _saveList(
      _gymScheduleKey,
      gymSchedules.map((e) => e.toMap()).toList(),
    );
    await NotificationService.instance.scheduleGymReminders(gymSchedules);
    notifyListeners();
  }

  Future<void> toggleGymSchedule(String id, bool enabled) async {
    gymSchedules = gymSchedules
        .map((e) => e.id == id ? e.copyWith(enabled: enabled) : e)
        .toList();
    await _saveList(
      _gymScheduleKey,
      gymSchedules.map((e) => e.toMap()).toList(),
    );
    await NotificationService.instance.scheduleGymReminders(gymSchedules);
    notifyListeners();
  }

  Future<void> removeGymSchedule(String id) async {
    gymSchedules.removeWhere((e) => e.id == id);
    await _saveList(
      _gymScheduleKey,
      gymSchedules.map((e) => e.toMap()).toList(),
    );
    await NotificationService.instance.scheduleGymReminders(gymSchedules);
    notifyListeners();
  }
}
