import 'package:drivenotes/login.dart';
import 'package:drivenotes/note_editor_page.dart';
import 'package:drivenotes/notes_list_page.dart';
import 'package:go_router/go_router.dart';


class AppRouter {
  static final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const LoginPage()),
      GoRoute(path: '/notes', builder: (_, __) => const NotesListPage()),
      GoRoute(path: '/notes/edit',
          builder: (ctx, state) {
            final note = state.extra as dynamic /* NoteModel? */;
            return NoteEditorPage(originalNote: note);
          }
      ),
    ],
  );
}
