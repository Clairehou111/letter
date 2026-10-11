import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';

void main() {
  test(
    'vocabulary version 3 preserves legacy codes and expands the catalog',
    () {
      expect(healthRecordVocabularyVersion, 3);
      expect(SymptomType.cramps.name, 'cramps');
      expect(SymptomType.concentration.availableForNewRecords, isFalse);
      expect(SymptomType.brainFog.availableForNewRecords, isTrue);
      expect(SymptomType.crying.label, 'Crying');
      expect(SymptomType.rage.category, SymptomCategory.mood);
      expect(SymptomType.palpitations.category, SymptomCategory.physical);
      expect(SymptomType.migraine.label, 'Migraine');
      expect(SymptomType.overwhelm.category, SymptomCategory.mood);
      expect(SafetySignal.values, hasLength(3));
      expect(SafetySignal.suicidalThoughts.label, 'Suicidal thoughts');
      expect(SafetySignal.palpitations.physical, isTrue);
    },
  );

  test(
    'severity preserves five anchors and explicitly maps observed absence',
    () {
      expect(SymptomSeverity.values, hasLength(6));
      expect(SymptomSeverity.notPresent.score, 0);
      expect(SymptomSeverity.notPresent.label, 'Not present');
      expect(SymptomSeverity.minimal.index, 0);
      for (var score = 0; score <= 5; score++) {
        expect(SymptomSeverity.fromScore(score).score, score);
      }
      expect(() => SymptomSeverity.fromScore(-1), throwsFormatException);
      expect(() => SymptomSeverity.fromScore(6), throwsFormatException);
      expect(SymptomSeverity.minimal.score, 1);
      expect(SymptomSeverity.extreme.score, 5);
      expect(SymptomSeverity.moderate.label, 'Moderate');
    },
  );

  test('validates the shared five-level symptom record', () {
    final draft = HealthRecordDraft(
      symptom: SymptomType.cramps,
      severity: SymptomSeverity.severe,
      functionalImpacts: const {FunctionalImpact.workOrSchool},
      experiencedDate: const LocalDate(2026, 7, 28),
      provenance: HealthRecordProvenance.sameDay,
    );

    final valid = validateHealthRecordDraft(draft);
    expect(valid.severity, SymptomSeverity.severe);
    expect(valid.functionalImpacts, {FunctionalImpact.workOrSchool});
  });
}
