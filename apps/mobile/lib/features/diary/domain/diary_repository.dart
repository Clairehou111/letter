import '../../cycle/domain/local_date.dart';
import 'diary_enrollment.dart';

abstract interface class DiaryEnrollmentRepository {
  /// Returns the most recent enrollment, or null if never enrolled.
  Future<DiaryEnrollment?> getLatest();

  /// Returns all enrollments ordered by start date descending.
  Future<List<DiaryEnrollment>> getAll();

  /// Creates a new enrollment. An active enrollment must be stopped or paused
  /// first; implementations enforce the single-active-enrollment rule.
  Future<DiaryEnrollment> create(DiaryEnrollmentDraft draft);

  /// Updates status or reminder of an existing enrollment.
  Future<DiaryEnrollment> update(String id, DiaryEnrollmentUpdate update);

  Future<void> close();
}

/// Required fields to create a new enrollment.
final class DiaryEnrollmentDraft {
  const DiaryEnrollmentDraft({this.reminder, this.startedAt});

  final DiaryReminder? reminder;

  /// Override for tests; defaults to now in production.
  final DateTime? startedAt;
}

/// Allowed mutations for an existing enrollment.
final class DiaryEnrollmentUpdate {
  const DiaryEnrollmentUpdate({
    this.status,
    this.reminder,
    this.stoppedAt,
    this.stoppedReason,
  });

  final DiaryEnrollmentStatus? status;
  final DiaryReminder? reminder;
  final DateTime? stoppedAt;
  final String? stoppedReason;

  bool get hasChanges =>
      status != null ||
      reminder != null ||
      stoppedAt != null ||
      stoppedReason != null;
}

abstract interface class DiaryEntryRepository {
  /// Returns all entries for an enrollment, ordered by experienced date.
  Future<List<DiaryEntry>> getEntries(String enrollmentId);

  /// Saves or replaces the entry for a given enrollment + experienced date.
  /// If an entry already exists for that date it is overwritten (edit).
  Future<DiaryEntry> saveEntry(DiaryEntryDraft draft);

  /// Deletes a single entry. Missed days are simply absent; never backfilled.
  Future<void> deleteEntry(String entryId);

  /// Returns all entries within a date range across all enrollments, for
  /// coverage views and reports.
  Future<List<DiaryEntry>> getEntriesInRange(
    LocalDate start,
    LocalDate end,
  );

  Future<void> close();
}

/// Draft to save or update a daily entry.
final class DiaryEntryDraft {
  const DiaryEntryDraft({
    required this.enrollmentId,
    required this.experiencedDate,
    this.provenance = DiaryEntryProvenance.prospective,
    this.symptoms = const {},
    this.functionalImpacts = const {},
  });

  final String enrollmentId;
  final LocalDate experiencedDate;
  final DiaryEntryProvenance provenance;
  final Map<String, int> symptoms;
  final Map<String, int> functionalImpacts;
}

/// Failure modes for diary operations. No health data in messages.
enum DiaryFailure {
  enrollmentAlreadyActive,
  enrollmentNotFound,
  enrollmentNotActive,
  invalidRating,
  entryNotFound,
  storageUnavailable,
}

final class DiaryException implements Exception {
  const DiaryException(this.failure);

  final DiaryFailure failure;

  String get userMessage => switch (failure) {
    DiaryFailure.enrollmentAlreadyActive =>
      'You already have an active diary. Pause or stop it first.',
    DiaryFailure.enrollmentNotFound => 'Diary enrollment not found.',
    DiaryFailure.enrollmentNotActive =>
      'Start or resume a diary enrollment first.',
    DiaryFailure.invalidRating => 'Each rating must be 0–5.',
    DiaryFailure.entryNotFound => 'This diary entry is no longer available.',
    DiaryFailure.storageUnavailable =>
      'Letter could not update your private diary. Try again.',
  };

  @override
  String toString() => 'DiaryException($failure)';
}
