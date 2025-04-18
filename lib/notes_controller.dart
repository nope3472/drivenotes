import 'package:drivenotes/features/notes/data/drive_service.dart';
import 'package:drivenotes/features/notes/domain/models/note_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drivenotes/features/notes/data/local_database.dart';

final notesControllerProvider =
    AsyncNotifierProvider<NotesController, List<NoteModel>>(
      NotesController.new,
    );

class NotesController extends AsyncNotifier<List<NoteModel>> {
  @override
  Future<List<NoteModel>> build() async {
    debugPrint('NotesController: Loading notes...');

    // Always get local notes first
    final localNotes = await LocalDatabase.instance.getAllNotes();
    debugPrint('NotesController: Found ${localNotes.length} local notes');

    try {
      // Get unsynced notes before trying to access Drive
      final unsyncedNotes = localNotes.where((note) => !note.isSynced).toList();
      if (unsyncedNotes.isNotEmpty) {
        debugPrint(
          'NotesController: Found ${unsyncedNotes.length} unsynced notes to upload',
        );
        for (var note in unsyncedNotes) {
          try {
            debugPrint(
              'NotesController: Uploading unsynced note: ${note.title}',
            );
            final driveId = await DriveService.instance.createNote(
              note.title,
              note.content,
            );
            await LocalDatabase.instance.markNoteAsSynced(note.id, driveId);
            debugPrint(
              'NotesController: Successfully uploaded and synced note: ${note.title}',
            );
          } catch (e) {
            debugPrint(
              'NotesController: Error uploading note ${note.title} - $e',
            );
            continue;
          }
        }
      }

      // Now get notes from Drive
      final driveFiles = await DriveService.instance.listRawFiles();
      debugPrint('NotesController: Found ${driveFiles.length} files in Drive');

      final driveNotes = <NoteModel>[];
      for (var f in driveFiles) {
        try {
          debugPrint('NotesController: Loading content for file ${f.name}');
          final content = await DriveService.instance.fetchContent(f.id);
          driveNotes.add(
            NoteModel.fromDrive(id: f.id, name: f.name, content: content),
          );
        } catch (e) {
          debugPrint('NotesController: Error loading note ${f.name} - $e');
          continue;
        }
      }

      // Merge notes, prioritizing Drive versions
      final mergedNotes = <NoteModel>[];
      final localNoteMap = {for (var note in localNotes) note.id: note};

      // Add all Drive notes first
      for (var driveNote in driveNotes) {
        mergedNotes.add(driveNote);
        // Remove from local map to track which notes are only local
        localNoteMap.remove(driveNote.id);
      }

      // Add remaining local notes that aren't in Drive
      mergedNotes.addAll(localNoteMap.values);

      debugPrint(
        'NotesController: Merged ${mergedNotes.length} notes (${driveNotes.length} from Drive, ${localNoteMap.length} local-only)',
      );
      return mergedNotes;
    } catch (e) {
      debugPrint(
        'NotesController: Error loading from Drive, using local notes - $e',
      );
      return localNotes;
    }
  }

  Future<void> delete(String id) async {
    debugPrint('NotesController: Deleting note $id');
    state = const AsyncValue.loading();
    try {
      // Get the note first to check if it's synced
      final note = state.value?.firstWhere((n) => n.id == id);

      // Delete from Drive if the note is synced and has a fileId
      if (note?.isSynced == true && note?.fileId != null) {
        try {
          final driveId = note!.fileId!;
          debugPrint('NotesController: Deleting from Drive - ID: $driveId');
          await DriveService.instance.deleteNote(driveId);
          debugPrint('NotesController: Deleted from Drive successfully');
        } catch (e) {
          debugPrint('NotesController: Error deleting from Drive - $e');
          // Continue with local deletion even if Drive fails
        }
      }

      // Always delete locally
      debugPrint('NotesController: Deleting from local DB - ID: $id');
      await LocalDatabase.instance.deleteNote(id);
      debugPrint('NotesController: Deleted from local DB successfully');

      // Get fresh list of notes after deletion
      final updatedNotes = await LocalDatabase.instance.getAllNotes();
      state = AsyncValue.data(updatedNotes);
    } catch (e, st) {
      debugPrint('NotesController: Error deleting note - $e');
      state = AsyncValue.error(e, st);
    }
  }
}
