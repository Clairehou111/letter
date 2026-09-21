import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/check_in/domain/moment_check_in.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';
import 'package:letter_mobile/features/health_records/domain/observation_catalog.dart';

void main() {
  test('catalog has one stable definition for every symptom code', () {
    expect(ObservationCatalog.version, healthRecordVocabularyVersion);
    expect(
      ObservationCatalog.symptoms.map((definition) => definition.id).toSet(),
      SymptomType.values.map((symptom) => symptom.name).toSet(),
    );
    expect(
      ObservationCatalog.symptoms.map((definition) => definition.id).length,
      ObservationCatalog.symptoms
          .map((definition) => definition.id)
          .toSet()
          .length,
    );
  });

  test(
    'search crosses labels and aliases without narrowing the vocabulary',
    () {
      expect(
        ObservationCatalog.search('breakout').single.symptom,
        SymptomType.acne,
      );
      expect(
        ObservationCatalog.search('lower back').single.symptom,
        SymptomType.backPain,
      );
      expect(
        ObservationCatalog.search(
          '',
          category: ObservationCategory.digestion,
        ).map((definition) => definition.symptom),
        containsAll(<SymptomType>[
          SymptomType.bloating,
          SymptomType.nausea,
          SymptomType.diarrhea,
          SymptomType.constipation,
        ]),
      );
    },
  );

  test('medical-attention and quick-pick metadata remain explicit', () {
    final palpitations = ObservationCatalog.definitionFor(
      SymptomType.palpitations,
    );
    expect(
      palpitations.recordingKind,
      ObservationRecordingKind.medicalAttention,
    );
    expect(palpitations.safetyRoute, ObservationSafetyRoute.medicalAttention);
    expect(
      ObservationCatalog.quickPicks(
        ObservationCategory.physical,
      ).map((definition) => definition.symptom),
      isNot(contains(SymptomType.palpitations)),
    );
  });

  test('moment catalog is broader than the compact legacy Today surface', () {
    expect(
      ObservationCatalog.momentStates
          .map((definition) => definition.state)
          .toSet(),
      MomentCheckInState.values.toSet(),
    );
    expect(
      ObservationCatalog.searchMomentStates('restless').single.state,
      MomentCheckInState.anxious,
    );
    expect(
      ObservationCatalog.momentStates
          .where((definition) => definition.suggestsCare)
          .map((definition) => definition.state),
      containsAll(<MomentCheckInState>[
        MomentCheckInState.low,
        MomentCheckInState.irritable,
        MomentCheckInState.anxious,
        MomentCheckInState.physical,
      ]),
    );
  });
}
