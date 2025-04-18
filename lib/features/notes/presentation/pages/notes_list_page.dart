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

    try {
      setState(() => _isLoadingUser = true);
      final googleSignIn = GoogleSignIn();

      // First try to get current user
      _currentUser = googleSignIn.currentUser;

      // If no current user, try silent sign in
      _currentUser ??= await googleSignIn.signInSilently();

      if (mounted) {
        setState(() {
          _isLoadingUser = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user: $e');
      if (mounted) {
        setState(() {
          _isLoadingUser = false;
          _currentUser = null;
        });
      }
    }
  }

  void _openProfile() {
    if (_currentUser == null || !mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in again'),
          duration: Duration(seconds: 2),
        ),
      );
      context.go('/login');
      return;
    }

    // Create a local final variable to prevent null issues during navigation
    final user = _currentUser;
    if (user != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ProfilePage(user: user)),
      );
    }
  }

  Future<void> _openDriveFolder(BuildContext context) async {
    const url = 'https://drive.google.com';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  void _openEditor(BuildContext context, NoteModel? note, {String? heroTag}) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder:
            (context, animation, secondaryAnimation) =>
                NoteEditorPage(originalNote: note, heroTag: heroTag),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 0.05);
          const end = Offset.zero;
          const curve = Curves.easeOut;
          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);
          var fadeAnimation = animation.drive(CurveTween(curve: curve));

          return FadeTransition(
            opacity: fadeAnimation,
            child: SlideTransition(position: offsetAnimation, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    ).then((_) {
      final container = ProviderScope.containerOf(context);
      container.invalidate(notesControllerProvider);
    });
  }

  Future<void> _deleteNote(BuildContext context, NoteModel note) async {
    if (!mounted) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Note'),
            content: Text('Are you sure you want to delete "${note.title}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('CANCEL'),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('DELETE'),
              ),
            ],
          ),
    );

    if (shouldDelete == true && mounted) {
      try {
        final container = ProviderScope.containerOf(context);
        await container.read(notesControllerProvider.notifier).delete(note.id);

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deleted ${note.title}'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting note: $e'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  Widget _buildNoteCard(BuildContext context, NoteModel note) {
    final theme = Theme.of(context);
    return Hero(
      tag: 'note_card_${note.id}',
      child: Material(
        color: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: Card(
            elevation: 2,
            margin: const EdgeInsets.all(4),
            child: InkWell(
              onTap:
                  () => _openEditor(
                    context,
                    note,
                    heroTag: 'note_card_${note.id}',
                  ),
              onLongPress: () => _deleteNote(context, note),
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: 100,
                  maxHeight: _isGridView ? 300 : 150,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              note.title.replaceAll(RegExp(r'\.txt$'), ''),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
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
                                builder:
                                    (context) => SafeArea(
                                      child: ListView(
                                        shrinkWrap: true,
                                        children: [
                                          ListTile(
                                            leading: const Icon(Icons.edit),
                                            title: const Text('Edit'),
                                            onTap: () {
                                              Navigator.pop(context);
                                              _openEditor(
                                                context,
                                                note,
                                                heroTag: 'note_card_${note.id}',
                                              );
                                            },
                                          ),
                                          ListTile(
                                            leading: const Icon(
                                              Icons.delete,
                                              color: Colors.red,
                                            ),
                                            title: const Text('Delete'),
                                            onTap: () {
                                              Navigator.pop(context);
                                              _deleteNote(context, note);
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                              );
                            },
                          ),
                        ],
                      ),
                      if (note.content.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Expanded(
                          child: Text(
                            note.content,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.textTheme.bodySmall?.color,
                            ),
                            maxLines: _isGridView ? 6 : 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        timeago.format(note.updatedAt),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final theme = Theme.of(context);
        final notesAsync = ref.watch(notesControllerProvider);
        final saveState = ref.watch(noteSaveProvider);
        final themeMode = ref.watch(themeProvider);
        final isOffline = ref.watch(connectivityProvider);

        // Auto-refresh notes list when save completes
        ref.listen(noteSaveProvider, (previous, next) {
          if (previous?.isSaving == true &&
              next.isSaving == false &&
              !next.isError) {
            ref.invalidate(notesControllerProvider);
          }
        });

        return Scaffold(
          appBar: AppBar(
            title: const Hero(
              tag: 'note_title',
              child: Material(
                color: Colors.transparent,
                child: Text('DriveNotes'),
              ),
            ),
            actions: [
              if (isOffline)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cloud_off,
                        color: theme.colorScheme.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Offline',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
              IconButton(
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    _isGridView ? Icons.view_list : Icons.grid_view,
                    key: ValueKey(_isGridView),
                  ),
                ),
                onPressed: () => setState(() => _isGridView = !_isGridView),
                tooltip: _isGridView ? 'List View' : 'Grid View',
              ),
              IconButton(
                icon: Hero(
                  tag: 'profile_image',
                  child: CircleAvatar(
                    radius: 14,
                    backgroundImage:
                        _currentUser?.photoUrl != null
                            ? NetworkImage(_currentUser!.photoUrl!)
                            : null,
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                    child:
                        (_currentUser?.photoUrl?.isEmpty ?? true)
                            ? Text(
                              (_currentUser?.displayName?.isNotEmpty ?? false)
                                  ? _currentUser!.displayName![0].toUpperCase()
                                  : 'U',
                              style: theme.textTheme.bodySmall,
                            )
                            : null,
                  ),
                ),
                onPressed: _openProfile,
                tooltip: 'Profile',
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  ref.invalidate(notesControllerProvider);
                  HapticFeedback.lightImpact();
                },
                tooltip: 'Refresh Notes',
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () => context.go('/login'),
                tooltip: 'Sign out',
              ),
            ],
          ),
          body: Stack(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: notesAsync.when(
                  loading:
                      () => const Center(child: CircularProgressIndicator()),
                  error:
                      (error, stack) => Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Colors.red,
                            ),
                            const SizedBox(height: 16),
                            Text('Error: $error'),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed:
                                  () => ref.invalidate(notesControllerProvider),
                              child: const Text('RETRY'),
                            ),
                          ],
                        ),
                      ),
                  data: (notes) {
                    if (notes.isEmpty) {
                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 500),
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 20 * (1 - value)),
                              child: child,
                            ),
                          );
                        },
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.note_add,
                                size: 64,
                                color: theme.colorScheme.primary.withOpacity(
                                  0.5,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No notes yet',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.7),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap the + button to create your first note',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child:
                          _isGridView
                              ? MasonryGridView.count(
                                key: const ValueKey('grid'),
                                padding: const EdgeInsets.all(8),
                                crossAxisCount:
                                    MediaQuery.of(context).size.width > 600
                                        ? 3
                                        : 2,
                                mainAxisSpacing: 4,
                                crossAxisSpacing: 4,
                                itemCount: notes.length,
                                itemBuilder:
                                    (context, index) =>
                                        _buildNoteCard(context, notes[index]),
                              )
                              : ListView.builder(
                                key: const ValueKey('list'),
                                padding: const EdgeInsets.all(8),
                                itemCount: notes.length,
                                itemBuilder:
                                    (context, index) =>
                                        _buildNoteCard(context, notes[index]),
                              ),
                    );
                  },
                ),
              ),
              // Save progress indicator
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                left: 0,
                right: 0,
                bottom:
                    saveState.isSaving || saveState.message != null ? 0 : -100,
                child: Material(
                  elevation: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color:
                          saveState.isError
                              ? theme.colorScheme.errorContainer
                              : theme.colorScheme.primaryContainer,
                    ),
                    child: Row(
                      children: [
                        if (saveState.isSaving) ...[
                          const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 16),
                        ],
                        Expanded(
                          child: Text(
                            saveState.message ?? '',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color:
                                  saveState.isError
                                      ? theme.colorScheme.onErrorContainer
                                      : theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        if (saveState.isError)
                          TextButton(
                            onPressed: () {
                              ref.read(noteSaveProvider.notifier).state =
                                  const NoteSaveState();
                            },
                            child: const Text('DISMISS'),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _openEditor(context, null, heroTag: 'new_note'),
            tooltip: 'Add Note',
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}
