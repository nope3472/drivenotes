import 'package:googleapis/drive/v3.dart' as drive;

class FolderService {
  final drive.DriveApi _driveApi;
  static const String folderName = 'DriveNotes';

  FolderService(this._driveApi);

  Future<String> getOrCreateFolder() async {
    // First try to find the folder
    final response = await _driveApi.files.list(
      q: "name='$folderName' and mimeType='application/vnd.google-apps.folder' and trashed=false",
    );

    if (response.files?.isNotEmpty ?? false) {
      return response.files!.first.id!;
    }

    // If not found, create it
    final folder =
        drive.File()
          ..name = folderName
          ..mimeType = 'application/vnd.google-apps.folder';

    final createdFolder = await _driveApi.files.create(folder);
    return createdFolder.id!;
  }
}
