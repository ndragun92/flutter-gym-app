import 'dart:ui';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/app_theme.dart';
import 'models/workout_entry.dart';
import 'screens/dashboard_page.dart';
import 'screens/measurements_page.dart';
import 'screens/nutrition_page.dart';
import 'screens/workout_page.dart';
import 'services/notification_service.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.initialize();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'PulseNest Tracker',
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.dark,
        home: const _RootShell(),
      ),
    );
  }
}

class _RootShell extends StatefulWidget {
  const _RootShell();

  @override
  State<_RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<_RootShell> {
  int index = 0;

  Future<void> _openQuickAddSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.restaurant_rounded),
                  ),
                  title: const Text('Quick log meal'),
                  subtitle: const Text('Add calories and macros quickly'),
                  onTap: () {
                    Navigator.pop(context);
                    _openQuickMealDialog();
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.monitor_weight_rounded),
                  ),
                  title: const Text('Quick body entry'),
                  subtitle: const Text('Save current weight'),
                  onTap: () {
                    Navigator.pop(context);
                    _openQuickMeasurementDialog();
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.fitness_center_rounded),
                  ),
                  title: const Text('Quick workout log'),
                  subtitle: const Text('Add latest lift set'),
                  onTap: () {
                    Navigator.pop(context);
                    _openQuickWorkoutDialog();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openQuickMealDialog() async {
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController();
    final calories = TextEditingController();
    final protein = TextEditingController(text: '0');
    final carbs = TextEditingController(text: '0');
    final fat = TextEditingController(text: '0');

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
                  'Quick meal log',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Meal name'),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Required'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: calories,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Calories'),
                  validator: (value) {
                    final parsed = int.tryParse((value ?? '').trim());
                    if (parsed == null || parsed < 0) return 'Invalid number';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _quickNumberField(
                        controller: protein,
                        label: 'Protein (g)',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _quickNumberField(
                        controller: carbs,
                        label: 'Carbs (g)',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _quickNumberField(controller: fat, label: 'Fat (g)'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    await context.read<AppState>().addMealEntry(
                      name: name.text.trim(),
                      calories: int.parse(calories.text.trim()),
                      protein: double.parse(protein.text.trim()),
                      carbs: double.parse(carbs.text.trim()),
                      fat: double.parse(fat.text.trim()),
                      at: DateTime.now(),
                    );
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(
                      this.context,
                    ).showSnackBar(const SnackBar(content: Text('Meal added')));
                  },
                  child: const Text('Save meal'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openQuickMeasurementDialog() async {
    final formKey = GlobalKey<FormState>();
    final weight = TextEditingController();
    final waist = TextEditingController();
    final chest = TextEditingController();
    final hips = TextEditingController();
    final biceps = TextEditingController();
    final thigh = TextEditingController();

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
                  'Quick body entry',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                _quickNumberField(controller: weight, label: 'Weight (kg)'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _quickNumberField(
                        controller: waist,
                        label: 'Waist (cm)',
                        requiredField: false,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _quickNumberField(
                        controller: chest,
                        label: 'Chest (cm)',
                        requiredField: false,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _quickNumberField(
                        controller: hips,
                        label: 'Hips (cm)',
                        requiredField: false,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _quickNumberField(
                        controller: biceps,
                        label: 'Biceps (cm)',
                        requiredField: false,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _quickNumberField(
                  controller: thigh,
                  label: 'Thigh (cm)',
                  requiredField: false,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    await context.read<AppState>().addBodyMeasurement(
                      date: DateTime.now(),
                      weight: double.parse(weight.text.trim()),
                      waist: _parseNullableNumber(waist.text),
                      chest: _parseNullableNumber(chest.text),
                      hips: _parseNullableNumber(hips.text),
                      biceps: _parseNullableNumber(biceps.text),
                      thigh: _parseNullableNumber(thigh.text),
                    );
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(content: Text('Measurement added')),
                    );
                  },
                  child: const Text('Save measurement'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openQuickWorkoutDialog() async {
    final formKey = GlobalKey<FormState>();
    final knownExercises = _exerciseSuggestions(
      context.read<AppState>().workoutEntries,
    );
    var exerciseName = '';
    final sets = TextEditingController(text: '3');
    final reps = TextEditingController(text: '8');
    final weight = TextEditingController();

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
                  'Quick workout log',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Autocomplete<String>(
                  optionsBuilder: (textEditingValue) {
                    final query = textEditingValue.text.trim().toLowerCase();
                    if (knownExercises.isEmpty) {
                      return const Iterable<String>.empty();
                    }
                    if (query.isEmpty) {
                      return knownExercises.take(8);
                    }
                    return knownExercises
                        .where((item) => item.toLowerCase().contains(query))
                        .take(8);
                  },
                  onSelected: (selected) => exerciseName = selected,
                  fieldViewBuilder:
                      (
                        context,
                        textEditingController,
                        focusNode,
                        onFieldSubmitted,
                      ) {
                        return TextFormField(
                          controller: textEditingController,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            labelText: 'Exercise',
                            hintText: knownExercises.isEmpty
                                ? 'e.g. Bench Press'
                                : 'Type to see suggestions',
                          ),
                          textInputAction: TextInputAction.next,
                          onChanged: (value) => exerciseName = value,
                          onFieldSubmitted: (_) => onFieldSubmitted(),
                          validator: (value) =>
                              (value == null || value.trim().isEmpty)
                              ? 'Required'
                              : null,
                        );
                      },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: sets,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Sets'),
                        validator: (value) {
                          final parsed = int.tryParse((value ?? '').trim());
                          if (parsed == null || parsed <= 0) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: reps,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Reps'),
                        validator: (value) {
                          final parsed = int.tryParse((value ?? '').trim());
                          if (parsed == null || parsed <= 0) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _quickNumberField(controller: weight, label: 'Weight (kg)'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    await context.read<AppState>().addWorkoutEntry(
                      date: DateTime.now(),
                      exercise: exerciseName.trim(),
                      sets: int.parse(sets.text.trim()),
                      reps: int.parse(reps.text.trim()),
                      weight: double.parse(weight.text.trim()),
                    );
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(content: Text('Workout added')),
                    );
                  },
                  child: const Text('Save workout'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _normalizeExerciseName(String value) {
    return value.trim().toLowerCase();
  }

  List<String> _exerciseSuggestions(List<WorkoutEntry> entries) {
    final grouped = <String, String>{};
    for (final entry in entries) {
      final normalized = _normalizeExerciseName(entry.exercise);
      grouped.putIfAbsent(normalized, () => entry.exercise.trim());
    }
    return grouped.values.toList()..sort((a, b) => a.compareTo(b));
  }

  Widget _quickNumberField({
    required TextEditingController controller,
    required String label,
    bool requiredField = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        final raw = (value ?? '').trim();
        if (!requiredField && raw.isEmpty) return null;
        final parsed = double.tryParse(raw);
        if (parsed == null || parsed < 0) return 'Invalid number';
        return null;
      },
    );
  }

  double? _parseNullableNumber(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    return double.tryParse(trimmed);
  }

  Widget _buildDecorativeBackground(ThemeData theme) {
    final colors = theme.colorScheme;

    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.background,
                  colors.surface.withOpacity(0.92),
                  colors.background,
                ],
              ),
            ),
          ),
          Align(
            alignment: const Alignment(-1.1, -1.0),
            child: Container(
              width: 270,
              height: 270,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    colors.primary.withOpacity(0.22),
                    colors.primary.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          Align(
            alignment: const Alignment(1.15, -0.2),
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    colors.tertiary.withOpacity(0.16),
                    colors.tertiary.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          Align(
            alignment: const Alignment(-0.2, 1.05),
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    colors.secondary.withOpacity(0.14),
                    colors.secondary.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(ThemeData theme) {
    final colors = theme.colorScheme;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: colors.outlineVariant.withOpacity(0.55),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.28),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: NavigationBarTheme(
                data: NavigationBarThemeData(
                  labelBehavior:
                      NavigationDestinationLabelBehavior.onlyShowSelected,
                  indicatorColor: colors.primary.withOpacity(0.24),
                  labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>(
                    (states) => TextStyle(
                      fontSize: 12,
                      fontWeight: states.contains(WidgetState.selected)
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: states.contains(WidgetState.selected)
                          ? colors.onSurface
                          : colors.onSurface.withOpacity(0.74),
                    ),
                  ),
                  iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>(
                    (states) => IconThemeData(
                      size: states.contains(WidgetState.selected) ? 26 : 23,
                      color: states.contains(WidgetState.selected)
                          ? colors.primary
                          : colors.onSurface.withOpacity(0.78),
                    ),
                  ),
                ),
                child: NavigationBar(
                  selectedIndex: index,
                  onDestinationSelected: (newIndex) =>
                      setState(() => index = newIndex),
                  height: 70,
                  elevation: 0,
                  backgroundColor: colors.surface.withOpacity(0.72),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard_rounded),
                      label: 'Dashboard',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.restaurant_menu_rounded),
                      selectedIcon: Icon(Icons.restaurant_rounded),
                      label: 'Meals',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.straighten_rounded),
                      selectedIcon: Icon(Icons.monitor_weight_rounded),
                      label: 'Body',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.fitness_center_outlined),
                      selectedIcon: Icon(Icons.fitness_center_rounded),
                      label: 'Gym',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<AppState>().isLoading;
    final theme = Theme.of(context);

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          _buildDecorativeBackground(theme),
          loading
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                  child: IndexedStack(
                    index: index,
                    children: [
                      const DashboardPage(),
                      NutritionPage(isActive: index == 1),
                      const MeasurementsPage(),
                      const WorkoutPage(),
                    ],
                  ),
                ),
        ],
      ),
      floatingActionButton: index == 2
          ? null
          : FloatingActionButton.extended(
              onPressed: _openQuickAddSheet,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Quick add'),
            ),
      bottomNavigationBar: _buildBottomNav(theme),
    );
  }
}
