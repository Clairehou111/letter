import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/design_system/letter_theme.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/health_records/data/in_memory_health_record_repository.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';
import 'package:letter_mobile/features/health_records/presentation/health_records_screen.dart';

HealthRecord sampleRecord() {
  return HealthRecord(
    id: 'health-001',
    symptom: SymptomType.cramps,
    severity: SymptomSeverity.severe,
    functionalImpacts: const {FunctionalImpact.workOrSchool},
    experiencedDate: const LocalDate(2026, 7, 28),
    recordedAt: DateTime.utc(2026, 7, 28, 12),
    updatedAt: DateTime.utc(2026, 7, 28, 12),
    provenance: HealthRecordProvenance.laterRecall,
    userConfirmed: true,
    vocabularyVersion: healthRecordVocabularyVersion,
  );
}

HealthRecord datedRecord({
  required String id,
  required LocalDate date,
  SymptomType symptom = SymptomType.cramps,
}) {
  final recordedAt = date.asLocalDateTime.add(const Duration(hours: 12));
  return HealthRecord(
    id: id,
    symptom: symptom,
    severity: SymptomSeverity.mild,
    functionalImpacts: const {},
    experiencedDate: date,
    recordedAt: recordedAt,
    updatedAt: recordedAt,
    provenance: HealthRecordProvenance.sameDay,
    userConfirmed: true,
    vocabularyVersion: healthRecordVocabularyVersion,
  );
}

Finder verticalScrollable() => find
    .byWidgetPredicate(
      (widget) =>
          widget is Scrollable &&
          (widget.axisDirection == AxisDirection.down ||
              widget.axisDirection == AxisDirection.up),
    )
    .first;

Future<void> ensureSymptomVisible(WidgetTester tester, String name) async {
  final symptom = find.byKey(Key('symptom-$name'));
  await tester.scrollUntilVisible(
    symptom,
    240,
    scrollable: verticalScrollable(),
  );
  await Scrollable.ensureVisible(tester.element(symptom), alignment: .2);
  await tester.pump();
}

