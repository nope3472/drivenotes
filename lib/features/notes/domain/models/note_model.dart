import 'package:freezed_annotation/freezed_annotation.dart';

part 'note_model.freezed.dart';
part 'note_model.g.dart';

@freezed
class NoteModel with _$NoteModel {
  const factory NoteModel({
    required String id,
    required String title,
    required String content,
    required DateTime createdAt,
    required DateTime updatedAt,
    String? fileId,
    @Default(false) bool isSynced,
  }) = _NoteModel;

  factory NoteModel.fromJson(Map<String, dynamic> json) =>
      _$NoteModelFromJson(json);

  factory NoteModel.create({required String title, required String content}) {
    final now = DateTime.now();
    return NoteModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      content: content,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory NoteModel.fromDrive({
    required String id,
    required String name,
    required String content,
  }) {
    final title =
        name.endsWith('.txt') ? name.substring(0, name.length - 4) : name;
    return NoteModel(
      id: id,
      title: title,
      content: content,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isSynced: true,
    );
  }
}
