import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/experience/care/care_animation_port.dart';
import 'package:letter_mobile/experience/care/care_completion_flow.dart';
import 'package:letter_mobile/experience/care/care_experience.dart';
import 'package:letter_mobile/experience/care/care_toolkit_experience.dart';
import 'package:letter_mobile/experience/theme/experience_foundation.dart';
import 'package:letter_mobile/features/care/application/care_action_recording_controller.dart';
import 'package:letter_mobile/features/care/data/in_memory_care_memory_repository.dart';
import 'package:letter_mobile/features/care/domain/care_memory.dart';
import 'package:letter_mobile/features/care/domain/care_mode.dart';
import 'package:letter_mobile/features/cycle/data/letter_health_database.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';
import 'package:letter_mobile/features/record_hub/data/drift_record_interventions_repository.dart';
import 'package:letter_mobile/features/record_hub/domain/record_hub_facts.dart';
import 'package:letter_mobile/features/record_hub/domain/record_interventions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  test(
    'concurrent completion and retry keep exactly one original action',
    () async {
      final fixture = _Fixture();
      addTearDown(fixture.database.close);
      var tokens = 0;
      final controller = CareActionRecordingController(
        repository: fixture.repository,
        completionTokenGenerator: () => 'synthetic-${++tokens}',
      );
      expect(await fixture.repository.getActions(), isEmpty);
      final completion = _completion(fixture.now);
      final saved = await Future.wait([
        controller.recordCompletion(completion),
        controller.recordCompletion(completion),
      ]);
      final retry = await controller.recordCompletion(completion);
      expect(saved.map((action) => action.id).toSet(), {retry.id});
      expect(tokens, 1);
      final action = (await fixture.repository.getActions()).single;
      expect(action.value.source, TriedActionSource.inAppCare);
      expect(action.value.actions.single.kind, TriedActionKind.other);
      expect(action.value.actions.single.customName, completion.actionLabel);
      expect(action.value.careSourceId, completion.actionId);
      expect(action.value.target, isNull);
      expect(action.value.duration, isNull);
      expect(action.value.bundle, isFalse);
      expect(await fixture.repository.getCheckbacks(), isEmpty);
      expect(retry.metadata.recordedAt, saved.first.metadata.recordedAt);
    },
  );

  test(
    'separate deliberate completions may repeat the same native action',
    () async {
      final fixture = _Fixture();
      addTearDown(fixture.database.close);
      var tokens = 0;
      final controller = CareActionRecordingController(
        repository: fixture.repository,
        completionTokenGenerator: () => 'synthetic-${++tokens}',
      );
      await controller.recordCompletion(_completion(fixture.now));
      await controller.recordCompletion(_completion(fixture.now));
      expect(await fixture.repository.getActions(), hasLength(2));
      expect(tokens, 2);
    },
  );

  test(
    'failed action retries after midnight with the original completion evidence',
    () async {
      final fixture = _Fixture(now: DateTime(2026, 10, 9, 23, 59));
      addTearDown(fixture.database.close);
      final repository = _FailOnceRepository(fixture.repository);
      var tokens = 0;
      final controller = CareActionRecordingController(
        repository: repository,
        completionTokenGenerator: () => 'synthetic-${++tokens}',
      );
      final completion = _completion(fixture.now);
      await expectLater(
        controller.recordCompletion(completion),
        throwsA(isA<RecordHubException>()),
      );
      expect(await fixture.repository.getActions(), isEmpty);
      fixture.now = DateTime(2026, 10, 10, 0, 1);
      final saved = await controller.recordCompletion(completion);
      expect(tokens, 1);
      expect(saved.experiencedDate, const LocalDate(2026, 10, 9));
      expect(
        saved.value.completionOccurredAt!.millisecondsSinceEpoch,
        completion.occurredAt.millisecondsSinceEpoch,
      );
      expect(
        saved.value.completionUtcOffsetMinutes,
        completion.occurredAt.toLocal().timeZoneOffset.inMinutes,
      );
      expect(saved.metadata.provenance, HealthRecordProvenance.laterRecall);
      expect(await fixture.repository.getActions(), hasLength(1));
      expect(await fixture.repository.getCheckbacks(), isEmpty);
    },
  );

  testWidgets(
    'scene render, step, dismissal and interrupted exit write no action',
    (tester) async {
      final fixture = _Fixture();
      await _pumpCare(tester, fixture, fixture.repository);
      expect(await tester.runAsync(fixture.repository.getActions), isEmpty);
      await _openHeavy(tester);
      await tester.tap(find.text('Step'));
      await _settle(tester);
      expect(await tester.runAsync(fixture.repository.getActions), isEmpty);
      await tester.tap(find.text('Dismiss'));
      await _settle(tester);
      expect(await tester.runAsync(fixture.repository.getActions), isEmpty);
      await _openHeavy(tester);
      await tester.tap(find.text('Exit'));
      await _settle(tester);
      await tester.tap(find.text('Leave it here'));
      await _settle(tester);
      expect(await tester.runAsync(fixture.repository.getActions), isEmpty);
      expect(await fixture.legacy.getRecords(), isEmpty);
      await fixture.close(tester);
    },
  );

  testWidgets(
    'deliberate scene completion persists an action before optional Skip',
    (tester) async {
      final fixture = _Fixture();
      await _pumpCare(tester, fixture, fixture.repository);
      await _openHeavy(tester);
      await tester.tap(find.text('Complete'));
      await _settle(tester);
      expect(
        await tester.runAsync(fixture.repository.getActions),
        hasLength(1),
      );
      expect(
        find.text('Care action recorded. The check-back is optional.'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Skip — no check-back'));
      await tester.tap(find.text('Skip — no check-back'));
      await _settle(tester);
      expect(
        await tester.runAsync(fixture.repository.getActions),
        hasLength(1),
      );
      expect(await tester.runAsync(fixture.repository.getCheckbacks), isEmpty);
      expect(await fixture.legacy.getRecords(), isEmpty);
      expect(find.byType(CareCompletionFlow), findsNothing);
      expect(find.text('I feel heavy'), findsOneWidget);
      await fixture.close(tester);
    },
  );

  testWidgets(
    'ritual final completion uses the same idempotent automatic bridge',
    (tester) async {
      final fixture = _Fixture();
      await _pumpCare(tester, fixture, fixture.repository);
      await tester.scrollUntilVisible(
        find.text('Everyday care'),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Everyday care'));
      await _settle(tester);
      expect(await tester.runAsync(fixture.repository.getActions), isEmpty);
      final toolkit = tester.widget<CareToolkitExperience>(
        find.byType(CareToolkitExperience),
      );
      final completion = CareActionCompletion(
        mode: CareMode.physical,
        actionId: 'warmth',
        actionLabel: 'Warmth on the cramping place',
        occurredAt: fixture.now,
      );
      await tester.runAsync(() => toolkit.onRitualCompleted(completion));
      await _settle(tester);
      await tester.runAsync(() => toolkit.onRitualCompleted(completion));
      await _settle(tester);
      final action = (await tester.runAsync(
        fixture.repository.getActions,
      ))!.single;
      expect(action.value.actions.single.customName, completion.actionLabel);
      expect(action.value.source, TriedActionSource.inAppCare);
      expect(await tester.runAsync(fixture.repository.getCheckbacks), isEmpty);
      await fixture.close(tester);
    },
  );

  testWidgets(
    'failed automatic action displays retry and no durable completion claim',
    (tester) async {
      final fixture = _Fixture();
      final repository = _FailOnceRepository(fixture.repository);
      var leaveCount = 0;
      await _pumpCare(
        tester,
        fixture,
        repository,
        onLeaveCare: () => leaveCount++,
      );
      await _openHeavy(tester);
      await tester.tap(find.text('Complete'));
      await _settle(tester);
      expect(
        find.text('Care action recorded. The check-back is optional.'),
        findsNothing,
      );
      expect(find.text('Retry saving Care action'), findsOneWidget);
      expect(await tester.runAsync(fixture.repository.getActions), isEmpty);
      await tester.ensureVisible(find.text('Skip — no check-back'));
      await tester.tap(find.text('Skip — no check-back'));
      await _settle(tester);
      expect(leaveCount, 1);
      expect(find.text('Retry saving Care action'), findsOneWidget);
      await tester.ensureVisible(find.text('Retry saving Care action'));
      await tester.tap(find.text('Retry saving Care action'));
      await _settle(tester);
      expect(
        await tester.runAsync(fixture.repository.getActions),
        hasLength(1),
      );
      expect(repository.tokens.toSet(), hasLength(1));
      expect(
        find.text('Care action recorded. The check-back is optional.'),
        findsOneWidget,
      );
      await fixture.close(tester);
    },
  );

  for (final outcome in ActionOutcome.values) {
    testWidgets(
      '${outcome.label} keeps its exact typed outcome and honest legacy behavior',
      (tester) async {
        final fixture = _Fixture();
        addTearDown(() => fixture.close(tester));
        final completion = _completion(fixture.now);
        final action = await tester.runAsync(
          () => CareActionRecordingController(
            repository: fixture.repository,
            completionTokenGenerator: () => 'synthetic-outcome',
          ).recordCompletion(completion),
        );
        await _window(tester);
        await tester.pumpWidget(
          MaterialApp(
            theme: ExperienceFoundation.lightTheme(),
            home: Scaffold(
              body: CareCompletionFlow(
                mode: completion.mode,
                completion: completion,
                careMemoryRepository: fixture.legacy,
                interventionsRepository: fixture.repository,
                recordedAction: action,
                onLeaveCare: () {},
                onSkip: () {},
                motionPreference: CareSceneMotionPreference.staticFallback,
                now: () => fixture.now,
              ),
            ),
          ),
        );
        await _settle(tester);
        if (outcome == ActionOutcome.mixed ||
            outcome == ActionOutcome.couldntTry) {
          await tester.ensureVisible(find.text('More check-back options'));
          await tester.tap(find.text('More check-back options'));
          await _settle(tester);
          await tester.ensureVisible(find.text(outcome.label));
          await tester.tap(find.text(outcome.label));
          await tester.pump();
          await tester.enterText(
            find.widgetWithText(TextField, 'Reflection (optional)'),
            'Synthetic reflection',
          );
          await tester.ensureVisible(find.text('Yes'));
          await tester.tap(find.text('Yes'));
          await tester.ensureVisible(find.text('Save check-back'));
          await tester.tap(find.text('Save check-back'));
        } else {
          await tester.ensureVisible(find.text(outcome.label));
          await tester.tap(find.text(outcome.label));
          await tester.pump();
          await tester.ensureVisible(find.text('Save this check-back'));
          await tester.tap(find.text('Save this check-back'));
        }
        await _settle(tester);
        final checkback = (await tester.runAsync(
          fixture.repository.getCheckbacks,
        ))!.single;
        expect(checkback.value.outcome, outcome);
        expect(checkback.value.actionId, action!.id);
        expect(checkback.value.targetDegree, isNull);
        expect(
          await tester.runAsync(fixture.repository.getActions),
          hasLength(1),
        );
        final legacy = await fixture.legacy.getRecords();
        if (outcome == ActionOutcome.mixed ||
            outcome == ActionOutcome.couldntTry) {
          expect(legacy, isEmpty);
          expect(checkback.value.reflection, 'Synthetic reflection');
          expect(checkback.value.unexpected, UnexpectedObservation.yes);
          expect(
            find.text('A few words for future you — optional'),
            findsNothing,
          );
          expect(find.text('Reflection kept for future you.'), findsNothing);
        } else {
          expect(legacy, hasLength(1));
          expect(legacy.single.outcome.name, outcome.name);
          expect(
            find.text('A few words for future you — optional'),
            findsOneWidget,
          );
        }
        await fixture.close(tester);
      },
    );
  }
}

CareActionCompletion _completion(DateTime at) => CareActionCompletion(
  mode: CareMode.heavy,
  actionId: 'care.heavy.guided_scene',
  actionLabel: 'Heavy — resting into support',
  occurredAt: at,
);
Future<void> _window(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 120)),
  );
  await tester.pump(const Duration(milliseconds: 800));
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 120)),
  );
  await tester.pump(const Duration(milliseconds: 800));
}

