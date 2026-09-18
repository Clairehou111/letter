import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/design_system/letter_theme.dart';
import 'package:letter_mobile/features/archive_views/domain/archive_repository.dart';
import 'package:letter_mobile/features/archive_views/presentation/archive_views_screen.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/health_records/data/in_memory_health_record_repository.dart';

import 'archive_views_domain_test.dart' as fixtures;

Future<void> pumpArchive(
  WidgetTester tester,
  ArchiveInput input, {
  InMemoryHealthRecordRepository? healthRecords,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: LetterTheme.light,
      home: ArchiveViewsScreen(
        key: ValueKey(input),
        repository: InMemoryArchiveRepository(input),
        healthRecordRepository: healthRecords,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> pumpArchiveRepository(
  WidgetTester tester,
  ArchiveRepository repository, {
  InMemoryHealthRecordRepository? healthRecords,
  TextScaler textScaler = TextScaler.noScaling,
  bool settle = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: LetterTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: ArchiveViewsScreen(
        key: ValueKey(repository),
        repository: repository,
        healthRecordRepository: healthRecords,
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

Future<void> revealArchive(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    180,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Future<void> openArchiveCycle(WidgetTester tester, String id) async {
  final finder = find.byKey(Key('archive-cycle-$id'));
  await revealArchive(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

ArchiveInput archiveHistoryInput() {
  final base = fixtures.archiveInput();
  return ArchiveInput(
    cycles: [
      ...base.cycles,
      const ArchiveCycleInput(
        id: 'complete-2',
        startDate: LocalDate(2026, 5, 1),
        endDate: LocalDate(2026, 5, 28),
        periodDates: [LocalDate(2026, 5, 1)],
        isComplete: true,
      ),
      const ArchiveCycleInput(
        id: 'complete-3',
        startDate: LocalDate(2025, 12, 1),
        endDate: LocalDate(2025, 12, 28),
        periodDates: [LocalDate(2025, 12, 1)],
        isComplete: true,
      ),
      const ArchiveCycleInput(
        id: 'complete-4',
        startDate: LocalDate(2025, 8, 1),
        endDate: LocalDate(2025, 8, 28),
        periodDates: [LocalDate(2025, 8, 1)],
        isComplete: true,
      ),
      const ArchiveCycleInput(
        id: 'complete-5',
        startDate: LocalDate(2024, 12, 1),
        endDate: LocalDate(2024, 12, 28),
        periodDates: [LocalDate(2024, 12, 1)],
        isComplete: true,
      ),
    ],
    healthRecords: base.healthRecords,
    careRecords: base.careRecords,
    reflections: base.reflections,
    cycleReflections: base.cycleReflections,
  );
}

final class _FailingArchiveRepository implements ArchiveRepository {
  @override
  Future<ArchiveInput> load() async => throw StateError('archive failed');
}

final class _PendingArchiveRepository implements ArchiveRepository {
  final completer = Completer<ArchiveInput>();

  @override
  Future<ArchiveInput> load() => completer.future;
}

void main() {
  testWidgets('Reports root has an explicit Back action', (tester) async {
    await pumpArchive(tester, fixtures.archiveInput());

    final back = find.byKey(const Key('reports-root-back'));
    expect(back, findsOneWidget);
    expect(tester.getSize(back).height, greaterThanOrEqualTo(44));
  });

  testWidgets(
    'shows current and only three recent reports with an all-reports entry',
    (tester) async {
      await pumpArchive(tester, archiveHistoryInput());

      expect(find.text('Current cycle'), findsWidgets);
      await revealArchive(
        tester,
        find.byKey(const Key('archive-cycle-complete-1')),
      );
      expect(find.text('7/1/2026 - 7/28/2026'), findsOneWidget);
      await revealArchive(
        tester,
        find.byKey(const Key('reports-archive-link')),
      );
      expect(find.text('12/1/2025 - 12/28/2025'), findsOneWidget);
      expect(find.text('8/1/2025 - 8/28/2025'), findsNothing);
      expect(find.textContaining('Letter No.'), findsNothing);
      expect(find.byKey(const Key('reports-archive-link')), findsOneWidget);
    },
  );

  testWidgets('all reports use year grouping and progressive disclosure', (
    tester,
  ) async {
    await pumpArchive(tester, archiveHistoryInput());
    await revealArchive(tester, find.byKey(const Key('reports-archive-link')));
    await tester.tap(find.byKey(const Key('reports-archive-link')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('reports-archive')), findsOneWidget);
    expect(find.byKey(const Key('reports-year-2026')), findsOneWidget);
    await revealArchive(tester, find.byKey(const Key('reports-year-2025')));
    expect(find.byKey(const Key('reports-year-2025')), findsOneWidget);
    await revealArchive(tester, find.byKey(const Key('reports-year-2024')));
    expect(find.byKey(const Key('reports-year-2024')), findsOneWidget);
    expect(find.byKey(const Key('reports-year-2024-content')), findsNothing);

    await tester.tap(find.byKey(const Key('reports-year-2024')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reports-year-2024-content')), findsOneWidget);
  });

  testWidgets('true empty history is distinct from search no-results', (
    tester,
  ) async {
    await pumpArchive(tester, fixtures.archiveInput(includeRecords: false));
    await tester.enterText(find.byKey(const Key('archive-search')), 'cramps');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('archive-no-search-results')), findsOneWidget);

    await pumpArchive(
      tester,
      const ArchiveInput(
        cycles: [],
        healthRecords: [],
        careRecords: [],
        reflections: [],
      ),
    );
    await revealArchive(tester, find.byKey(const Key('reports-empty')));
    expect(find.byKey(const Key('reports-empty')), findsOneWidget);
    expect(find.byKey(const Key('archive-no-search-results')), findsNothing);
  });

  testWidgets('Reports remains usable at 320x700 with 200 percent text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpArchiveRepository(
      tester,
      InMemoryArchiveRepository(archiveHistoryInput()),
      textScaler: const TextScaler.linear(2),
    );
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('archive-cycle-list')), findsOneWidget);
  });

  testWidgets(
    'Clinical uses mobile cards and section Edit still opens Health Records',
    (tester) async {
      final input = fixtures.archiveInput();
      final healthRecords = InMemoryHealthRecordRepository(
        seed: input.healthRecords,
      );
      await pumpArchive(tester, input, healthRecords: healthRecords);
      await openArchiveCycle(tester, 'complete-1');
      await tester.tap(find.byIcon(Icons.table_chart_outlined));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('archive-clinical-health-cards')),
        findsOneWidget,
      );
      await revealArchive(
        tester,
        find.byKey(const Key('archive-edit-health-records')),
      );
      await tester.tap(find.byKey(const Key('archive-edit-health-records')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('health-record-back')), findsOneWidget);
    },
  );

  testWidgets('loading and error states retain an explicit Back action', (
    tester,
  ) async {
    final pending = _PendingArchiveRepository();
    await pumpArchiveRepository(tester, pending, settle: false);
    await tester.pump();
    expect(find.byKey(const Key('reports-root-back')), findsOneWidget);
    expect(find.byKey(const Key('reports-loading')), findsOneWidget);

    await pumpArchiveRepository(tester, _FailingArchiveRepository());
    expect(find.byKey(const Key('reports-root-back')), findsOneWidget);
    expect(find.byKey(const Key('reports-error')), findsOneWidget);
    await tester.tap(find.byKey(const Key('reports-retry')));
  });

  testWidgets('keeps incomplete cycle separate and opens Story and Clinical', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpArchive(tester, fixtures.archiveInput());

    expect(find.text('Current cycle'), findsWidgets);
    expect(find.text('Incomplete'), findsOneWidget);
    expect(find.text('7/1/2026 - 7/28/2026'), findsOneWidget);
    expect(find.textContaining('Letter No.'), findsNothing);

    await openArchiveCycle(tester, 'complete-1');
    expect(find.byKey(const Key('archive-view-tabs')), findsOneWidget);
    expect(
      find.text('The middle of this cycle needed a quieter pace.'),
      findsOneWidget,
    );
    expect(find.text('Care overview'), findsOneWidget);
    final storyScroll = find
        .descendant(
          of: find.byKey(const Key('archive-story-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('Warmth and quiet'),
      160,
      scrollable: storyScroll,
    );
    await tester.drag(storyScroll, const Offset(0, -100));
    await tester.pump();
    await tester.tap(find.text('Warmth and quiet'));
    await tester.pumpAndSettle();
    expect(find.text('Saved Care note'), findsOneWidget);
    expect(
      find.textContaining('The warmth made the next hour easier.'),
      findsOneWidget,
    );

    expect(find.text('Pattern'), findsNothing);

    await tester.tap(find.byIcon(Icons.table_chart_outlined));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('archive-clinical-health-cards')),
      findsOneWidget,
    );
    expect(find.textContaining('Same day'), findsOneWidget);
  });

  testWidgets('search uses only visible saved evidence', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpArchive(tester, fixtures.archiveInput());

    await tester.enterText(
      find.byKey(const Key('archive-search')),
      'not a draft',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('archive-no-search-results')), findsOneWidget);
    expect(find.text('7/1/2026 - 7/28/2026'), findsNothing);

    await tester.enterText(find.byKey(const Key('archive-search')), 'cramps');
    await tester.pumpAndSettle();
    expect(find.text('7/1/2026 - 7/28/2026'), findsOneWidget);
    expect(find.text('Current cycle'), findsNothing);
  });

  testWidgets('clinical records offer an edit entrance', (tester) async {
    final input = fixtures.archiveInput();
    final healthRecords = InMemoryHealthRecordRepository(
      seed: input.healthRecords,
    );
    await pumpArchive(tester, input, healthRecords: healthRecords);

    await openArchiveCycle(tester, 'complete-1');
    await tester.tap(find.byIcon(Icons.table_chart_outlined));
    await tester.pumpAndSettle();

    await revealArchive(
      tester,
      find.byKey(const Key('archive-edit-health-records')),
    );
    expect(
      find.byKey(const Key('archive-edit-health-records')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('archive-edit-health-records')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('health-record-back')), findsOneWidget);
  });
}
