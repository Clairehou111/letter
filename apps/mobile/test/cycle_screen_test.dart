import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/design_system/letter_theme.dart';
import 'package:letter_mobile/features/cycle/data/in_memory_period_repository.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/cycle/domain/period_record.dart';
import 'package:letter_mobile/features/cycle/domain/period_repository.dart';
import 'package:letter_mobile/features/cycle/presentation/cycle_screen.dart';

const fixedNow = LocalDate(2026, 7, 28);

PeriodRecord record({
  required String id,
  required LocalDate start,
  LocalDate? end,
}) {
  return PeriodRecord(
    id: id,
    startDate: start,
    endDate: end,
    createdAt: DateTime.utc(2026, 7, 1),
    updatedAt: DateTime.utc(2026, 7, 1),
  );
}

Future<void> pumpCycle(
  WidgetTester tester, {
  required PeriodRepository repository,
  Size size = const Size(390, 844),
  double textScale = 1,
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
        ),
        child: CycleScreen(
          repository: repository,
          now: () => DateTime(2026, 7, 28, 12),
        ),
      ),
    ),
  );
}

final class RetryLoadPeriodRepository implements PeriodRepository {
  bool failNextLoad = true;

  @override
  Future<List<PeriodRecord>> getAll() async {
    if (failNextLoad) {
      failNextLoad = false;
      throw StateError('synthetic secure storage failure');
    }
    return const [];
  }

  @override
  Future<PeriodRecord> create(PeriodDraft draft, {required LocalDate today}) {
    throw UnimplementedError();
  }

  @override
  Future<void> delete(String id) {
    throw UnimplementedError();
  }

  @override
  Future<PeriodRecord> update(
    String id,
    PeriodDraft draft, {
    required LocalDate today,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> close() async {}
}

void main() {
  testWidgets('does not flash empty history while repository is loading', (
    tester,
  ) async {
    await pumpCycle(tester, repository: InMemoryPeriodRepository());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const Key('no-current-period')), findsNothing);

    await tester.pumpAndSettle();
    expect(find.byKey(const Key('no-current-period')), findsOneWidget);
    expect(find.byKey(const Key('prediction-learning')), findsOneWidget);
    expect(find.text('0 of 2 cycle intervals'), findsOneWidget);
  });

  testWidgets('shows an explicit storage error and retries loading', (
    tester,
  ) async {
    await pumpCycle(tester, repository: RetryLoadPeriodRepository());
    await tester.pumpAndSettle();

    expect(
      find.text('Your private cycle history could not be opened.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('retry-cycle-load')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('no-current-period')), findsOneWidget);
  });

  testWidgets('shows a transparent range after two complete intervals', (
    tester,
  ) async {
    final repository = InMemoryPeriodRepository(
      seed: [
        record(id: 'current', start: const LocalDate(2026, 7, 26)),
        record(
          id: 'past',
          start: const LocalDate(2026, 6, 27),
          end: const LocalDate(2026, 7, 1),
        ),
        record(
          id: 'older',
          start: const LocalDate(2026, 5, 29),
          end: const LocalDate(2026, 6, 2),
        ),
      ],
    );
    await pumpCycle(tester, repository: repository);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('prediction-available')), findsOneWidget);
    expect(find.text('Low confidence'), findsOneWidget);
    expect(find.text('2 recent intervals'), findsOneWidget);
    expect(find.text('Recorded cycles: 29 days'), findsOneWidget);
    expect(find.textContaining('fertile'), findsNothing);
    expect(find.textContaining('ovulation'), findsNothing);
    expect(find.textContaining('PMDD'), findsNothing);
  });

