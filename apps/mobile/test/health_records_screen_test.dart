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
    painRating: 7,
    painLocations: const {PainLocation.lowerAbdomen},
    functionalImpacts: const {FunctionalImpact.workOrSchool},
    experiencedDate: const LocalDate(2026, 7, 28),
    recordedAt: DateTime.utc(2026, 7, 28, 12),
    updatedAt: DateTime.utc(2026, 7, 28, 12),
    provenance: HealthRecordProvenance.laterRecall,
    userConfirmed: true,
    vocabularyVersion: healthRecordVocabularyVersion,
  );
}

Future<void> pumpHealthRecords(
  WidgetTester tester, {
  required Size size,
  required InMemoryHealthRecordRepository repository,
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
        child: HealthRecordsScreen(
          repository: repository,
          now: () => DateTime(2026, 7, 28),
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
    for (var i = 0; i < 6; i++) {
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pump();
    }

    expect(find.text('Cramps'), findsOneWidget);
    expect(find.textContaining('Pain 7/10'), findsNothing);
    expect(find.textContaining('Later recall'), findsOneWidget);

    await tester.tap(find.byKey(const Key('health-record-menu-health-001')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
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
    expect(find.text('Choose a symptom'), findsOneWidget);

    await tester.tap(find.byKey(const Key('symptom-cramps')));
    await tester.pumpAndSettle();

    expect(find.text('Cramps'), findsWidgets);
    expect(find.text('Not at all'), findsOneWidget);
    expect(find.text('Extreme'), findsOneWidget);
    final confirm = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Add symptom'),
    );
    expect(confirm.onPressed, isNull);

    await tester.tap(find.byKey(const Key('severity-extreme')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('confirm-symptom-intensity')));
    await tester.pumpAndSettle();

    expect(find.text('6 · Extreme'), findsOneWidget);
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

    await tester.tap(find.byKey(const Key('symptom-cramps')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('severity-extreme')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('confirm-symptom-intensity')));
    await tester.pumpAndSettle();

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
    expect(find.text('Same day'), findsOneWidget);
    expect(find.text('Save 2 symptoms'), findsOneWidget);

    final impact = tester.widget<FilterChip>(
      find.byKey(const Key('functional-impact-workOrSchool')),
    );
    impact.onSelected!(true);
    final save = tester.widget<FilledButton>(
      find.byKey(const Key('health-record-save')),
    );
    save.onPressed!();
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

    await tester.tap(find.byKey(const Key('symptom-cramps')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('severity-moderate')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('confirm-symptom-intensity')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('health-record-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('health-record-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(RegExp('July 27')));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Later recall'), findsOneWidget);
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

    expect(find.text('Crying'), findsOneWidget);
    expect(find.text('Rage'), findsOneWidget);
    expect(find.text('Brain fog'), findsNothing);
    expect(find.text('Suicidal thoughts'), findsOneWidget);
    expect(find.text('Self-harm'), findsOneWidget);

    await tester.tap(find.byKey(const Key('safety-signal-suicidalThoughts')));
    await tester.pumpAndSettle();

    expect(find.text('Immediate safety comes first.'), findsOneWidget);
    expect(
      find.textContaining('Letter cannot provide emergency help'),
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
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -260));
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
    await tester.scrollUntilVisible(
      find.byKey(const Key('symptom-cramps')),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('symptom-cramps')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('severity-notAtAll')), findsOneWidget);
    expect(find.byKey(const Key('confirm-symptom-intensity')), findsOneWidget);
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
