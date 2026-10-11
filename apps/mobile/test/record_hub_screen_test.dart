import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:letter_mobile/experience/theme/experience_foundation.dart';
import 'package:letter_mobile/features/capture/domain/capture_models.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/cycle/data/letter_health_database.dart';
import 'package:letter_mobile/features/health_records/data/in_memory_health_record_repository.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';
import 'package:letter_mobile/features/record_hub/domain/record_session.dart';
import 'package:letter_mobile/features/record_hub/data/drift_record_hub_repository.dart';
import 'package:letter_mobile/features/record_hub/domain/record_hub_facts.dart';
import 'package:letter_mobile/features/record_hub/presentation/record_hub_screen.dart';

final class _FailingNoteStore implements CaptureNoteStore {
  final List<CaptureNote> notes = [];
  @override
  Future<List<CaptureNote>> getAll() async => notes;
  @override
  Future<void> delete(CaptureNote note, {CaptureNote? expectedCurrent}) async {}
  @override
  Future<CaptureNote> save(CaptureNote note) async =>
      throw StateError('Synthetic failure');
  @override
  Future<CaptureNote> update(CaptureNote note) async =>
      throw StateError('Synthetic failure');
  @override
  Future<CaptureNote> restore(
    CaptureNote note, {
    CaptureNote? expectedCurrent,
  }) async => throw StateError('Synthetic failure');
}

