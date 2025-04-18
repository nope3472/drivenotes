import 'package:googleapis/drive/v3.dart' as drive;
import 'package:drivenotes/features/notes/domain/models/note_model.dart';
import 'dart:convert';

class DriveService {
  final drive.DriveApi _driveApi;

  DriveService(this._driveApi);

  Future<String> uploadNote({
    required NoteModel note,
    required String folderId,
  }) async {
    final file =
        drive.File()
          ..name = '${note.id}.json'
          ..parents = [folderId]
          ..mimeType = 'application/json';

    final media = drive.Media(
      note.toJson().toString().codeUnits as Stream<List<int>>,
      'application/json' as int?,
    );

    final response = await _driveApi.files.create(file, uploadMedia: media);

    return response.id!;
  }

  Future<void> deleteNote(String fileId) async {
    await _driveApi.files.delete(fileId);
  }

  Future<List<NoteModel>> getNotes(String folderId) async {
    final response = await _driveApi.files.list(
      q: "'$folderId' in parents and mimeType='application/json'",
    );

    final notes = <NoteModel>[];
    for (final file in response.files ?? []) {
      final media =
          await _driveApi.files.get(
                file.id!,
                downloadOptions: drive.DownloadOptions.fullMedia,
              )
              as drive.Media;

      final bytes = await media.stream.expand((x) => x).toList();
      final content = String.fromCharCodes(bytes);
      notes.add(NoteModel.fromJson(jsonDecode(content)));
    }

    return notes;
  }
}
