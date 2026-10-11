import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/experience/theme/experience_foundation.dart';
import 'package:letter_mobile/features/cycle/data/in_memory_period_repository.dart';
import 'package:letter_mobile/features/cycle/data/letter_health_database.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/health_records/data/in_memory_health_record_repository.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';
import 'package:letter_mobile/features/record_hub/data/drift_record_hub_repository.dart';
import 'package:letter_mobile/features/record_hub/data/drift_record_programme_repository.dart';
import 'package:letter_mobile/features/record_hub/presentation/record_programme_screen.dart';

Future<void> _databaseSettles(WidgetTester tester) async {
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
  });
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'enrollment chooses existing IDs without generating ratings; entry links preserve date and symptom',
    (tester) async {
      final database = LetterHealthDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final now = DateTime(2026, 10, 9);
      final programme = DriftRecordProgrammeRepository(
        database,
        clock: () => now,
      );
      final symptoms = InMemoryHealthRecordRepository(clock: () => now);
      LocalDate? openedDate;
      SymptomType? openedSymptom;
      await tester.pumpWidget(
        MaterialApp(
          theme: ExperienceFoundation.lightTheme(),
          home: RecordProgrammeScreen(
            programmeRepository: programme,
            healthRecordRepository: symptoms,
            recordHubRepository: DriftRecordHubRepository(
              database,
              clock: () => now,
            ),
            periodRepository: InMemoryPeriodRepository(clock: () => now),
            clock: () => now,
            onOpenRecord: (date, symptom) async {
              openedDate = date;
              openedSymptom = symptom;
            },
          ),
        ),
      );
      await _databaseSettles(tester);
      await tester.tap(find.text('Choose fields'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Save fields'),
            )
            .onPressed,
        isNull,
      );
      final cramps = find.widgetWithText(CheckboxListTile, 'Cramps');
      await tester.scrollUntilVisible(
        cramps,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(cramps);
      await tester.pump();
      await tester.tap(find.text('Save fields'));
      await _databaseSettles(tester);
      final current = await tester.runAsync(programme.getCurrent);
      expect(current!.configurations.single.symptoms, [SymptomType.cramps]);
      expect(await symptoms.getAll(), isEmpty);
      expect(
        await tester.runAsync(
          () => database.select(database.recordHubImpactRows).get(),
        ),
        isEmpty,
      );
      await tester.ensureVisible(find.widgetWithText(ActionChip, 'Cramps'));
      await tester.tap(find.widgetWithText(ActionChip, 'Cramps'));
      await _databaseSettles(tester);
      expect(openedDate, const LocalDate(2026, 10, 9));
      expect(openedSymptom, SymptomType.cramps);
    },
  );

  testWidgets(
    'clock rollback blocks enrollment and keeps selected fields and leave guard',
    (tester) async {
      final database = LetterHealthDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      var now = DateTime(2026, 10, 9);
      final programme = DriftRecordProgrammeRepository(
        database,
        clock: () => now,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ExperienceFoundation.lightTheme(),
          home: RecordProgrammeScreen(
            programmeRepository: programme,
            healthRecordRepository: InMemoryHealthRecordRepository(),
            recordHubRepository: DriftRecordHubRepository(
              database,
              clock: () => now,
            ),
            periodRepository: InMemoryPeriodRepository(),
            clock: () => now,
          ),
        ),
      );
      await _databaseSettles(tester);
      await tester.tap(find.text('Choose fields'));
      await tester.pumpAndSettle();
      final cramps = find.widgetWithText(CheckboxListTile, 'Cramps');
      await tester.scrollUntilVisible(
        cramps,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(cramps);
      await tester.pump();
      now = DateTime(2026, 10, 8, 23);
      await tester.tap(find.text('Save fields'));
      await tester.pumpAndSettle();
      expect(find.text('Choose today or an earlier date.'), findsOneWidget);
      expect(tester.widget<CheckboxListTile>(cramps).value, isTrue);
      expect(await tester.runAsync(programme.getAll), isEmpty);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Leave without saving?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('Save fields'), findsOneWidget);
    },
  );
}
