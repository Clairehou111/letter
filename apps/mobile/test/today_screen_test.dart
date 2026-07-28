import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/design_system/letter_theme.dart';
import 'package:letter_mobile/features/cycle/data/in_memory_period_repository.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/cycle/domain/period_record.dart';
import 'package:letter_mobile/features/cycle/domain/period_repository.dart';
import 'package:letter_mobile/features/today/today_screen.dart';

PeriodRecord period({
  required String id,
  required LocalDate start,
  LocalDate? end,
}) {
  return PeriodRecord(
    id: id,
    startDate: start,
    endDate: end,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
}

InMemoryPeriodRepository seededRepository() {
  return InMemoryPeriodRepository(
    seed: [
      period(id: 'current', start: const LocalDate(2026, 7, 26)),
      period(
        id: 'past',
        start: const LocalDate(2026, 6, 27),
        end: const LocalDate(2026, 7, 1),
      ),
      period(
        id: 'older',
        start: const LocalDate(2026, 5, 29),
        end: const LocalDate(2026, 6, 2),
      ),
    ],
  );
}

final class ControllablePeriodRepository implements PeriodRepository {
  ControllablePeriodRepository({this.failFirstLoad = false});

  final InMemoryPeriodRepository delegate = InMemoryPeriodRepository();
  final bool failFirstLoad;
  final Completer<List<PeriodRecord>> pendingLoad =
      Completer<List<PeriodRecord>>();
  int loadCount = 0;

  @override
  Future<List<PeriodRecord>> getAll() {
    loadCount += 1;
    if (failFirstLoad && loadCount == 1) {
      throw StateError('synthetic load failure');
    }
    if (!pendingLoad.isCompleted) {
      return pendingLoad.future;
    }
    return delegate.getAll();
  }

  @override
  Future<PeriodRecord> create(PeriodDraft draft, {required LocalDate today}) {
    return delegate.create(draft, today: today);
  }

  @override
  Future<PeriodRecord> update(
    String id,
    PeriodDraft draft, {
    required LocalDate today,
  }) {
    return delegate.update(id, draft, today: today);
  }

  @override
  Future<void> delete(String id) => delegate.delete(id);

  @override
  Future<void> close() => delegate.close();
}

Future<void> pumpToday(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double textScale = 1,
  PeriodRepository? repository,
  ValueChanged<int>? onNavigationSelected,
  bool settle = true,
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
        child: TodayScreen(
          repository: repository ?? seededRepository(),
          onNavigationSelected: onNavigationSelected,
          now: () => DateTime(2026, 7, 28, 12),
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

void main() {
  testWidgets('does not flash cycle context while repository is loading', (
    tester,
  ) async {
    final repository = ControllablePeriodRepository();
    await pumpToday(tester, repository: repository, settle: false);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const Key('today-cycle-context')), findsNothing);

    repository.pendingLoad.complete([]);
    await tester.pumpAndSettle();

    expect(find.text('Start with a real cycle record.'), findsOneWidget);
  });

  testWidgets('load failure is explicit and retryable', (tester) async {
    final repository = ControllablePeriodRepository(failFirstLoad: true);
    repository.pendingLoad.complete([]);
    await pumpToday(tester, repository: repository);

    expect(
      find.text('Today could not open your private cycle context.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('retry-today-load')));
    await tester.pumpAndSettle();

    expect(find.text('Start with a real cycle record.'), findsOneWidget);
    expect(repository.loadCount, 2);
  });

  testWidgets('no history shows no guessed day and routes to Cycle', (
    tester,
  ) async {
    int? selectedNavigation;
    await pumpToday(
      tester,
      repository: InMemoryPeriodRepository(),
      onNavigationSelected: (index) => selectedNavigation = index,
    );

    expect(find.text('Start with a real cycle record.'), findsOneWidget);
    expect(find.textContaining('Cycle day'), findsNothing);
    expect(find.textContaining('Estimated next period'), findsNothing);

    await tester.tap(find.byKey(const Key('today-open-cycle')));
    expect(selectedNavigation, 0);
  });

  testWidgets('open period shows its inclusive period day and start date', (
    tester,
  ) async {
    await pumpToday(tester);

    expect(find.text('Your period is in progress.'), findsOneWidget);
    expect(find.textContaining('Period day 3.'), findsOneWidget);
    expect(find.textContaining('Jul 26'), findsOneWidget);
  });

  testWidgets('closed history shows cycle day and shared prediction', (
    tester,
  ) async {
    final repository = InMemoryPeriodRepository(
      seed: [
        period(
          id: 'latest',
          start: const LocalDate(2026, 7, 1),
          end: const LocalDate(2026, 7, 5),
        ),
        period(
          id: 'past',
          start: const LocalDate(2026, 6, 2),
          end: const LocalDate(2026, 6, 6),
        ),
        period(
          id: 'older',
          start: const LocalDate(2026, 5, 4),
          end: const LocalDate(2026, 5, 8),
        ),
      ],
    );

    await pumpToday(tester, repository: repository);

    expect(find.textContaining('Cycle day 28.'), findsOneWidget);
    expect(find.text('Your estimate window is here.'), findsOneWidget);
    expect(find.textContaining('Today falls within'), findsOneWidget);
  });

  testWidgets('renders balanced states and centered Today navigation', (
    tester,
  ) async {
    await pumpToday(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('state-physical')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    for (final label in [
      'Good',
      'Steady',
      'Energized',
      'Low',
      'Irritable',
      'Physical',
    ]) {
      expect(find.text(label), findsOneWidget);
    }

    expect(find.text('Cycle'), findsOneWidget);
    expect(find.text('Letters'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Care'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);

    final todayX = tester.getCenter(find.text('Today')).dx;
    expect(todayX, closeTo(195, 2));
  });

  testWidgets('header Log opens session-only quick-state entry', (
    tester,
  ) async {
    await pumpToday(tester);

    await tester.tap(find.byKey(const Key('header-log-button')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Choose one starting point. Nothing is saved to your health record yet.',
      ),
      findsOneWidget,
    );
    for (final label in [
      'Good',
      'Steady',
      'Energized',
      'Low',
      'Irritable',
      'Physical',
    ]) {
      expect(
        find.descendant(
          of: find.byType(QuickStateSheet),
          matching: find.text(label),
        ),
        findsOneWidget,
      );
    }

    await tester.tap(
      find.descendant(
        of: find.byType(QuickStateSheet),
        matching: find.byKey(const Key('state-good')),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'One tap is enough. This is not saved to your health record yet.',
      ),
      findsOneWidget,
    );
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Save today'), findsNothing);
  });

  testWidgets('records multiple pain locations with separate severity', (
    tester,
  ) async {
    await pumpToday(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('state-physical')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('state-physical')));
    await tester.pumpAndSettle();

    expect(find.text('Where does your body hurt?'), findsOneWidget);
    expect(find.text('Pelvic cramps'), findsOneWidget);
    expect(find.text('Lower back pain'), findsOneWidget);
    expect(find.text('Headache'), findsOneWidget);
    expect(find.text('Breast tenderness'), findsOneWidget);

    await tester.tap(find.byKey(const Key('pain-pelvic-cramps')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('severity-strong')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pain-lower-back-pain')));
    await tester.pumpAndSettle();

    expect(find.text('2 pain locations added'), findsOneWidget);
    final pelvicChip = tester.widget<FilterChip>(
      find.byKey(const Key('pain-pelvic-cramps')),
    );
    final backChip = tester.widget<FilterChip>(
      find.byKey(const Key('pain-lower-back-pain')),
    );
    expect(pelvicChip.selected, isTrue);
    expect(backChip.selected, isTrue);
  });

  testWidgets('does not show synthetic phase, plan, note, or Recent content', (
    tester,
  ) async {
    await pumpToday(tester);

    for (final syntheticText in [
      'Luteal',
      'Your care plan is ready',
      'Warm drink',
      'Heat + quiet',
      'Message Maya',
      'A note from calm-you',
      'Recent',
      'Low mood and poor focus',
    ]) {
      expect(find.text(syntheticText), findsNothing);
    }
  });

  testWidgets('opens the low-effort Care sheet', (tester) async {
    await pumpToday(tester);

    await tester.tap(find.byKey(const Key('open-care-button')));
    await tester.pumpAndSettle();

    expect(find.text('What would feel easier right now?'), findsOneWidget);
    expect(find.text('Ease pain'), findsOneWidget);
    expect(find.text('Settle my body'), findsOneWidget);
    expect(find.text('Feel less alone'), findsOneWidget);
    expect(find.text('Use my plan'), findsOneWidget);

    await tester.tap(find.byKey(const Key('care-ease-pain')));
    await tester.pumpAndSettle();
    expect(find.text('Start gently'), findsOneWidget);
  });

  testWidgets('keeps primary touch targets at least 44 logical pixels', (
    tester,
  ) async {
    await pumpToday(tester);
    final logSize = tester.getSize(find.byKey(const Key('header-log-button')));
    final careSize = tester.getSize(find.byKey(const Key('open-care-button')));

    await tester.scrollUntilVisible(
      find.byKey(const Key('state-good')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    final stateSize = tester.getSize(find.byKey(const Key('state-good')));

    expect(stateSize.height, greaterThanOrEqualTo(44));
    expect(careSize.height, greaterThanOrEqualTo(44));
    expect(logSize.height, greaterThanOrEqualTo(44));
  });

  testWidgets('does not overflow at 320 width and 200 percent text scale', (
    tester,
  ) async {
    await pumpToday(tester, size: const Size(320, 700), textScale: 2);

    expect(find.text('Your period is in progress.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.byKey(const Key('state-good')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Good'), findsOneWidget);
    expect(find.text('Physical'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('matches the approved 390 by 844 visual baseline', (
    tester,
  ) async {
    await pumpToday(tester);

    await expectLater(
      find.byType(TodayScreen),
      matchesGoldenFile('goldens/today_390x844.png'),
    );
  });
}
