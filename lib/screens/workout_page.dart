import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/workout_entry.dart';
import '../state/app_state.dart';

enum _WorkoutCardAction { edit, delete }

class WorkoutPage extends StatelessWidget {
  const WorkoutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Gym progress',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Log exercises and track lifted weight trends.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 16),
          _scheduleSection(context, appState),
          const SizedBox(height: 12),
          _prSection(context, appState),
          const SizedBox(height: 12),
          _workoutLogSection(context, appState),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _scheduleSection(BuildContext context, AppState appState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Gym schedule',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Add gym day',
                  onPressed: () => _openAddGymSchedule(context),
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (appState.gymSchedules.isEmpty)
              Text(
                'No gym reminders set.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              ...appState.gymSchedules.map((item) {
                final day = _weekday(item.weekday);
                final time =
                    '${item.hour.toString().padLeft(2, '0')}:${item.minute.toString().padLeft(2, '0')}';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    child: Icon(Icons.fitness_center_rounded),
                  ),
                  title: Text(item.title),
                  subtitle: Text('$day · $time'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch.adaptive(
                        value: item.enabled,
                        onChanged: (v) =>
                            appState.toggleGymSchedule(item.id, v),
                      ),
                      PopupMenuButton<_WorkoutCardAction>(
                        tooltip: 'More actions',
                        icon: const Icon(Icons.more_vert_rounded),
                        onSelected: (action) {
                          switch (action) {
                            case _WorkoutCardAction.edit:
                              _openAddGymSchedule(context, existing: item);
                            case _WorkoutCardAction.delete:
                              appState.removeGymSchedule(item.id);
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem<_WorkoutCardAction>(
                            value: _WorkoutCardAction.edit,
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.edit_outlined),
                              title: Text('Edit'),
                            ),
                          ),
                          PopupMenuItem<_WorkoutCardAction>(
                            value: _WorkoutCardAction.delete,
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.delete_outline_rounded),
                              title: Text('Delete'),
                            ),
                          ),
                        ],
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

