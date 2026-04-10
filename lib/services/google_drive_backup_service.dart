import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

class GoogleDriveBackupService {
  GoogleDriveBackupService()
    : _initializeFuture = GoogleSignIn.instance.initialize();

  static const _backupFileName = 'pulsenest_backup.json';
  static const _autoBackupDebounce = Duration(seconds: 3);

  final Future<void> _initializeFuture;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  GoogleSignInAccount? _account;
  Timer? _autoBackupTimer;
  DateTime? _lastBackupAt;

  bool get isSignedIn => _account != null;
  String? get signedInEmail => _account?.email;
  DateTime? get lastBackupAt => _lastBackupAt;

  Future<void> restoreSession() async {
    await _initializeFuture;
    final attempt = _googleSignIn.attemptLightweightAuthentication();
    _account = attempt == null ? null : await attempt;
  }

  Future<void> signIn() async {
    await _initializeFuture;
    _account = await _googleSignIn.authenticate(
      scopeHint: const [drive.DriveApi.driveAppdataScope],
    );
  }

  Future<void> signOut() async {
    _autoBackupTimer?.cancel();
    await _googleSignIn.signOut();
    _account = null;
  }

  void scheduleAutoBackup(Future<String> Function() exportBackupJson) {
    if (!isSignedIn) return;
    _autoBackupTimer?.cancel();
    _autoBackupTimer = Timer(_autoBackupDebounce, () async {
      try {
        final backupJson = await exportBackupJson();
        await uploadBackupJson(backupJson);
      } catch (error, stackTrace) {
        debugPrint('Auto-backup to Google Drive failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    });
  }

  Future<void> uploadBackupJson(String backupJson) async {
    final client = await _createDriveClient();
    try {
      final driveApi = drive.DriveApi(client);
      final existingFile = await _findBackupFile(driveApi);
      final bytes = utf8.encode(backupJson);
      final media = drive.Media(Stream.value(bytes), bytes.length);
      final metadata = drive.File()
        ..name = _backupFileName
        ..mimeType = 'application/json'
        ..parents = const ['appDataFolder'];

      if (existingFile?.id != null) {
        await driveApi.files.update(
          metadata,
          existingFile!.id!,
          uploadMedia: media,
        );
      } else {
        await driveApi.files.create(metadata, uploadMedia: media);
      }
      _lastBackupAt = DateTime.now();
    } finally {
      client.close();
    }
  }

  Future<String?> downloadBackupJson() async {
    final client = await _createDriveClient();
    try {
      final driveApi = drive.DriveApi(client);
      final existingFile = await _findBackupFile(driveApi);
      if (existingFile?.id == null) return null;

      final response = await driveApi.files.get(
        existingFile!.id!,
        downloadOptions: drive.DownloadOptions.fullMedia,
      );
      if (response is! drive.Media) {
        throw StateError('Unexpected Google Drive download response');
      }

      final chunks = <int>[];
      await for (final chunk in response.stream) {
        chunks.addAll(chunk);
      }
      return utf8.decode(chunks);
    } finally {
      client.close();
    }
  }

  Future<drive.File?> _findBackupFile(drive.DriveApi driveApi) async {
    final list = await driveApi.files.list(
      spaces: 'appDataFolder',
      q: "name = '$_backupFileName' and trashed = false",
      orderBy: 'modifiedTime desc',
      pageSize: 1,
      $fields: 'files(id,name,modifiedTime)',
    );
    final files = list.files;
    if (files == null || files.isEmpty) {
      return null;
    }
    return files.first;
  }

  Future<http.Client> _createDriveClient() async {
    await _initializeFuture;
    if (_account == null) {
      final attempt = _googleSignIn.attemptLightweightAuthentication();
      _account = attempt == null ? null : await attempt;
    }
    if (_account == null) {
      throw StateError('Please sign in with Google first');
    }

    final authClient = _account!.authorizationClient;
    const scopes = [drive.DriveApi.driveAppdataScope];
    var authorization = await authClient.authorizationForScopes(scopes);
    authorization ??= await authClient.authorizeScopes(scopes);

    final headers = <String, String>{
      'Authorization': 'Bearer ${authorization.accessToken}',
    };
    return _DriveAuthenticatedClient(headers);
  }

  void dispose() {
    _autoBackupTimer?.cancel();
  }
}

class _DriveAuthenticatedClient extends http.BaseClient {
  _DriveAuthenticatedClient(this._headers);

  final Map<String, String> _headers;
  final http.Client _baseClient = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _baseClient.send(request);
  }

  @override
  void close() {
    _baseClient.close();
  }
}
