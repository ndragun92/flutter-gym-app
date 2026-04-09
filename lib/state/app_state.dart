import 'dart:convert';
import 'dart:io';

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
  static const _mealItemsKey = 'meal_items';
  static const _mealPlanKey = 'meal_plan';
  static const _bodyMeasurementKey = 'body_measurements';
  static const _workoutLogsKey = 'workout_logs';
  static const _gymScheduleKey = 'gym_schedule';
  static const _goalsKey = 'goals';

  bool isLoading = true;

  List<MealEntry> mealEntries = [];
  List<MealSchedule> mealSchedules = [];
  List<MealItem> mealItems = [];
  List<MealPlanItem> mealPlanItems = [];
  List<BodyMeasurementEntry> bodyMeasurements = [];
  List<WorkoutEntry> workoutEntries = [];
  List<GymSchedule> gymSchedules = [];

  // Personalized defaults for slow cut while preserving muscle.
  int dailyCalorieGoal = 2500;
  double dailyProteinGoal = 190;
  int weeklyWorkoutGoal = 4;

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

    mealItems = _decodeList(
      prefs.getStringList(_mealItemsKey),
      (e) => MealItem.fromMap(e),
    );

    _recalculateMealPlanTotals();

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

    final goalRaw = prefs.getString(_goalsKey);
    if (goalRaw != null && goalRaw.isNotEmpty) {
      try {
        final parsed = jsonDecode(goalRaw) as Map<String, dynamic>;
        final calories = (parsed['dailyCalorieGoal'] as num?)?.toInt();
        final protein = (parsed['dailyProteinGoal'] as num?)?.toDouble();
        final workouts = (parsed['weeklyWorkoutGoal'] as num?)?.toInt();

        // One-time migration from previous defaults.
        final shouldMigrateLegacyDefaults =
            calories == 2200 && protein == 140 && workouts == 4;
        if (shouldMigrateLegacyDefaults) {
          dailyCalorieGoal = 2500;
          dailyProteinGoal = 190;
          weeklyWorkoutGoal = 4;
          await _saveGoals();
        } else {
          if (calories != null && calories > 0) {
            dailyCalorieGoal = calories;
          }
          if (protein != null && protein > 0) {
            dailyProteinGoal = protein;
          }
          if (workouts != null && workouts > 0) {
            weeklyWorkoutGoal = workouts;
          }
        }
      } catch (_) {
        // Keep defaults if persisted data is malformed.
      }
    }

    isLoading = false;
    notifyListeners();

    await NotificationService.instance.scheduleMealReminders(mealSchedules);
    await NotificationService.instance.scheduleGymReminders(gymSchedules);
  }

  Future<void> _saveList(String key, List<Map<String, dynamic>> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, data.map(jsonEncode).toList());
  }

  Future<void> _saveGoals() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _goalsKey,
      jsonEncode({
        'dailyCalorieGoal': dailyCalorieGoal,
        'dailyProteinGoal': dailyProteinGoal,
        'weeklyWorkoutGoal': weeklyWorkoutGoal,
      }),
    );
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
    required List<String> mealItemIds,
  }) async {
    final totals = _mealPlanTotalsForItems(mealItemIds);
    mealPlanItems.add(
      MealPlanItem(
        id: _id(),
        name: name,
        mealItemIds: mealItemIds,
        calories: totals.calories,
        protein: totals.protein,
        carbs: totals.carbs,
        fat: totals.fat,
      ),
    );
    await _saveList(_mealPlanKey, mealPlanItems.map((e) => e.toMap()).toList());
    notifyListeners();
  }

  Future<void> updateMealPlanItem({
    required String id,
    required String name,
    required List<String> mealItemIds,
  }) async {
    final totals = _mealPlanTotalsForItems(mealItemIds);
    mealPlanItems = mealPlanItems
        .map(
          (e) => e.id == id
              ? e.copyWith(
                  name: name,
                  mealItemIds: mealItemIds,
                  calories: totals.calories,
                  protein: totals.protein,
                  carbs: totals.carbs,
                  fat: totals.fat,
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

  Future<void> addMealItem({
    required String name,
    required String portion,
    String? imagePath,
    required int calories,
    required double protein,
    required double carbs,
    required double fat,
  }) async {
    mealItems.add(
      MealItem(
        id: _id(),
        name: name,
        portion: portion,
        imagePath: imagePath,
        calories: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
      ),
    );
    await _saveList(_mealItemsKey, mealItems.map((e) => e.toMap()).toList());
    _recalculateMealPlanTotals();
    await _saveList(_mealPlanKey, mealPlanItems.map((e) => e.toMap()).toList());
    notifyListeners();
  }

  Future<void> updateMealItem({
    required String id,
    required String name,
    required String portion,
    String? imagePath,
    required int calories,
    required double protein,
    required double carbs,
    required double fat,
  }) async {
    String? previousImagePath;
    for (final item in mealItems) {
      if (item.id == id) {
        previousImagePath = item.imagePath;
        break;
      }
    }

    mealItems = mealItems
        .map(
          (e) => e.id == id
              ? e.copyWith(
                  name: name,
                  portion: portion,
                  imagePath: imagePath,
                  calories: calories,
                  protein: protein,
                  carbs: carbs,
                  fat: fat,
                )
              : e,
        )
        .toList();
    await _saveList(_mealItemsKey, mealItems.map((e) => e.toMap()).toList());
    await _deleteLocalImageIfObsolete(previousImagePath, imagePath);
    _recalculateMealPlanTotals();
    await _saveList(_mealPlanKey, mealPlanItems.map((e) => e.toMap()).toList());
    notifyListeners();
  }

  Future<void> removeMealItem(String id) async {
    String? imagePath;
    for (final item in mealItems) {
      if (item.id == id) {
        imagePath = item.imagePath;
        break;
      }
    }

    mealItems.removeWhere((e) => e.id == id);
    mealPlanItems = mealPlanItems
        .map(
          (e) => e.copyWith(
            mealItemIds: e.mealItemIds.where((itemId) => itemId != id).toList(),
          ),
        )
        .toList();
    _recalculateMealPlanTotals();
    await _saveList(_mealItemsKey, mealItems.map((e) => e.toMap()).toList());
    await _saveList(_mealPlanKey, mealPlanItems.map((e) => e.toMap()).toList());
    await _deleteLocalImageIfObsolete(imagePath, null);
    notifyListeners();
  }

  Future<void> _deleteLocalImageIfObsolete(
    String? previous,
    String? current,
  ) async {
    if (previous == null || previous.isEmpty) return;
    if (previous == current) return;
    try {
      final file = File(previous);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Ignore best-effort file cleanup failures.
    }
  }

  _MealTotals _mealPlanTotalsForItems(List<String> mealItemIds) {
    final byId = {for (final item in mealItems) item.id: item};
    var calories = 0;
    var protein = 0.0;
    var carbs = 0.0;
    var fat = 0.0;

    for (final itemId in mealItemIds) {
      final item = byId[itemId];
      if (item == null) continue;
      calories += item.calories;
      protein += item.protein;
      carbs += item.carbs;
      fat += item.fat;
    }

    return _MealTotals(
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
    );
  }

  void _recalculateMealPlanTotals() {
    mealPlanItems = mealPlanItems.map((plan) {
      final totals = _mealPlanTotalsForItems(plan.mealItemIds);
      return plan.copyWith(
        calories: totals.calories,
        protein: totals.protein,
        carbs: totals.carbs,
        fat: totals.fat,
      );
    }).toList();
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
    String? imagePath,
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
        imagePath: imagePath,
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
    String? imagePath;
    for (final measurement in bodyMeasurements) {
      if (measurement.id == id) {
        imagePath = measurement.imagePath;
        break;
      }
    }

    bodyMeasurements.removeWhere((e) => e.id == id);
    await _saveList(
      _bodyMeasurementKey,
      bodyMeasurements.map((e) => e.toMap()).toList(),
    );
    await _deleteLocalImageIfObsolete(imagePath, null);
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

  Future<void> updateWorkoutEntry({
    required String id,
    required DateTime date,
    required String exercise,
    required int sets,
    required int reps,
    required double weight,
    String? notes,
  }) async {
    workoutEntries = workoutEntries
        .map(
          (e) => e.id == id
              ? WorkoutEntry(
                  id: e.id,
                  date: date,
                  exercise: exercise,
                  sets: sets,
                  reps: reps,
                  weight: weight,
                  notes: notes,
                )
              : e,
        )
        .toList();

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

  Future<void> updateGymSchedule({
    required String id,
    required String title,
    required int weekday,
    required int hour,
    required int minute,
  }) async {
    gymSchedules = gymSchedules
        .map(
          (e) => e.id == id
              ? e.copyWith(
                  title: title,
                  weekday: weekday,
                  hour: hour,
                  minute: minute,
                )
              : e,
        )
        .toList();

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

  Future<void> updateGoals({
    required int dailyCalories,
    required double dailyProtein,
    required int weeklyWorkouts,
  }) async {
    dailyCalorieGoal = dailyCalories.clamp(1, 20000);
    dailyProteinGoal = dailyProtein.clamp(1, 1000);
    weeklyWorkoutGoal = weeklyWorkouts.clamp(1, 14);
    await _saveGoals();
    notifyListeners();
  }
}

class _MealTotals {
  const _MealTotals({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  final int calories;
  final double protein;
  final double carbs;
  final double fat;
}
