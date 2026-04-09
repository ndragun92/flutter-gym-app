import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/meal_entry.dart';
import '../state/app_state.dart';

class NutritionPage extends StatelessWidget {
  const NutritionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final secondaryText = Theme.of(
      context,
    ).colorScheme.onSurface.withOpacity(0.7);

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Nutrition & meals',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Track calories, macros, meal schedule, and your meal plan.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: secondaryText),
          ),
          const SizedBox(height: 16),
          _scheduleSection(context, appState),
          const SizedBox(height: 12),
          _mealPlanSection(context, appState),
          const SizedBox(height: 12),
          _mealLogSection(context, appState),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _scheduleSection(BuildContext context, AppState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Meal schedule',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Add meal schedule',
                  icon: const Icon(Icons.add_rounded),
                  onPressed: () => _openAddOrEditScheduleDialog(context),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (state.mealSchedules.isEmpty)
              Text(
                'No schedule yet. Add your recurring meals.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              ...state.mealSchedules.map((s) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    child: Icon(Icons.access_time_rounded),
                  ),
                  title: Text(s.title),
                  subtitle: Text(s.formattedTime),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch.adaptive(
                        value: s.enabled,
                        onChanged: (v) => state.toggleMealSchedule(s.id, v),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () =>
                            _openAddOrEditScheduleDialog(context, existing: s),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () => state.removeMealSchedule(s.id),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _mealPlanSection(BuildContext context, AppState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Meal plan',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Add meal plan item',
                  icon: const Icon(Icons.add_rounded),
                  onPressed: () => _openAddOrEditMealPlanDialog(context),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (state.mealPlanItems.isEmpty)
              Text(
                'No meal plan yet. Add your planned meals and log them with one tap.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              ...state.mealPlanItems.map((mealPlan) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    child: Icon(Icons.menu_book_rounded),
                  ),
                  title: Text(mealPlan.name),
                  subtitle: Text(
                    '${mealPlan.calories} kcal · P ${mealPlan.protein.toStringAsFixed(1)} · C ${mealPlan.carbs.toStringAsFixed(1)} · F ${mealPlan.fat.toStringAsFixed(1)}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Log as eaten',
                        icon: const Icon(Icons.check_circle_outline_rounded),
                        onPressed: () async {
                          await state.createMealLogFromPlan(mealPlan.id);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Meal logged: ${mealPlan.name}'),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        tooltip: 'Edit meal plan',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _openAddOrEditMealPlanDialog(
                          context,
                          existing: mealPlan,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Delete meal plan',
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () => state.removeMealPlanItem(mealPlan.id),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _mealLogSection(BuildContext context, AppState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Meal log', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            if (state.mealEntries.isEmpty)
              Text(
                'No meals logged yet.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              ...state.mealEntries.take(30).map((MealEntry meal) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    child: Icon(Icons.fastfood_rounded),
                  ),
                  title: Text(meal.name),
                  subtitle: Text(
                    '${DateFormat('d MMM HH:mm').format(meal.ateAt)} · ${meal.calories} kcal\nP ${meal.protein.toStringAsFixed(1)} · C ${meal.carbs.toStringAsFixed(1)} · F ${meal.fat.toStringAsFixed(1)}',
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () => state.removeMealEntry(meal.id),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Future<void> _openAddOrEditScheduleDialog(
    BuildContext context, {
    MealSchedule? existing,
  }) async {
    final titleController = TextEditingController(text: existing?.title ?? '');
    TimeOfDay selectedTime = TimeOfDay(
      hour: existing?.hour ?? TimeOfDay.now().hour,
      minute: existing?.minute ?? TimeOfDay.now().minute,
    );
    final formKey = GlobalKey<FormState>();

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
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      existing == null
                          ? 'New meal schedule'
                          : 'Edit meal schedule',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Meal title',
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.schedule_rounded),
                      label: Text(selectedTime.format(context)),
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                        );
                        if (picked != null) {
                          setState(() => selectedTime = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        if (existing == null) {
                          await context.read<AppState>().addMealSchedule(
                            title: titleController.text.trim(),
                            hour: selectedTime.hour,
                            minute: selectedTime.minute,
                          );
                        } else {
                          await context.read<AppState>().updateMealSchedule(
                            id: existing.id,
                            title: titleController.text.trim(),
                            hour: selectedTime.hour,
                            minute: selectedTime.minute,
                          );
                        }
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: Text(
                        existing == null ? 'Save schedule' : 'Update schedule',
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _openAddOrEditMealPlanDialog(
    BuildContext context, {
    MealPlanItem? existing,
  }) async {
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController(text: existing?.name ?? '');
    final calories = TextEditingController(
      text: existing?.calories.toString() ?? '',
    );
    final protein = TextEditingController(
      text: existing?.protein.toString() ?? '',
    );
    final carbs = TextEditingController(text: existing?.carbs.toString() ?? '');
    final fat = TextEditingController(text: existing?.fat.toString() ?? '');

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
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        existing == null
                            ? 'Add meal plan item'
                            : 'Edit meal plan item',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: name,
                        decoration: const InputDecoration(
                          labelText: 'Meal name',
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 10),
                      _number(
                        calories,
                        'Calories (kcal)',
                        isInt: true,
                        requiredField: true,
                      ),
                      const SizedBox(height: 10),
                      _number(protein, 'Protein (g)', requiredField: true),
                      const SizedBox(height: 10),
                      _number(carbs, 'Carbs (g)', requiredField: true),
                      const SizedBox(height: 10),
                      _number(fat, 'Fat (g)', requiredField: true),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          if (existing == null) {
                            await context.read<AppState>().addMealPlanItem(
                              name: name.text.trim(),
                              calories: int.parse(calories.text.trim()),
                              protein: double.parse(protein.text.trim()),
                              carbs: double.parse(carbs.text.trim()),
                              fat: double.parse(fat.text.trim()),
                            );
                          } else {
                            await context.read<AppState>().updateMealPlanItem(
                              id: existing.id,
                              name: name.text.trim(),
                              calories: int.parse(calories.text.trim()),
                              protein: double.parse(protein.text.trim()),
                              carbs: double.parse(carbs.text.trim()),
                              fat: double.parse(fat.text.trim()),
                            );
                          }
                          if (context.mounted) Navigator.pop(context);
                        },
                        child: Text(
                          existing == null
                              ? 'Save meal plan'
                              : 'Update meal plan',
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _number(
    TextEditingController controller,
    String label, {
    bool isInt = false,
    bool requiredField = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: !isInt),
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        final raw = value?.trim() ?? '';
        if (requiredField && raw.isEmpty) return 'Required';
        if (raw.isNotEmpty) {
          final valid = isInt
              ? int.tryParse(raw) != null
              : double.tryParse(raw) != null;
          if (!valid) return 'Invalid number';
        }
        return null;
      },
    );
  }
}
