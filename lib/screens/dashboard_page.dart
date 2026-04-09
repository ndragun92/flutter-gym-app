import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/body_measurement_entry.dart';
import '../models/workout_entry.dart';
import '../state/app_state.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final now = DateTime.now();

    final todaysMeals = appState.mealEntries.where((meal) {
      return meal.ateAt.year == now.year &&
          meal.ateAt.month == now.month &&
          meal.ateAt.day == now.day;
    }).toList();

    final totalCalories = todaysMeals.fold<int>(
      0,
      (sum, meal) => sum + meal.calories,
    );
    final totalProtein = todaysMeals.fold<double>(
      0,
      (sum, meal) => sum + meal.protein,
    );
    final totalCarbs = todaysMeals.fold<double>(
      0,
      (sum, meal) => sum + meal.carbs,
    );
    final totalFat = todaysMeals.fold<double>(0, (sum, meal) => sum + meal.fat);
    final startOfWeek = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final weeklyWorkouts = appState.workoutEntries
        .where((entry) => !entry.date.isBefore(startOfWeek))
        .length;
    final hasWorkoutToday = appState.workoutEntries.any(
      (entry) =>
          entry.date.year == now.year &&
          entry.date.month == now.month &&
          entry.date.day == now.day,
    );
    final proteinLeft = (appState.dailyProteinGoal - totalProtein).clamp(
      0.0,
      9999.0,
    );
    final calorieDelta = appState.dailyCalorieGoal - totalCalories;
    final workoutsLeft = (appState.weeklyWorkoutGoal - weeklyWorkouts).clamp(
      0,
      99,
    );

    final calorieRatio = appState.dailyCalorieGoal <= 0
        ? 0.0
        : totalCalories / appState.dailyCalorieGoal;
    final calorieAdherence = calorieRatio <= 1
        ? calorieRatio
        : (2 - calorieRatio).clamp(0.0, 1.0);
    final proteinProgress = appState.dailyProteinGoal <= 0
        ? 0.0
        : (totalProtein / appState.dailyProteinGoal).clamp(0.0, 1.0);
    final todayCompletion =
        (((todaysMeals.isNotEmpty ? 1.0 : 0.0) +
                    calorieAdherence +
                    proteinProgress +
                    (hasWorkoutToday ? 1.0 : 0.0)) /
                4 *
                100)
            .round();

    final nextMeal = _nextMeal(appState);
    final nextGym = _nextGym(appState.gymSchedules);

    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentOrange = colorScheme.secondary;
    final accentRed = isDark
        ? const Color(0xFFF48FB1)
        : Colors.pinkAccent; // pink-200 in dark
    final accentBlue = isDark
        ? const Color(0xFF81D4FA)
        : Colors.lightBlueAccent; // lightBlue-200 in dark
    final accentTeal = colorScheme.primary;
    final accentPurple = isDark
        ? const Color(0xFFCE93D8)
        : Colors.deepPurpleAccent; // purple-200 in dark
    final secondaryText = colorScheme.onSurface.withOpacity(0.7);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Your daily dashboard',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          DateFormat('EEEE, d MMMM').format(now),
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: secondaryText),
        ),
        const SizedBox(height: 12),
        _ProfileSnapshotCard(appState: appState),
        const SizedBox(height: 16),
        _SummaryCard(
          title: 'Calories today',
          value: '$totalCalories kcal',
          icon: Icons.local_fire_department_rounded,
          color: accentOrange,
        ),
        const SizedBox(height: 12),
        _GoalProgressCard(
          consumedCalories: totalCalories,
          consumedProtein: totalProtein,
          weeklyWorkouts: weeklyWorkouts,
          calorieGoal: appState.dailyCalorieGoal,
          proteinGoal: appState.dailyProteinGoal,
          workoutGoal: appState.weeklyWorkoutGoal,
          onEditGoals: () => _openGoalsDialog(context, appState),
        ),
        const SizedBox(height: 12),
        _TodayCompletionCard(
          score: todayCompletion,
          mealLogged: todaysMeals.isNotEmpty,
          proteinGoalReached: proteinLeft <= 0.1,
          caloriesOnTrack: calorieDelta >= 0,
          workoutLogged: hasWorkoutToday,
        ),
        const SizedBox(height: 12),
        _SmartNudgesCard(
          proteinLeft: proteinLeft,
          calorieDelta: calorieDelta,
          workoutsLeft: workoutsLeft,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MacroCard(
                label: 'Protein',
                value: '${totalProtein.toStringAsFixed(1)} g',
                color: accentRed,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MacroCard(
                label: 'Carbs',
                value: '${totalCarbs.toStringAsFixed(1)} g',
                color: accentBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MacroCard(
                label: 'Fat',
                value: '${totalFat.toStringAsFixed(1)} g',
                color: accentTeal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SummaryCard(
          title: 'Next meal reminder',
          value: nextMeal,
          icon: Icons.alarm,
          color: accentTeal,
        ),
        const SizedBox(height: 12),
        _SummaryCard(
          title: 'Next gym session',
          value: nextGym,
          icon: Icons.fitness_center_rounded,
          color: accentPurple,
        ),
        const SizedBox(height: 12),
        _BodyProgressCard(entries: appState.bodyMeasurements),
      ],
    );
  }

  String _nextMeal(AppState appState) {
    final now = DateTime.now();
    final enabled = appState.mealSchedules.where((m) => m.enabled).toList();
    if (enabled.isEmpty) {
      return 'No meal reminders configured';
    }

    DateTime? best;
    String? title;
    for (final item in enabled) {
      var candidate = DateTime(
        now.year,
        now.month,
        now.day,
        item.hour,
        item.minute,
      );
      if (candidate.isBefore(now)) {
        candidate = candidate.add(const Duration(days: 1));
      }
      if (best == null || candidate.isBefore(best)) {
        best = candidate;
        title = item.title;
      }
    }

    if (best == null) return 'No meal reminders configured';
    return '${title ?? 'Meal'} · ${DateFormat('EEE HH:mm').format(best)}';
  }

  String _nextGym(List<GymSchedule> schedules) {
    final now = DateTime.now();
    final enabled = schedules.where((g) => g.enabled).toList();
    if (enabled.isEmpty) return 'No gym reminders configured';

    DateTime? best;
    String? title;
    for (final item in enabled) {
      var candidate = DateTime(
        now.year,
        now.month,
        now.day,
        item.hour,
        item.minute,
      );
      while (candidate.weekday != item.weekday || candidate.isBefore(now)) {
        candidate = candidate.add(const Duration(days: 1));
      }
      if (best == null || candidate.isBefore(best)) {
        best = candidate;
        title = item.title;
      }
    }

    if (best == null) return 'No gym reminders configured';
    return '${title ?? 'Gym'} · ${DateFormat('EEE HH:mm').format(best)}';
  }

  Future<void> _openGoalsDialog(BuildContext context, AppState state) async {
    final formKey = GlobalKey<FormState>();
    final calories = TextEditingController(
      text: state.dailyCalorieGoal.toString(),
    );
    final protein = TextEditingController(
      text: state.dailyProteinGoal.toStringAsFixed(0),
    );
    final workouts = TextEditingController(
      text: state.weeklyWorkoutGoal.toString(),
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom:
                math.max(
                  MediaQuery.of(context).viewInsets.bottom,
                  MediaQuery.of(context).viewPadding.bottom,
                ) +
                16,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Edit goals',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: calories,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Daily calorie goal (kcal)',
                  ),
                  validator: (value) {
                    final parsed = int.tryParse((value ?? '').trim());
                    if (parsed == null || parsed <= 0) return 'Invalid value';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: protein,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Daily protein goal (g)',
                  ),
                  validator: (value) {
                    final parsed = double.tryParse((value ?? '').trim());
                    if (parsed == null || parsed <= 0) return 'Invalid value';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: workouts,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Workout sessions per week',
                  ),
                  validator: (value) {
                    final parsed = int.tryParse((value ?? '').trim());
                    if (parsed == null || parsed <= 0) return 'Invalid value';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    await state.updateGoals(
                      dailyCalories: int.parse(calories.text.trim()),
                      dailyProtein: double.parse(protein.text.trim()),
                      weeklyWorkouts: int.parse(workouts.text.trim()),
                    );
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Save goals'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProfileSnapshotCard extends StatelessWidget {
  const _ProfileSnapshotCard({required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final profile = appState.userProfile;
    final hasProfile = profile != null;
    final profileImagePath = profile?.profileImagePath;
    final hasImage =
        hasProfile &&
        profileImagePath != null &&
        profileImagePath.isNotEmpty &&
        File(profileImagePath).existsSync();

    final bmi = appState.currentBmi;
    final bmiLabel = appState.currentBmiCategory;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundImage: hasImage
                  ? FileImage(File(profileImagePath))
                  : null,
              child: hasImage ? null : const Icon(Icons.person_rounded),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile?.fullName ?? 'Set up your profile',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    !hasProfile
                        ? 'Add full name, birth date, and height in Profile tab.'
                        : [
                            if (appState.profileAge != null)
                              '${appState.profileAge} yrs',
                            '${profile.heightCm.toStringAsFixed(1)} cm',
                            if (bmi != null)
                              'BMI ${bmi.toStringAsFixed(1)} (${bmiLabel ?? ''})',
                          ].join(' · '),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.72),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalProgressCard extends StatelessWidget {
  const _GoalProgressCard({
    required this.consumedCalories,
    required this.consumedProtein,
    required this.weeklyWorkouts,
    required this.calorieGoal,
    required this.proteinGoal,
    required this.workoutGoal,
    required this.onEditGoals,
  });

  final int consumedCalories;
  final double consumedProtein;
  final int weeklyWorkouts;
  final int calorieGoal;
  final double proteinGoal;
  final int workoutGoal;
  final VoidCallback onEditGoals;

  @override
  Widget build(BuildContext context) {
    final calorieProgress = calorieGoal <= 0
        ? 0.0
        : (consumedCalories / calorieGoal).clamp(0.0, 1.0);
    final proteinProgress = proteinGoal <= 0
        ? 0.0
        : (consumedProtein / proteinGoal).clamp(0.0, 1.0);
    final workoutProgress = workoutGoal <= 0
        ? 0.0
        : (weeklyWorkouts / workoutGoal).clamp(0.0, 1.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Goals progress',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: onEditGoals,
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Edit'),
                ),
              ],
            ),
            _ProgressRow(
              label: 'Calories',
              value: '$consumedCalories / $calorieGoal kcal',
              progress: calorieProgress,
            ),
            const SizedBox(height: 10),
            _ProgressRow(
              label: 'Protein',
              value:
                  '${consumedProtein.toStringAsFixed(1)} / ${proteinGoal.toStringAsFixed(0)} g',
              progress: proteinProgress,
            ),
            const SizedBox(height: 10),
            _ProgressRow(
              label: 'Workouts this week',
              value: '$weeklyWorkouts / $workoutGoal sessions',
              progress: workoutProgress,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.label,
    required this.value,
    required this.progress,
  });

  final String label;
  final String value;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.labelLarge),
            ),
            Text(value, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: clamped,
            minHeight: 8,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }
}

