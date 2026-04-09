import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../models/body_progress_photo.dart';
import '../state/app_state.dart';

class BodyGalleryPage extends StatefulWidget {
  const BodyGalleryPage({super.key});

  @override
  State<BodyGalleryPage> createState() => _BodyGalleryPageState();
}

class _BodyGalleryPageState extends State<BodyGalleryPage> {
  final ImagePicker _imagePicker = ImagePicker();
  final Set<String> _selectedIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final photos = appState.bodyProgressPhotos;
    final selectedPhotos =
        photos.where((photo) => _selectedIds.contains(photo.id)).toList()
          ..sort((a, b) => a.capturedAt.compareTo(b.capturedAt));

    return Scaffold(
      appBar: AppBar(title: const Text('Body gallery')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _GalleryHeroCard(
            photoCount: photos.length,
            selectedCount: selectedPhotos.length,
            onTakePhoto: () => _pickAndStoreImage(ImageSource.camera),
            onUploadPhoto: () => _pickAndStoreImage(ImageSource.gallery),
            onCompare: selectedPhotos.length == 2
                ? () => _openCompare(context, selectedPhotos)
                : null,
            onClearSelection: _selectedIds.isEmpty
                ? null
                : () {
                    setState(_selectedIds.clear);
                  },
          ),
          const SizedBox(height: 16),
          if (photos.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 42,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Start your visual progress timeline',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Upload front, side, or mirror check-ins and then select any two photos to compare changes with the slider.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.72),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else ...[
            Text(
              'Tap photos to select up to two for comparison.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: photos.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.78,
              ),
              itemBuilder: (context, index) {
                final photo = photos[index];
                final isSelected = _selectedIds.contains(photo.id);
                return _GalleryPhotoCard(
                  photo: photo,
                  isSelected: isSelected,
                  canSelectMore:
                      _selectedIds.length < 2 ||
                      _selectedIds.contains(photo.id),
                  onTap: () => _toggleSelection(photo.id),
                  onDelete: () => _deletePhoto(context, photo),
                );
              },
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddOptions(context),
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('Add photo'),
      ),
    );
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        return;
      }
      if (_selectedIds.length >= 2) return;
      _selectedIds.add(id);
    });
  }

  Future<void> _showAddOptions(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Add body photo',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _pickAndStoreImage(ImageSource.camera);
                },
                icon: const Icon(Icons.camera_alt_rounded),
                label: const Text('Take photo'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _pickAndStoreImage(ImageSource.gallery);
                },
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Upload from gallery'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndStoreImage(ImageSource source) async {
    final picked = await _imagePicker.pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 1600,
    );
    if (picked == null) return;

    final savedPath = await _persistBodyGalleryImage(picked.path);
    if (!mounted) return;

    await context.read<AppState>().addBodyProgressPhoto(imagePath: savedPath);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Body photo added to gallery')),
    );
  }

  Future<void> _deletePhoto(
    BuildContext context,
    BodyProgressPhoto photo,
  ) async {
    final appState = context.read<AppState>();
    final shouldDelete =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete photo?'),
            content: const Text(
              'This removes the photo from your body gallery.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldDelete || !mounted) return;

    setState(() {
      _selectedIds.remove(photo.id);
    });
    await appState.removeBodyProgressPhoto(photo.id);
  }

  void _openCompare(
    BuildContext context,
    List<BodyProgressPhoto> selectedPhotos,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BodyPhotoComparePage(
          before: selectedPhotos.first,
          after: selectedPhotos.last,
        ),
      ),
    );
  }

  Future<String> _persistBodyGalleryImage(String sourcePath) async {
    final source = File(sourcePath);
    final directory = await getApplicationDocumentsDirectory();
    final galleryDir = Directory('${directory.path}/body_progress_gallery');
    if (!await galleryDir.exists()) {
      await galleryDir.create(recursive: true);
    }

    final extension = source.path.contains('.')
        ? source.path.substring(source.path.lastIndexOf('.'))
        : '.jpg';
    final fileName = 'body_${DateTime.now().microsecondsSinceEpoch}$extension';
    final targetPath = '${galleryDir.path}/$fileName';
    final copied = await source.copy(targetPath);
    return copied.path;
  }
}

