import 'package:flutter/foundation.dart';

const captureTextLimit = 2000;

enum CaptureSource { typed, voiceTranscript }

enum CaptureStatus {
  editing,
  requestingPermission,
  listening,
  reviewing,
  saving,
  saved,
  permissionDenied,
  unavailable,
  interrupted,
  failed,
  saveFailed,
  deleteFailed,
  canceled,
  deleted,
}

enum SpeechPermissionStatus { granted, denied }

enum SpeechAvailability { available, unavailable }

enum SpeechFailureReason { permissionDenied, unavailable, interrupted, failed }

@immutable
final class SpeechTranscript {
  const SpeechTranscript({required this.text, required this.isFinal});

  final String text;
  final bool isFinal;
}

@immutable
final class SpeechCaptureFailure {
  const SpeechCaptureFailure(this.reason, {this.message});

  final SpeechFailureReason reason;
  final String? message;
}

@immutable
final class CaptureNote {
  const CaptureNote({
    required this.id,
    required this.text,
    required this.source,
    required this.createdAt,
  });

  final String id;
  final String text;
  final CaptureSource source;
  final DateTime createdAt;
}

abstract interface class CaptureNoteStore {
  /// Returns only user-authored text and metadata. Raw audio is never accepted
  /// by this local storage boundary.
  Future<CaptureNote> save(CaptureNote note);

  Future<List<CaptureNote>> getAll();

  Future<void> delete(CaptureNote note);
}

final class InMemoryCaptureNoteStore implements CaptureNoteStore {
  final List<CaptureNote> notes = [];

  @override
  Future<CaptureNote> save(CaptureNote note) async {
    notes.add(note);
    return note;
  }

  @override
  Future<List<CaptureNote>> getAll() async {
    return [...notes]
      ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
  }

  @override
  Future<void> delete(CaptureNote note) async {
    notes.removeWhere((entry) => entry.id == note.id);
  }
}

@immutable
final class CaptureState {
  const CaptureState({
    this.status = CaptureStatus.editing,
    this.draftText = '',
    this.transcriptText = '',
    this.savedNote,
    this.errorMessage,
  });

  final CaptureStatus status;
  final String draftText;
  final String transcriptText;
  final CaptureNote? savedNote;
  final String? errorMessage;

  bool get isBusy =>
      status == CaptureStatus.requestingPermission ||
      status == CaptureStatus.listening ||
      status == CaptureStatus.saving ||
      status == CaptureStatus.deleteFailed;

  bool get hasText => draftText.trim().isNotEmpty;

  CaptureState copyWith({
    CaptureStatus? status,
    String? draftText,
    String? transcriptText,
    CaptureNote? savedNote,
    String? errorMessage,
    bool clearSavedNote = false,
    bool clearError = false,
  }) {
    return CaptureState(
      status: status ?? this.status,
      draftText: draftText ?? this.draftText,
      transcriptText: transcriptText ?? this.transcriptText,
      savedNote: clearSavedNote ? null : savedNote ?? this.savedNote,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
