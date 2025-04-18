import 'package:flutter_riverpod/flutter_riverpod.dart';

final noteSaveProvider = StateProvider<NoteSaveState>(
  (ref) => const NoteSaveState(),
);

class NoteSaveState {
  final bool isSaving;
  final String? message;
  final bool isError;

  const NoteSaveState({
    this.isSaving = false,
    this.message,
    this.isError = false,
  });

  NoteSaveState copyWith({bool? isSaving, String? message, bool? isError}) {
    return NoteSaveState(
      isSaving: isSaving ?? this.isSaving,
      message: message ?? this.message,
      isError: isError ?? this.isError,
    );
  }
}
