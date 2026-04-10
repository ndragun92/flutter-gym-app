import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'body_gallery_page.dart';
import '../state/app_state.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _heightController = TextEditingController();
  final _imagePicker = ImagePicker();

  DateTime? _birthDate;
  String? _selectedImagePath;
  bool _initialized = false;
  bool _isImportExportBusy = false;
  bool _isGoogleDriveBusy = false;
  static const XTypeGroup _jsonTypeGroup = XTypeGroup(
    label: 'JSON',
    extensions: ['json'],
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;

    _syncFormWithProfileFromAppState(context.read<AppState>());

    _initialized = true;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  void _syncFormWithProfileFromAppState(AppState appState) {
    final profile = appState.userProfile;
    _fullNameController.text = profile?.fullName ?? '';
    _heightController.text = profile?.heightCm.toStringAsFixed(1) ?? '';
    _birthDate = profile?.birthDate;
    _selectedImagePath = profile?.profileImagePath;
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final profile = appState.userProfile;
    final hasImage =
        _selectedImagePath != null &&
        _selectedImagePath!.isNotEmpty &&
        File(_selectedImagePath!).existsSync();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Profile & settings',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Add your details to unlock smarter goals and insights.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundImage: hasImage
                              ? FileImage(File(_selectedImagePath!))
                              : null,
                          child: hasImage
                              ? null
                              : const Icon(Icons.person_rounded, size: 30),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            profile?.fullName.isNotEmpty == true
                                ? profile!.fullName
                                : 'Your profile',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.camera_alt_rounded),
                          label: const Text('Take photo'),
                          onPressed: () =>
                              _pickProfileImage(ImageSource.camera),
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Upload photo'),
                          onPressed: () =>
                              _pickProfileImage(ImageSource.gallery),
                        ),
                        if (hasImage)
                          TextButton.icon(
                            icon: const Icon(Icons.delete_outline_rounded),
                            label: const Text('Remove'),
                            onPressed: () {
                              setState(() {
                                _selectedImagePath = null;
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _fullNameController,
                      decoration: const InputDecoration(labelText: 'Full name'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.cake_outlined),
                      label: Text(
                        _birthDate == null
                            ? 'Birth date'
                            : DateFormat('d MMM yyyy').format(_birthDate!),
                      ),
                      onPressed: _pickBirthDate,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _heightController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Height (cm)',
                      ),
                      validator: (value) {
                        final parsed = double.tryParse((value ?? '').trim());
                        if (parsed == null || parsed < 80 || parsed > 260) {
                          return 'Enter valid height';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _saveProfile,
                      child: const Text('Save profile'),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _isImportExportBusy ? null : _exportData,
                          icon: _isImportExportBusy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.download_rounded),
                          label: const Text('Export data'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _isImportExportBusy ? null : _importData,
                          icon: const Icon(Icons.upload_file_rounded),
                          label: const Text('Import data'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          Icons.cloud_sync_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Google Drive backup',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      appState.isGoogleDriveSignedIn
                          ? 'Connected as ${appState.googleDriveAccountEmail ?? 'Google account'}'
                          : 'Sign in to back up and restore your data from Google Drive.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _isGoogleDriveBusy
                              ? null
                              : (appState.isGoogleDriveSignedIn
                                    ? _signOutFromGoogleDrive
                                    : _signInWithGoogleDrive),
                          icon: _isGoogleDriveBusy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  appState.isGoogleDriveSignedIn
                                      ? Icons.logout_rounded
                                      : Icons.login_rounded,
                                ),
                          label: Text(
                            appState.isGoogleDriveSignedIn
                                ? 'Sign out'
                                : 'Sign in with Google',
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed:
                              _isGoogleDriveBusy ||
                                  !appState.isGoogleDriveSignedIn
                              ? null
                              : _backupToGoogleDrive,
                          icon: const Icon(Icons.backup_rounded),
                          label: const Text('Backup to Google Drive'),
                        ),
                        OutlinedButton.icon(
                          onPressed:
                              _isGoogleDriveBusy ||
                                  !appState.isGoogleDriveSignedIn
                              ? null
                              : _restoreFromGoogleDrive,
                          icon: const Icon(Icons.restore_rounded),
                          label: const Text('Restore from Google Drive'),
                        ),
                      ],
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: appState.autoBackupToGoogleDriveEnabled,
                      onChanged: !appState.isGoogleDriveSignedIn
                          ? null
                          : (enabled) {
                              appState.setAutoBackupToGoogleDriveEnabled(
                                enabled,
                              );
                            },
                      title: const Text('Auto-upload changes'),
                      subtitle: Text(
                        appState.isGoogleDriveSignedIn
                            ? 'Automatically uploads after important data changes.'
                            : 'Sign in with Google to enable auto-upload.',
                      ),
                    ),
                    if (appState.lastGoogleDriveBackupAt != null)
                      Text(
                        'Last Google Drive backup: ${DateFormat('d MMM yyyy, HH:mm').format(appState.lastGoogleDriveBackupAt!.toLocal())}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.65),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.photo_library_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Body gallery',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              appState.bodyProgressPhotos.isEmpty
                                  ? 'Upload progress pictures and compare any two with a slider.'
                                  : '${appState.bodyProgressPhotos.length} photos saved for progress tracking.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.7),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const BodyGalleryPage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.compare_rounded),
                    label: const Text('Open body gallery'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _InsightsCard(appState: appState),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: appState.currentBmi == null
                ? null
                : () async {
                    await appState.applySmartGoalsFromProfile();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Smart goals applied from profile'),
                      ),
                    );
                  },
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const Text('Apply smart goal suggestions'),
          ),
          const SizedBox(height: 90),
        ],
      ),
    );
  }

  Future<void> _pickBirthDate() async {
    final current = _birthDate ?? DateTime(2000, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      _birthDate = picked;
    });
  }

  Future<void> _pickProfileImage(ImageSource source) async {
    final picked = await _imagePicker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1440,
    );
    if (picked == null) return;
    final savedPath = await _persistProfileImage(picked.path);
    if (!mounted) return;
    setState(() {
      _selectedImagePath = savedPath;
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_birthDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Birth date is required')));
      return;
    }

    await context.read<AppState>().updateUserProfile(
      fullName: _fullNameController.text.trim(),
      birthDate: _birthDate!,
      heightCm: double.parse(_heightController.text.trim()),
      profileImagePath: _selectedImagePath,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Profile saved')));
  }

  Future<void> _exportData() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final appState = context.read<AppState>();

    setState(() {
      _isImportExportBusy = true;
    });

    try {
      final json = await appState.exportBackupJson();
      final suggestedName =
          'pulsenest_backup_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json';

      if (Platform.isAndroid || Platform.isIOS) {
        final tempDir = await getTemporaryDirectory();
        final exportFile = File('${tempDir.path}/$suggestedName');
        await exportFile.writeAsString(json);

        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(exportFile.path)],
            subject: 'PulseNest backup - ${DateTime.now().toLocal()}',
            text: 'PulseNest backup exported on ${DateTime.now().toLocal()}',
          ),
        );

        if (mounted) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Backup file ready to share')),
          );
        }
        return;
      }

      final location = await getSaveLocation(
        suggestedName: suggestedName,
        acceptedTypeGroups: const [_jsonTypeGroup],
      );
      if (location != null) {
        await File(location.path).writeAsString(json);
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text('Data exported to ${location.path}')),
          );
        }
      }
    } catch (error) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Export failed: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isImportExportBusy = false;
        });
      }
    }
  }

  Future<void> _importData() async {
    final appState = context.read<AppState>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final shouldImport =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Import data?'),
            content: const Text(
              'Importing will fully replace your current app data with the contents of the selected backup file.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Import'),
              ),
            ],
          ),
        ) ??
        false;
    if (!shouldImport) return;

    setState(() {
      _isImportExportBusy = true;
    });

    try {
      final file = await openFile(acceptedTypeGroups: const [_jsonTypeGroup]);
      if (file != null) {
        final content = await file.readAsString();
        await appState.importBackupJson(content);

        if (mounted) {
          setState(() {
            _syncFormWithProfileFromAppState(appState);
          });
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Data imported successfully')),
          );
        }
      }
    } on FormatException catch (error) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Import failed: ${error.message}')),
        );
      }
    } catch (error) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Import failed: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isImportExportBusy = false;
        });
      }
    }
  }

  Future<void> _signInWithGoogleDrive() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _isGoogleDriveBusy = true;
    });
    try {
      await context.read<AppState>().signInWithGoogleDrive();
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Signed in with Google successfully')),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Google sign-in failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleDriveBusy = false;
        });
      }
    }
  }

  Future<void> _signOutFromGoogleDrive() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _isGoogleDriveBusy = true;
    });
    try {
      await context.read<AppState>().signOutFromGoogleDrive();
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Signed out from Google Drive')),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Sign out failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleDriveBusy = false;
        });
      }
    }
  }

  Future<void> _backupToGoogleDrive() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _isGoogleDriveBusy = true;
    });
    try {
      await context.read<AppState>().backupToGoogleDriveNow();
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Backup uploaded to Google Drive')),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Backup failed: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleDriveBusy = false;
        });
      }
    }
  }

  Future<void> _restoreFromGoogleDrive() async {
    final shouldRestore =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Restore from Google Drive?'),
            content: const Text(
              'This replaces your current app data with the latest Google Drive backup.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Restore'),
              ),
            ],
          ),
        ) ??
        false;
    if (!shouldRestore) return;
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _isGoogleDriveBusy = true;
    });
    try {
      final appState = context.read<AppState>();
      await appState.restoreFromGoogleDrive();
      if (!mounted) return;
      setState(() {
        _syncFormWithProfileFromAppState(appState);
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Data restored from Google Drive')),
      );
    } on FormatException catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Restore failed: ${error.message}')),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Restore failed: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleDriveBusy = false;
        });
      }
    }
  }

  Future<String> _persistProfileImage(String sourcePath) async {
    final source = File(sourcePath);
    final directory = await getApplicationDocumentsDirectory();
    final profileDir = Directory('${directory.path}/profile_images');
    if (!await profileDir.exists()) {
      await profileDir.create(recursive: true);
    }

    final extension = source.path.contains('.')
        ? source.path.substring(source.path.lastIndexOf('.'))
        : '.jpg';
    final fileName =
        'profile_${DateTime.now().microsecondsSinceEpoch}$extension';
    final targetPath = '${profileDir.path}/$fileName';
    final copied = await source.copy(targetPath);
    return copied.path;
  }
}

