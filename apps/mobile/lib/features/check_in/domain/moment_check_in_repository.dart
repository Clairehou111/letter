import 'moment_check_in.dart';
import '../../cycle/domain/local_date.dart';
import '../../health_records/domain/health_record.dart';

enum MomentCheckInFailure {
  notFound,
  storageUnavailable,
  futureDate,
  staleWrite,
}

final class MomentCheckInException implements Exception {
  const MomentCheckInException(this.failure);

  final MomentCheckInFailure failure;

  String get userMessage => switch (failure) {
    MomentCheckInFailure.notFound =>
      'This check-in is no longer available. Refresh and try again.',
    MomentCheckInFailure.staleWrite =>
      'This check-in changed. Refresh before correcting or deleting it.',
    MomentCheckInFailure.futureDate => 'Choose today or an earlier moment.',
    MomentCheckInFailure.storageUnavailable =>
      'Letter Within could not update your private check-in. Try again.',
  };
}

abstract interface class MomentCheckInRepository {
  Future<List<MomentCheckIn>> getAll();

  Future<MomentCheckIn> create(
    MomentCheckInState state, {
    required DateTime occurredAt,
  });

  Future<void> delete(String id);

  Future<void> close();
}

/// Source-detail correction only; date and source identity are immutable.
/// Legacy test doubles keep the smaller base interface.
abstract interface class CorrectableMomentRepository
    implements MomentCheckInRepository {
  Future<MomentCheckIn> update(
    String id,
    MomentCheckInState state, {
    MomentCheckIn? expected,
  });
  Future<bool> deleteIfUnchanged(MomentCheckIn expected);

  /// Only a source durably deleted by this repository instance may be restored.
  Future<MomentCheckIn> restoreDeleted(MomentCheckIn deleted);
}

/// The selected day and write-zone evidence freeze before the async write.
/// Saving after local midnight is later recall; legacy rows stay unknown.
MomentCheckIn createMomentCheckIn({
  required String id,
  required MomentCheckInState state,
  required DateTime occurredAt,
  required DateTime savedAt,
}) {
  final selected = occurredAt.toLocal();
  final actualSave = savedAt.toLocal();
  final date = LocalDate.fromDateTime(selected);
  if (occurredAt.isAfter(savedAt) ||
      date.isAfter(LocalDate.fromDateTime(actualSave))) {
    throw const MomentCheckInException(MomentCheckInFailure.futureDate);
  }
  DateTime timestamp(DateTime value) => DateTime.fromMillisecondsSinceEpoch(
    value.millisecondsSinceEpoch,
    isUtc: true,
  );
  return MomentCheckIn(
    id: id,
    state: state,
    occurredAt: timestamp(occurredAt),
    createdAt: timestamp(savedAt),
    experiencedDate: date,
    provenance: date == LocalDate.fromDateTime(actualSave)
        ? HealthRecordProvenance.sameDay
        : HealthRecordProvenance.laterRecall,
    writeZoneOffsetMinutes: actualSave.timeZoneOffset.inMinutes,
    writeZoneName: actualSave.timeZoneName,
    updatedZoneOffsetMinutes: actualSave.timeZoneOffset.inMinutes,
    updatedZoneName: actualSave.timeZoneName,
  );
}

MomentCheckIn correctMomentCheckIn({
  required MomentCheckIn previous,
  required MomentCheckInState state,
  required DateTime savedAt,
}) {
  if (previous.state == state) return previous;
  final local = savedAt.toLocal();
  final date = previous.experiencedDate;
  final canonical = DateTime.fromMillisecondsSinceEpoch(
    savedAt.millisecondsSinceEpoch,
    isUtc: true,
  );
  if (canonical.isBefore(previous.updatedAt) ||
      date != null &&
          (date.isAfter(LocalDate.fromDateTime(local)) ||
              previous.occurredAt.isAfter(savedAt))) {
    throw const MomentCheckInException(MomentCheckInFailure.futureDate);
  }
  return MomentCheckIn(
    id: previous.id,
    state: state,
    occurredAt: previous.occurredAt,
    createdAt: previous.createdAt,
    updatedAt: canonical,
    experiencedDate: date,
    originalProvenance: date == null
        ? HealthRecordProvenance.timingUnknown
        : previous.originalProvenance,
    provenance: date == null
        ? HealthRecordProvenance.timingUnknown
        : date == LocalDate.fromDateTime(local)
        ? HealthRecordProvenance.sameDay
        : HealthRecordProvenance.laterRecall,
    writeZoneOffsetMinutes: previous.writeZoneOffsetMinutes,
    writeZoneName: previous.writeZoneName,
    updatedZoneOffsetMinutes: local.timeZoneOffset.inMinutes,
    updatedZoneName: local.timeZoneName,
  );
}

bool momentCheckInsMatch(MomentCheckIn left, MomentCheckIn right) =>
    left.id == right.id &&
    left.state == right.state &&
    left.occurredAt == right.occurredAt &&
    left.createdAt == right.createdAt &&
    left.updatedAt == right.updatedAt &&
    left.experiencedDate == right.experiencedDate &&
    left.provenance == right.provenance &&
    left.originalProvenance == right.originalProvenance &&
    left.writeZoneOffsetMinutes == right.writeZoneOffsetMinutes &&
    left.writeZoneName == right.writeZoneName &&
    left.updatedZoneOffsetMinutes == right.updatedZoneOffsetMinutes &&
    left.updatedZoneName == right.updatedZoneName;
