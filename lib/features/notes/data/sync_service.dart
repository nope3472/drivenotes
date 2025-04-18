import 'package:drivenotes/features/notes/data/local_database.dart';
import 'package:drivenotes/features/notes/domain/models/note_model.dart';
import 'package:drivenotes/features/notes/domain/services/drive_service.dart';
import 'package:drivenotes/features/notes/domain/services/folder_service.dart';

class SyncService {
  final LocalDatabase _localDatabase = LocalDatabase.instance;
  final DriveService _driveService;
  final FolderService _folderService;

  SyncService({
    required DriveService driveService,
    required FolderService folderService,
  }) : _driveService = driveService,
       _folderService = folderService;

  Future<void> syncNotes() async {
    // Get unsynced notes from local database
    final unsyncedNotes = await _localDatabase.getUnsyncedNotes();

    // Ensure DriveNotes folder exists
    final folderId = await _folderService.getOrCreateFolder();

    // Upload each unsynced note to Google Drive
    for (final note in unsyncedNotes) {
      try {
        final driveId = await _driveService.uploadNote(
          note: note,
          folderId: folderId,
        );

        // Mark note as synced in local database
        await _localDatabase.markNoteAsSynced(note.id, driveId);
      } catch (e) {
        print('Error syncing note ${note.id}: $e');
        // Continue with next note even if one fails
        continue;
      }
    }
  }

  Future<List<NoteModel>> getNotes() async {
    // First try to get notes from local database
    final localNotes = await _localDatabase.getAllNotes();

    // If we have unsynced notes, try to sync them
    if (localNotes.any((note) => note.isSynced == false)) {
      await syncNotes();
    }

    // Return the updated local notes
    return await _localDatabase.getAllNotes();
  }

  Future<void> saveNote(NoteModel note) async {
    // Save to local database first
    await _localDatabase.insertNote(note);

    // Try to sync immediately only if we have internet
    try {
      // Check if we can reach Google's servers
      await Future.delayed(Duration.zero); // This will throw if we're offline
      await syncNotes();
    } catch (e) {
      print('Note saved locally. Will sync when online: $e');
      // Note is saved locally, will sync next time we're online
    }
  }

  Future<void> deleteNote(String id) async {
    // Delete from local database
    await _localDatabase.deleteNote(id);

    // Try to delete from Drive if synced
    try {
      final note = await _localDatabase.getNoteById(id);
      if (note?.fileId != null) {
        await _driveService.deleteNote(note!.fileId!);
      }
    } catch (e) {
      print('Error deleting from Drive: $e');
      // Note is deleted locally, will handle Drive deletion next sync
    }
  }
}