Future<void> _pumpCare(
  WidgetTester tester,
  _Fixture fixture,
  RecordInterventionsRepository repository, {
  VoidCallback? onLeaveCare,
}) async {
  await _window(tester);
  await tester.runAsync(fixture.repository.getActions);
  await tester.pumpWidget(
    MaterialApp(
      theme: ExperienceFoundation.lightTheme(),
      home: CareExperience(
        careMemoryRepository: fixture.legacy,
        interventionsRepository: repository,
        animationPort: _ProbePort(),
        onLeaveCare: onLeaveCare,
        performanceConstrained: true,
        now: () => fixture.now,
      ),
    ),
  );
  addTearDown(() => fixture.close(tester));
  await _settle(tester);
}

Future<void> _openHeavy(WidgetTester tester) async {
  await tester.ensureVisible(find.text('I feel heavy'));
  await tester.tap(find.text('I feel heavy'));
  await _settle(tester);
}

final class _Fixture {
  _Fixture({DateTime? now}) : now = now ?? DateTime(2026, 10, 9, 12) {
    repository = DriftRecordInterventionsRepository(
      database,
      clock: () => this.now,
    );
    legacy = InMemoryCareMemoryRepository(clock: () => this.now);
  }
  DateTime now;
  final database = LetterHealthDatabase(NativeDatabase.memory());
  late final DriftRecordInterventionsRepository repository;
  late final InMemoryCareMemoryRepository legacy;
  bool _closed = false;
  Future<void> close(WidgetTester tester) async {
    if (_closed) return;
    _closed = true;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(database.close);
  }
}