class _TodayCompletionCard extends StatelessWidget {
  const _TodayCompletionCard({
    required this.score,
    required this.mealLogged,
    required this.proteinGoalReached,
    required this.caloriesOnTrack,
    required this.workoutLogged,
  });

  final int score;
  final bool mealLogged;
  final bool proteinGoalReached;
  final bool caloriesOnTrack;
  final bool workoutLogged;

  @override
  Widget build(BuildContext context) {
    final normalizedScore = score.clamp(0, 100);
    final progress = (normalizedScore / 100).clamp(0.0, 1.0);
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Today completion score',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 72,
                  height: 72,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 8,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                      ),
                      Center(
                        child: Text(
                          '$normalizedScore%',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    normalizedScore >= 80
                        ? 'Excellent pace today. Keep this consistency.'
                        : normalizedScore >= 60
                        ? 'Good progress. One more action can push it higher.'
                        : 'Start with one quick action: meal log or workout log.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                const gap = 6.0;
                final itemWidth = (constraints.maxWidth - gap) / 2;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    SizedBox(
                      width: itemWidth,
                      child: _StatusChip(
                        label: 'Meal logged',
                        done: mealLogged,
                        icon: Icons.restaurant_rounded,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _StatusChip(
                        label: 'Protein target',
                        done: proteinGoalReached,
                        icon: Icons.egg_alt_rounded,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _StatusChip(
                        label: 'Calories on track',
                        done: caloriesOnTrack,
                        icon: Icons.local_fire_department_rounded,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _StatusChip(
                        label: 'Workout logged',
                        done: workoutLogged,
                        icon: Icons.fitness_center_rounded,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SmartNudgesCard extends StatelessWidget {
  const _SmartNudgesCard({
    required this.proteinLeft,
    required this.calorieDelta,
    required this.workoutsLeft,
  });

  final double proteinLeft;
  final int calorieDelta;
  final int workoutsLeft;

  @override
  Widget build(BuildContext context) {
    final workoutSuffix = workoutsLeft == 1 ? '' : 's';
    final nudges = <String>[
      proteinLeft > 0.1
          ? 'Protein left today: ${proteinLeft.toStringAsFixed(0)} g. Add a lean-protein meal.'
          : 'Protein target reached today. Great job.',
      calorieDelta >= 0
          ? '$calorieDelta kcal remaining today.'
          : 'You are ${-calorieDelta} kcal above target. Keep the next meal lighter.',
      workoutsLeft > 0
          ? '$workoutsLeft workout$workoutSuffix left this week to hit goal.'
          : 'Weekly workout goal completed. Nice momentum.',
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Smart nudges',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final nudge in nudges) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Icon(
                      Icons.bolt_rounded,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      nudge,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              if (nudge != nudges.last) const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.done,
    required this.icon,
  });

  final String label;
  final bool done;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: done
            ? colorScheme.primary.withOpacity(0.16)
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          Icon(
            done ? Icons.check_circle_rounded : icon,
            size: 14,
            color: done ? colorScheme.primary : colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: color.withOpacity(0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(12),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroCard extends StatelessWidget {
  const _MacroCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        child: Column(
          children: [
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: color),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _BodyProgressCard extends StatelessWidget {
  const _BodyProgressCard({required this.entries});

  final List<BodyMeasurementEntry> entries;

  @override
  Widget build(BuildContext context) {
    final latest = entries.isNotEmpty ? entries.first : null;
    final oldest = entries.length >= 2 ? entries.last : null;
    final waistDelta = (latest != null && oldest != null)
        ? _nullableDelta(latest.waist, oldest.waist)
        : null;
    final chestDelta = (latest != null && oldest != null)
        ? _nullableDelta(latest.chest, oldest.chest)
        : null;
    final hipsDelta = (latest != null && oldest != null)
        ? _nullableDelta(latest.hips, oldest.hips)
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Body progress snapshot',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              latest == null
                  ? 'No body measurements yet.'
                  : 'Updated ${DateFormat('d MMM yyyy').format(latest.date)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            if (latest == null) ...[
              const SizedBox(height: 10),
              Text(
                'Add your first measurement in the Measurements tab to see current weight and progress highlights here.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ] else ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      Icons.monitor_weight_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current weight',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        Text(
                          '${latest.weight.toStringAsFixed(1)} kg',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (latest.waist != null) ...[
                      _MetricChip(
                        'Waist',
                        '${latest.waist!.toStringAsFixed(1)} cm',
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (latest.chest != null) ...[
                      _MetricChip(
                        'Chest',
                        '${latest.chest!.toStringAsFixed(1)} cm',
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (latest.hips != null) ...[
                      _MetricChip(
                        'Hips',
                        '${latest.hips!.toStringAsFixed(1)} cm',
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (latest.biceps != null) ...[
                      _MetricChip(
                        'Biceps',
                        '${latest.biceps!.toStringAsFixed(1)} cm',
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (latest.thigh != null)
                      _MetricChip(
                        'Thigh',
                        '${latest.thigh!.toStringAsFixed(1)} cm',
                      ),
                  ],
                ),
              ),
              if (oldest != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Progress highlights',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _DeltaChip(
                        'Weight ${_formatDelta(latest.weight - oldest.weight)} kg',
                      ),
                      if (waistDelta != null) ...[
                        const SizedBox(width: 6),
                        _DeltaChip('Waist ${_formatDelta(waistDelta)} cm'),
                      ],
                      if (chestDelta != null) ...[
                        const SizedBox(width: 6),
                        _DeltaChip('Chest ${_formatDelta(chestDelta)} cm'),
                      ],
                      if (hipsDelta != null) ...[
                        const SizedBox(width: 6),
                        _DeltaChip('Hips ${_formatDelta(hipsDelta)} cm'),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  double? _nullableDelta(double? current, double? baseline) {
    if (current == null || baseline == null) return null;
    return current - baseline;
  }

  String _formatDelta(double value) {
    final prefix = value > 0 ? '+' : '';
    return '$prefix${value.toStringAsFixed(1)}';
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

class _DeltaChip extends StatelessWidget {
  const _DeltaChip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}
