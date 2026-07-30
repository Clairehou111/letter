import '../../cycle/domain/local_date.dart';
import '../domain/diary_enrollment.dart';
import '../domain/diary_repository.dart';

/// In-memory implementation for tests and previews. Not for production use
/// (no encryption, no persistence).
final class InMemoryDiaryEnrollmentRepository
    implements DiaryEnrollmentRepository {
  InMemoryDiaryEnrollmentRepository({DateTime Function()? clock})
    : _clock = clock ?? (() => DateTime.now());

  final DateTime Function() _clock;
  final List<DiaryEnrollment> _enrollments = [];
  int _nextId = 1;

  DateTime get _now => _clock();

  @override
  Future<DiaryEnrollment?> getLatest() async {
    final sorted = _enrollments.toList()
      ..sort((left, right) => right.startedAt.compareTo(left.startedAt));
    return sorted.isEmpty ? null : sorted.first;
  }

  @override
  Future<List<DiaryEnrollment>> getAll() async {
    return _enrollments.toList()
      ..sort((left, right) => right.startedAt.compareTo(left.startedAt));
  }

  @override
  Future<DiaryEnrollment> create(DiaryEnrollmentDraft draft) async {
    final active = _enrollments.any(
      (enrollment) => enrollment.isActive,
    );
    if (active) {
      throw const DiaryException(DiaryFailure.enrollmentAlreadyActive);
    }
    final enrollment = DiaryEnrollment(
      id: 'diary-enrollment-${_nextId++}',
      status: DiaryEnrollmentStatus.active,
      startedAt: draft.startedAt ?? _now,
      reminder: draft.reminder,
    );
    _enrollments.add(enrollment);
    return enrollment;
  }

  @override
  Future<DiaryEnrollment> update(
    String id,
    DiaryEnrollmentUpdate update,
  ) async {
    final index = _enrollments.indexWhere((enrollment) => enrollment.id == id);
    if (index == -1) {
      throw const DiaryException(DiaryFailure.enrollmentNotFound);
    }
    final updated = _enrollments[index].copyWith(
      status: update.status,
      reminder: update.reminder,
      stoppedAt: update.stoppedAt ?? _now,
      stoppedReason: update.stoppedReason,
    );
    _enrollments[index] = updated;
    return updated;
  }

  @override
  Future<void> close() async => _enrollments.clear();
}

/// In-memory implementation for tests and previews.
final class InMemoryDiaryEntryRepository implements DiaryEntryRepository {
  InMemoryDiaryEntryRepository({DateTime Function()? clock})
    : _clock = clock ?? (() => DateTime.now());

  final DateTime Function() _clock;
  final List<DiaryEntry> _entries = [];
  int _nextId = 1;

  @override
  Future<List<DiaryEntry>> getEntries(String enrollmentId) async {
    return _entries
        .where((entry) => entry.enrollmentId == enrollmentId)
        .toList()
      ..sort((left, right) =>
          left.experiencedDate.compareTo(right.experiencedDate));
  }

  @override
  Future<DiaryEntry> saveEntry(DiaryEntryDraft draft) async {
    _validateRatings(draft);

    final existingIndex = _entries.indexWhere(
      (entry) =>
          entry.enrollmentId == draft.enrollmentId &&
          entry.experiencedDate == draft.experiencedDate,
    );

    final entry = DiaryEntry(
      id: existingIndex == -1
          ? 'diary-entry-${_nextId++}'
          : _entries[existingIndex].id,
      enrollmentId: draft.enrollmentId,
      experiencedDate: draft.experiencedDate,
      recordedAt: _clock(),
      provenance: draft.provenance,
      symptoms: Map.unmodifiable(draft.symptoms),
      functionalImpacts: Map.unmodifiable(draft.functionalImpacts),
    );

    if (existingIndex == -1) {
      _entries.add(entry);
    } else {
      _entries[existingIndex] = entry;
    }
    return entry;
  }

  @override
  Future<void> deleteEntry(String entryId) async {
    _entries.removeWhere((entry) => entry.id == entryId);
  }

  @override
  Future<List<DiaryEntry>> getEntriesInRange(
    LocalDate start,
    LocalDate end,
  ) async {
    return _entries
        .where(
          (entry) =>
              entry.experiencedDate.compareTo(start) >= 0 &&
              entry.experiencedDate.compareTo(end) <= 0,
        )
        .toList()
      ..sort((left, right) =>
          left.experiencedDate.compareTo(right.experiencedDate));
  }

  void _validateRatings(DiaryEntryDraft draft) {
    for (final value in draft.symptoms.values) {
      if (value < 0 || value > 5) {
        throw const DiaryException(DiaryFailure.invalidRating);
      }
    }
    for (final value in draft.functionalImpacts.values) {
      if (value < 0 || value > 5) {
        throw const DiaryException(DiaryFailure.invalidRating);
      }
    }
  }

  @override
  Future<void> close() async => _entries.clear();
}