Future<void> pumpHealthRecords(
  WidgetTester tester, {
  required Size size,
  required InMemoryHealthRecordRepository repository,
  double textScale = 1,
  VoidCallback? onBack,
  LocalDate? from,
  LocalDate? through,
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
        child: HealthRecordsScreen(
          repository: repository,
          now: () => DateTime(2026, 7, 28),
          onBack: onBack,
          from: from,
          through: through,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows confirmed data and deletion at 320px and large text', (
    tester,
  ) async {
    final repository = InMemoryHealthRecordRepository(seed: [sampleRecord()]);
    await pumpHealthRecords(
      tester,
      size: const Size(320, 700),
      textScale: 2,
      repository: repository,
    );
    await tester.scrollUntilVisible(
      find.text('Cramps'),
      240,
      scrollable: verticalScrollable(),
    );
    expect(find.text('Cramps'), findsOneWidget);
    expect(find.textContaining('Pain 7/10'), findsNothing);
    expect(find.textContaining('Later recall'), findsOneWidget);

    tester
        .widget<PopupMenuButton<String>>(
          find.byKey(const Key('health-record-menu-health-001')),
        )
        .onSelected!('delete');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('health-record-confirm-delete')));
    await tester.pumpAndSettle();

    expect(find.text('Nothing recorded yet.'), findsOneWidget);
  });

  testWidgets('symptom choice requires an explicit intensity', (tester) async {
    final repository = InMemoryHealthRecordRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: LetterTheme.light,
        home: HealthRecordFormScreen(
          repository: repository,
          now: () => DateTime(2026, 7, 28),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add symptom details'), findsOneWidget);
    expect(find.text('What are you noticing?'), findsOneWidget);
    expect(find.text('Choose a symptom'), findsWidgets);
    expect(find.byKey(const Key('health-record-cancel')), findsOneWidget);

    await ensureSymptomVisible(tester, 'cramps');
    await tester.tap(find.byKey(const Key('symptom-cramps')));
    await tester.pumpAndSettle();

    expect(find.text('Cramps'), findsWidgets);
    expect(find.textContaining('Minimal'), findsWidgets);
    expect(find.textContaining('Not at all'), findsNothing);
    expect(find.textContaining('Extreme'), findsWidgets);
    final confirm = tester.widget<InkWell>(
      find.byKey(const Key('confirm-symptom-intensity')),
    );
    expect(confirm.onTap, isNull);

    await tester.tap(find.byKey(const Key('severity-extreme')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('confirm-symptom-intensity')));
    await tester.pumpAndSettle();

    expect(find.text('Continue with 1'), findsOneWidget);
    expect(await repository.getAll(), isEmpty);
  });

  testWidgets('multi-symptom flow saves separate confirmed records', (
    tester,
  ) async {
    final repository = InMemoryHealthRecordRepository();
    final navigatorObserver = _TestNavigatorObserver();
    await tester.pumpWidget(
      MaterialApp(
        theme: LetterTheme.light,
        navigatorObservers: [navigatorObserver],
        home: HealthRecordFormScreen(
          repository: repository,
          now: () => DateTime(2026, 7, 28),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await ensureSymptomVisible(tester, 'cramps');
    await tester.tap(find.byKey(const Key('symptom-cramps')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('severity-extreme')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('confirm-symptom-intensity')));
    await tester.pumpAndSettle();

    await ensureSymptomVisible(tester, 'headache');
    await tester.tap(find.byKey(const Key('symptom-headache')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('severity-mild')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('confirm-symptom-intensity')));
    await tester.pumpAndSettle();

    expect(find.text('Continue with 2'), findsOneWidget);
    await tester.tap(find.byKey(const Key('health-record-save')));
    await tester.pumpAndSettle();

    expect(find.text('Add context'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('Same day'),
      180,
      scrollable: verticalScrollable(),
    );
    expect(find.textContaining('Same day'), findsOneWidget);
    expect(find.text('Save 2 symptoms'), findsOneWidget);
    expect(find.byKey(const Key('health-record-cancel')), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('functional-impact-workOrSchool')),
      180,
      scrollable: verticalScrollable(),
    );
    await tester.tap(find.byKey(const Key('functional-impact-workOrSchool')));
    final save = tester.widget<InkWell>(
      find.byKey(const Key('health-record-save')),
    );
    save.onTap!();
    await tester.pumpAndSettle();

    expect(navigatorObserver.popped, isTrue);
    final records = await repository.getAll();
    expect(records, hasLength(2));
    expect(
      records.map((record) => record.symptom),
      containsAll([SymptomType.cramps, SymptomType.headache]),
    );
    expect(
      records
          .firstWhere((record) => record.symptom == SymptomType.cramps)
          .severity,
      SymptomSeverity.extreme,
    );
    expect(
      records
          .firstWhere((record) => record.symptom == SymptomType.headache)
          .severity,
      SymptomSeverity.mild,
    );
    expect(
      records.every(
        (record) =>
            record.functionalImpacts.contains(FunctionalImpact.workOrSchool),
      ),
      isTrue,
    );
  });

  testWidgets('choosing a previous experienced date selects later recall', (
    tester,
  ) async {
    final repository = InMemoryHealthRecordRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: LetterTheme.light,
        home: HealthRecordFormScreen(
          repository: repository,
          now: () => DateTime(2026, 7, 28),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await ensureSymptomVisible(tester, 'cramps');
    await tester.tap(find.byKey(const Key('symptom-cramps')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('severity-moderate')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('confirm-symptom-intensity')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('health-record-save')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('health-record-date')),
      180,
      scrollable: verticalScrollable(),
    );
    await Scrollable.ensureVisible(
      tester.element(find.byKey(const Key('health-record-date'))),
      alignment: .35,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('health-record-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(RegExp('July 27')));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Later recall'), findsOneWidget);
  });

  testWidgets('mood directory exposes corpus terms and crisis interruption', (
    tester,
  ) async {
    final repository = InMemoryHealthRecordRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: LetterTheme.light,
        home: HealthRecordFormScreen(
          repository: repository,
          now: () => DateTime(2026, 7, 28),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mood'));
    await tester.pumpAndSettle();

    final showAll = find.byKey(const Key('symptom-toggle-more'));
    await tester.scrollUntilVisible(
      showAll,
      180,
      scrollable: verticalScrollable(),
    );
    await Scrollable.ensureVisible(tester.element(showAll), alignment: .2);
    await tester.pump();
    await tester.tap(showAll);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Rage'),
      180,
      scrollable: verticalScrollable(),
    );
    expect(find.text('Crying'), findsOneWidget);
    expect(find.text('Rage'), findsOneWidget);
    expect(find.text('Brain fog'), findsNothing);

    await tester.drag(find.byType(ListView), const Offset(0, 900));
    await tester.pumpAndSettle();
    expect(find.text('Suicidal thoughts'), findsOneWidget);
    expect(find.text('Self-harm'), findsOneWidget);

    await tester.tap(find.byKey(const Key('safety-signal-suicidalThoughts')));
    await tester.pumpAndSettle();

    expect(find.text('Immediate safety comes first.'), findsOneWidget);
    expect(
      find.textContaining('Letter Within cannot provide emergency help'),
      findsOneWidget,
    );
    expect(await repository.getAll(), isEmpty);
  });

  testWidgets('palpitations route to physical safety before routine capture', (
    tester,
  ) async {
    final repository = InMemoryHealthRecordRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: LetterTheme.light,
        home: HealthRecordFormScreen(
          repository: repository,
          now: () => DateTime(2026, 7, 28),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('symptom-palpitations')), findsNothing);

    await tester.scrollUntilVisible(
      find.byKey(const Key('safety-signal-palpitations')),
      180,
      scrollable: verticalScrollable(),
    );
    await Scrollable.ensureVisible(
      tester.element(find.byKey(const Key('safety-signal-palpitations'))),
      alignment: .5,
    );
    await tester.pump();
    expect(find.byKey(const Key('safety-signal-palpitations')), findsOneWidget);
    await tester.tap(find.byKey(const Key('safety-signal-palpitations')));
    await tester.pumpAndSettle();

    expect(
      find.text('This needs medical attention, not more interaction.'),
      findsOneWidget,
    );
    expect(await repository.getAll(), isEmpty);
  });

  testWidgets('form remains usable at 320px with 200 percent text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 700);
    addTearDown(tester.view.reset);
    final repository = InMemoryHealthRecordRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: LetterTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 700),
            textScaler: TextScaler.linear(2),
          ),
          child: HealthRecordFormScreen(
            repository: repository,
            now: () => DateTime(2026, 7, 28),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await ensureSymptomVisible(tester, 'cramps');
    await tester.tap(find.byKey(const Key('symptom-cramps')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('severity-minimal')), findsOneWidget);
    expect(find.byKey(const Key('confirm-symptom-intensity')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('health records expose an explicit Back control', (tester) async {
    var backPressed = false;
    await pumpHealthRecords(
      tester,
      size: const Size(390, 844),
      repository: InMemoryHealthRecordRepository(seed: [sampleRecord()]),
      onBack: () => backPressed = true,
    );

    await tester.tap(find.byKey(const Key('health-record-back')));
    expect(backPressed, isTrue);
  });

  testWidgets(
    'cycle filter includes both boundaries and confirmed records only',
    (tester) async {
      final from = const LocalDate(2026, 7, 14);
      final through = const LocalDate(2026, 7, 18);
      final repository = InMemoryHealthRecordRepository(
        seed: [
          datedRecord(id: 'cycle-from', date: from),
          datedRecord(
            id: 'cycle-through',
            date: through,
            symptom: SymptomType.headache,
          ),
          datedRecord(
            id: 'cycle-before',
            date: const LocalDate(2026, 7, 13),
            symptom: SymptomType.fatigue,
          ),
          datedRecord(
            id: 'cycle-after',
            date: const LocalDate(2026, 7, 19),
            symptom: SymptomType.nausea,
          ),
          _unconfirmedRecord(
            id: 'cycle-unconfirmed',
            date: const LocalDate(2026, 7, 16),
            symptom: SymptomType.bloating,
          ),
        ],
      );

      await pumpHealthRecords(
        tester,
        size: const Size(390, 844),
        repository: repository,
        from: from,
        through: through,
      );

      expect(find.textContaining('Cycle symptoms'), findsOneWidget);
      expect(find.text('Cramps'), findsOneWidget);
      expect(find.text('Headache'), findsOneWidget);
      expect(find.text('Fatigue'), findsNothing);
      expect(find.text('Nausea'), findsNothing);
      expect(find.text('Bloating'), findsNothing);
      expect(
        find.byKey(Key('health-record-day-${from.epochDay}')),
        findsOneWidget,
      );
      expect(
        find.byKey(Key('health-record-day-${through.epochDay}')),
        findsOneWidget,
      );
    },
  );

  testWidgets('cycle filter reloads after deleting a visible record', (
    tester,
  ) async {
    final from = const LocalDate(2026, 7, 14);
    final through = const LocalDate(2026, 7, 18);
    final repository = InMemoryHealthRecordRepository(
      seed: [
        datedRecord(id: 'delete-me', date: from),
        datedRecord(
          id: 'keep-me',
          date: through,
          symptom: SymptomType.headache,
        ),
      ],
    );

    await pumpHealthRecords(
      tester,
      size: const Size(390, 844),
      repository: repository,
      from: from,
      through: through,
    );

    final menu = tester.widget<PopupMenuButton<String>>(
      find.byKey(const Key('health-record-menu-delete-me')),
    );
    menu.onSelected!('delete');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('health-record-confirm-delete')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('health-record-menu-delete-me')), findsNothing);
    expect(find.byKey(const Key('health-record-menu-keep-me')), findsOneWidget);
    expect(await repository.getAll(), hasLength(1));
  });

  testWidgets('routine chips wrap at 390px and stack for large text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: LetterTheme.light,
        home: HealthRecordFormScreen(
          repository: InMemoryHealthRecordRepository(),
          now: () => DateTime(2026, 7, 28),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('symptom-cramps')),
      180,
      scrollable: verticalScrollable(),
    );

    final crampsCenter = tester.getCenter(
      find.byKey(const Key('symptom-cramps')),
    );
    final headacheCenter = tester.getCenter(
      find.byKey(const Key('symptom-headache')),
    );
    expect((crampsCenter.dy - headacheCenter.dy).abs(), lessThan(1));

    tester.view.physicalSize = const Size(320, 700);
    await tester.pumpWidget(
      MaterialApp(
        theme: LetterTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 700),
            textScaler: TextScaler.linear(2),
          ),
          child: HealthRecordFormScreen(
            repository: InMemoryHealthRecordRepository(),
            now: () => DateTime(2026, 7, 28),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('symptom-headache')),
      180,
      scrollable: verticalScrollable(),
    );

    final stackedCrampsCenter = tester.getCenter(
      find.byKey(const Key('symptom-cramps')),
    );
    final stackedHeadacheCenter = tester.getCenter(
      find.byKey(const Key('symptom-headache')),
    );
    expect(
      (stackedCrampsCenter.dy - stackedHeadacheCenter.dy).abs(),
      greaterThan(1),
    );
  });

  testWidgets('primary list is limited to recent records and 20 date groups', (
    tester,
  ) async {
    final records = [
      for (var daysAgo = 0; daysAgo < 22; daysAgo++)
        datedRecord(
          id: 'recent-$daysAgo',
          date: LocalDate.fromDateTime(
            DateTime(2026, 7, 28).subtract(Duration(days: daysAgo)),
          ),
        ),
      datedRecord(id: 'older', date: const LocalDate(2026, 5, 1)),
    ];
    await pumpHealthRecords(
      tester,
      size: const Size(390, 844),
      repository: InMemoryHealthRecordRepository(seed: records),
    );

    expect(find.byKey(const Key('health-record-day-20662')), findsOneWidget);
    expect(find.byKey(const Key('health-record-view-archive')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('health-record-day-20643')),
      240,
      scrollable: verticalScrollable(),
    );
    expect(find.byKey(const Key('health-record-day-20643')), findsOneWidget);
    expect(find.byKey(const Key('health-record-day-20642')), findsNothing);
    expect(find.byKey(const Key('health-record-day-20574')), findsNothing);
  });

  testWidgets(
    'older-only state opens archive with total, month filter, and more',
    (tester) async {
      final records = [
        for (var daysAgo = 0; daysAgo < 10; daysAgo++)
          datedRecord(
            id: 'archive-$daysAgo',
            date: LocalDate.fromDateTime(
              DateTime(2026, 5, 28).subtract(Duration(days: daysAgo)),
            ),
          ),
      ];
      await pumpHealthRecords(
        tester,
        size: const Size(390, 844),
        repository: InMemoryHealthRecordRepository(seed: records),
      );

      expect(find.text('No symptoms in the last 30 days.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('health-record-view-archive')));
      await tester.pumpAndSettle();

      expect(find.text('All symptom records'), findsOneWidget);
      expect(find.text('10 total records'), findsOneWidget);
      expect(find.byKey(const Key('archive-month-filter-all')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('health-record-archive-load-more')),
        240,
        scrollable: verticalScrollable(),
      );
      expect(
        find.byKey(const Key('health-record-archive-load-more')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('health-record-archive-load-more')),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('health-record-day-20592')),
        240,
        scrollable: verticalScrollable(),
      );
      expect(find.byKey(const Key('health-record-day-20592')), findsOneWidget);
    },
  );

  testWidgets('health records remain visually usable at 390 by 844', (
    tester,
  ) async {
    final repository = InMemoryHealthRecordRepository(seed: [sampleRecord()]);
    await pumpHealthRecords(
      tester,
      size: const Size(390, 844),
      repository: repository,
    );

    expect(find.byKey(const Key('health-record-back')), findsOneWidget);
    expect(find.text('Symptoms'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _TestNavigatorObserver extends NavigatorObserver {
  bool popped = false;
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    popped = true;
  }
}

HealthRecord _unconfirmedRecord({
  required String id,
  required LocalDate date,
  required SymptomType symptom,
}) {
  final record = datedRecord(id: id, date: date, symptom: symptom);
  return HealthRecord(
    id: record.id,
    symptom: record.symptom,
    severity: record.severity,
    functionalImpacts: record.functionalImpacts,
    experiencedDate: record.experiencedDate,
    recordedAt: record.recordedAt,
    updatedAt: record.updatedAt,
    provenance: record.provenance,
    userConfirmed: false,
    vocabularyVersion: record.vocabularyVersion,
  );
}
