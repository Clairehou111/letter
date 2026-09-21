import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/care/domain/care_mode.dart';
import 'package:letter_mobile/features/cycle/domain/cycle_prediction.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';
import 'package:letter_mobile/features/patterns/domain/personal_pattern.dart';
import 'package:letter_mobile/features/preparation/data/in_memory_preparation_repository.dart';
import 'package:letter_mobile/features/preparation/domain/preparation_loop_state.dart';
import 'package:letter_mobile/features/preparation/domain/preparation_plan.dart';
import 'package:letter_mobile/features/preparation/domain/preparation_snapshot.dart';

PreparationSnapshot _snapshot({int better = 2, int observationCount = 2}) =>
    PreparationSnapshot(
      timing: const PreparationTimingEvidence(
        rangeStart: LocalDate(2026, 8, 1),
        rangeEnd: LocalDate(2026, 8, 20),
        periodRangeStart: LocalDate(2026, 8, 12),
        periodRangeEnd: LocalDate(2026, 8, 20),
        confidence: PredictionConfidence.low,
        observedIntervalCount: 2,
        observedSpreadDays: 8,
      ),
      observation: PreparationObservationEvidence(
        symptom: SymptomType.cramps,
        recordCount: observationCount,
        distinctCompletedCycles: 2,
        totalCompletedCycles: 3,
        supportingCycleStarts: const [
          LocalDate(2026, 5, 1),
          LocalDate(2026, 6, 1),
        ],
        sources: const [
          PatternSourceReference(
            id: 'health-1',
            kind: PatternSourceKind.healthRecord,
            date: LocalDate(2026, 5, 20),
          ),
        ],
        strength: PreparationPatternStrength.early,
      ),
      care: PreparationCareEvidence(
        actionId: 'physical.warmth',
        actionLabel: 'Warmth and quiet',
        mode: CareMode.physical,
        recordCount: better + 1,
        betterCount: better,
        sameCount: 1,
        worseCount: 0,
        pinned: false,
        lastRecordedDate: const LocalDate(2026, 7, 30),
        sources: const [
          PatternSourceReference(
            id: 'care-1',
            kind: PatternSourceKind.careRecord,
            date: LocalDate(2026, 7, 30),
          ),
        ],
      ),
      futureNote: const PreparationFutureNoteEvidence(
        text: 'Make the room quieter.',
        mode: CareMode.physical,
        careRecordId: 'care-1',
      ),
    );

Future<PreparationPlan> _savePlan(
  InMemoryPreparationRepository repository,
  PreparationSnapshot snapshot,
) async {
  final fingerprint = await PreparationFingerprint.forSelection(
    snapshot,
    includeCare: true,
    includeNote: true,
  );
  final now = DateTime.utc(2026, 8, 7);
  final care = snapshot.care!;
  final plan = PreparationPlan(
    id: PreparationPlan.activeId,
    status: PreparationPlanStatus.current,
    evidenceFingerprint: fingerprint,
    sourceRecordIds: PreparationFingerprint.selectionSourceIds(
      snapshot,
      includeCare: true,
      includeNote: true,
    ),
    includeCare: true,
    careActionId: care.actionId,
    careActionLabel: care.actionLabel,
    careMode: care.mode,
    betterCount: care.betterCount,
    sameCount: care.sameCount,
    worseCount: care.worseCount,
    noteText: snapshot.futureNote!.text,
    personalText: 'Keep tomorrow evening quiet.',
    createdAt: now,
    updatedAt: now,
  );
  await repository.savePlan(plan);
  return plan;
}

void main() {
  test(
    'selected Care stays current when only observation evidence changes',
    () async {
      final repository = InMemoryPreparationRepository();
      await _savePlan(repository, _snapshot());

      final state = await PreparationLoopState.load(
        snapshot: _snapshot(observationCount: 3),
        repository: repository,
        currentSourceIds: const {'care-1', 'health-1'},
      );

      expect(state.kind, PreparationLoopKind.saved);
    },
  );

  test(
    'changed selected Care is stale and missing support is withdrawn',
    () async {
      final repository = InMemoryPreparationRepository();
      await _savePlan(repository, _snapshot());

      final stale = await PreparationLoopState.load(
        snapshot: _snapshot(better: 3),
        repository: repository,
        currentSourceIds: const {'care-1', 'health-1'},
      );
      expect(stale.kind, PreparationLoopKind.stale);
      expect(
        stale.plan!.betterCount,
        2,
        reason: 'saved text is never rewritten',
      );

      final withdrawn = await PreparationLoopState.load(
        snapshot: _snapshot(better: 3),
        repository: repository,
        currentSourceIds: const {'health-1'},
      );
      expect(withdrawn.kind, PreparationLoopKind.withdrawn);
    },
  );

  test('dismissal applies only to the exact proposal fingerprint', () async {
    final repository = InMemoryPreparationRepository();
    final first = _snapshot();
    final firstFingerprint = await PreparationFingerprint.forSnapshot(first);
    await repository.dismiss(
      PreparationDismissal(
        fingerprint: firstFingerprint,
        evidenceLine: 'Warmth and quiet',
        dismissedAt: DateTime.utc(2026, 8, 7),
      ),
    );

    final dismissed = await PreparationLoopState.load(
      snapshot: first,
      repository: repository,
      currentSourceIds: const {'care-1', 'health-1'},
    );
    final changed = await PreparationLoopState.load(
      snapshot: _snapshot(better: 3),
      repository: repository,
      currentSourceIds: const {'care-1', 'health-1'},
    );

    expect(dismissed.kind, PreparationLoopKind.dismissed);
    expect(changed.kind, PreparationLoopKind.proposed);
  });

  test('user-authored-only preparation does not become withdrawn', () async {
    final repository = InMemoryPreparationRepository();
    final snapshot = _snapshot();
    final fingerprint = await PreparationFingerprint.forSelection(
      snapshot,
      includeCare: false,
      includeNote: false,
    );
    final now = DateTime.utc(2026, 8, 7);
    final care = snapshot.care!;
    await repository.savePlan(
      PreparationPlan(
        id: PreparationPlan.activeId,
        status: PreparationPlanStatus.current,
        evidenceFingerprint: fingerprint,
        sourceRecordIds: const [],
        includeCare: false,
        careActionId: care.actionId,
        careActionLabel: care.actionLabel,
        careMode: care.mode,
        betterCount: care.betterCount,
        sameCount: care.sameCount,
        worseCount: care.worseCount,
        noteText: null,
        personalText: 'Keep tomorrow evening clear.',
        createdAt: now,
        updatedAt: now,
      ),
    );

    final state = await PreparationLoopState.load(
      snapshot: snapshot,
      repository: repository,
      currentSourceIds: const {},
    );

    expect(state.kind, PreparationLoopKind.saved);
  });
}
