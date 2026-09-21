import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/care/domain/care_mode.dart';
import 'package:letter_mobile/features/cycle/data/letter_health_database.dart';
import 'package:letter_mobile/features/preparation/data/drift_preparation_repository.dart';
import 'package:letter_mobile/features/preparation/domain/preparation_plan.dart';

void main() {
  test('persists one confirmed plan and exact dismissed suggestions', () async {
    final database = LetterHealthDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftPreparationRepository(database);
    final createdAt = DateTime.utc(2026, 8, 7, 4);
    final plan = PreparationPlan(
      id: PreparationPlan.activeId,
      status: PreparationPlanStatus.current,
      evidenceFingerprint: 'evidence-v1',
      sourceRecordIds: const ['care-1', 'care-2'],
      includeCare: true,
      careActionId: 'physical.warmth',
      careActionLabel: 'Warmth and quiet',
      careMode: CareMode.physical,
      betterCount: 2,
      sameCount: 1,
      worseCount: 0,
      noteText: 'Make the room quieter.',
      personalText: 'Put a heat pack beside the bed.',
      createdAt: createdAt,
      updatedAt: createdAt,
    );
    final dismissal = PreparationDismissal(
      fingerprint: 'proposal-v1',
      evidenceLine: 'You marked Warmth and quiet Better twice.',
      dismissedAt: createdAt,
    );

    await repository.savePlan(plan);
    await repository.dismiss(dismissal);

    final loaded = await repository.getActivePlan();
    expect(loaded, isNotNull);
    expect(loaded!.careMode, CareMode.physical);
    expect(loaded.noteText, 'Make the room quieter.');
    expect(loaded.personalText, 'Put a heat pack beside the bed.');
    expect(loaded.sourceRecordIds, ['care-1', 'care-2']);
    expect(await repository.getDismissals(), hasLength(1));

    await repository.restoreDismissal('proposal-v1');
    await repository.removeActivePlan();
    expect(await repository.getDismissals(), isEmpty);
    expect(await repository.getActivePlan(), isNull);
  });
}
