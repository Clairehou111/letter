import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';

void main() {
  test('vocabulary version 2 preserves legacy codes and adds corpus terms', () {
    expect(healthRecordVocabularyVersion, 2);
    expect(SymptomType.cramps.name, 'cramps');
    expect(SymptomType.concentration.availableForNewRecords, isFalse);
    expect(SymptomType.brainFog.availableForNewRecords, isTrue);
    expect(SymptomType.crying.label, 'Crying');
    expect(SymptomType.rage.category, SymptomCategory.mood);
    expect(SymptomType.palpitations.category, SymptomCategory.physical);
    expect(SafetySignal.values, hasLength(3));
    expect(SafetySignal.suicidalThoughts.label, 'Suicidal thoughts');
    expect(SafetySignal.palpitations.physical, isTrue);
  });

  test('severity vocabulary exposes six explicit anchors', () {
    expect(SymptomSeverity.values, hasLength(6));
    expect(SymptomSeverity.notAtAll.score, 1);
    expect(SymptomSeverity.extreme.score, 6);
    expect(SymptomSeverity.moderate.label, 'Moderate');
  });

  test('validates pain as a separate scale with selected locations', () {
    final draft = HealthRecordDraft(
      symptom: SymptomType.cramps,
      severity: SymptomSeverity.severe,
      painRating: 8,
      painLocations: const {PainLocation.lowerAbdomen},
      functionalImpacts: const {FunctionalImpact.workOrSchool},
      experiencedDate: const LocalDate(2026, 7, 28),
      provenance: HealthRecordProvenance.sameDay,
    );

    expect(validateHealthRecordDraft(draft).painRating, 8);
    expect(validateHealthRecordDraft(draft).severity, SymptomSeverity.severe);
  });

  test('rejects incomplete pain details and out of range ratings', () {
    final withoutLocation = HealthRecordDraft(
      symptom: SymptomType.headache,
      severity: SymptomSeverity.mild,
      painRating: 4,
      experiencedDate: const LocalDate(2026, 7, 28),
      provenance: HealthRecordProvenance.laterRecall,
    );
    final outOfRange = HealthRecordDraft(
      symptom: SymptomType.headache,
      severity: SymptomSeverity.mild,
      painRating: 11,
      painLocations: const {PainLocation.head},
      experiencedDate: const LocalDate(2026, 7, 28),
      provenance: HealthRecordProvenance.laterRecall,
    );

    expect(
      () => validateHealthRecordDraft(withoutLocation),
      throwsA(
        isA<HealthRecordException>().having(
          (error) => error.failure,
          'failure',
          HealthRecordFailure.incompletePainEntry,
        ),
      ),
    );
    expect(
      () => validateHealthRecordDraft(outOfRange),
      throwsA(
        isA<HealthRecordException>().having(
          (error) => error.failure,
          'failure',
          HealthRecordFailure.invalidPainRating,
        ),
      ),
    );
  });
}