void main() {
  testWidgets(
    'targeted symptom entry saves explicit zero and guarded Undo removes it',
    (tester) async {
      final repository = InMemoryHealthRecordRepository(
        clock: () => DateTime(2026, 10, 9),
        idGenerator: () => 'synthetic-symptom',
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ExperienceFoundation.lightTheme(),
          home: RecordHubScreen(
            healthRecordRepository: repository,
            captureNoteStore: InMemoryCaptureNoteStore(),
            initialSymptom: SymptomType.cramps,
            clock: () => DateTime(2026, 10, 9),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('observation-degree-0')));
      await tester.tap(find.byKey(const Key('observation-degree-0')));
      await tester.pumpAndSettle();
      expect((await repository.getAll()).single.symptom, SymptomType.cramps);
      expect(
        (await repository.getAll()).single.severity,
        SymptomSeverity.notPresent,
      );
      await tester.ensureVisible(find.text('Undo'));
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(await repository.getAll(), isEmpty);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('observation-current-degree')))
            .data,
        'Not recorded',
      );
    },
  );
  testWidgets('dated note edit keeps its source ID and original timestamp', (
    tester,
  ) async {
    final notes = InMemoryCaptureNoteStore(clock: () => DateTime(2026, 10, 9));
    notes.notes.add(
      CaptureNote(
        id: 'synthetic-note',
        text: 'Synthetic saved note',
        source: CaptureSource.typed,
        createdAt: DateTime(2026, 10, 7, 10),
        experiencedDate: const LocalDate(2026, 10, 7),
        keepInComfortKit: true,
        provenance: HealthRecordProvenance.sameDay,
        originalProvenance: HealthRecordProvenance.sameDay,
        writeZoneOffsetMinutes: 540,
        writeZoneName: 'JST',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ExperienceFoundation.lightTheme(),
        home: RecordHubScreen(
          healthRecordRepository: InMemoryHealthRecordRepository(),
          captureNoteStore: notes,
          initialDate: const LocalDate(2026, 10, 7),
          clock: () => DateTime(2026, 10, 9),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('record-saved-on-day')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Synthetic saved note'));
    await tester.tap(find.text('Synthetic saved note'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('record-note')),
      'Synthetic changed note',
    );
    await tester.pump();
    await tester.ensureVisible(find.text('Save note changes'));
    await tester.tap(find.text('Save note changes'));
    await tester.pumpAndSettle();
    expect(notes.notes.single.id, 'synthetic-note');
    expect(notes.notes.single.createdAt, DateTime(2026, 10, 7, 10));
    expect(notes.notes.single.experiencedDate, const LocalDate(2026, 10, 7));
    expect(notes.notes.single.text, 'Synthetic changed note');
    expect(notes.notes.single.keepInComfortKit, isTrue);
    expect(notes.notes.single.provenance, HealthRecordProvenance.laterRecall);
    expect(
      notes.notes.single.effectiveOriginalProvenance,
      HealthRecordProvenance.sameDay,
    );
    expect(notes.notes.single.writeZoneOffsetMinutes, 540);
    expect(notes.notes.single.writeZoneName, 'JST');
    await tester.ensureVisible(find.text('Undo'));
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(notes.notes.single.text, 'Synthetic saved note');
    expect(notes.notes.single.id, 'synthetic-note');
    expect(notes.notes.single.keepInComfortKit, isTrue);
    expect(notes.notes.single.provenance, HealthRecordProvenance.sameDay);
    expect(notes.notes.single.writeZoneName, 'JST');
  });
  testWidgets(
    'real context child saves inherited past date and returns to Record',
    (tester) async {
      final database = LetterHealthDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftRecordHubRepository(
        database,
        clock: () => DateTime(2026, 10, 9),
      );
      var changes = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ExperienceFoundation.lightTheme(),
          home: RecordHubScreen(
            healthRecordRepository: InMemoryHealthRecordRepository(),
            captureNoteStore: InMemoryCaptureNoteStore(),
            recordHubRepository: repository,
            initialDate: const LocalDate(2026, 10, 7),
            clock: () => DateTime(2026, 10, 9),
            onChanged: () => changes++,
          ),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('record-workspace-dailyLife')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('record-category-Sleep')),
      );
      await tester.tap(find.byKey(const Key('record-category-Sleep')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('sleep-quality-5')),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.byKey(const Key('sleep-quality-5')));
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('Save sleep'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Save sleep'));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();
      expect(find.byType(RecordHubScreen), findsOneWidget);
      expect(changes, 1);
      final facts = await tester.runAsync(
        () => repository.getDateFacts(const LocalDate(2026, 10, 7)),
      );
      expect(facts!.sleep!.value.quality, SleepQuality.restful);
      expect(find.byKey(const Key('record-date')), findsOneWidget);
    },
  );
  testWidgets(
    'durable dated note save retains captured day across midnight and Undo',
    (tester) async {
      var now = DateTime(2026, 10, 9, 23, 59);
      final notes = InMemoryCaptureNoteStore(clock: () => now);
      var revision = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ExperienceFoundation.lightTheme(),
          home: RecordHubScreen(
            healthRecordRepository: InMemoryHealthRecordRepository(
              clock: () => now,
            ),
            captureNoteStore: notes,
            clock: () => now,
            onChanged: () => revision++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('record-workspace-notes')),
      );
      await tester.tap(find.byKey(const Key('record-workspace-notes')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('record-note')));
      await tester.enterText(
        find.byKey(const Key('record-note')),
        'Synthetic private note',
      );
      await tester.pump();
      now = DateTime(2026, 10, 10, 0, 1);
      await tester.ensureVisible(find.text('Save note'));
      await tester.tap(find.text('Save note'));
      await tester.pumpAndSettle();
      expect(notes.notes.single.experiencedDate, const LocalDate(2026, 10, 9));
      expect(notes.notes.single.createdAt.isAtSameMomentAs(now), isTrue);
      expect(revision, 1);
      await tester.ensureVisible(find.text('Undo'));
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(notes.notes, isEmpty);
      expect(revision, 2);
    },
  );

  testWidgets('failed note save preserves draft and never announces success', (
    tester,
  ) async {
    var revision = 0;
    final notes = _FailingNoteStore();
    await tester.pumpWidget(
      MaterialApp(
        theme: ExperienceFoundation.lightTheme(),
        home: RecordHubScreen(
          healthRecordRepository: InMemoryHealthRecordRepository(),
          captureNoteStore: notes,
          clock: () => DateTime(2026, 10, 9),
          onChanged: () => revision++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('record-workspace-notes')));
    await tester.tap(find.byKey(const Key('record-workspace-notes')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('record-note')));
    await tester.enterText(
      find.byKey(const Key('record-note')),
      'Synthetic unfinished note',
    );
    await tester.pump();
    await tester.ensureVisible(find.text('Save note'));
    await tester.tap(find.text('Save note'));
    await tester.pumpAndSettle();
    expect(notes.notes, isEmpty);
    expect(revision, 0);
    expect(find.textContaining('saved locally'), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('record-note')))
          .controller!
          .text,
      'Synthetic unfinished note',
    );
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Keep your unfinished record?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.byType(RecordHubScreen), findsOneWidget);
  });

  testWidgets(
    'Done guards notes and restores exact retained Cycle origin route',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ExperienceFoundation.lightTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('Synthetic Cycle detail'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => RecordHubScreen(
                      healthRecordRepository: InMemoryHealthRecordRepository(),
                      captureNoteStore: InMemoryCaptureNoteStore(),
                      initialDate: const LocalDate(2026, 9, 28),
                      origin: RecordOrigin.cycle,
                      clock: () => DateTime(2026, 10, 9),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Synthetic Cycle detail'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('record-workspace-notes')),
      );
      await tester.tap(find.byKey(const Key('record-workspace-notes')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('record-note')));
      await tester.enterText(
        find.byKey(const Key('record-note')),
        'Synthetic draft',
      );
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.byType(RecordHubScreen), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard draft'));
      await tester.pumpAndSettle();
      expect(find.byType(RecordHubScreen), findsNothing);
      expect(find.text('Synthetic Cycle detail'), findsOneWidget);
    },
  );
}