  testWidgets('does not roll a later estimate into an invented cycle', (
    tester,
  ) async {
    final repository = InMemoryPeriodRepository(
      seed: [
        record(
          id: 'one',
          start: const LocalDate(2026, 1, 1),
          end: const LocalDate(2026, 1, 5),
        ),
        record(
          id: 'two',
          start: const LocalDate(2026, 1, 29),
          end: const LocalDate(2026, 2, 2),
        ),
        record(
          id: 'three',
          start: const LocalDate(2026, 2, 26),
          end: const LocalDate(2026, 3, 2),
        ),
      ],
    );
    await pumpCycle(tester, repository: repository);
    await tester.pumpAndSettle();

    expect(find.text('LATER THAN THIS ESTIMATE'), findsOneWidget);
    expect(
      find.text(
        'No new start is recorded. Letter will not invent another cycle.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('starts and ends a period from the empty state', (tester) async {
    final repository = InMemoryPeriodRepository(idGenerator: () => 'current');
    await pumpCycle(tester, repository: repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('start-period-today')));
    await tester.pumpAndSettle();

    expect(find.text('Period day 1'), findsOneWidget);
    expect((await repository.getAll()).single.isOpen, isTrue);

    await tester.tap(find.byKey(const Key('end-period-today')));
    await tester.pumpAndSettle();

    expect(find.text('No period in progress'), findsOneWidget);
    expect(find.text('1 day'), findsOneWidget);
    expect((await repository.getAll()).single.endDate, fixedNow);
  });

  testWidgets('adds a closed past period with the low-effort editor', (
    tester,
  ) async {
    final repository = InMemoryPeriodRepository(idGenerator: () => 'past');
    await pumpCycle(tester, repository: repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add-past-period')));
    await tester.pumpAndSettle();
    expect(find.text('Add a past period'), findsOneWidget);

    await tester.tap(find.byKey(const Key('save-period-dates')));
    await tester.pumpAndSettle();

    final saved = (await repository.getAll()).single;
    expect(saved.startDate, const LocalDate(2026, 7, 24));
    expect(saved.endDate, fixedNow);
    expect(find.text('5 days'), findsOneWidget);
  });

  testWidgets('keeps attempted dates available after an overlap error', (
    tester,
  ) async {
    final repository = InMemoryPeriodRepository(
      seed: [
        record(
          id: 'existing',
          start: const LocalDate(2026, 7, 24),
          end: fixedNow,
        ),
      ],
    );
    await pumpCycle(tester, repository: repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add-past-period')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-period-dates')));
    await tester.pumpAndSettle();

    expect(find.text('Add a past period'), findsOneWidget);
    final editor = find.byType(PeriodEditorSheet);
    expect(
      find.descendant(of: editor, matching: find.textContaining('Jul 24')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: editor, matching: find.textContaining('Jul 28')),
      findsOneWidget,
    );
    expect(
      find.text(
        'These dates overlap another period. Edit one of the date ranges first.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('deletes a selected period only after confirmation', (
    tester,
  ) async {
    final repository = InMemoryPeriodRepository(
      seed: [
        record(
          id: 'delete-me',
          start: const LocalDate(2026, 7, 1),
          end: const LocalDate(2026, 7, 5),
        ),
      ],
    );
    await pumpCycle(tester, repository: repository);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('period-menu-delete-me')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('period-menu-delete-me')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete this period?'), findsOneWidget);
    expect(await repository.getAll(), hasLength(1));

    await tester.tap(find.byKey(const Key('confirm-delete-period')));
    await tester.pumpAndSettle();

    expect(await repository.getAll(), isEmpty);
    expect(find.byKey(const Key('period-history-empty')), findsOneWidget);
  });

  testWidgets('removes the estimate when deleted history is insufficient', (
    tester,
  ) async {
    final repository = InMemoryPeriodRepository(
      seed: [
        record(id: 'current', start: const LocalDate(2026, 7, 26)),
        record(
          id: 'past',
          start: const LocalDate(2026, 6, 27),
          end: const LocalDate(2026, 7, 1),
        ),
        record(
          id: 'oldest',
          start: const LocalDate(2026, 5, 29),
          end: const LocalDate(2026, 6, 2),
        ),
      ],
    );
    await pumpCycle(tester, repository: repository);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('prediction-available')), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('period-menu-oldest')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('period-menu-oldest')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete-period')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('prediction-available')), findsNothing);
    expect(find.byKey(const Key('prediction-learning')), findsOneWidget);
    expect(find.text('1 of 2 cycle intervals'), findsOneWidget);
  });

  testWidgets('keeps controls usable at narrow width and large text', (
    tester,
  ) async {
    final repository = InMemoryPeriodRepository(
      seed: [
        record(id: 'current', start: const LocalDate(2026, 7, 26)),
        record(
          id: 'past',
          start: const LocalDate(2026, 6, 27),
          end: const LocalDate(2026, 7, 1),
        ),
        record(
          id: 'older',
          start: const LocalDate(2026, 5, 29),
          end: const LocalDate(2026, 6, 2),
        ),
      ],
    );
    await pumpCycle(
      tester,
      repository: repository,
      size: const Size(320, 700),
      textScale: 2,
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(const Key('end-period-today'))).height,
      greaterThanOrEqualTo(44),
    );
    expect(find.text('Period day 3'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('period-record-past')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('matches the Cycle 390 by 844 visual baseline', (tester) async {
    final repository = InMemoryPeriodRepository(
      seed: [
        record(id: 'current', start: const LocalDate(2026, 7, 26)),
        record(
          id: 'past',
          start: const LocalDate(2026, 6, 27),
          end: const LocalDate(2026, 7, 1),
        ),
        record(
          id: 'older',
          start: const LocalDate(2026, 5, 29),
          end: const LocalDate(2026, 6, 2),
        ),
      ],
    );
    await pumpCycle(tester, repository: repository);
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(CycleScreen),
      matchesGoldenFile('goldens/cycle_390x844.png'),
    );
  });
}
