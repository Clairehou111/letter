import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/experience/degree/degree_graphics.dart';
import 'package:letter_mobile/experience/records/observation_picker.dart';
import 'package:letter_mobile/experience/theme/experience_foundation.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';
import 'package:letter_mobile/features/health_records/data/in_memory_health_record_repository.dart';

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
  test('zero color and ordered scale preserve missing values', () {
    expect(ExperienceSeverityRamp.forScoreOrNull(null), isNull);
    expect(ExperienceSeverityRamp.forScore(0), ExperienceColors.inkSoft);
    expect(
      ExperienceSeverityRamp.forScore(0),
      isNot(ExperienceSeverityRamp.forScore(1)),
    );
    expect(DegreeGraphics.severityDegrees.map((degree) => degree.score), [
      0,
      1,
      2,
      3,
      4,
      5,
    ]);
  });

  testWidgets('zero glyph exposes named observed absence', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DegreeGraphics.severity(SymptomSeverity.notPresent),
        ),
      ),
    );
    expect(find.text('Not present'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(r'^Severity: Not present, 0 of 5')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    handle.dispose();
  });

  testWidgets('focused picker saves zero immediately then withdraws it', (
    tester,
  ) async {
    final drafts = <HealthRecordDraft>[];
    final withdrawals = <SymptomType>[];
    final pending = <bool>[];
    await _pumpPicker(
      tester,
      initialSymptom: SymptomType.cramps,
      onSave: (draft) async => drafts.add(draft),
      onWithdraw: (symptom) async => withdrawals.add(symptom),
      onDraftChanged: pending.add,
    );
    await tester.ensureVisible(find.byKey(const Key('observation-degree-0')));
    await tester.tap(find.byKey(const Key('observation-degree-0')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(drafts, hasLength(1));
    expect(drafts.single.symptom, SymptomType.cramps);
    expect(drafts.single.severity, SymptomSeverity.notPresent);
    expect(drafts.single.experiencedDate, const LocalDate(2026, 7, 15));
    expect(withdrawals, isEmpty);
    expect(pending, [true, false]);
    expect(
      tester
          .widget<InkWell>(
            find.descendant(
              of: find.byKey(const Key('observation-degree-0')),
              matching: find.byType(InkWell),
            ),
          )
          .onTap,
      isNotNull,
    );
    await tester.ensureVisible(find.byKey(const Key('observation-degree-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('observation-degree-0')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(drafts, hasLength(1));
    expect(withdrawals, [SymptomType.cramps]);
  });

  testWidgets('legacy unavailable focus does not create a new draft', (
    tester,
  ) async {
    final pending = <bool>[];
    await _pumpPicker(
      tester,
      initialSymptom: SymptomType.palpitations,
      onDraftChanged: pending.add,
    );
    expect(find.text('Save to record'), findsNothing);
    expect(find.text('Heart palpitations'), findsNothing);
    expect(pending, isEmpty);
  });

  testWidgets('failed immediate save preserves navigation guard', (
    tester,
  ) async {
    final pending = <bool>[];
    await _pumpPicker(
      tester,
      initialSymptom: SymptomType.cramps,
      onSave: (_) async =>
          throw const HealthRecordException(HealthRecordFailure.futureDate),
      onDraftChanged: pending.add,
    );
    await tester.ensureVisible(find.byKey(const Key('observation-degree-0')));
    await tester.tap(find.byKey(const Key('observation-degree-0')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(pending, [true]);
    await tester.ensureVisible(
      find.byKey(const Key('observation-close-symptom')),
    );
    await tester.tap(find.byKey(const Key('observation-close-symptom')));
    await tester.pumpAndSettle();
    expect(pending, [true, false]);
  });
}

Future<void> _pumpPicker(
  WidgetTester tester, {
  required SymptomType initialSymptom,
  Future<void> Function(HealthRecordDraft)? onSave,
  Future<void> Function(SymptomType)? onWithdraw,
  ValueChanged<bool>? onDraftChanged,
}) async {
  final repository = InMemoryHealthRecordRepository(
    clock: () => DateTime(2026, 7, 15, 12),
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ObservationPicker(
            experiencedDate: const LocalDate(2026, 7, 15),
            provenance: HealthRecordProvenance.sameDay,
            initialSymptom: initialSymptom,
            onSave: onSave == null
                ? null
                : (draft) async {
                    await onSave(draft);
                    return repository.create(draft);
                  },
            onDelete: onWithdraw == null
                ? null
                : (record) async {
                    await onWithdraw(record.symptom);
                    await repository.delete(record.id, expectedCurrent: record);
                  },
            onWithdraw: onWithdraw,
            onDraftChanged: onDraftChanged,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
