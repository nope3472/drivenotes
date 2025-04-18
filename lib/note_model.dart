class NoteModel {
  final String id;
  final String title;
  final String content;
  NoteModel({required this.id, required this.title, required this.content});

  factory NoteModel.fromDrive({
    required String id,
    required String name,
    required String content,
  }) {
    final t = name.endsWith('.txt')
        ? name.substring(0, name.length - 4)
        : name;
    return NoteModel(id: id, title: t, content: content);
  }
}
