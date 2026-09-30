import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/care/domain/care_mode.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/cycle/domain/period_record.dart';
import 'package:letter_mobile/features/entitlement/data/plus_preview_repositories.dart';
import 'package:letter_mobile/features/entitlement/domain/plus_preview.dart';
import 'package:letter_mobile/features/entitlement/domain/plus_preview_evidence.dart';
import 'package:letter_mobile/features/patterns/domain/personal_pattern.dart';

void main() {
  test('does not start before Plus-grade evidence exists', () async {
    final repo = InMemoryPlusPreviewGrantRepository();
    final result = await PlusPreviewController(repo).resolve(
      hasPaidAccess: false,
      hasPlusGradeEvidence: false,
      periods: [_period('a', 1)],
      now: DateTime.utc(2026, 1, 20),
    );
    expect(result.access, PlusPreviewAccess.notEligible);
    expect(repo.value, isNull);
  });

  test('starts at evidence and lasts through one following cycle', () async {
    final repo = InMemoryPlusPreviewGrantRepository();
    final controller = PlusPreviewController(repo);
    final started = await controller.resolve(
      hasPaidAccess: false,
      hasPlusGradeEvidence: true,
      periods: [_period('a', 1), _period('b', 29)],
      now: DateTime.utc(2026, 2, 5),
    );
    expect(started.access, PlusPreviewAccess.active);
    expect(started.grant!.anchorPeriodId, 'b');

    final nextCycle = await controller.resolve(
      hasPaidAccess: false,
      hasPlusGradeEvidence: true,
      periods: [_period('a', 1), _period('b', 29), _period('c', 57)],
      now: DateTime.utc(2026, 3, 2),
    );
    expect(nextCycle.access, PlusPreviewAccess.active);

    final followingStart = await controller.resolve(
      hasPaidAccess: false,
      hasPlusGradeEvidence: true,
      periods: [
        _period('a', 1),
        _period('b', 29),
        _period('c', 57),
        _period('d', 85),
      ],
      now: DateTime.utc(2026, 3, 30),
    );
    expect(followingStart.access, PlusPreviewAccess.ended);
  });

  test('ends after 45 days even with no later period start', () async {
    final repo = InMemoryPlusPreviewGrantRepository();
    final controller = PlusPreviewController(repo);
    await controller.resolve(
      hasPaidAccess: false,
      hasPlusGradeEvidence: true,
      periods: [_period('a', 1)],
      now: DateTime.utc(2026, 1, 2),
    );
    final result = await controller.resolve(
      hasPaidAccess: false,
      hasPlusGradeEvidence: true,
      periods: [_period('a', 1)],
      now: DateTime.utc(2026, 2, 16),
    );
    expect(result.access, PlusPreviewAccess.ended);
  });

  test('commercial preview waits for two completed cycles and repetition', () {
    final once = PersonalPatternAnalysis(
      symptomPatterns: const [],
      supportActions: [_action(count: 1)],
      selectedCareMode: null,
    );
    final repeated = PersonalPatternAnalysis(
      symptomPatterns: const [],
      supportActions: [_action(count: 2)],
      selectedCareMode: null,
    );

    expect(
      PlusPreviewEvidencePolicy.isEligible(
        periods: [_period('a', 1), _period('b', 29)],
        analysis: repeated,
      ),
      isFalse,
    );
    expect(
      PlusPreviewEvidencePolicy.isEligible(
        periods: [_period('a', 1), _period('b', 29), _period('c', 57)],
        analysis: once,
      ),
      isFalse,
    );
    expect(
      PlusPreviewEvidencePolicy.isEligible(
        periods: [_period('a', 1), _period('b', 29), _period('c', 57)],
        analysis: repeated,
      ),
      isTrue,
    );
  });
}

SupportActionPattern _action({required int count}) => SupportActionPattern(
  id: 'care-action',
  actionId: 'space',
  actionLabel: 'Take space',
  mode: CareMode.space,
  count: count,
  firstDate: const LocalDate(2026, 1, 5),
  lastDate: const LocalDate(2026, 2, 5),
  coveredDates: const [LocalDate(2026, 1, 5), LocalDate(2026, 2, 5)],
  betterCount: count,
  sameCount: 0,
  worseCount: 0,
  sources: const [
    PatternSourceReference(
      id: 'care-record',
      kind: PatternSourceKind.careRecord,
      date: LocalDate(2026, 1, 5),
    ),
  ],
  pinned: false,
  reflections: const [],
);

PeriodRecord _period(String id, int day) {
  final start = LocalDate(2026, 1, 1).addDays(day - 1);
  final timestamp = DateTime.utc(2026, 1, 1).add(Duration(days: day - 1));
  return PeriodRecord(
    id: id,
    startDate: start,
    endDate: null,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}
