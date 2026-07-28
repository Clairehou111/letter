import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/design_system/letter_theme.dart';
import 'package:letter_mobile/features/care/data/in_memory_impulse_buffer_repository.dart';
import 'package:letter_mobile/features/care/domain/impulse_buffer_repository.dart';
import 'package:letter_mobile/features/care/domain/impulse_draft_record.dart';
import 'package:letter_mobile/features/care/presentation/angry_impulse_flow.dart';

final class FailingImpulseBufferRepository implements ImpulseBufferRepository {
  FailingImpulseBufferRepository({
    this.failLoad = false,
    this.failSave = false,
    this.failSeal = false,
    this.failKeep = false,
    this.failReseal = false,
    this.failDelete = false,
  });

  final InMemoryImpulseBufferRepository delegate =
      InMemoryImpulseBufferRepository(idGenerator: () => 'active');
  bool failLoad;
  bool failSave;
  bool failSeal;
  bool failKeep;
  bool failReseal;
  bool failDelete;

  @override
  Future<ImpulseDraftRecord?> getActive() async {
    if (failLoad) {
      throw StateError('synthetic load failure');
    }
    return delegate.getActive();
  }

  @override
  Future<ImpulseDraftRecord> saveDraft(String content) {
    if (failSave) {
      throw const ImpulseBufferException(
        ImpulseBufferFailure.storageUnavailable,
      );
    }
    return delegate.saveDraft(content);
  }

  @override
  Future<ImpulseDraftRecord> sealDraft(String id, {required DateTime now}) {
    if (failSeal) {
      throw const ImpulseBufferException(
        ImpulseBufferFailure.storageUnavailable,
      );
    }
    return delegate.sealDraft(id, now: now);
  }

  @override
  Future<ImpulseDraftRecord> keepReadySealed(
    String id, {
    required DateTime now,
  }) {
    if (failKeep) {
      throw const ImpulseBufferException(
        ImpulseBufferFailure.storageUnavailable,
      );
    }
    return delegate.keepReadySealed(id, now: now);
  }

  @override
  Future<ImpulseDraftRecord> resealReady(
    String id,
    String content, {
    required DateTime now,
  }) {
    if (failReseal) {
      throw const ImpulseBufferException(
        ImpulseBufferFailure.storageUnavailable,
      );
    }
    return delegate.resealReady(id, content, now: now);
  }

  @override
  Future<void> delete(String id) {
    if (failDelete) {
      throw const ImpulseBufferException(
        ImpulseBufferFailure.storageUnavailable,
      );
    }
    return delegate.delete(id);
  }

  @override
  Future<void> close() => delegate.close();
}

Future<void> pumpAngry(
  WidgetTester tester, {
  required ImpulseBufferRepository repository,
  DateTime Function()? now,
  Size size = const Size(390, 844),
  double textScale = 1,
  bool disableAnimations = false,
  VoidCallback? onReturnToGate,
  VoidCallback? onExitCare,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: LetterTheme.light,
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
          disableAnimations: disableAnimations,
        ),
        child: AngryImpulseFlow(
          repository: repository,
          now: now ?? () => DateTime.utc(2026, 7, 28, 8),
          onReturnToGate: onReturnToGate ?? () {},
          onExitCare: onExitCare ?? () {},
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> reachDraft(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('skip-shatter')));
  await tester.pump();
  await tester.tap(find.byKey(const Key('open-private-draft')));
  await tester.pump();
}

Future<void> sealText(WidgetTester tester, String content) async {
  await reachDraft(tester);
  await tester.enterText(find.byKey(const Key('private-draft-field')), content);
  await tester.tap(find.byKey(const Key('review-private-draft')));
  await tester.pump();
  await tester.pump();
  await tester.tap(find.byKey(const Key('seal-for-24-hours')));
  await tester.pump();
  await tester.pump();
}

ImpulseDraftRecord record({
  required String content,
  required DateTime createdAt,
  DateTime? sealedAt,
  DateTime? unlockAt,
}) {
  return ImpulseDraftRecord(
    id: 'active',
    content: content,
    createdAt: createdAt,
    updatedAt: sealedAt ?? createdAt,
    sealedAt: sealedAt,
    unlockAt: unlockAt,
  );
}

