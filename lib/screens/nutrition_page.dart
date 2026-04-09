import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../models/meal_entry.dart';
import '../state/app_state.dart';

class NutritionPage extends StatefulWidget {
  const NutritionPage({super.key, this.isActive = true});

  final bool isActive;

  @override
  State<NutritionPage> createState() => _NutritionPageState();
}

class _NutritionPageState extends State<NutritionPage> {
  int _mealLogResetVersion = 0;

  @override
  void initState() {
    super.initState();
    _resetMealLogExpansion();
  }

  @override
  void didUpdateWidget(covariant NutritionPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _resetMealLogExpansion();
    }
  }

  void _resetMealLogExpansion() {
    if (!mounted) return;
    setState(() {
      _mealLogResetVersion += 1;
    });
  }

  String _dateKey(DateTime value) {
    final day = DateTime(value.year, value.month, value.day);
    return '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final secondaryText = Theme.of(
      context,
    ).colorScheme.onSurface.withOpacity(0.7);

    return Scaffold(
      backgroundColor: Colors.transparent,
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
          _mealItemsSection(context, appState),
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
                  subtitle: Text('Every day at ${s.formattedTime}'),
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
    final mealItemsById = {for (final item in state.mealItems) item.id: item};

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
                    '${mealPlan.mealItemIds.length} items · ${mealPlan.calories} kcal · P ${mealPlan.protein.toStringAsFixed(1)} · C ${mealPlan.carbs.toStringAsFixed(1)} · F ${mealPlan.fat.toStringAsFixed(1)}\n${mealPlan.mealItemIds.map((id) => mealItemsById[id]?.name ?? 'Unknown').join(', ')}',
                  ),
                  isThreeLine: true,
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

  Widget _mealItemsSection(BuildContext context, AppState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Meal items',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Add meal item',
                  icon: const Icon(Icons.add_rounded),
                  onPressed: () => _openAddOrEditMealItemDialog(context),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (state.mealItems.isEmpty)
              Text(
                'No meal items yet. Add ingredients like Egg, Chicken Breast, Rice...',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              ...state.mealItems.map((item) {
                final hasPhoto =
                    item.imagePath != null &&
                    item.imagePath!.isNotEmpty &&
                    File(item.imagePath!).existsSync();
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundImage: hasPhoto
                        ? FileImage(File(item.imagePath!))
                        : null,
                    child: hasPhoto ? null : const Icon(Icons.egg_alt_rounded),
                  ),
                  title: Text(item.name),
                  subtitle: Text(
                    '${item.portion} · ${item.calories} kcal\nP ${item.protein.toStringAsFixed(1)} · C ${item.carbs.toStringAsFixed(1)} · F ${item.fat.toStringAsFixed(1)}',
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Edit meal item',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _openAddOrEditMealItemDialog(
                          context,
                          existing: item,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Delete meal item',
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () => state.removeMealItem(item.id),
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
    final grouped = <DateTime, List<MealEntry>>{};
    for (final meal in state.mealEntries) {
      final day = DateTime(meal.ateAt.year, meal.ateAt.month, meal.ateAt.day);
      grouped.putIfAbsent(day, () => []).add(meal);
    }

    final today = DateTime.now();
    final todayKey = _dateKey(today);

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
              ...grouped.entries.map((entry) {
                final day = entry.key;
                final meals = entry.value;
                final dayKey = _dateKey(day);
                final totalCalories = meals.fold<int>(
                  0,
                  (sum, meal) => sum + meal.calories,
                );

                return ExpansionTile(
                  key: ValueKey('${_mealLogResetVersion}_$dayKey'),
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(top: 4, bottom: 8),
                  initiallyExpanded: dayKey == todayKey,
                  title: Text(
                    dayKey == todayKey
                        ? 'Today'
                        : DateFormat('EEE, d MMM yyyy').format(day),
                  ),
                  subtitle: Text('${meals.length} meals · $totalCalories kcal'),
                  children: meals.map((MealEntry meal) {
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      leading: const CircleAvatar(
                        child: Icon(Icons.fastfood_rounded),
                      ),
                      title: Text(meal.name),
                      subtitle: Text(
                        '${DateFormat('HH:mm').format(meal.ateAt)} · ${meal.calories} kcal\nP ${meal.protein.toStringAsFixed(1)} · C ${meal.carbs.toStringAsFixed(1)} · F ${meal.fat.toStringAsFixed(1)}',
                      ),
                      isThreeLine: true,
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () => state.removeMealEntry(meal.id),
                      ),
                    );
                  }).toList(),
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
                      label: Text(
                        'Every day at ${selectedTime.format(context)}',
                      ),
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
    final state = context.read<AppState>();
    final selectedMealItemIds = <String>{
      ...(existing?.mealItemIds ?? const []),
    };

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
                      Text(
                        'Select meal items for this meal',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      if (state.mealItems.isEmpty)
                        Text(
                          'No meal items available. Add them first in Meal items section.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        )
                      else
                        ...state.mealItems.map((item) {
                          final selected = selectedMealItemIds.contains(
                            item.id,
                          );
                          return CheckboxListTile(
                            value: selected,
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                            title: Text(item.name),
                            subtitle: Text(
                              '${item.portion} · ${item.calories} kcal · P ${item.protein.toStringAsFixed(1)} · C ${item.carbs.toStringAsFixed(1)} · F ${item.fat.toStringAsFixed(1)}',
                            ),
                            onChanged: (checked) {
                              setState(() {
                                if (checked ?? false) {
                                  selectedMealItemIds.add(item.id);
                                } else {
                                  selectedMealItemIds.remove(item.id);
                                }
                              });
                            },
                          );
                        }),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          if (selectedMealItemIds.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Select at least one meal item.'),
                              ),
                            );
                            return;
                          }
                          if (existing == null) {
                            await context.read<AppState>().addMealPlanItem(
                              name: name.text.trim(),
                              mealItemIds: selectedMealItemIds.toList(),
                            );
                          } else {
                            await context.read<AppState>().updateMealPlanItem(
                              id: existing.id,
                              name: name.text.trim(),
                              mealItemIds: selectedMealItemIds.toList(),
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

  Future<void> _openAddOrEditMealItemDialog(
    BuildContext context, {
    MealItem? existing,
  }) async {
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController(text: existing?.name ?? '');
    final portion = TextEditingController(text: existing?.portion ?? '');
    final calories = TextEditingController(
      text: existing?.calories.toString() ?? '',
    );
    final protein = TextEditingController(
      text: existing?.protein.toString() ?? '',
    );
    final carbs = TextEditingController(text: existing?.carbs.toString() ?? '');
    final fat = TextEditingController(text: existing?.fat.toString() ?? '');
    final imagePicker = ImagePicker();
    String? selectedImagePath = existing?.imagePath;

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
            builder: (context, setModalState) {
              final hasImage =
                  selectedImagePath != null &&
                  selectedImagePath!.isNotEmpty &&
                  File(selectedImagePath!).existsSync();

              return Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        existing == null ? 'Add meal item' : 'Edit meal item',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: name,
                        decoration: const InputDecoration(
                          labelText: 'Item name',
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: portion,
                        decoration: const InputDecoration(
                          labelText: 'Portion (e.g. 3 eggs, 200g)',
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Photo',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      if (hasImage)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(selectedImagePath!),
                            height: 180,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        Container(
                          height: 120,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                          child: const Center(
                            child: Icon(Icons.image_outlined, size: 32),
                          ),
                        ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.camera_alt_rounded),
                            label: const Text('Take photo'),
                            onPressed: () async {
                              final shot = await imagePicker.pickImage(
                                source: ImageSource.camera,
                                imageQuality: 85,
                                maxWidth: 1440,
                              );
                              if (shot == null) return;
                              final savedPath = await _persistMealItemImage(
                                shot.path,
                              );
                              if (!context.mounted) return;
                              setModalState(() {
                                selectedImagePath = savedPath;
                              });
                            },
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('Upload photo'),
                            onPressed: () async {
                              final picked = await imagePicker.pickImage(
                                source: ImageSource.gallery,
                                imageQuality: 85,
                                maxWidth: 1440,
                              );
                              if (picked == null) return;
                              final savedPath = await _persistMealItemImage(
                                picked.path,
                              );
                              if (!context.mounted) return;
                              setModalState(() {
                                selectedImagePath = savedPath;
                              });
                            },
                          ),
                          if (hasImage)
                            TextButton.icon(
                              icon: const Icon(Icons.delete_outline_rounded),
                              label: const Text('Remove photo'),
                              onPressed: () {
                                setModalState(() {
                                  selectedImagePath = null;
                                });
                              },
                            ),
                        ],
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
                            await context.read<AppState>().addMealItem(
                              name: name.text.trim(),
                              portion: portion.text.trim(),
                              imagePath: selectedImagePath,
                              calories: int.parse(calories.text.trim()),
                              protein: double.parse(protein.text.trim()),
                              carbs: double.parse(carbs.text.trim()),
                              fat: double.parse(fat.text.trim()),
                            );
                          } else {
                            await context.read<AppState>().updateMealItem(
                              id: existing.id,
                              name: name.text.trim(),
                              portion: portion.text.trim(),
                              imagePath: selectedImagePath,
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
                              ? 'Save meal item'
                              : 'Update meal item',
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

  Future<String> _persistMealItemImage(String sourcePath) async {
    final source = File(sourcePath);
    final directory = await getApplicationDocumentsDirectory();
    final mealItemDir = Directory('${directory.path}/meal_item_images');
    if (!await mealItemDir.exists()) {
      await mealItemDir.create(recursive: true);
    }

    final extension = source.path.contains('.')
        ? source.path.substring(source.path.lastIndexOf('.'))
        : '.jpg';
    final fileName =
        'meal_item_${DateTime.now().microsecondsSinceEpoch}$extension';
    final targetPath = '${mealItemDir.path}/$fileName';
    final copied = await source.copy(targetPath);
    return copied.path;
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