  Widget _prSection(BuildContext context, AppState appState) {
    final map = <String, WorkoutEntry>{};
    for (final entry in appState.workoutEntries) {
      final key = _normalizeExerciseName(entry.exercise);
      final current = map[key];
      if (current == null || entry.weight > current.weight) {
        map[key] = entry;
      }
    }

    final prs = map.values.toList()
      ..sort((a, b) => b.weight.compareTo(a.weight));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Personal records',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            if (prs.isEmpty)
              Text(
                'No lifts yet.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var i = 0; i < prs.length && i < 8; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Chip(
                        label: Text(
                          '${prs[i].exercise}: ${prs[i].weight.toStringAsFixed(1)} kg',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _workoutLogSection(BuildContext context, AppState appState) {
    final groupedEntries = <String, List<WorkoutEntry>>{};
    for (final entry in appState.workoutEntries.take(80)) {
      final key = _normalizeExerciseName(entry.exercise);
      groupedEntries.putIfAbsent(key, () => <WorkoutEntry>[]).add(entry);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Workout log',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Add lift',
                  onPressed: () => _openAddWorkoutDialog(context),
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (appState.workoutEntries.isEmpty)
              Text(
                'No workout entries yet.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              ...groupedEntries.entries.map((group) {
                final logs = group.value;
                final latest = logs.first;
                final pr = logs.reduce((a, b) => a.weight >= b.weight ? a : b);

                return ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    child: Icon(Icons.monitor_weight_rounded),
                  ),
                  title: Text(latest.exercise),
                  subtitle: Text(
                    '${logs.length} logs · PR ${pr.weight.toStringAsFixed(1)} kg',
                  ),
                  children: logs.take(12).map((entry) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${DateFormat('d MMM yyyy').format(entry.date)} · ${entry.sets}x${entry.reps} · ${entry.weight.toStringAsFixed(1)} kg',
                      ),
                      subtitle:
                          (entry.notes == null || entry.notes!.trim().isEmpty)
                          ? null
                          : Text(entry.notes!),
                      trailing: PopupMenuButton<_WorkoutCardAction>(
                        tooltip: 'More actions',
                        icon: const Icon(Icons.more_vert_rounded),
                        onSelected: (action) {
                          switch (action) {
                            case _WorkoutCardAction.edit:
                              _openAddWorkoutDialog(context, existing: entry);
                            case _WorkoutCardAction.delete:
                              appState.removeWorkoutEntry(entry.id);
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem<_WorkoutCardAction>(
                            value: _WorkoutCardAction.edit,
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.edit_outlined),
                              title: Text('Edit'),
                            ),
                          ),
                          PopupMenuItem<_WorkoutCardAction>(
                            value: _WorkoutCardAction.delete,
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.delete_outline_rounded),
                              title: Text('Delete'),
                            ),
                          ),
                        ],
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

  String _weekday(int day) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[(day - 1).clamp(0, 6)];
  }

  Future<void> _openAddGymSchedule(
    BuildContext context, {
    GymSchedule? existing,
  }) async {
    final formKey = GlobalKey<FormState>();
    final title = TextEditingController(text: existing?.title ?? '');
    var weekday = existing?.weekday ?? DateTime.now().weekday;
    var time = existing == null
        ? TimeOfDay.now()
        : TimeOfDay(hour: existing.hour, minute: existing.minute);

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
                          ? 'New gym schedule'
                          : 'Edit gym schedule',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: title,
                      decoration: const InputDecoration(
                        labelText: 'Session title',
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      value: weekday,
                      decoration: const InputDecoration(labelText: 'Weekday'),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('Monday')),
                        DropdownMenuItem(value: 2, child: Text('Tuesday')),
                        DropdownMenuItem(value: 3, child: Text('Wednesday')),
                        DropdownMenuItem(value: 4, child: Text('Thursday')),
                        DropdownMenuItem(value: 5, child: Text('Friday')),
                        DropdownMenuItem(value: 6, child: Text('Saturday')),
                        DropdownMenuItem(value: 7, child: Text('Sunday')),
                      ],
                      onChanged: (v) => setState(() => weekday = v ?? weekday),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.access_time_rounded),
                      label: Text(time.format(context)),
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: time,
                        );
                        if (picked != null) setState(() => time = picked);
                      },
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        final state = context.read<AppState>();
                        if (existing == null) {
                          await state.addGymSchedule(
                            title: title.text.trim(),
                            weekday: weekday,
                            hour: time.hour,
                            minute: time.minute,
                          );
                        } else {
                          await state.updateGymSchedule(
                            id: existing.id,
                            title: title.text.trim(),
                            weekday: weekday,
                            hour: time.hour,
                            minute: time.minute,
                          );
                        }
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: Text(
                        existing == null ? 'Save schedule' : 'Save changes',
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

  Future<void> _openAddWorkoutDialog(
    BuildContext context, {
    WorkoutEntry? existing,
  }) async {
    final formKey = GlobalKey<FormState>();
    final exercise = TextEditingController(text: existing?.exercise ?? '');
    final sets = TextEditingController(
      text: existing == null ? '' : existing.sets.toString(),
    );
    final reps = TextEditingController(
      text: existing == null ? '' : existing.reps.toString(),
    );
    final weight = TextEditingController(
      text: existing == null ? '' : existing.weight.toStringAsFixed(1),
    );
    final notes = TextEditingController(text: existing?.notes ?? '');
    final exerciseSuggestions = _exerciseSuggestions(
      context.read<AppState>().workoutEntries,
    );
    var date = existing?.date ?? DateTime.now();

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
                        existing == null ? 'Log workout' : 'Edit workout',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Autocomplete<String>(
                        optionsBuilder: (textEditingValue) {
                          final query = textEditingValue.text
                              .trim()
                              .toLowerCase();
                          if (query.isEmpty) {
                            return exerciseSuggestions.take(6);
                          }
                          return exerciseSuggestions
                              .where(
                                (item) => item.toLowerCase().contains(query),
                              )
                              .take(6);
                        },
                        onSelected: (selection) => exercise.text = selection,
                        fieldViewBuilder:
                            (
                              context,
                              textEditingController,
                              focusNode,
                              onFieldSubmitted,
                            ) {
                              if (textEditingController.text != exercise.text) {
                                textEditingController.value = TextEditingValue(
                                  text: exercise.text,
                                  selection: TextSelection.collapsed(
                                    offset: exercise.text.length,
                                  ),
                                );
                              }
                              return TextFormField(
                                controller: textEditingController,
                                focusNode: focusNode,
                                decoration: const InputDecoration(
                                  labelText: 'Exercise name',
                                  hintText: 'Start typing (e.g. Bench press)',
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                    ? 'Required'
                                    : null,
                                onChanged: (_) {
                                  exercise.value = textEditingController.value;
                                },
                              );
                            },
                      ),
                      const SizedBox(height: 10),
                      _intField(sets, 'Sets'),
                      const SizedBox(height: 10),
                      _intField(reps, 'Reps'),
                      const SizedBox(height: 10),
                      _doubleField(weight, 'Weight (kg)'),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: notes,
                        decoration: const InputDecoration(
                          labelText: 'Notes (optional)',
                        ),
                        minLines: 2,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today_rounded),
                        label: Text(DateFormat('d MMM yyyy').format(date)),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: date,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (picked != null) setState(() => date = picked);
                        },
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          final state = context.read<AppState>();
                          if (existing == null) {
                            await state.addWorkoutEntry(
                              date: date,
                              exercise: exercise.text.trim(),
                              sets: int.parse(sets.text.trim()),
                              reps: int.parse(reps.text.trim()),
                              weight: double.parse(weight.text.trim()),
                              notes: notes.text.trim().isEmpty
                                  ? null
                                  : notes.text.trim(),
                            );
                          } else {
                            await state.updateWorkoutEntry(
                              id: existing.id,
                              date: date,
                              exercise: exercise.text.trim(),
                              sets: int.parse(sets.text.trim()),
                              reps: int.parse(reps.text.trim()),
                              weight: double.parse(weight.text.trim()),
                              notes: notes.text.trim().isEmpty
                                  ? null
                                  : notes.text.trim(),
                            );
                          }
                          if (context.mounted) Navigator.pop(context);
                        },
                        child: Text(
                          existing == null ? 'Save workout' : 'Save changes',
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

  Widget _intField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        final raw = value?.trim() ?? '';
        if (raw.isEmpty) return 'Required';
        if (int.tryParse(raw) == null) return 'Invalid number';
        return null;
      },
    );
  }

  Widget _doubleField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        final raw = value?.trim() ?? '';
        if (raw.isEmpty) return 'Required';
        if (double.tryParse(raw) == null) return 'Invalid number';
        return null;
      },
    );
  }
}