void main() {
  final now = DateTime.utc(2026, 7, 28, 8);
  const privateText = 'I want to send this private angry message.';

  testWidgets('every tap adds a visible crack to the crystal', (tester) async {
    await pumpAngry(tester, repository: InMemoryImpulseBufferRepository());

    ShatterCrystalPainter painter() {
      return tester
              .widget<CustomPaint>(
                find.descendant(
                  of: find.byKey(const Key('shatter-crystal')),
                  matching: find.byType(CustomPaint),
                ),
              )
              .painter!
          as ShatterCrystalPainter;
    }

    expect(painter().impacts, isEmpty);
    await tester.tap(find.byKey(const Key('shatter-crystal')));
    await tester.pump();
    expect(painter().impacts, hasLength(1));
  });

  testWidgets('twenty taps end Shatter on the quiet screen', (tester) async {
    await pumpAngry(tester, repository: InMemoryImpulseBufferRepository());

    for (var index = 0; index < 20; index++) {
      await tester.tap(find.byKey(const Key('shatter-crystal')));
      await tester.pump();
    }

    expect(
      find.text('Done. Nothing has to leave this screen.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('shatter-crystal')), findsNothing);
  });

  testWidgets('Shatter ends after twenty seconds without taps', (tester) async {
    await pumpAngry(tester, repository: InMemoryImpulseBufferRepository());

    await tester.pump(const Duration(seconds: 20));

    expect(
      find.text('Done. Nothing has to leave this screen.'),
      findsOneWidget,
    );
  });

  testWidgets('skip reaches the same quiet transition', (tester) async {
    await pumpAngry(tester, repository: InMemoryImpulseBufferRepository());

    await tester.tap(find.byKey(const Key('skip-shatter')));
    await tester.pump();

    expect(
      find.text("Don't send it. Don't post it. Don't quit tonight."),
      findsOneWidget,
    );
    expect(find.byKey(const Key('open-private-draft')), findsOneWidget);
  });

  testWidgets('empty drafts remain editable with an explicit error', (
    tester,
  ) async {
    await pumpAngry(tester, repository: InMemoryImpulseBufferRepository());
    await reachDraft(tester);

    await tester.tap(find.byKey(const Key('review-private-draft')));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('impulse-operation-error')), findsOneWidget);
    expect(find.byKey(const Key('private-draft-field')), findsOneWidget);
    expect(find.byKey(const Key('seal-for-24-hours')), findsNothing);
  });

  testWidgets('draft input enforces the four-thousand-character boundary', (
    tester,
  ) async {
    await pumpAngry(tester, repository: InMemoryImpulseBufferRepository());
    await reachDraft(tester);

    await tester.enterText(
      find.byKey(const Key('private-draft-field')),
      List.filled(4001, 'a').join(),
    );
    await tester.pump();

    final field = tester.widget<TextField>(
      find.byKey(const Key('private-draft-field')),
    );
    expect(field.controller!.text, hasLength(impulseDraftMaximumCharacters));
  });

  testWidgets('review explains the exact app-enforced consequence', (
    tester,
  ) async {
    await pumpAngry(
      tester,
      repository: InMemoryImpulseBufferRepository(
        clock: () => now,
        idGenerator: () => 'active',
      ),
      now: () => now,
    );
    await reachDraft(tester);
    await tester.enterText(
      find.byKey(const Key('private-draft-field')),
      privateText,
    );

    await tester.tap(find.byKey(const Key('review-private-draft')));
    await tester.pump();
    await tester.pump();

    expect(
      find.text('This is an app-enforced 24-hour cooldown.'),
      findsOneWidget,
    );
    expect(
      find.text('It cannot stop you from acting somewhere else.'),
      findsOneWidget,
    );
    expect(find.textContaining('device clock determines'), findsOneWidget);
  });

  testWidgets('sealing hides content and uses exactly twenty-four hours', (
    tester,
  ) async {
    final repository = InMemoryImpulseBufferRepository(
      clock: () => now,
      idGenerator: () => 'active',
    );
    await pumpAngry(tester, repository: repository, now: () => now);

    await sealText(tester, privateText);

    final active = (await repository.getActive())!;
    expect(active.unlockAt, now.add(impulseCooldown));
    expect(active.stateAt(now), ImpulseDraftState.locked);
    expect(find.textContaining(privateText), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.byKey(const Key('locked-remaining')), findsOneWidget);
    expect(find.byKey(const Key('open-ready-privately')), findsNothing);
  });

  testWidgets('a saved unsealed draft resumes after reconstruction', (
    tester,
  ) async {
    var returned = 0;
    final repository = InMemoryImpulseBufferRepository(
      clock: () => now,
      idGenerator: () => 'active',
    );
    await pumpAngry(
      tester,
      repository: repository,
      now: () => now,
      onReturnToGate: () => returned += 1,
    );
    await reachDraft(tester);
    await tester.enterText(
      find.byKey(const Key('private-draft-field')),
      privateText,
    );
    await tester.tap(find.byKey(const Key('save-draft-and-leave')));
    await tester.pump();
    await tester.pump();
    expect(returned, 1);

    await pumpAngry(tester, repository: repository, now: () => now);

    final field = tester.widget<TextField>(
      find.byKey(const Key('private-draft-field')),
    );
    expect(field.controller!.text, privateText);
  });

  testWidgets('locked reconstruction never renders stored content', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final repository = InMemoryImpulseBufferRepository(
      seed: record(
        content: privateText,
        createdAt: now,
        sealedAt: now,
        unlockAt: now.add(impulseCooldown),
      ),
    );

    await pumpAngry(tester, repository: repository, now: () => now);

    expect(find.textContaining(privateText), findsNothing);
    expect(find.bySemanticsLabel(privateText), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('The words are hidden inside Letter.'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets(
    'locked envelope becomes ready at unlock without revealing text',
    (tester) async {
      var current = now;
      final unlockAt = now.add(const Duration(seconds: 1));
      final repository = InMemoryImpulseBufferRepository(
        seed: record(
          content: privateText,
          createdAt: now,
          sealedAt: now,
          unlockAt: unlockAt,
        ),
      );

      await pumpAngry(tester, repository: repository, now: () => current);
      expect(find.byKey(const Key('locked-remaining')), findsOneWidget);

      current = unlockAt;
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('A sealed note is ready when you are.'), findsOneWidget);
      expect(find.textContaining(privateText), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.byKey(const Key('open-ready-privately')), findsOneWidget);
    },
  );

  testWidgets('ready envelope stays hidden until Open privately', (
    tester,
  ) async {
    final repository = InMemoryImpulseBufferRepository(
      seed: record(
        content: privateText,
        createdAt: now.subtract(impulseCooldown),
        sealedAt: now.subtract(impulseCooldown),
        unlockAt: now,
      ),
    );

    await pumpAngry(tester, repository: repository, now: () => now);

    expect(find.textContaining(privateText), findsNothing);
    expect(find.text('A sealed note is ready when you are.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('open-ready-privately')));
    await tester.pump();

    final field = tester.widget<TextField>(
      find.byKey(const Key('opened-draft-field')),
    );
    expect(field.controller!.text, privateText);
  });

  testWidgets('ready envelope can stay sealed for another twenty-four hours', (
    tester,
  ) async {
    final repository = InMemoryImpulseBufferRepository(
      seed: record(
        content: privateText,
        createdAt: now.subtract(impulseCooldown),
        sealedAt: now.subtract(impulseCooldown),
        unlockAt: now,
      ),
    );
    await pumpAngry(tester, repository: repository, now: () => now);

    await tester.tap(find.byKey(const Key('keep-sealed-24-hours')));
    await tester.pump();
    await tester.pump();

    final active = (await repository.getActive())!;
    expect(active.unlockAt, now.add(impulseCooldown));
    expect(find.textContaining(privateText), findsNothing);
    expect(find.byKey(const Key('locked-remaining')), findsOneWidget);
  });

  testWidgets('opened content can be rewritten and resealed', (tester) async {
    final repository = InMemoryImpulseBufferRepository(
      seed: record(
        content: privateText,
        createdAt: now.subtract(impulseCooldown),
        sealedAt: now.subtract(impulseCooldown),
        unlockAt: now,
      ),
    );
    await pumpAngry(tester, repository: repository, now: () => now);
    await tester.tap(find.byKey(const Key('open-ready-privately')));
    await tester.pump();

    await tester.enterText(
      find.byKey(const Key('opened-draft-field')),
      'Calmer rewrite',
    );
    await tester.tap(find.byKey(const Key('reseal-rewrite')));
    await tester.pump();
    await tester.pump();

    final active = (await repository.getActive())!;
    expect(active.content, 'Calmer rewrite');
    expect(active.stateAt(now), ImpulseDraftState.locked);
    expect(find.text('Calmer rewrite'), findsNothing);
  });

  testWidgets('locked envelope can be deleted without opening', (tester) async {
    var returned = 0;
    final repository = InMemoryImpulseBufferRepository(
      seed: record(
        content: privateText,
        createdAt: now,
        sealedAt: now,
        unlockAt: now.add(impulseCooldown),
      ),
    );
    await pumpAngry(
      tester,
      repository: repository,
      now: () => now,
      onReturnToGate: () => returned += 1,
    );

    await tester.tap(find.byKey(const Key('delete-locked-unopened')));
    await tester.pump();
    expect(find.text('Delete without opening?'), findsOneWidget);
    expect(find.textContaining(privateText), findsNothing);
    await tester.tap(find.byKey(const Key('confirm-delete-impulse')));
    await tester.pump();
    await tester.pump();

    expect(await repository.getActive(), isNull);
    expect(returned, 1);
  });

  testWidgets('a saved unsealed draft can be deleted explicitly', (
    tester,
  ) async {
    var returned = 0;
    final repository = InMemoryImpulseBufferRepository(
      seed: record(content: privateText, createdAt: now),
    );
    await pumpAngry(
      tester,
      repository: repository,
      now: () => now,
      onReturnToGate: () => returned += 1,
    );

    await tester.tap(find.byKey(const Key('delete-active-draft')));
    await tester.pump();
    expect(find.text('Delete this draft?'), findsOneWidget);
    expect(
      find.textContaining('The sealed text will be permanently deleted'),
      findsNothing,
    );
    await tester.tap(find.byKey(const Key('confirm-delete-impulse')));
    await tester.pump();
    await tester.pump();

    expect(await repository.getActive(), isNull);
    expect(returned, 1);
  });

  testWidgets('load, save, and seal failures remain explicit and retryable', (
    tester,
  ) async {
    final repository = FailingImpulseBufferRepository(failLoad: true);
    await pumpAngry(tester, repository: repository, now: () => now);

    expect(find.byKey(const Key('retry-impulse-load')), findsOneWidget);
    repository.failLoad = false;
    await tester.tap(find.byKey(const Key('retry-impulse-load')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('shatter-crystal')), findsOneWidget);

    await reachDraft(tester);
    await tester.enterText(
      find.byKey(const Key('private-draft-field')),
      privateText,
    );
    repository.failSave = true;
    await tester.tap(find.byKey(const Key('review-private-draft')));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('impulse-operation-error')), findsOneWidget);
    expect(find.byKey(const Key('private-draft-field')), findsOneWidget);

    repository.failSave = false;
    await tester.tap(find.byKey(const Key('review-private-draft')));
    await tester.pump();
    await tester.pump();
    repository.failSeal = true;
    await tester.tap(find.byKey(const Key('seal-for-24-hours')));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('impulse-operation-error')), findsOneWidget);
    expect(find.byKey(const Key('seal-for-24-hours')), findsOneWidget);
    expect(find.byKey(const Key('locked-remaining')), findsNothing);
  });

  testWidgets('keep, reseal, and delete failures preserve private state', (
    tester,
  ) async {
    final repository = FailingImpulseBufferRepository();
    await repository.delegate.saveDraft(privateText);
    await repository.delegate.sealDraft('active', now: now);
    final readyAt = now.add(impulseCooldown);

    repository.failKeep = true;
    await pumpAngry(tester, repository: repository, now: () => readyAt);
    await tester.tap(find.byKey(const Key('keep-sealed-24-hours')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('impulse-operation-error')), findsOneWidget);
    expect(find.byKey(const Key('open-ready-privately')), findsOneWidget);

    await tester.tap(find.byKey(const Key('open-ready-privately')));
    await tester.pump();
    repository.failReseal = true;
    await tester.tap(find.byKey(const Key('reseal-rewrite')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('impulse-operation-error')), findsOneWidget);
    expect(find.byKey(const Key('opened-draft-field')), findsOneWidget);

    repository.failDelete = true;
    await tester.tap(find.byKey(const Key('delete-active-draft')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('confirm-delete-impulse')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('impulse-operation-error')), findsOneWidget);
    expect(find.byKey(const Key('opened-draft-field')), findsOneWidget);
    expect((await repository.getActive())!.content, privateText);
  });

  testWidgets(
    'reduced motion and 200 percent text remain usable at 320 width',
    (tester) async {
      await pumpAngry(
        tester,
        repository: InMemoryImpulseBufferRepository(),
        size: const Size(320, 700),
        textScale: 2,
        disableAnimations: true,
      );

      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.byKey(const Key('skip-shatter')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('skip-shatter')));
      await tester.pump();
      await tester.scrollUntilVisible(
        find.byKey(const Key('open-private-draft')),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.byKey(const Key('open-private-draft')), findsOneWidget);
      expect(find.byKey(const Key('angry-safety')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Shatter matches the visual baseline', (tester) async {
    await pumpAngry(tester, repository: InMemoryImpulseBufferRepository());
    for (var index = 0; index < 6; index++) {
      await tester.tap(find.byKey(const Key('shatter-crystal')));
      await tester.pump();
    }

    await expectLater(
      find.byType(AngryImpulseFlow),
      matchesGoldenFile('goldens/angry_shatter_390x844.png'),
    );
  });

  testWidgets('locked envelope matches the visual baseline', (tester) async {
    final repository = InMemoryImpulseBufferRepository(
      seed: record(
        content: privateText,
        createdAt: now,
        sealedAt: now,
        unlockAt: now.add(impulseCooldown),
      ),
    );
    await pumpAngry(tester, repository: repository, now: () => now);

    await expectLater(
      find.byType(AngryImpulseFlow),
      matchesGoldenFile('goldens/angry_locked_390x844.png'),
    );
  });
}
