import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

/// Injects Google OAuth headers into HTTP requests.
class GoogleHttpClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _inner = http.Client();
  GoogleHttpClient(this._headers);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest req) {
    req.headers.addAll(_headers);
    return _inner.send(req);
  }
}

class DriveService {
  DriveService._();
  static final instance = DriveService._();
  final _googleSignIn = GoogleSignIn(scopes: [drive.DriveApi.driveFileScope]);

  Future<drive.DriveApi> _getApi() async {
    var acct = await _googleSignIn.signInSilently();
    acct ??= await _googleSignIn.signIn();
    if (acct == null) throw Exception('Sign‑in aborted');
    final headers = await acct.authHeaders;
    return drive.DriveApi(GoogleHttpClient(headers));
  }

  Future<String> ensureFolderExists() async {
    final api = await _getApi();
    const name = 'DriveNotes';
    final res = await api.files.list(
      q:
          "mimeType='application/vnd.google-apps.folder' and name='$name' and trashed=false",
      $fields: 'files(id)',
    );
    if (res.files != null && res.files!.isNotEmpty) {
      return res.files!.first.id!;
    }
    final folder = drive.File()
      ..name = name
      ..mimeType = 'application/vnd.google-apps.folder';
    final created = await api.files.create(folder);
    return created.id!;
  }

  Future<List<drive.File>> listRawFiles() async {
    final api = await _getApi();
    final folderId = await ensureFolderExists();
    final res = await api.files.list(
      q:
          "'$folderId' in parents and mimeType='text/plain' and trashed=false",
      $fields: 'files(id, name)',
    );
    return res.files ?? [];
  }

  Future<String> fetchContent(String fileId) async {
    final api = await _getApi();
    final media = await api.files.get(fileId,
        downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
    final bytes = <int>[];
    await media.stream.forEach(bytes.addAll);
    return utf8.decode(bytes);
  }

  Future<void> createNote(String title, String content) async {
    final api = await _getApi();
    final folderId = await ensureFolderExists();
    final meta = drive.File()..name = '$title.txt'..parents = [folderId];
    final data = utf8.encode(content);
    await api.files.create(meta,
        uploadMedia: drive.Media(Stream.value(data), data.length,
            contentType: 'text/plain'));
  }

  Future<void> updateNote({
    required String fileId,
    required String newTitle,
    required String newContent,
  }) async {
    final api = await _getApi();
    final meta = drive.File()..name = '$newTitle.txt';
    final data = utf8.encode(newContent);
    await api.files.update(meta, fileId,
        uploadMedia: drive.Media(Stream.value(data), data.length,
            contentType: 'text/plain'));
  }

  Future<void> deleteNote(String fileId) async {
    final api = await _getApi();
    await api.files.delete(fileId);
  }
}
