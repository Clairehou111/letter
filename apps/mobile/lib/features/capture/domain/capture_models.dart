import 'package:flutter/foundation.dart';
import '../../cycle/domain/local_date.dart';
import '../../health_records/domain/health_record.dart';

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
    this.experiencedDate,
    DateTime? updatedAt,
    this.keepInComfortKit = false,
    this.provenance = HealthRecordProvenance.timingUnknown,
    this.originalProvenance,
    this.writeZoneOffsetMinutes,
    this.writeZoneName,
  }) : updatedAt = updatedAt ?? createdAt;

  final String id;
  final String text;
  final CaptureSource source;
  final DateTime createdAt;
  final LocalDate? experiencedDate;
  final DateTime updatedAt;
  final bool keepInComfortKit;
  final HealthRecordProvenance provenance;
  final HealthRecordProvenance? originalProvenance;
  final int? writeZoneOffsetMinutes;
  final String? writeZoneName;
  DateTime get effectiveUpdatedAt => updatedAt;
  HealthRecordProvenance get effectiveOriginalProvenance =>
      originalProvenance ?? provenance;
  CaptureNote copyWith({
    String? text,
    bool? keepInComfortKit,
    DateTime? updatedAt,
  }) => CaptureNote(
    id: id,
    text: text ?? this.text,
    source: source,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    keepInComfortKit: keepInComfortKit ?? this.keepInComfortKit,
    experiencedDate: experiencedDate,
    provenance: provenance,
    originalProvenance: originalProvenance,
    writeZoneOffsetMinutes: writeZoneOffsetMinutes,
    writeZoneName: writeZoneName,
  );
}

abstract interface class CaptureNoteStore {
  /// Returns only user-authored text and metadata. Raw audio is never accepted
  /// by this local storage boundary.
  Future<CaptureNote> save(CaptureNote note);
  Future<CaptureNote> update(CaptureNote note);
  Future<CaptureNote> restore(CaptureNote note, {CaptureNote? expectedCurrent});

  Future<List<CaptureNote>> getAll();

  Future<void> delete(CaptureNote note, {CaptureNote? expectedCurrent});
}

/// Optional atomic source comparison for existing-note correction. Existing
/// read-only/test adapters keep the base store API unchanged.
abstract interface class ConditionalCaptureNoteStore
    implements CaptureNoteStore {
  Future<CaptureNote> updateIfUnchanged(
    CaptureNote note, {
    required CaptureNote expectedCurrent,
  });
}

final class InMemoryCaptureNoteStore implements ConditionalCaptureNoteStore {
  InMemoryCaptureNoteStore({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;
  final DateTime Function() _clock;
  final List<CaptureNote> notes = [];

  @override
  Future<CaptureNote> save(CaptureNote note) async {
    if (notes.any((n) => n.id == note.id)) {
      throw StateError('Note already exists.');
    }
    final saved = prepareCaptureNoteWrite(note, localNow: _clock().toLocal());
    notes.add(saved);
    return saved;
  }

  @override
  Future<CaptureNote> update(CaptureNote note) => _update(note);

  @override
  Future<CaptureNote> updateIfUnchanged(
    CaptureNote note, {
    required CaptureNote expectedCurrent,
  }) => _update(note, expectedCurrent: expectedCurrent);

  Future<CaptureNote> _update(
    CaptureNote note, {
    CaptureNote? expectedCurrent,
  }) async {
    final index = notes.indexWhere((n) => n.id == note.id);
    if (index < 0) throw StateError('Note no longer available.');
    if (expectedCurrent != null &&
        !sameCaptureNoteVersion(notes[index], expectedCurrent)) {
      throw StateError('Note changed since correction.');
    }
    final saved = prepareCaptureNoteWrite(
      note,
      localNow: _clock().toLocal(),
      previous: notes[index],
    );
    notes[index] = saved;
    return saved;
  }

  @override
  Future<CaptureNote> restore(
    CaptureNote note, {
    CaptureNote? expectedCurrent,
  }) async {
    final existing = notes.where((n) => n.id == note.id).firstOrNull;
    if (expectedCurrent == null
        ? existing != null
        : existing == null ||
              !sameCaptureNoteVersion(existing, expectedCurrent)) {
      throw StateError('Note changed since Undo.');
    }
    if (existing != null) notes.remove(existing);
    notes.add(note);
    return note;
  }

  @override
  Future<List<CaptureNote>> getAll() async {
    return [...notes]
      ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
  }

  @override
  Future<void> delete(CaptureNote note, {CaptureNote? expectedCurrent}) async {
    final existing = notes.where((n) => n.id == note.id).firstOrNull;
    if (expectedCurrent != null &&
        (existing == null ||
            !sameCaptureNoteVersion(existing, expectedCurrent))) {
      throw StateError('Note changed since Undo.');
    }
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

CaptureNote prepareCaptureNoteWrite(
  CaptureNote note, {
  required DateTime localNow,
  CaptureNote? previous,
}) {
  final date = note.experiencedDate;
  final today = LocalDate.fromDateTime(localNow);
  if (date != null && date.isAfter(today)) {
    throw StateError('Choose today or an earlier date.');
  }
  if (note.text.trim().isEmpty || note.text.length > captureTextLimit) {
    throw StateError('Check the note and try again.');
  }
  if (previous != null &&
      previous.text == note.text &&
      previous.source == note.source &&
      previous.experiencedDate == date &&
      previous.keepInComfortKit == note.keepInComfortKit) {
    return previous;
  }
  final changedExperience =
      previous == null ||
      previous.text != note.text ||
      previous.source != note.source ||
      previous.experiencedDate != date;
  final timing = date == null
      ? HealthRecordProvenance.timingUnknown
      : date == today
      ? HealthRecordProvenance.sameDay
      : HealthRecordProvenance.laterRecall;
  return CaptureNote(
    id: note.id,
    text: note.text,
    source: note.source,
    keepInComfortKit: note.keepInComfortKit,
    createdAt:
        previous?.createdAt ??
        DateTime.fromMillisecondsSinceEpoch(
          note.createdAt.millisecondsSinceEpoch,
          isUtc: true,
        ),
    experiencedDate: date,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(
      localNow.millisecondsSinceEpoch,
      isUtc: true,
    ),
    provenance: !changedExperience
        ? previous.provenance
        : previous?.provenance == HealthRecordProvenance.laterRecall &&
              previous?.experiencedDate == date
        ? HealthRecordProvenance.laterRecall
        : timing,
    originalProvenance: previous?.effectiveOriginalProvenance ?? timing,
    writeZoneOffsetMinutes: previous == null
        ? localNow.timeZoneOffset.inMinutes
        : previous.writeZoneOffsetMinutes,
    writeZoneName: previous == null
        ? localNow.timeZoneName
        : previous.writeZoneName,
  );
}

bool sameCaptureNoteVersion(CaptureNote a, CaptureNote b) =>
    a.id == b.id &&
    a.keepInComfortKit == b.keepInComfortKit &&
    a.text == b.text &&
    a.source == b.source &&
    a.experiencedDate == b.experiencedDate &&
    a.createdAt == b.createdAt &&
    a.effectiveUpdatedAt == b.effectiveUpdatedAt &&
    a.provenance == b.provenance &&
    a.effectiveOriginalProvenance == b.effectiveOriginalProvenance &&
    a.writeZoneOffsetMinutes == b.writeZoneOffsetMinutes &&
    a.writeZoneName == b.writeZoneName;
