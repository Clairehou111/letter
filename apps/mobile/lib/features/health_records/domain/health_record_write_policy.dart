import '../../cycle/domain/local_date.dart';
import 'health_record.dart';

/// Timing belongs to the successful write, never to the viewed/editor date.
HealthRecordProvenance healthRecordTiming(LocalDate date, DateTime localNow) {
  final today = LocalDate.fromDateTime(localNow);
  if (date.isAfter(today)) {
    throw const HealthRecordException(HealthRecordFailure.futureDate);
  }
  return date == today ? HealthRecordProvenance.sameDay : HealthRecordProvenance.laterRecall;
}

HealthRecord buildHealthRecord({
  required String id,
  required HealthRecordDraft draft,
  required DateTime localNow,
  HealthRecord? previous,
}) {
  final timing = healthRecordTiming(draft.experiencedDate, localNow);
  if (previous != null && previous.hasSameValue(draft)) return previous;
  final active = previous?.provenance == HealthRecordProvenance.laterRecall &&
      previous?.experiencedDate == draft.experiencedDate
      ? HealthRecordProvenance.laterRecall : timing;
  final timestamp = DateTime.fromMillisecondsSinceEpoch(localNow.millisecondsSinceEpoch, isUtc: true);
  return HealthRecord(
    id: previous?.id ?? id,
    symptom: draft.symptom,
    severity: draft.severity,
    functionalImpacts: Set.unmodifiable(draft.functionalImpacts),
    experiencedDate: draft.experiencedDate,
    recordedAt: previous?.recordedAt ?? timestamp,
    updatedAt: timestamp,
    provenance: active,
    originalProvenance: previous?.effectiveOriginalProvenance ?? timing,
    writeZoneOffsetMinutes: previous == null ? localNow.timeZoneOffset.inMinutes : previous.writeZoneOffsetMinutes,
    writeZoneName: previous == null ? localNow.timeZoneName : previous.writeZoneName,
    updatedZoneOffsetMinutes: localNow.timeZoneOffset.inMinutes,
    updatedZoneName: localNow.timeZoneName,
    userConfirmed: previous?.userConfirmed ?? true,
    vocabularyVersion: previous?.vocabularyVersion ?? healthRecordVocabularyVersion,
  );
}

bool sameHealthRecordVersion(HealthRecord left, HealthRecord right) =>
    left.id == right.id && left.recordedAt == right.recordedAt &&
    left.updatedAt == right.updatedAt && left.provenance == right.provenance &&
    left.effectiveOriginalProvenance == right.effectiveOriginalProvenance &&
    left.userConfirmed == right.userConfirmed && left.vocabularyVersion == right.vocabularyVersion &&
    left.writeZoneOffsetMinutes == right.writeZoneOffsetMinutes && left.writeZoneName == right.writeZoneName &&
    left.updatedZoneOffsetMinutes == right.updatedZoneOffsetMinutes && left.updatedZoneName == right.updatedZoneName &&
    left.hasSameValue(HealthRecordDraft(symptom: right.symptom, severity: right.severity,
      functionalImpacts: right.functionalImpacts, experiencedDate: right.experiencedDate, provenance: right.provenance));
