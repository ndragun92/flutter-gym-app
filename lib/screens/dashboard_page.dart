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
        const SizedBox(height: 16),
        _SummaryCard(
          title: 'Calories today',
          value: '$totalCalories kcal',
          icon: Icons.local_fire_department_rounded,
          color: accentOrange,
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
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (latest.waist != null)
                    _MetricChip(
                      'Waist',
                      '${latest.waist!.toStringAsFixed(1)} cm',
                    ),
                  if (latest.chest != null)
                    _MetricChip(
                      'Chest',
                      '${latest.chest!.toStringAsFixed(1)} cm',
                    ),
                  if (latest.hips != null)
                    _MetricChip(
                      'Hips',
                      '${latest.hips!.toStringAsFixed(1)} cm',
                    ),
                  if (latest.biceps != null)
                    _MetricChip(
                      'Biceps',
                      '${latest.biceps!.toStringAsFixed(1)} cm',
                    ),
                  if (latest.thigh != null)
                    _MetricChip(
                      'Thigh',
                      '${latest.thigh!.toStringAsFixed(1)} cm',
                    ),
                ],
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
