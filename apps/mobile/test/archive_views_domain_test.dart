import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/archive_views/domain/archive_repository.dart';
import 'package:letter_mobile/features/archive_views/domain/archive_view_models.dart';
import 'package:letter_mobile/features/care/domain/care_memory.dart';
import 'package:letter_mobile/features/care/domain/care_mode.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';

HealthRecord healthRecord({
  required String id,
  required SymptomType symptom,
  required LocalDate date,
  SymptomSeverity severity = SymptomSeverity.moderate,
  bool confirmed = true,
  int? painRating,
  Set<PainLocation> painLocations = const {},
}) {
  return HealthRecord(
    id: id,
    symptom: symptom,
    severity: severity,
    painRating: painRating,
    painLocations: painLocations,
    functionalImpacts: const {FunctionalImpact.workOrSchool},
    experiencedDate: date,
    recordedAt: DateTime.utc(2026, 7, 20),
    updatedAt: DateTime.utc(2026, 7, 20),
    provenance: HealthRecordProvenance.sameDay,
    userConfirmed: confirmed,
    vocabularyVersion: healthRecordVocabularyVersion,
  );
}

CareRecord careRecord(String id) {
  return CareRecord(
    id: id,
    mode: CareMode.physical,
    actionId: 'warmth',
    actionLabel: 'Warmth and quiet',
    outcome: CareOutcome.better,
    occurredAt: DateTime.utc(2026, 7, 18, 10),
    createdAt: DateTime.utc(2026, 7, 18, 10),
    updatedAt: DateTime.utc(2026, 7, 18, 10),
    pinned: false,
  );
}

ArchiveInput archiveInput({bool includeRecords = true}) {
  return ArchiveInput(
    cycles: const [
      ArchiveCycleInput(
        id: 'complete-1',
        number: 12,
        startDate: LocalDate(2026, 7, 1),
        endDate: LocalDate(2026, 7, 28),
        periodDates: [LocalDate(2026, 7, 1), LocalDate(2026, 7, 2)],
        isComplete: true,
      ),
      ArchiveCycleInput(
        id: 'current',
        startDate: LocalDate(2026, 7, 29),
        endDate: null,
        periodDates: [LocalDate(2026, 7, 29)],
        isComplete: false,
      ),
    ],
    healthRecords: includeRecords
        ? [
            healthRecord(
              id: 'confirmed-cramps',
              symptom: SymptomType.cramps,
              date: const LocalDate(2026, 7, 18),
              severity: SymptomSeverity.severe,
              painRating: 8,
              painLocations: const {PainLocation.lowerAbdomen},
            ),
            healthRecord(
              id: 'unconfirmed-anxiety',
              symptom: SymptomType.anxiety,
              date: const LocalDate(2026, 7, 18),
              confirmed: false,
            ),
          ]
        : const [],
    careRecords: includeRecords ? [careRecord('care-1')] : const [],
    reflections: includeRecords
        ? [
            CareReflection(
              id: 'reflection-1',
              careRecordId: 'care-1',
              mode: CareMode.physical,
              observation: 'The warmth made the next hour easier.',
              need: ReflectionNeed.restOrPhysicalCapacity,
              whatHelped: 'A quiet room.',
              futureSelfNote: 'Try warmth before making plans.',
              createdAt: DateTime.utc(2026, 7, 18, 11),
              updatedAt: DateTime.utc(2026, 7, 18, 11),
            ),
          ]
        : const [],
  );
}

void main() {
  test('builds separate truthful Story, Pattern, and Clinical views', () {
    final viewModel = buildArchiveViewsViewModel(archiveInput());

    expect(viewModel.completedCycles, hasLength(1));
    expect(viewModel.currentCycle?.isComplete, isFalse);
    final cycle = viewModel.completedCycles.single;

    expect(cycle.periodDatesLabel, contains('7/1/2026'));
    expect(cycle.coverageLabel, '1/28 days with confirmed records');
    expect(
      cycle.story.items.map((item) => item.body),
      contains('The warmth made the next hour easier.'),
    );
    expect(
      cycle.story.items.map((item) => item.body),
      contains('Try warmth before making plans.'),
    );
    expect(
      cycle.story.items.map((item) => item.body),
      contains('Outcome recorded: Better after the action.'),
    );
    expect(cycle.pattern.metrics, hasLength(1));
    expect(cycle.pattern.metrics.single.label, 'Cramps');
    expect(
      cycle.pattern.metrics.single.highestSeverity,
      SymptomSeverity.severe,
    );
    expect(cycle.pattern.metrics.single.sourceLabel, contains('Confirmed'));
    expect(cycle.pattern.careOutcomes.single.better, 1);
    expect(cycle.clinical.healthRows, hasLength(1));
    expect(cycle.clinical.healthRows.single.provenanceLabel, 'Same day');
    expect(cycle.clinical.healthRows.single.painLabel, '8/10');
    expect(
      cycle.clinical.careRows.single.outcomeLabel,
      'Better after the action',
    );
    expect(
      cycle.story.items.any((item) => item.body.contains('unconfirmed')),
      isFalse,
    );
  });

  test('empty or open cycles preserve missingness instead of filling gaps', () {
    final viewModel = buildArchiveViewsViewModel(
      archiveInput(includeRecords: false),
    );
    final complete = viewModel.completedCycles.single;
    final current = viewModel.currentCycle!;

    expect(
      complete.missingLabel,
      'No confirmed symptom records in this cycle.',
    );
    expect(complete.pattern.evidence, ArchiveEvidenceState.notRecorded);
    expect(complete.clinical.evidence, ArchiveEvidenceState.notRecorded);
    expect(current.title, 'Current cycle');
    expect(current.missingLabel, contains('still open'));
    expect(current.pattern.missingNote, contains('No confirmed'));
    expect(current.clinical.missingNote, contains('No confirmed'));
  });

  test(
    'repository input is read-only and removed records disappear from all views',
    () async {
      final repository = InMemoryArchiveRepository(archiveInput());
      final first = buildArchiveViewsViewModel(await repository.load());
      final second = buildArchiveViewsViewModel(
        archiveInput(includeRecords: false),
      );

      expect(first.completedCycles.single.story.items, isNotEmpty);
      expect(second.completedCycles.single.story.items, isEmpty);
      expect(second.completedCycles.single.pattern.metrics, isEmpty);
      expect(second.completedCycles.single.clinical.healthRows, isEmpty);
    },
  );
}
