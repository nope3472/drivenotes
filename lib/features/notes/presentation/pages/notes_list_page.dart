import 'package:drivenotes/features/notes/domain/models/note_model.dart';
import 'package:drivenotes/features/notes/presentation/providers/note_editor_controller.dart';
import 'package:drivenotes/note_editor_page.dart';
import 'package:drivenotes/notes_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:drivenotes/features/notes/presentation/providers/note_save_provider.dart';
import 'package:drivenotes/features/notes/presentation/providers/theme_provider.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:drivenotes/features/notes/presentation/pages/profile_page.dart';
import 'package:drivenotes/features/connectivity/providers/connectivity_provider.dart';

class NotesListPage extends StatefulWidget {
  const NotesListPage({super.key});

  @override
  State<NotesListPage> createState() => _NotesListPageState();
}

class _NotesListPageState extends State<NotesListPage> {
  bool _isGridView = true;
  GoogleSignInAccount? _currentUser;
  bool _isLoadingUser = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadUser();
  }

  Future<void> _loadUser() async {
    if (_isLoadingUser) return;
    setState(() => _isLoadingUser = true);

    try {
      final googleSignIn = GoogleSignIn();
      _currentUser =
          googleSignIn.currentUser ?? await googleSignIn.signInSilently();
    } catch (e) {
      debugPrint('Error loading user: $e');
      _currentUser = null;
    } finally {
      if (mounted) setState(() => _isLoadingUser = false);
    }
  }

  void _openProfile(BuildContext context) {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in again')),
      );
      context.go('/login');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfilePage(user: _currentUser!)),
    );
  }

  Future<void> _openDriveFolder() async {
    const url = 'https://drive.google.com';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  Future<void> _deleteNote(
    WidgetRef ref,
    BuildContext context,
    NoteModel note,
  ) async {
    // Capture messenger before async gaps
    final messenger = ScaffoldMessenger.of(context);
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Note'),
        content: Text('Are you sure you want to delete "${note.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('CANCEL')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    try {
      await ref.read(notesControllerProvider.notifier).delete(note.id);
      messenger.showSnackBar(
        SnackBar(content: Text('Deleted "${note.title}"')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error deleting "${note.title}": $e')),
      );
    }
  }

  void _openEditor(
    WidgetRef ref,
    BuildContext context,
    NoteModel? note, {
    String? heroTag,
  }) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => NoteEditorPage(originalNote: note, heroTag: heroTag),
        transitionsBuilder: (_, anim, __, child) {
          final tween = Tween(begin: const Offset(0, 0.05), end: Offset.zero)
              .chain(CurveTween(curve: Curves.easeOut));
          return FadeTransition(opacity: anim, child: SlideTransition(position: anim.drive(tween), child: child));
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    ).then((_) => ref.invalidate(notesControllerProvider));
  }

  Widget _buildNoteCard(
    WidgetRef ref,
    BuildContext context,
    NoteModel note,
  ) {
    final theme = Theme.of(context);
    return Hero(
      tag: 'note_card_${note.id}',
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.all(4),
        child: InkWell(
          onTap: () => _openEditor(ref, context, note, heroTag: 'note_card_${note.id}'),
          onLongPress: () => _deleteNote(ref, context, note),
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: 100, maxHeight: _isGridView ? 300 : 150),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & menu
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          note.title.replaceAll(RegExp(r'\.txt$'), ''),
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_vert),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          showModalBottomSheet(
                            context: context,
                            builder: (ctx) => SafeArea(
                              child: ListView(shrinkWrap: true, children: [
                                ListTile(
                                  leading: const Icon(Icons.edit),
                                  title: const Text('Edit'),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    _openEditor(ref, context, note, heroTag: 'note_card_${note.id}');
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.delete, color: Colors.red),
                                  title: const Text('Delete'),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    _deleteNote(ref, context, note);
                                  },
                                ),
                              ]),
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  // Content preview
                  if (note.content.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Expanded(
                      child: Text(
                        note.content,
                        style: theme.textTheme.bodyMedium,
                        maxLines: _isGridView ? 6 : 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],

                  // Timestamp
                  const SizedBox(height: 8),
                  Text(timeago.format(note.updatedAt), style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, _) {
      final theme = Theme.of(context);
      final notesAsync = ref.watch(notesControllerProvider);
      final saveState = ref.watch(noteSaveProvider);
      final isOffline = ref.watch(connectivityProvider);

      // Auto-refresh after save
      ref.listen<NoteSaveState?>(noteSaveProvider, (prev, next) {
        if (prev?.isSaving == true && next?.isSaving == false && next?.isError == false) {
          ref.invalidate(notesControllerProvider);
        }
      });

      return Scaffold(
        appBar: AppBar(
          title: const Hero(tag: 'note_title', child: Material(color: Colors.transparent, child: Text('DriveNotes'))),
          actions: [
            if (isOffline)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.cloud_off, color: theme.colorScheme.error, size: 20),
                  const SizedBox(width: 8),
                  Text('Offline', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error)),
                ]),
              ),
            IconButton(
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(_isGridView ? Icons.view_list : Icons.grid_view, key: ValueKey(_isGridView)),
              ),
              onPressed: () => setState(() => _isGridView = !_isGridView),
            ),
            IconButton(
              icon: Hero(
                tag: 'profile_image',
                child: CircleAvatar(
                  radius: 14,
                  backgroundImage: (_currentUser?.photoUrl?.isNotEmpty ?? false)
                      ? NetworkImage(_currentUser!.photoUrl!)
                      : null,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  child: (_currentUser?.photoUrl?.isEmpty ?? true)
                      ? Text(
                          (_currentUser?.displayName?.isNotEmpty ?? false)
                              ? _currentUser!.displayName![0].toUpperCase()
                              : 'U',
                          style: theme.textTheme.bodySmall,
                        )
                      : null,
                ),
              ),
              onPressed: () => _openProfile(context),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(notesControllerProvider),
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await GoogleSignIn().signOut();
                if (mounted) context.go('/login');
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: notesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error: $e'),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: () => ref.invalidate(notesControllerProvider), child: const Text('RETRY')),
                  ]),
                ),
                data: (notes) {
                  if (notes.isEmpty) {
                    return Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.note_add, size: 64, color: theme.colorScheme.primary.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        Text(
                          'No notes yet',
                          style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7)),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap the + button to create your first note',
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.5)),
                        ),
                      ]),
                    );
                  }
                  return _isGridView
                      ? MasonryGridView.count(
                          crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
                          itemCount: notes.length,
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 4,
                          padding: const EdgeInsets.all(8),
                          itemBuilder: (_, i) => _buildNoteCard(ref, context, notes[i]),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: notes.length,
                          itemBuilder: (_, i) => _buildNoteCard(ref, context, notes[i]),
                        );
                },
              ),
            ),

            // your save-progress indicator remains unchanged
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _openEditor(ref, context, null, heroTag: 'new_note'),
          child: const Icon(Icons.add),
        ),
      );
    });
  }
}