class _GalleryHeroCard extends StatelessWidget {
  const _GalleryHeroCard({
    required this.photoCount,
    required this.selectedCount,
    required this.onTakePhoto,
    required this.onUploadPhoto,
    required this.onCompare,
    required this.onClearSelection,
  });

  final int photoCount;
  final int selectedCount;
  final VoidCallback onTakePhoto;
  final VoidCallback onUploadPhoto;
  final VoidCallback? onCompare;
  final VoidCallback? onClearSelection;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              colors.primary.withValues(alpha: 0.18),
              colors.secondary.withValues(alpha: 0.12),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.photo_library_outlined,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Progress photo gallery',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$photoCount photos saved • Select 2 to compare',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onTakePhoto,
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: const Text('Take photo'),
                ),
                OutlinedButton.icon(
                  onPressed: onUploadPhoto,
                  icon: const Icon(Icons.file_upload_outlined),
                  label: const Text('Upload'),
                ),
                FilledButton.tonalIcon(
                  onPressed: onCompare,
                  icon: const Icon(Icons.compare_rounded),
                  label: Text(
                    selectedCount == 2
                        ? 'Compare selected'
                        : 'Pick 2 to compare',
                  ),
                ),
                if (selectedCount > 0)
                  TextButton.icon(
                    onPressed: onClearSelection,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Clear selection'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GalleryPhotoCard extends StatelessWidget {
  const _GalleryPhotoCard({
    required this.photo,
    required this.isSelected,
    required this.canSelectMore,
    required this.onTap,
    required this.onDelete,
  });

  final BodyProgressPhoto photo;
  final bool isSelected;
  final bool canSelectMore;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final file = File(photo.imagePath);
    final exists = file.existsSync();
    final colors = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected
              ? colors.primary
              : colors.outline.withValues(alpha: 0.18),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          if (isSelected)
            BoxShadow(
              color: colors.primary.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: canSelectMore || isSelected ? onTap : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(19),
                        ),
                        child: exists
                            ? Image.file(file, fit: BoxFit.cover)
                            : Container(
                                color: colors.surfaceContainerHighest,
                                alignment: Alignment.center,
                                child: const Icon(Icons.broken_image_outlined),
                              ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: CircleAvatar(
                        radius: 15,
                        backgroundColor: Colors.black.withValues(alpha: 0.45),
                        child: Icon(
                          isSelected
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          DateFormat('d MMM yyyy').format(photo.capturedAt),
                          style: Theme.of(
                            context,
                          ).textTheme.labelLarge?.copyWith(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 8, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        DateFormat('EEE, d MMM').format(photo.capturedAt),
                        style: Theme.of(context).textTheme.titleSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BodyPhotoComparePage extends StatefulWidget {
  const BodyPhotoComparePage({
    super.key,
    required this.before,
    required this.after,
  });

  final BodyProgressPhoto before;
  final BodyProgressPhoto after;

  @override
  State<BodyPhotoComparePage> createState() => _BodyPhotoComparePageState();
}

class _BodyPhotoComparePageState extends State<BodyPhotoComparePage> {
  double _sliderPosition = 0.5;

  @override
  Widget build(BuildContext context) {
    final beforeFile = File(widget.before.imagePath);
    final afterFile = File(widget.after.imagePath);
    final daysBetween = widget.after.capturedAt
        .difference(widget.before.capturedAt)
        .inDays;

    return Scaffold(
      appBar: AppBar(title: const Text('Compare progress')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Before vs after',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    daysBetween <= 0
                        ? 'Drag the slider to reveal changes between your two selected photos.'
                        : 'Drag the slider to reveal your progress across $daysBetween days.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.72),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _CompareTimeline(before: widget.before, after: widget.after),
                  const SizedBox(height: 16),
                  _PhotoCompareSlider(
                    beforeFile: beforeFile,
                    afterFile: afterFile,
                    position: _sliderPosition,
                    onChanged: (value) {
                      setState(() {
                        _sliderPosition = value;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _CompareInfoCard(
                  title: 'Before',
                  subtitle: DateFormat(
                    'd MMM yyyy',
                  ).format(widget.before.capturedAt),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CompareInfoCard(
                  title: 'After',
                  subtitle: DateFormat(
                    'd MMM yyyy',
                  ).format(widget.after.capturedAt),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompareTimeline extends StatelessWidget {
  const _CompareTimeline({required this.before, required this.after});

  final BodyProgressPhoto before;
  final BodyProgressPhoto after;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: _CompareTimelineDot(
            label: 'Before',
            date: DateFormat('d MMM yyyy').format(before.capturedAt),
            color: colors.secondary,
            alignment: CrossAxisAlignment.start,
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(top: 10),
            height: 3,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: LinearGradient(
                colors: [colors.secondary, colors.primary],
              ),
            ),
          ),
        ),
        Expanded(
          child: _CompareTimelineDot(
            label: 'After',
            date: DateFormat('d MMM yyyy').format(after.capturedAt),
            color: colors.primary,
            alignment: CrossAxisAlignment.end,
          ),
        ),
      ],
    );
  }
}

class _CompareTimelineDot extends StatelessWidget {
  const _CompareTimelineDot({
    required this.label,
    required this.date,
    required this.color,
    required this.alignment,
  });

  final String label;
  final String date;
  final Color color;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(height: 6),
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 2),
        Text(
          date,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.72),
          ),
        ),
      ],
    );
  }
}

class _PhotoCompareSlider extends StatelessWidget {
  const _PhotoCompareSlider({
    required this.beforeFile,
    required this.afterFile,
    required this.position,
    required this.onChanged,
  });

  final File beforeFile;
  final File afterFile;
  final double position;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        void handleDrag(Offset localPosition) {
          final next = (localPosition.dx / width).clamp(0.0, 1.0);
          onChanged(next);
        }

        return GestureDetector(
          onHorizontalDragUpdate: (details) =>
              handleDrag(details.localPosition),
          onTapDown: (details) => handleDrag(details.localPosition),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  beforeFile.existsSync()
                      ? Image.file(beforeFile, fit: BoxFit.cover)
                      : Container(color: colors.surfaceContainerHighest),
                  ClipRect(
                    clipper: _RevealClipper(position),
                    child: afterFile.existsSync()
                        ? Image.file(afterFile, fit: BoxFit.cover)
                        : Container(color: colors.surfaceContainerHighest),
                  ),
                  Positioned(
                    top: 14,
                    left: 14,
                    child: _CompareLabel(text: 'Before'),
                  ),
                  Positioned(
                    top: 14,
                    right: 14,
                    child: _CompareLabel(text: 'After'),
                  ),
                  Positioned(
                    left: math.max(0, width * position - 1.5),
                    top: 0,
                    bottom: 0,
                    child: Container(width: 3, color: Colors.white),
                  ),
                  Positioned(
                    left: math.max(0, width * position - 22),
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.drag_indicator_rounded,
                          color: colors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CompareLabel extends StatelessWidget {
  const _CompareLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(color: Colors.white),
      ),
    );
  }
}

class _CompareInfoCard extends StatelessWidget {
  const _CompareInfoCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RevealClipper extends CustomClipper<Rect> {
  _RevealClipper(this.position);

  final double position;

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, size.width * position, size.height);
  }

  @override
  bool shouldReclip(covariant _RevealClipper oldClipper) {
    return oldClipper.position != position;
  }
}
