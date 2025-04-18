import 'package:drivenotes/features/notes/domain/models/note_model.dart';
import 'package:drivenotes/notes_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'note_editor_page.dart';


class NotesListPage extends ConsumerWidget {
  const NotesListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Your Notes')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Objective:\n'
                'Build a Flutter application that allows users to authenticate '
                'with Google using OAuth 2.0 and view, create, and update text '
                'notes that are stored and synced with the user\'s Google Drive.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: notesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (notes) {
                if (notes.isEmpty) {
                  return const Center(child: Text('No notes yet.'));
                }
                return ListView.builder(
                  itemCount: notes.length,
                  itemBuilder: (ctx, i) {
                    final n = notes[i];
                    return Card(
                      child: ListTile(
                        title: Text(n.title),
                        onTap: () => _openEditor(context, ref, n),
                        onLongPress: () => ref
                            .read(notesControllerProvider.notifier)
                            .delete(n.id)
                            .then((_) => ScaffoldMessenger.of(context)
                                .showSnackBar(
                                    const SnackBar(content: Text('Deleted')))),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ]),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(context, ref, null),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _openEditor(BuildContext c, WidgetRef r, NoteModel? n) {
    Navigator.of(c)
        .push(MaterialPageRoute(
            builder: (_) => NoteEditorPage(originalNote: n)))
        .then((_) => r.invalidate(notesControllerProvider));
  }
}