class _InsightsCard extends StatelessWidget {
  const _InsightsCard({required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final age = appState.profileAge;
    final bmi = appState.currentBmi;
    final bmiCategory = appState.currentBmiCategory;
    final minWeight = appState.healthyWeightMinKg;
    final maxWeight = appState.healthyWeightMaxKg;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Health insights',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (appState.userProfile == null)
              const Text(
                'Save your profile first to see personalized insights.',
              )
            else ...[
              _InsightLine(label: 'Age', value: age == null ? '—' : '$age yrs'),
              _InsightLine(
                label: 'Latest weight',
                value: appState.latestWeightKg == null
                    ? 'Add a body entry'
                    : '${appState.latestWeightKg!.toStringAsFixed(1)} kg',
              ),
              _InsightLine(
                label: 'BMI',
                value: bmi == null
                    ? 'Add a body entry'
                    : '${bmi.toStringAsFixed(1)} ($bmiCategory)',
              ),
              _InsightLine(
                label: 'Healthy weight range',
                value: minWeight == null || maxWeight == null
                    ? '—'
                    : '${minWeight.toStringAsFixed(1)} - ${maxWeight.toStringAsFixed(1)} kg',
              ),
              const Divider(height: 20),
              _InsightLine(
                label: 'Suggested calories',
                value: appState.suggestedDailyCalories == null
                    ? 'Add more data'
                    : '${appState.suggestedDailyCalories} kcal/day',
              ),
              _InsightLine(
                label: 'Suggested protein',
                value: appState.suggestedDailyProtein == null
                    ? 'Add more data'
                    : '${appState.suggestedDailyProtein!.toStringAsFixed(0)} g/day',
              ),
              _InsightLine(
                label: 'Suggested workouts',
                value: appState.suggestedWeeklyWorkouts == null
                    ? 'Add more data'
                    : '${appState.suggestedWeeklyWorkouts} / week',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InsightLine extends StatelessWidget {
  const _InsightLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
