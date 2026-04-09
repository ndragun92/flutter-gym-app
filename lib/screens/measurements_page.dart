import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

class MeasurementsPage extends StatelessWidget {
  const MeasurementsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final list = appState.bodyMeasurements;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Body measurements',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Track visual and physical progress by body part.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 16),
          if (list.length >= 2) _ProgressHighlights(),
          if (list.length >= 2) const SizedBox(height: 12),
          if (list.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No measurements yet. Add your first entry.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            )
          else
            ...list.map(
              (item) => Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(14),
                  title: Text(DateFormat('d MMM yyyy').format(item.date)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _chip('Weight', '${item.weight.toStringAsFixed(1)} kg'),
                        if (item.waist != null)
                          _chip(
                            'Waist',
                            '${item.waist!.toStringAsFixed(1)} cm',
                          ),
                        if (item.chest != null)
                          _chip(
                            'Chest',
                            '${item.chest!.toStringAsFixed(1)} cm',
                          ),
                        if (item.hips != null)
                          _chip('Hips', '${item.hips!.toStringAsFixed(1)} cm'),
                        if (item.biceps != null)
                          _chip(
                            'Biceps',
                            '${item.biceps!.toStringAsFixed(1)} cm',
                          ),
                        if (item.thigh != null)
                          _chip(
                            'Thigh',
                            '${item.thigh!.toStringAsFixed(1)} cm',
                          ),
                      ],
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () => appState.removeBodyMeasurement(item.id),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 90),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
    );
  }

  Widget _chip(String label, String value) {
    return Chip(
      label: Text('$label: $value'),
      visualDensity: VisualDensity.compact,
    );
  }

  Future<void> _openAddDialog(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final weight = TextEditingController();
    final waist = TextEditingController();
    final chest = TextEditingController();
    final hips = TextEditingController();
    final biceps = TextEditingController();
    final thigh = TextEditingController();
    var selectedDate = DateTime.now();

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
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Add measurement',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_month_rounded),
                        label: Text(
                          DateFormat('d MMM yyyy').format(selectedDate),
                        ),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (picked != null) {
                            setState(() => selectedDate = picked);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      _numField(weight, 'Weight (kg)', requiredField: true),
                      const SizedBox(height: 10),
                      _numField(waist, 'Waist (cm)'),
                      const SizedBox(height: 10),
                      _numField(chest, 'Chest (cm)'),
                      const SizedBox(height: 10),
                      _numField(hips, 'Hips (cm)'),
                      const SizedBox(height: 10),
                      _numField(biceps, 'Biceps (cm)'),
                      const SizedBox(height: 10),
                      _numField(thigh, 'Thigh (cm)'),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          await context.read<AppState>().addBodyMeasurement(
                            date: selectedDate,
                            weight: double.parse(weight.text.trim()),
                            waist: _parseNullable(waist.text),
                            chest: _parseNullable(chest.text),
                            hips: _parseNullable(hips.text),
                            biceps: _parseNullable(biceps.text),
                            thigh: _parseNullable(thigh.text),
                          );
                          if (context.mounted) Navigator.pop(context);
                        },
                        child: const Text('Save measurement'),
                      ),
                      const SizedBox(height: 8),
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

  double? _parseNullable(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return null;
    return double.tryParse(clean);
  }

  Widget _numField(
    TextEditingController controller,
    String label, {
    bool requiredField = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        final raw = value?.trim() ?? '';
        if (requiredField && raw.isEmpty) return 'Required';
        if (raw.isNotEmpty && double.tryParse(raw) == null) {
          return 'Invalid number';
        }
        return null;
      },
    );
  }
}

class _ProgressHighlights extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final measurements = context.watch<AppState>().bodyMeasurements;
    final latest = measurements.first;
    final oldest = measurements.last;

    final weightDelta = latest.weight - oldest.weight;
    final waistDelta = _delta(latest.waist, oldest.waist);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Progress highlights',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('Weight Δ ${_format(weightDelta)} kg')),
                if (waistDelta != null)
                  Chip(label: Text('Waist Δ ${_format(waistDelta)} cm')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  double? _delta(double? a, double? b) =>
      (a != null && b != null) ? a - b : null;

  String _format(double value) {
    final prefix = value > 0 ? '+' : '';
    return '$prefix${value.toStringAsFixed(1)}';
  }
}
