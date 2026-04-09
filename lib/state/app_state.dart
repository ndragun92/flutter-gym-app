import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/body_measurement_entry.dart';
import '../models/body_progress_photo.dart';
import '../models/meal_entry.dart';
import '../models/user_profile.dart';
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
  static const _bodyProgressGalleryKey = 'body_progress_gallery';
  static const _workoutLogsKey = 'workout_logs';
  static const _gymScheduleKey = 'gym_schedule';
  static const _goalsKey = 'goals';
  static const _userProfileKey = 'user_profile';
  static const _backupVersion = 1;
  static const _profileImageAssetKey = 'profile_image';

  bool isLoading = true;

  List<MealEntry> mealEntries = [];
  List<MealSchedule> mealSchedules = [];
  List<MealItem> mealItems = [];
  List<MealPlanItem> mealPlanItems = [];
  List<BodyMeasurementEntry> bodyMeasurements = [];
  List<BodyProgressPhoto> bodyProgressPhotos = [];
  List<WorkoutEntry> workoutEntries = [];
  List<GymSchedule> gymSchedules = [];
  UserProfile? userProfile;

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

    bodyProgressPhotos = _decodeList(
      prefs.getStringList(_bodyProgressGalleryKey),
      (e) => BodyProgressPhoto.fromMap(e),
    )..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));

    workoutEntries = _decodeList(
      prefs.getStringList(_workoutLogsKey),
      (e) => WorkoutEntry.fromMap(e),
    )..sort((a, b) => b.date.compareTo(a.date));

    final profileRaw = prefs.getString(_userProfileKey);
    if (profileRaw != null && profileRaw.isNotEmpty) {
      try {
        userProfile = UserProfile.fromMap(
          jsonDecode(profileRaw) as Map<String, dynamic>,
        );
      } catch (_) {
        userProfile = null;
      }
    }

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

    unawaited(_syncAllScheduleNotifications());
  }

  Future<void> _syncAllScheduleNotifications() async {
    await _syncMealScheduleNotifications();
    await _syncGymScheduleNotifications();
  }

  Future<void> _syncMealScheduleNotifications() async {
    try {
      await NotificationService.instance.scheduleMealReminders(
        List<MealSchedule>.unmodifiable(mealSchedules),
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to sync meal reminders: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _syncGymScheduleNotifications() async {
    try {
      await NotificationService.instance.scheduleGymReminders(
        List<GymSchedule>.unmodifiable(gymSchedules),
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to sync gym reminders: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
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

  Future<void> _saveUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    if (userProfile == null) {
      await prefs.remove(_userProfileKey);
      return;
    }
    await prefs.setString(_userProfileKey, userProfile!.toJson());
  }

  Future<void> _saveAllState() async {
    await _saveList(_mealLogsKey, mealEntries.map((e) => e.toMap()).toList());
    await _saveList(
      _mealScheduleKey,
      mealSchedules.map((e) => e.toMap()).toList(),
    );
    await _saveList(_mealItemsKey, mealItems.map((e) => e.toMap()).toList());
    await _saveList(_mealPlanKey, mealPlanItems.map((e) => e.toMap()).toList());
    await _saveList(
      _bodyMeasurementKey,
      bodyMeasurements.map((e) => e.toMap()).toList(),
    );
    await _saveList(
      _bodyProgressGalleryKey,
      bodyProgressPhotos.map((e) => e.toMap()).toList(),
    );
    await _saveList(
      _workoutLogsKey,
      workoutEntries.map((e) => e.toMap()).toList(),
    );
    await _saveList(
      _gymScheduleKey,
      gymSchedules.map((e) => e.toMap()).toList(),
    );
    await _saveUserProfile();
    await _saveGoals();
  }

  Set<String> _collectReferencedImagePaths() {
    final paths = <String>{};

    void addPath(String? path) {
      if (path == null || path.isEmpty) return;
      paths.add(path);
    }

    addPath(userProfile?.profileImagePath);
    for (final item in mealItems) {
      addPath(item.imagePath);
    }
    for (final measurement in bodyMeasurements) {
      addPath(measurement.imagePath);
    }
    for (final photo in bodyProgressPhotos) {
      addPath(photo.imagePath);
    }

    return paths;
  }

  Future<Map<String, dynamic>?> _encodeImageAsset(String? path) async {
    if (path == null || path.isEmpty) return null;

    final file = File(path);
    if (!await file.exists()) return null;

    final fileName = path.split(Platform.pathSeparator).last;
    return {
      'fileName': fileName,
      'bytesBase64': base64Encode(await file.readAsBytes()),
    };
  }

  Future<Map<String, dynamic>> _buildBackupAssets() async {
    final assets = <String, dynamic>{};

    final profileAsset = await _encodeImageAsset(userProfile?.profileImagePath);
    if (profileAsset != null) {
      assets[_profileImageAssetKey] = profileAsset;
    }

    for (final item in mealItems) {
      final asset = await _encodeImageAsset(item.imagePath);
      if (asset != null) {
        assets['meal_item_${item.id}'] = asset;
      }
    }

    for (final measurement in bodyMeasurements) {
      final asset = await _encodeImageAsset(measurement.imagePath);
      if (asset != null) {
        assets['body_measurement_${measurement.id}'] = asset;
      }
    }

    for (final photo in bodyProgressPhotos) {
      final asset = await _encodeImageAsset(photo.imagePath);
      if (asset != null) {
        assets['body_gallery_${photo.id}'] = asset;
      }
    }

    return assets;
  }

  List<Map<String, dynamic>> _parseBackupList(Object? raw, String fieldName) {
    if (raw == null) return const [];
    if (raw is! List) {
      throw FormatException('Invalid backup field: $fieldName');
    }

    return raw.map((entry) {
      if (entry is! Map) {
        throw FormatException('Invalid backup item in $fieldName');
      }
      return Map<String, dynamic>.from(entry);
    }).toList();
  }

  String _safeAssetFileName(String assetKey, String? originalFileName) {
    final extension = originalFileName != null && originalFileName.contains('.')
        ? originalFileName.substring(originalFileName.lastIndexOf('.'))
        : '.bin';
    final safeKey = assetKey.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return '$safeKey$extension';
  }

  Future<String?> _restoreImageAsset({
    required String assetKey,
    required Map<String, dynamic> assets,
    required Directory assetDirectory,
  }) async {
    final rawAsset = assets[assetKey];
    if (rawAsset is! Map) return null;

    final asset = Map<String, dynamic>.from(rawAsset);
    final bytesBase64 = asset['bytesBase64'] as String?;
    if (bytesBase64 == null || bytesBase64.isEmpty) return null;

    final fileName = _safeAssetFileName(assetKey, asset['fileName'] as String?);
    final file = File('${assetDirectory.path}/$fileName');
    await file.writeAsBytes(base64Decode(bytesBase64), flush: true);
    return file.path;
  }

  Future<String> exportBackupJson() async {
    final assets = await _buildBackupAssets();
    return jsonEncode({
      'version': _backupVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'payload': {
        'mealEntries': mealEntries.map((e) => e.toMap()).toList(),
        'mealSchedules': mealSchedules.map((e) => e.toMap()).toList(),
        'mealItems': mealItems.map((e) => e.toMap()).toList(),
        'mealPlanItems': mealPlanItems.map((e) => e.toMap()).toList(),
        'bodyMeasurements': bodyMeasurements.map((e) => e.toMap()).toList(),
        'bodyProgressPhotos': bodyProgressPhotos.map((e) => e.toMap()).toList(),
        'workoutEntries': workoutEntries.map((e) => e.toMap()).toList(),
        'gymSchedules': gymSchedules.map((e) => e.toMap()).toList(),
        'userProfile': userProfile?.toMap(),
        'goals': {
          'dailyCalorieGoal': dailyCalorieGoal,
          'dailyProteinGoal': dailyProteinGoal,
          'weeklyWorkoutGoal': weeklyWorkoutGoal,
        },
      },
      'assets': assets,
    });
  }

  Future<void> importBackupJson(String source) async {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException('Invalid backup file');
    }

    final backup = Map<String, dynamic>.from(decoded);
    final version = (backup['version'] as num?)?.toInt();
    if (version != _backupVersion) {
      throw FormatException('Unsupported backup version: $version');
    }

    final rawPayload = backup['payload'];
    if (rawPayload is! Map) {
      throw const FormatException('Missing backup payload');
    }

    final payload = Map<String, dynamic>.from(rawPayload);
    final assets = backup['assets'] is Map
        ? Map<String, dynamic>.from(backup['assets'] as Map)
        : <String, dynamic>{};

    final previousImagePaths = _collectReferencedImagePaths();
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final assetDirectory = Directory(
      '${documentsDirectory.path}/imported_assets',
    );
    if (!await assetDirectory.exists()) {
      await assetDirectory.create(recursive: true);
    }

    final importedMealEntries =
        _parseBackupList(
            payload['mealEntries'],
            'mealEntries',
          ).map(MealEntry.fromMap).toList()
          ..sort((a, b) => b.ateAt.compareTo(a.ateAt));

    final importedMealSchedules =
        _parseBackupList(
          payload['mealSchedules'],
          'mealSchedules',
        ).map(MealSchedule.fromMap).toList()..sort(
          (a, b) => _toMinutes(
            a.hour,
            a.minute,
          ).compareTo(_toMinutes(b.hour, b.minute)),
        );

    final importedMealItems = <MealItem>[];
    for (final itemMap in _parseBackupList(payload['mealItems'], 'mealItems')) {
      final restoredImagePath = await _restoreImageAsset(
        assetKey: 'meal_item_${itemMap['id']}',
        assets: assets,
        assetDirectory: assetDirectory,
      );
      importedMealItems.add(
        MealItem.fromMap({...itemMap, 'imagePath': restoredImagePath}),
      );
    }

    final importedMealPlanItems = _parseBackupList(
      payload['mealPlanItems'],
      'mealPlanItems',
    ).map(MealPlanItem.fromMap).toList();

    final importedBodyMeasurements = <BodyMeasurementEntry>[];
    for (final measurementMap in _parseBackupList(
      payload['bodyMeasurements'],
      'bodyMeasurements',
    )) {
      final restoredImagePath = await _restoreImageAsset(
        assetKey: 'body_measurement_${measurementMap['id']}',
        assets: assets,
        assetDirectory: assetDirectory,
      );
      importedBodyMeasurements.add(
        BodyMeasurementEntry.fromMap({
          ...measurementMap,
          'imagePath': restoredImagePath,
        }),
      );
    }
    importedBodyMeasurements.sort((a, b) => b.date.compareTo(a.date));

    final importedBodyProgressPhotos = <BodyProgressPhoto>[];
    for (final photoMap in _parseBackupList(
      payload['bodyProgressPhotos'],
      'bodyProgressPhotos',
    )) {
      final restoredImagePath = await _restoreImageAsset(
        assetKey: 'body_gallery_${photoMap['id']}',
        assets: assets,
        assetDirectory: assetDirectory,
      );
      if (restoredImagePath == null || restoredImagePath.isEmpty) {
        continue;
      }
      importedBodyProgressPhotos.add(
        BodyProgressPhoto.fromMap({
          ...photoMap,
          'imagePath': restoredImagePath,
        }),
      );
    }
    importedBodyProgressPhotos.sort(
      (a, b) => b.capturedAt.compareTo(a.capturedAt),
    );

    final importedWorkoutEntries =
        _parseBackupList(
            payload['workoutEntries'],
            'workoutEntries',
          ).map(WorkoutEntry.fromMap).toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    final importedGymSchedules =
        _parseBackupList(
          payload['gymSchedules'],
          'gymSchedules',
        ).map(GymSchedule.fromMap).toList()..sort((a, b) {
          final byDay = a.weekday.compareTo(b.weekday);
          if (byDay != 0) return byDay;
          return _toMinutes(
            a.hour,
            a.minute,
          ).compareTo(_toMinutes(b.hour, b.minute));
        });

    UserProfile? importedUserProfile;
    final rawProfile = payload['userProfile'];
    if (rawProfile != null) {
      if (rawProfile is! Map) {
        throw const FormatException('Invalid backup field: userProfile');
      }
      final profileMap = Map<String, dynamic>.from(rawProfile);
      final restoredProfileImagePath = await _restoreImageAsset(
        assetKey: _profileImageAssetKey,
        assets: assets,
        assetDirectory: assetDirectory,
      );
      importedUserProfile = UserProfile.fromMap({
        ...profileMap,
        'profileImagePath': restoredProfileImagePath,
      });
    }

    dailyCalorieGoal = 2500;
    dailyProteinGoal = 190;
    weeklyWorkoutGoal = 4;

    final rawGoals = payload['goals'];
    if (rawGoals != null) {
      if (rawGoals is! Map) {
        throw const FormatException('Invalid backup field: goals');
      }
      final goals = Map<String, dynamic>.from(rawGoals);
      final calories = (goals['dailyCalorieGoal'] as num?)?.toInt();
      final protein = (goals['dailyProteinGoal'] as num?)?.toDouble();
      final workouts = (goals['weeklyWorkoutGoal'] as num?)?.toInt();
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

    mealEntries = importedMealEntries;
    mealSchedules = importedMealSchedules;
    mealItems = importedMealItems;
    mealPlanItems = importedMealPlanItems;
    bodyMeasurements = importedBodyMeasurements;
    bodyProgressPhotos = importedBodyProgressPhotos;
    workoutEntries = importedWorkoutEntries;
    gymSchedules = importedGymSchedules;
    userProfile = importedUserProfile;
    _recalculateMealPlanTotals();

    await _saveAllState();

    final importedImagePaths = _collectReferencedImagePaths();
    for (final previousPath in previousImagePaths) {
      if (!importedImagePaths.contains(previousPath)) {
        await _deleteLocalImageIfObsolete(previousPath, null);
      }
    }

    notifyListeners();
    unawaited(_syncAllScheduleNotifications());
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
    required double baseMassGrams,
    required double massGrams,
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
        baseMassGrams: baseMassGrams,
        massGrams: massGrams,
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
    required double baseMassGrams,
    required double massGrams,
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
                  baseMassGrams: baseMassGrams,
                  massGrams: massGrams,
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
      calories += item.scaledCalories;
      protein += item.scaledProtein;
      carbs += item.scaledCarbs;
      fat += item.scaledFat;
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
    notifyListeners();
    unawaited(_syncMealScheduleNotifications());
  }

  Future<void> toggleMealSchedule(String id, bool enabled) async {
    mealSchedules = mealSchedules
        .map((e) => e.id == id ? e.copyWith(enabled: enabled) : e)
        .toList();
    await _saveList(
      _mealScheduleKey,
      mealSchedules.map((e) => e.toMap()).toList(),
    );
    notifyListeners();
    unawaited(_syncMealScheduleNotifications());
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
    notifyListeners();
    unawaited(_syncMealScheduleNotifications());
  }

  Future<void> removeMealSchedule(String id) async {
    mealSchedules.removeWhere((e) => e.id == id);
    await _saveList(
      _mealScheduleKey,
      mealSchedules.map((e) => e.toMap()).toList(),
    );
    notifyListeners();
    unawaited(_syncMealScheduleNotifications());
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

  Future<void> addBodyProgressPhoto({
    required String imagePath,
    DateTime? capturedAt,
  }) async {
    bodyProgressPhotos.insert(
      0,
      BodyProgressPhoto(
        id: _id(),
        imagePath: imagePath,
        capturedAt: capturedAt ?? DateTime.now(),
      ),
    );
    bodyProgressPhotos.sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    await _saveList(
      _bodyProgressGalleryKey,
      bodyProgressPhotos.map((e) => e.toMap()).toList(),
    );
    notifyListeners();
  }

  Future<void> removeBodyProgressPhoto(String id) async {
    String? imagePath;
    for (final photo in bodyProgressPhotos) {
      if (photo.id == id) {
        imagePath = photo.imagePath;
        break;
      }
    }

    bodyProgressPhotos.removeWhere((e) => e.id == id);
    await _saveList(
      _bodyProgressGalleryKey,
      bodyProgressPhotos.map((e) => e.toMap()).toList(),
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
    notifyListeners();
    unawaited(_syncGymScheduleNotifications());
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
    notifyListeners();
    unawaited(_syncGymScheduleNotifications());
  }

  Future<void> toggleGymSchedule(String id, bool enabled) async {
    gymSchedules = gymSchedules
        .map((e) => e.id == id ? e.copyWith(enabled: enabled) : e)
        .toList();
    await _saveList(
      _gymScheduleKey,
      gymSchedules.map((e) => e.toMap()).toList(),
    );
    notifyListeners();
    unawaited(_syncGymScheduleNotifications());
  }

  Future<void> removeGymSchedule(String id) async {
    gymSchedules.removeWhere((e) => e.id == id);
    await _saveList(
      _gymScheduleKey,
      gymSchedules.map((e) => e.toMap()).toList(),
    );
    notifyListeners();
    unawaited(_syncGymScheduleNotifications());
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

  int? get profileAge {
    final profile = userProfile;
    if (profile == null) return null;
    final age = profile.ageAt(DateTime.now());
    if (age < 0) return null;
    return age;
  }

  double? get latestWeightKg =>
      bodyMeasurements.isEmpty ? null : bodyMeasurements.first.weight;

  double? get currentBmi {
    final profile = userProfile;
    final weight = latestWeightKg;
    if (profile == null || weight == null || profile.heightCm <= 0) {
      return null;
    }
    final heightInMeters = profile.heightCm / 100;
    final bmi = weight / (heightInMeters * heightInMeters);
    return bmi.isFinite ? bmi : null;
  }

  String? get currentBmiCategory {
    final bmi = currentBmi;
    if (bmi == null) return null;
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Healthy';
    if (bmi < 30) return 'Overweight';
    return 'Obesity';
  }

  double? get healthyWeightMinKg {
    final profile = userProfile;
    if (profile == null || profile.heightCm <= 0) return null;
    final heightInMeters = profile.heightCm / 100;
    return 18.5 * heightInMeters * heightInMeters;
  }

  double? get healthyWeightMaxKg {
    final profile = userProfile;
    if (profile == null || profile.heightCm <= 0) return null;
    final heightInMeters = profile.heightCm / 100;
    return 24.9 * heightInMeters * heightInMeters;
  }

  int? get suggestedDailyCalories {
    final bmi = currentBmi;
    if (bmi == null) return null;

    var adjusted = dailyCalorieGoal;
    if (bmi >= 30) {
      adjusted -= 500;
    } else if (bmi >= 27) {
      adjusted -= 350;
    } else if (bmi >= 25) {
      adjusted -= 250;
    } else if (bmi < 18.5) {
      adjusted += 250;
    }
    return adjusted.clamp(1200, 4000);
  }

  double? get suggestedDailyProtein {
    final weight = latestWeightKg;
    if (weight == null) return null;
    return (weight * 1.8).clamp(60, 260);
  }

  int? get suggestedWeeklyWorkouts {
    final bmi = currentBmi;
    if (bmi == null) return null;
    if (bmi >= 30) return 5;
    if (bmi >= 25) return 4;
    return 4;
  }

  Future<void> updateUserProfile({
    required String fullName,
    required DateTime birthDate,
    required double heightCm,
    String? profileImagePath,
  }) async {
    final previousImagePath = userProfile?.profileImagePath;
    userProfile = UserProfile(
      fullName: fullName,
      birthDate: birthDate,
      heightCm: heightCm.clamp(80, 260),
      profileImagePath: profileImagePath,
    );
    await _saveUserProfile();
    await _deleteLocalImageIfObsolete(previousImagePath, profileImagePath);
    notifyListeners();
  }

  Future<void> applySmartGoalsFromProfile() async {
    final calories = suggestedDailyCalories;
    final protein = suggestedDailyProtein;
    final workouts = suggestedWeeklyWorkouts;
    if (calories == null || protein == null || workouts == null) return;

    dailyCalorieGoal = calories;
    dailyProteinGoal = protein;
    weeklyWorkoutGoal = workouts;
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
