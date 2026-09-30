import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/comfort_kit/data/drift_comfort_kit_repository.dart';
import 'package:letter_mobile/features/comfort_kit/domain/comfort_kit.dart';
import 'package:letter_mobile/features/comfort_window/data/comfort_reminder_preference_repositories.dart';
import 'package:letter_mobile/features/comfort_window/domain/comfort_reminder_preference.dart';
import 'package:letter_mobile/features/cycle/data/letter_health_database.dart';

void main() {
  late LetterHealthDatabase database;

  setUp(() {
    database = LetterHealthDatabase(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('comfort kit removal is version-scoped and restorable', () async {
    final repository = DriftComfortKitRepository(database);
    final item = ComfortKitItem(
      sourceId: 'action:heavy',
      sourceVersion: 'v1',
      kind: ComfortKitSourceKind.careAction,
      title: 'Heavy',
      body: 'Marked easier once.',
      lastChangedAt: DateTime.utc(2026, 1, 1),
      rankGroup: 2,
    );

    await repository.removeUntilChanged(
      item: item,
      updatedAt: DateTime.utc(2026, 1, 2),
    );
    final override = (await repository.getOverrides()).single;
    expect(override.hides(item), isTrue);
    expect(
      override.hides(
        ComfortKitItem(
          sourceId: item.sourceId,
          sourceVersion: 'v2',
          kind: item.kind,
          title: item.title,
          body: item.body,
          lastChangedAt: item.lastChangedAt,
          rankGroup: item.rankGroup,
        ),
      ),
      isFalse,
    );

    await repository.restore(item.sourceId);
    expect(await repository.getOverrides(), isEmpty);
  });

  test('do not show again survives source changes', () async {
    final repository = DriftComfortKitRepository(database);
    await repository.dontShowAgain(
      sourceId: 'quick-note:one',
      updatedAt: DateTime.utc(2026, 1, 2),
    );
    final override = (await repository.getOverrides()).single;
    expect(override.action, ComfortKitOverrideAction.dontShowAgain);
    expect(override.sourceVersion, isNull);
  });

  test('comfort reminder defaults off and persists approved bounds', () async {
    final repository = DriftComfortReminderPreferenceRepository(database);
    expect((await repository.load()).enabled, isFalse);

    await repository.save(
      ComfortReminderPreference(
        enabled: true,
        leadDays: 1,
        hour: 8,
        minute: 30,
        updatedAt: DateTime.utc(2026, 1, 2),
      ),
    );
    final restored = await repository.load();
    expect(restored.enabled, isTrue);
    expect(restored.leadDays, 1);
    expect(restored.hour, 8);
    expect(restored.minute, 30);
  });
}
