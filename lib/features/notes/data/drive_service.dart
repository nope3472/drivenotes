import 'dart:convert';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/googleapis_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class DriveService {
  static final DriveService instance = DriveService._();
  DriveService._();

  static const _storage = FlutterSecureStorage();
  static const _scopes = [
    drive.DriveApi.driveFileScope,
    drive.DriveApi.driveReadonlyScope,
  ];

  late drive.DriveApi _driveApi;

  Future<void> _ensureAuthenticated() async {
    debugPrint('DriveService: Ensuring authentication...');
    final accessToken = await _storage.read(key: 'access_token');
    final refreshToken = await _storage.read(key: 'refresh_token');
    final expiryStr = await _storage.read(key: 'token_expiry');

    if (accessToken == null || refreshToken == null || expiryStr == null) {
      debugPrint('DriveService: Missing authentication tokens');
      throw Exception('Not authenticated');
    }

    final expiry = DateTime.parse(expiryStr).toUtc();
    if (expiry.isBefore(DateTime.now().toUtc())) {
      debugPrint('DriveService: Token expired, refreshing...');
      // Token expired, refresh it
      final client = http.Client();
      try {
        final credentials = await refreshCredentials(
          ClientId(
            '93768373598-your-client-id.apps.googleusercontent.com',
            null,
          ),
          AccessCredentials(
            AccessToken('Bearer', accessToken, expiry),
            refreshToken,
            _scopes,
          ),
          client,
        );

        // Save new tokens
        await _storage.write(
          key: 'access_token',
          value: credentials.accessToken.data,
        );
        await _storage.write(
          key: 'token_expiry',
          value: credentials.accessToken.expiry.toUtc().toIso8601String(),
        );

        _driveApi = drive.DriveApi(authenticatedClient(client, credentials));
        debugPrint('DriveService: Successfully refreshed token');
      } catch (e) {
        debugPrint('DriveService: Error refreshing token - $e');
        client.close();
        rethrow;
      }
    } else {
      debugPrint('DriveService: Using existing valid token');
      // Token still valid
      final credentials = AccessCredentials(
        AccessToken('Bearer', accessToken, expiry),
        refreshToken,
        _scopes,
      );

      _driveApi = drive.DriveApi(
        authenticatedClient(http.Client(), credentials),
      );
    }
  }

  Future<List<DriveFile>> listRawFiles() async {
    debugPrint('DriveService: Fetching .txt files from Drive...');
    await _ensureAuthenticated();

    // Simple query to find only .txt files
    const query = "fileExtension = 'txt' and trashed = false";

    debugPrint('DriveService: Using query: $query');

    try {
      final response = await _driveApi.files.list(
        q: query,
        spaces: 'drive',
        $fields: 'files(id, name)',
        orderBy: 'modifiedTime desc',
        pageSize: 1000,
      );

      debugPrint(
        'DriveService: Found ${response.files?.length ?? 0} .txt files',
      );
      if (response.files?.isNotEmpty == true) {
        for (var file in response.files!) {
          debugPrint('DriveService: Found file: ${file.name} - ID: ${file.id}');
        }
      }

      return response.files
              ?.where((f) => f.id != null && f.name != null)
              .map((f) => DriveFile(id: f.id!, name: f.name!))
              .toList() ??
          [];
    } catch (e) {
      debugPrint('DriveService: Error listing files - $e');
      rethrow;
    }
  }

  Future<String> fetchContent(String fileId) async {
    debugPrint('DriveService: Fetching content for file $fileId');
    await _ensureAuthenticated();
    final media =
        await _driveApi.files.get(
              fileId,
              downloadOptions: drive.DownloadOptions.fullMedia,
            )
            as drive.Media;

    final bytes = await media.stream.fold<List<int>>(
      [],
      (previous, element) => previous..addAll(element),
    );
    return utf8.decode(bytes);
  }

  Future<void> deleteNote(String fileId) async {
    debugPrint('DriveService: Starting delete operation for file $fileId');
    await _ensureAuthenticated();
    try {
      debugPrint('DriveService: Attempting to delete file $fileId from Drive');
      await _driveApi.files.delete(fileId);
      debugPrint('DriveService: Successfully deleted file $fileId from Drive');
    } catch (e, stackTrace) {
      debugPrint('DriveService: Error deleting file $fileId - $e');
      debugPrint('DriveService: Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<String> createNote(String title, String content) async {
    debugPrint('DriveService: Creating new note: $title');
    await _ensureAuthenticated();

    try {
      final file =
          drive.File()
            ..name = title.endsWith('.txt') ? title : '$title.txt'
            ..mimeType = 'text/plain';

      final bytes = utf8.encode(content);
      final media = drive.Media(Stream.value(bytes), bytes.length);

      final result = await _driveApi.files.create(
        file,
        uploadMedia: media,
        $fields: 'id,name',
      );

      debugPrint(
        'DriveService: Successfully created note with ID: ${result.id}',
      );
      return result.id!;
    } catch (e) {
      debugPrint('DriveService: Error creating note - $e');
      throw Exception('Failed to create note: $e');
    }
  }

  Future<void> updateNote({
    required String fileId,
    required String newTitle,
    required String newContent,
  }) async {
    debugPrint('DriveService: Updating note $fileId to $newTitle');
    await _ensureAuthenticated();

    try {
      // First, update the content
      final bytes = utf8.encode(newContent);
      final media = drive.Media(Stream.value(bytes), bytes.length);

      // Then update the metadata (including title)
      final file =
          drive.File()
            ..name = newTitle.endsWith('.txt') ? newTitle : '$newTitle.txt';

      final result = await _driveApi.files.update(
        file,
        fileId,
        uploadMedia: media,
        $fields: 'id,name',
      );

      debugPrint(
        'DriveService: Successfully updated note with ID: ${result.id}',
      );
    } catch (e) {
      debugPrint('DriveService: Error updating note - $e');
      throw Exception('Failed to update note: $e');
    }
  }
}

class DriveFile {
  final String id;
  final String name;

  DriveFile({required this.id, required this.name});
}
