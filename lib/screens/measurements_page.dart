import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../models/body_measurement_entry.dart';
import '../state/app_state.dart';

class MeasurementsPage extends StatelessWidget {
  const MeasurementsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final list = appState.bodyMeasurements;

    return Scaffold(
      backgroundColor: Colors.transparent,
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
          if (list.length >= 2) _ProgressHighlights(entries: list),
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
            ...list.map((item) => _MeasurementCard(item: item)),
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

  Future<void> _openAddDialog(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final weight = TextEditingController();
    final waist = TextEditingController();
    final chest = TextEditingController();
    final hips = TextEditingController();
    final biceps = TextEditingController();
    final thigh = TextEditingController();
    final imagePicker = ImagePicker();
    String? selectedImagePath;
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
            bottom:
                math.max(
                  MediaQuery.of(context).viewInsets.bottom,
                  MediaQuery.of(context).viewPadding.bottom,
                ) +
                16,
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              final hasImage =
                  selectedImagePath != null &&
                  selectedImagePath!.isNotEmpty &&
                  File(selectedImagePath!).existsSync();

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
                      _twoColumnFields(
                        left: _numField(
                          weight,
                          'Weight (kg)',
                          requiredField: true,
                        ),
                        right: _numField(waist, 'Waist (cm)'),
                      ),
                      const SizedBox(height: 10),
                      _twoColumnFields(
                        left: _numField(chest, 'Chest (cm)'),
                        right: _numField(hips, 'Hips (cm)'),
                      ),
                      const SizedBox(height: 10),
                      _twoColumnFields(
                        left: _numField(biceps, 'Biceps (cm)'),
                        right: _numField(thigh, 'Thigh (cm)'),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Progress photo',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      if (hasImage)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(selectedImagePath!),
                            height: 150,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        Container(
                          height: 94,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                          child: const Center(
                            child: Icon(Icons.image_outlined, size: 30),
                          ),
                        ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
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
                              final savedPath = await _persistMeasurementImage(
                                shot.path,
                              );
                              if (!context.mounted) return;
                              setState(() {
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
                              final savedPath = await _persistMeasurementImage(
                                picked.path,
                              );
                              if (!context.mounted) return;
                              setState(() {
                                selectedImagePath = savedPath;
                              });
                            },
                          ),
                          if (hasImage)
                            TextButton.icon(
                              icon: const Icon(Icons.delete_outline_rounded),
                              label: const Text('Remove photo'),
                              onPressed: () {
                                setState(() {
                                  selectedImagePath = null;
                                });
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          await context.read<AppState>().addBodyMeasurement(
                            date: selectedDate,
                            weight: double.parse(weight.text.trim()),
                            imagePath: selectedImagePath,
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

  Widget _twoColumnFields({required Widget left, required Widget right}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 10),
        Expanded(child: right),
      ],
    );
  }

  Future<String> _persistMeasurementImage(String sourcePath) async {
    final source = File(sourcePath);
    final directory = await getApplicationDocumentsDirectory();
    final measurementDir = Directory(
      '${directory.path}/body_measurement_images',
    );
    if (!await measurementDir.exists()) {
      await measurementDir.create(recursive: true);
    }

    final extension = source.path.contains('.')
        ? source.path.substring(source.path.lastIndexOf('.'))
        : '.jpg';
    final fileName =
        'measurement_${DateTime.now().microsecondsSinceEpoch}$extension';
    final targetPath = '${measurementDir.path}/$fileName';
    final copied = await source.copy(targetPath);
    return copied.path;
  }
}

class _MeasurementCard extends StatelessWidget {
  const _MeasurementCard({required this.item});

  final BodyMeasurementEntry item;

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    final hasImage =
        item.imagePath != null &&
        item.imagePath!.isNotEmpty &&
        File(item.imagePath!).existsSync();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat('d MMM yyyy').format(item.date),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () => appState.removeBodyMeasurement(item.id),
                ),
              ],
            ),
            if (hasImage)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(item.imagePath!),
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            _MetricGrid(
              items: [
                _MetricItem('Weight', '${item.weight.toStringAsFixed(1)} kg'),
                if (item.waist != null)
                  _MetricItem('Waist', '${item.waist!.toStringAsFixed(1)} cm'),
                if (item.chest != null)
                  _MetricItem('Chest', '${item.chest!.toStringAsFixed(1)} cm'),
                if (item.hips != null)
                  _MetricItem('Hips', '${item.hips!.toStringAsFixed(1)} cm'),
                if (item.biceps != null)
                  _MetricItem(
                    'Biceps',
                    '${item.biceps!.toStringAsFixed(1)} cm',
                  ),
                if (item.thigh != null)
                  _MetricItem('Thigh', '${item.thigh!.toStringAsFixed(1)} cm'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressHighlights extends StatelessWidget {
  const _ProgressHighlights({required this.entries});

  final List<BodyMeasurementEntry> entries;

  @override
  Widget build(BuildContext context) {
    final latest = entries.first;
    final oldest = entries.last;

    final weightDelta = latest.weight - oldest.weight;
    final waistDelta = _delta(latest.waist, oldest.waist);
    final chestDelta = _delta(latest.chest, oldest.chest);
    final hipsDelta = _delta(latest.hips, oldest.hips);
    final bicepsDelta = _delta(latest.biceps, oldest.biceps);
    final thighDelta = _delta(latest.thigh, oldest.thigh);

    final ascendingByDate = [...entries]
      ..sort((a, b) => a.date.compareTo(b.date));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Progress highlights',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _DeltaPill('Weight Δ ${_format(weightDelta)} kg'),
                  if (waistDelta != null) ...[
                    const SizedBox(width: 6),
                    _DeltaPill('Waist Δ ${_format(waistDelta)} cm'),
                  ],
                  if (chestDelta != null) ...[
                    const SizedBox(width: 6),
                    _DeltaPill('Chest Δ ${_format(chestDelta)} cm'),
                  ],
                  if (hipsDelta != null) ...[
                    const SizedBox(width: 6),
                    _DeltaPill('Hips Δ ${_format(hipsDelta)} cm'),
                  ],
                  if (bicepsDelta != null) ...[
                    const SizedBox(width: 6),
                    _DeltaPill('Biceps Δ ${_format(bicepsDelta)} cm'),
                  ],
                  if (thighDelta != null) ...[
                    const SizedBox(width: 6),
                    _DeltaPill('Thigh Δ ${_format(thighDelta)} cm'),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            _TrendRow(
              title: 'Weight',
              unit: 'kg',
              values: ascendingByDate.map((e) => e.weight).toList(),
              preferDecrease: true,
            ),
            _TrendRow(
              title: 'Waist',
              unit: 'cm',
              values: ascendingByDate
                  .map((e) => e.waist)
                  .whereType<double>()
                  .toList(),
              preferDecrease: true,
            ),
            _TrendRow(
              title: 'Chest',
              unit: 'cm',
              values: ascendingByDate
                  .map((e) => e.chest)
                  .whereType<double>()
                  .toList(),
              preferDecrease: false,
            ),
            _TrendRow(
              title: 'Hips',
              unit: 'cm',
              values: ascendingByDate
                  .map((e) => e.hips)
                  .whereType<double>()
                  .toList(),
              preferDecrease: true,
            ),
            _TrendRow(
              title: 'Biceps',
              unit: 'cm',
              values: ascendingByDate
                  .map((e) => e.biceps)
                  .whereType<double>()
                  .toList(),
              preferDecrease: false,
            ),
            _TrendRow(
              title: 'Thigh',
              unit: 'cm',
              values: ascendingByDate
                  .map((e) => e.thigh)
                  .whereType<double>()
                  .toList(),
              preferDecrease: true,
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

class _TrendRow extends StatelessWidget {
  const _TrendRow({
    required this.title,
    required this.unit,
    required this.values,
    required this.preferDecrease,
  });

  final String title;
  final String unit;
  final List<double> values;
  final bool preferDecrease;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) return const SizedBox.shrink();

    final previous = values[values.length - 2];
    final latest = values.last;
    final delta = latest - previous;

    const epsilon = 0.05;
    final trend = delta.abs() <= epsilon
        ? _TrendState.neutral
        : (delta > 0 ? _TrendState.up : _TrendState.down);

    final isGood = switch (trend) {
      _TrendState.neutral => null,
      _TrendState.up => !preferDecrease,
      _TrendState.down => preferDecrease,
    };

    final icon = switch (trend) {
      _TrendState.up => Icons.expand_less_rounded,
      _TrendState.down => Icons.expand_more_rounded,
      _TrendState.neutral => Icons.chevron_right_rounded,
    };

    final iconColor = switch (isGood) {
      true => Colors.green.shade600,
      false => Colors.red.shade600,
      null => Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
    };

    final deltaText =
        '${delta > 0 ? '+' : ''}${delta.toStringAsFixed(1)} $unit';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(title, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Expanded(child: _MiniBars(values: values)),
          const SizedBox(width: 8),
          Icon(icon, color: iconColor),
          const SizedBox(width: 4),
          SizedBox(
            width: 58,
            child: Text(
              deltaText,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniBars extends StatelessWidget {
  const _MiniBars({required this.values});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    final count = values.length > 8 ? 8 : values.length;
    final recent = values.sublist(values.length - count);
    final min = recent.reduce((a, b) => a < b ? a : b);
    final max = recent.reduce((a, b) => a > b ? a : b);
    final range = (max - min).abs();

    return SizedBox(
      height: 28,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: recent.map((value) {
          final normalized = range < 0.001 ? 0.5 : (value - min) / range;
          final barHeight = 7 + (normalized * 17);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Container(
                height: barHeight,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _DeltaPill extends StatelessWidget {
  const _DeltaPill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class _MetricItem {
  const _MetricItem(this.label, this.value);

  final String label;
  final String value;
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.items});

  final List<_MetricItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 6.0;
        final width = (constraints.maxWidth - spacing) / 2;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items
              .map(
                (item) => SizedBox(
                  width: width,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.label,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item.value,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

enum _TrendState { up, down, neutral }