final class _ProbePort implements CareAnimationPort {
  @override
  Widget buildScene(
    BuildContext context, {
    required CareMode mode,
    required CareSceneMotionPreference motionPreference,
    required ValueChanged<CareSceneSignal> onSignal,
  }) => Material(
    child: Column(
      children: [
        for (final entry in {
          'Step': CareSceneSignal.stepCompleted,
          'Complete': CareSceneSignal.sceneCompleted,
          'Dismiss': CareSceneSignal.sceneDismissed,
          'Exit': CareSceneSignal.requestedExit,
        }.entries)
          TextButton(
            onPressed: () => onSignal(entry.value),
            child: Text(entry.key),
          ),
      ],
    ),
  );
}

final class _FailOnceRepository implements RecordInterventionsRepository {
  _FailOnceRepository(this.delegate);
  final RecordInterventionsRepository delegate;
  final tokens = <String?>[];
  @override
  Future<TriedActionRecord> saveAction(
    TriedActionDraft draft, {
    String? id,
  }) async {
    tokens.add(draft.completionToken);
    if (tokens.length == 1) {
      throw const RecordHubException(RecordHubFailure.storageUnavailable);
    }
    return delegate.saveAction(draft, id: id);
  }

  @override
  Future<List<ProductEpisode>> getEpisodes({bool includeArchived = false}) =>
      delegate.getEpisodes(includeArchived: includeArchived);
  @override
  Future<ProductEpisode> createEpisode(ProductEpisodeDraft draft) =>
      delegate.createEpisode(draft);
  @override
  Future<ProductEpisode> reviseEpisode(
    String id,
    ProductDetails details, {
    required LocalDate effectiveFrom,
  }) => delegate.reviseEpisode(id, details, effectiveFrom: effectiveFrom);
  @override
  Future<ProductEpisode> stopEpisode(String id, LocalDate endDate) =>
      delegate.stopEpisode(id, endDate);
  @override
  Future<void> archiveEpisode(String id) => delegate.archiveEpisode(id);
  @override
  Future<List<ProductUseRecord>> getUses({
    LocalDate? date,
    String? episodeId,
  }) => delegate.getUses(date: date, episodeId: episodeId);
  @override
  Future<ProductUseRecord> saveUse(
    ProductUseDraft draft, {
    String? id,
    bool dailyShortcut = true,
  }) => delegate.saveUse(draft, id: id, dailyShortcut: dailyShortcut);
  @override
  Future<void> deleteUse(String id) => delegate.deleteUse(id);
  @override
  Future<List<TriedActionRecord>> getActions({LocalDate? date}) =>
      delegate.getActions(date: date);
  @override
  Future<void> deleteAction(String id) => delegate.deleteAction(id);
  @override
  Future<List<ActionCheckbackRecord>> getCheckbacks() =>
      delegate.getCheckbacks();
  @override
  Future<ActionCheckbackRecord> saveCheckback(ActionCheckbackDraft draft) =>
      delegate.saveCheckback(draft);
  @override
  Future<void> deleteCheckback(String actionId) =>
      delegate.deleteCheckback(actionId);
}
