import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

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
    final accentOrange = colorScheme.secondary;
    final accentRed = Colors.pinkAccent;
    final accentBlue = Colors.lightBlueAccent;
    final accentTeal = colorScheme.primary;
    final accentPurple = Colors.deepPurpleAccent;
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
      ],
    );
  }

  String _nextMeal(AppState appState) {
    final now = DateTime.now();
    if (appState.mealSchedules.where((m) => m.enabled).isEmpty) {
      return 'No meal reminders configured';
    }

    DateTime? best;
    String? title;

    for (final item in appState.mealSchedules.where((m) => m.enabled)) {
      var date = DateTime(now.year, now.month, now.day, item.hour, item.minute);
      if (date.isBefore(now)) {
        date = date.add(const Duration(days: 1));
      }
      if (best == null || date.isBefore(best)) {
        best = date;
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
