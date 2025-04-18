import 'package:drivenotes/features/notes/data/drive_service.dart';
import 'package:drivenotes/features/notes/domain/models/note_model.dart';
import 'package:drivenotes/notes_controller.dart';
import 'package:drivenotes/features/notes/presentation/providers/note_save_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drivenotes/features/notes/data/local_database.dart';

final noteEditorControllerProvider =
    AsyncNotifierProviderFamily<NoteEditorController, void, NoteModel?>(
      NoteEditorController.new,
    );

final localDatabaseProvider = Provider<LocalDatabase>((ref) => LocalDatabase());

class NoteEditorController extends FamilyAsyncNotifier<void, NoteModel?> {
  late final NoteModel? original;

  @override
  Future<void> build(NoteModel? arg) async {
    original = arg;
  }

  String _ensureTxtExtension(String title) {
    if (!title.toLowerCase().endsWith('.txt')) {
      return '$title.txt';
    }
    return title;
  }

  Future<void> save(String title, String content) async {
    debugPrint('NoteEditorController: Starting save...');
    state = const AsyncValue.loading();

    // Update save state at the start
    ref.read(noteSaveProvider.notifier).state = const NoteSaveState(
      isSaving: true,
      message: 'Saving note...',
    );

    try {
      final fileName = _ensureTxtExtension(title);
      final note = NoteModel.create(title: fileName, content: content);

      // Save locally first
      await ref.read(localDatabaseProvider).insertNote(note);

      // Try to sync to Drive if online
      try {
        if (original == null) {
          debugPrint('NoteEditorController: Creating new note: $fileName');
          await DriveService.instance.createNote(fileName, content);
          // Mark as synced
          await ref
              .read(localDatabaseProvider)
              .markNoteAsSynced(note.id, note.id);
        } else {
          debugPrint(
            'NoteEditorController: Updating note ${original!.id} to: $fileName',
          );
          await DriveService.instance.updateNote(
            fileId: original!.id,
            newTitle: fileName,
            newContent: content,
          );
        }
      } catch (e) {
        debugPrint(
          'NoteEditorController: Note saved locally, will sync when online: $e',
        );
        // Note is saved locally, will sync when online
      }

      // Force refresh the notes list
      debugPrint('NoteEditorController: Refreshing notes list...');
      await ref.refresh(notesControllerProvider.future);

      debugPrint('NoteEditorController: Save completed successfully');
      state = const AsyncValue.data(null);

      // Update save state on success
      ref.read(noteSaveProvider.notifier).state = const NoteSaveState(
        isSaving: false,
        message: 'Note saved successfully!',
      );

      // Clear success message after delay
      Future.delayed(const Duration(seconds: 2), () {
        if (ref.exists(noteSaveProvider)) {
          ref.read(noteSaveProvider.notifier).state = const NoteSaveState();
        }
      });
    } catch (e, st) {
      debugPrint('NoteEditorController: Error during save - $e');
      state = AsyncValue.error(e, st);

      // Update save state on error
      ref.read(noteSaveProvider.notifier).state = NoteSaveState(
        isSaving: false,
        message: 'Error saving note: $e',
        isError: true,
      );
      rethrow;
    }
  }
}
