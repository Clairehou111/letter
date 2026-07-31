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
    expect(find.textContaining('Pain 7/10'), findsOneWidget);
    expect(find.textContaining('Later recall'), findsOneWidget);

    await tester.tap(find.byKey(const Key('health-record-menu-health-001')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('health-record-confirm-delete')));
    await tester.pumpAndSettle();

    expect(find.text('Nothing recorded yet.'), findsOneWidget);
  });

  testWidgets('form exposes explicit severity, pain, impact, and provenance', (
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

    expect(find.text("what's happening?"), findsOneWidget);

    // Select cramps symptom.
    await tester.tap(find.text('Cramps'));
    await tester.pumpAndSettle();

    // Intensity section appears.
    expect(find.text('intensity'), findsOneWidget);
    // Severity pills show.
    expect(find.text('1'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);

    // Tap extreme severity.
    await tester.tap(find.text('6'));
    await tester.pumpAndSettle();
    expect(find.text('Extreme'), findsOneWidget);

    // Expand 'when?' section.
    await tester.tap(find.text('when?'));
    await tester.pumpAndSettle();
    expect(find.text('Same day'), findsOneWidget);

    // Save button is visible with symptom count.
    expect(find.text('save 1 symptom'), findsOneWidget);
  });
}
