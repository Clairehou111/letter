import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/experience/components/interaction_controls.dart';
import 'package:letter_mobile/experience/records/observation_picker.dart';
import 'package:letter_mobile/experience/theme/experience_foundation.dart';
import 'package:letter_mobile/features/capture/domain/capture_models.dart';
import 'package:letter_mobile/features/cycle/data/letter_health_database.dart';
import 'package:letter_mobile/features/cycle/data/drift_period_repository.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/health_records/data/in_memory_health_record_repository.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';
import 'package:letter_mobile/features/health_records/domain/health_record_repository.dart';
import 'package:letter_mobile/features/record_hub/data/drift_record_interventions_repository.dart';
import 'package:letter_mobile/features/record_hub/data/drift_record_hub_repository.dart';
import 'package:letter_mobile/features/record_hub/presentation/record_context_editor.dart';
import 'package:letter_mobile/features/record_hub/presentation/record_entry_section.dart';
import 'package:letter_mobile/features/record_hub/presentation/record_hub_screen.dart';

const _date = LocalDate(2026, 10, 9);
DateTime _clock() => DateTime(2026, 10, 9, 12);

Widget _host(Widget child, {bool reduceMotion = false}) => MaterialApp(
  theme: ExperienceFoundation.careTheme(),
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  ),
);

ObservationPicker _picker({
  Future<HealthRecord> Function(HealthRecordDraft)? onSave,
  Future<void> Function(HealthRecord)? onDelete,
  ValueChanged<bool>? onDraftChanged,
}) => ObservationPicker(
  experiencedDate: _date,
  provenance: HealthRecordProvenance.sameDay,
  initialSymptom: SymptomType.cramps,
  onSave: onSave,
  onDelete: onDelete,
  onDraftChanged: onDraftChanged,
  careWorld: true,
);

final class _PendingNoteStore implements CaptureNoteStore {
  final delegate = InMemoryCaptureNoteStore(clock: _clock);
  final pending = Completer<CaptureNote>();
  int saveCalls = 0;
  @override
  Future<List<CaptureNote>> getAll() => delegate.getAll();
  @override
  Future<CaptureNote> save(CaptureNote note) {
    saveCalls++;
    return pending.future;
  }

  @override
  Future<CaptureNote> update(CaptureNote note) => delegate.update(note);
  @override
  Future<void> delete(CaptureNote note, {CaptureNote? expectedCurrent}) =>
      delegate.delete(note, expectedCurrent: expectedCurrent);
  @override
  Future<CaptureNote> restore(
    CaptureNote note, {
    CaptureNote? expectedCurrent,
  }) => delegate.restore(note, expectedCurrent: expectedCurrent);
}

final class _FailOnceNoteStore implements CaptureNoteStore {
  final delegate = InMemoryCaptureNoteStore(clock: _clock);
  int saves = 0;
  @override
  Future<List<CaptureNote>> getAll() => delegate.getAll();
  @override
  Future<CaptureNote> save(CaptureNote note) async {
    if (++saves == 1) throw StateError('Synthetic storage failure');
    return delegate.save(note);
  }

  @override
  Future<CaptureNote> update(CaptureNote note) => delegate.update(note);
  @override
  Future<void> delete(CaptureNote note, {CaptureNote? expectedCurrent}) =>
      delegate.delete(note, expectedCurrent: expectedCurrent);
  @override
  Future<CaptureNote> restore(
    CaptureNote note, {
    CaptureNote? expectedCurrent,
  }) => delegate.restore(note, expectedCurrent: expectedCurrent);
}

Future<void> _workspace(WidgetTester tester, String name) async {
  final tab = find.byKey(Key('record-workspace-$name'));
  await tester.ensureVisible(tab);
  await tester.tap(tab);
  await tester.pumpAndSettle();
}

Finder _tabState(String label) => find.byWidgetPredicate(
  (widget) => widget is Semantics && widget.properties.label == '$label tab',
);

final class _FailOnceRecords implements HealthRecordRepository {
  final delegate = InMemoryHealthRecordRepository(clock: _clock);
  int creates = 0;
  @override
  Future<List<HealthRecord>> getAll() => delegate.getAll();
  @override
  Future<HealthRecord> create(HealthRecordDraft draft) {
    if (++creates == 1) {
      return Future.error(
        const HealthRecordException(HealthRecordFailure.storageUnavailable),
      );
    }
    return delegate.create(draft);
  }

  @override
  Future<HealthRecord> update(String id, HealthRecordDraft draft) =>
      delegate.update(id, draft);
  @override
  Future<void> delete(String id, {HealthRecord? expectedCurrent}) =>
      delegate.delete(id, expectedCurrent: expectedCurrent);
  @override
  Future<HealthRecord> restore(
    HealthRecord record, {
    HealthRecord? expectedCurrent,
  }) => delegate.restore(record, expectedCurrent: expectedCurrent);
  @override
  Future<void> close() => delegate.close();
}

void main() {
  setUp(SavedRhythm.resetSession);

  testWidgets(
    'default shortcuts are deduplicated; named Browse opens one symptom without writes',
    (tester) async {
      var saves = 0;
      await tester.pumpWidget(
        _host(
          ObservationPicker(
            experiencedDate: _date,
            provenance: HealthRecordProvenance.sameDay,
            pinnedSymptoms: const [SymptomType.cramps, SymptomType.anxiety],
            careWorld: true,
            onSave: (draft) async {
              saves++;
              return InMemoryHealthRecordRepository(
                clock: _clock,
              ).create(draft);
            },
          ),
        ),
      );
      expect(find.text('Cramps'), findsOneWidget);
      expect(find.text('Anxiety or worry'), findsOneWidget);
      expect(find.text('Quick picks'), findsNothing);
      expect(find.text('Physical'), findsNothing);
      await tester.tap(find.byKey(const Key('observation-browse-symptoms')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Physical'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Headache'));
      await tester.tap(find.text('Headache'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('observation-degree-0')), findsOneWidget);
      expect(find.text('Headache'), findsOneWidget);
      expect(find.text('Quick picks'), findsNothing);
      expect(saves, 0);
    },
  );

  testWidgets(
    'zero selects immediately; durable acknowledgment and removal wait for callbacks; rapid taps do not queue',
    (tester) async {
      final records = InMemoryHealthRecordRepository(clock: _clock);
      final saved = await records.create(
        HealthRecordDraft(
          symptom: SymptomType.cramps,
          severity: SymptomSeverity.notPresent,
          experiencedDate: _date,
          provenance: HealthRecordProvenance.sameDay,
        ),
      );
      final save = Completer<HealthRecord>();
      final remove = Completer<void>();
      var saveCalls = 0;
      var removeCalls = 0;
      await tester.pumpWidget(
        _host(
          _picker(
            onSave: (draft) {
              saveCalls++;
              return save.future;
            },
            onDelete: (record) {
              removeCalls++;
              return remove.future;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('observation-degree-0')));
      await tester.pump();
      expect(
        tester
            .widget<InteractionSurface>(
              find.byKey(const Key('observation-degree-0')),
            )
            .selected,
        isTrue,
      );
      expect(find.text('Saving…'), findsOneWidget);
      expect(find.text('Saved locally'), findsNothing);
      await tester.tap(find.byKey(const Key('observation-degree-3')));
      await tester.pump();
      expect(saveCalls, 1);
      save.complete(saved);
      await tester.pumpAndSettle();
      expect(find.text('Saved locally'), findsOneWidget);
      expect(
        find.byKey(const Key('observation-current-degree')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('observation-current-degree')))
            .data,
        'Not present',
      );
      await tester.tap(find.byKey(const Key('observation-degree-0')));
      await tester.pump();
      expect(removeCalls, 1);
      expect(find.text('Removed from this record.'), findsNothing);
      await tester.tap(find.byKey(const Key('observation-degree-0')));
      expect(removeCalls, 1);
      remove.complete();
      await tester.pumpAndSettle();
      expect(find.text('Removed from this record.'), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('observation-current-degree')))
            .data,
        'Not recorded',
      );
    },
  );

  testWidgets(
    'failed degree retains editable selection and dirty guard; retry is a real write',
    (tester) async {
      var calls = 0;
      final dirty = <bool>[];
      final records = InMemoryHealthRecordRepository(clock: _clock);
      await tester.pumpWidget(
        _host(
          _picker(
            onDraftChanged: dirty.add,
            onSave: (draft) async {
              if (++calls == 1) {
                throw const HealthRecordException(
                  HealthRecordFailure.storageUnavailable,
                );
              }
              return records.create(draft);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('observation-degree-3')));
      await tester.pumpAndSettle();
      expect(find.text('Saved locally'), findsNothing);
      expect(
        tester
            .widget<InteractionSurface>(
              find.byKey(const Key('observation-degree-3')),
            )
            .selected,
        isTrue,
      );
      expect(dirty.last, isTrue);
      expect(await records.getAll(), isEmpty);
      await tester.tap(find.byKey(const Key('observation-degree-3')));
      await tester.pumpAndSettle();
      expect(
        (await records.getAll()).single.severity,
        SymptomSeverity.moderate,
      );
      expect(dirty.last, isFalse);
      expect(find.text('Saved locally'), findsOneWidget);
    },
  );

  testWidgets(
    'disposal during pending degree callback does not deliver stale UI state',
    (tester) async {
      final pending = Completer<HealthRecord>();
      final records = InMemoryHealthRecordRepository(clock: _clock);
      await tester.pumpWidget(_host(_picker(onSave: (_) => pending.future)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('observation-degree-2')));
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      pending.complete(
        await records.create(
          HealthRecordDraft(
            symptom: SymptomType.cramps,
            severity: SymptomSeverity.mild,
            experiencedDate: _date,
            provenance: HealthRecordProvenance.sameDay,
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'normal phone has six accessible degree targets and Reduce Motion removes scale travel',
    (tester) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(_host(_picker(), reduceMotion: true));
      for (var degree = 0; degree <= 5; degree++) {
        final option = find.byKey(Key('observation-degree-$degree'));
        final size = tester.getSize(option);
        expect(size.width, greaterThanOrEqualTo(44));
        expect(size.height, greaterThanOrEqualTo(44));
        expect(
          tester
              .widget<AnimatedScale>(
                find.descendant(
                  of: option,
                  matching: find.byType(AnimatedScale),
                ),
              )
              .duration,
          Duration.zero,
        );
      }
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets(
    'Note shortcut focuses without writes; pending Save is local and guarded',
    (tester) async {
      final notes = _PendingNoteStore();
      await tester.pumpWidget(
        MaterialApp(
          theme: ExperienceFoundation.careTheme(),
          home: RecordHubScreen(
            healthRecordRepository: InMemoryHealthRecordRepository(
              clock: _clock,
            ),
            captureNoteStore: notes,
            clock: _clock,
            initialSection: RecordEntrySection.note,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(
        find.byKey(const Key('record-note')),
      );
      expect(field.focusNode!.hasFocus, isTrue);
      expect(notes.saveCalls, 0);
      expect(await notes.getAll(), isEmpty);
      await tester.enterText(
        find.byKey(const Key('record-note')),
        'Synthetic pending note',
      );
      await tester.pump();
      await tester.ensureVisible(find.text('Save note'));
      await tester.tap(find.text('Save note'));
      await tester.pump();
      final status = find.byKey(const Key('record-status-Private note'));
      expect(
        find.descendant(of: status, matching: find.text('Saving…')),
        findsOneWidget,
      );
      expect(find.textContaining('saved locally'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('record-note-save')),
          matching: find.text('Saving'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('record-note-save')));
      await tester.pump();
      expect(notes.saveCalls, 1);
      for (final name in ['symptoms', 'dailyLife', 'products', 'notes']) {
        expect(
          tester
              .widget<InkWell>(find.byKey(Key('record-workspace-$name')))
              .onTap,
          isNull,
        );
      }
      expect(
        tester.widget<Semantics>(_tabState('Notes')).properties.selected,
        isTrue,
      );
      final note = await notes.delegate.save(
        CaptureNote(
          id: 'synthetic-pending-note',
          text: 'Synthetic pending note',
          source: CaptureSource.typed,
          createdAt: _clock(),
          experiencedDate: _date,
        ),
      );
      notes.pending.complete(note);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const Key('record-note-save')),
          matching: find.text('Saved'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: status,
          matching: find.textContaining('saved locally'),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('record-note')))
            .controller!
            .text,
        isEmpty,
      );
    },
  );

  testWidgets(
    'Sleep shortcut opens existing dated editor once; cancel leaves sources unwritten',
    (tester) async {
      final db = LetterHealthDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final facts = DriftRecordHubRepository(db, clock: _clock);
      await tester.pumpWidget(
        MaterialApp(
          theme: ExperienceFoundation.careTheme(),
          home: RecordHubScreen(
            healthRecordRepository: InMemoryHealthRecordRepository(
              clock: _clock,
            ),
            captureNoteStore: InMemoryCaptureNoteStore(clock: _clock),
            recordHubRepository: facts,
            initialDate: const LocalDate(2026, 10, 7),
            clock: _clock,
            initialSection: RecordEntrySection.sleep,
          ),
        ),
      );
      for (
        var attempt = 0;
        attempt < 20 && find.byType(RecordContextEditor).evaluate().isEmpty;
        attempt++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pumpAndSettle();
      }
      final editor = tester.widget<RecordContextEditor>(
        find.byType(RecordContextEditor),
      );
      expect(editor.type, RecordContextType.sleep);
      expect(editor.date, const LocalDate(2026, 10, 7));
      expect((await tester.runAsync(() => facts.getAllFacts()))!, isEmpty);
      await tester.tap(find.byTooltip('Close editor'));
      await tester.pumpAndSettle();
      expect(find.byType(RecordContextEditor), findsNothing);
      expect(find.byType(RecordHubScreen), findsOneWidget);
      expect((await tester.runAsync(() => facts.getAllFacts()))!, isEmpty);
    },
  );
  testWidgets(
    'compact flow keeps None distinct from missing and never creates a period',
    (tester) async {
      final db = LetterHealthDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final facts = DriftRecordHubRepository(db, clock: _clock);
      final periods = DriftPeriodRepository(
        db,
        clock: _clock,
        closeDatabase: false,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ExperienceFoundation.careTheme(),
          home: RecordHubScreen(
            healthRecordRepository: InMemoryHealthRecordRepository(
              clock: _clock,
            ),
            captureNoteStore: InMemoryCaptureNoteStore(clock: _clock),
            recordHubRepository: facts,
            periodRepository: periods,
            clock: _clock,
          ),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();
      final section = find.byKey(const Key('record-section-Bleeding'));
      await tester.ensureVisible(section);
      await tester.tap(section);
      await tester.pumpAndSettle();
      final none = find.byKey(const Key('record-flow-none'));
      expect(tester.widget<InteractionSurface>(none).selected, isFalse);
      expect(tester.getSize(none).height, lessThan(100));
      await tester.ensureVisible(none);
      await tester.tap(none);
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();
      final recorded = await tester.runAsync(() => facts.getDateFacts(_date));
      expect(recorded!.bleeding!.value.noBleeding, isTrue);
      expect(tester.widget<InteractionSurface>(none).selected, isTrue);
      expect((await tester.runAsync(periods.getAll))!, isEmpty);
      await tester.tap(none);
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();
      expect(
        (await tester.runAsync(() => facts.getDateFacts(_date)))!.bleeding,
        isNull,
      );
      expect(tester.widget<InteractionSurface>(none).selected, isFalse);
      expect((await tester.runAsync(periods.getAll))!, isEmpty);
    },
  );

  testWidgets(
    'withdrawal Undo refreshes the focused picker to the exact restored record',
    (tester) async {
      final records = InMemoryHealthRecordRepository(clock: _clock);
      await tester.pumpWidget(
        MaterialApp(
          theme: ExperienceFoundation.careTheme(),
          home: RecordHubScreen(
            healthRecordRepository: records,
            captureNoteStore: InMemoryCaptureNoteStore(clock: _clock),
            initialSymptom: SymptomType.cramps,
            clock: _clock,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final degree = find.byKey(const Key('observation-degree-3'));
      await tester.ensureVisible(degree);
      await tester.tap(degree);
      await tester.pumpAndSettle();
      final source = (await records.getAll()).single;
      await tester.tap(degree);
      await tester.pumpAndSettle();
      expect(await records.getAll(), isEmpty);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('observation-current-degree')))
            .data,
        'Not recorded',
      );
      await tester.ensureVisible(find.text('Undo'));
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect((await records.getAll()).single.id, source.id);
      expect((await records.getAll()).single.severity, source.severity);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('observation-current-degree')))
            .data,
        'Moderate',
      );
      expect(tester.widget<InteractionSurface>(degree).selected, isTrue);
    },
  );
  testWidgets(
    'non-destructive workspace changes retain note draft and hidden draft guards date and Done',
    (tester) async {
      final notes = InMemoryCaptureNoteStore(clock: _clock);
      await tester.pumpWidget(
        MaterialApp(
          theme: ExperienceFoundation.careTheme(),
          home: RecordHubScreen(
            healthRecordRepository: InMemoryHealthRecordRepository(
              clock: _clock,
            ),
            captureNoteStore: notes,
            initialSection: RecordEntrySection.note,
            clock: _clock,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final input = find.byKey(const Key('record-note'));
      await tester.enterText(input, 'Synthetic retained note');
      await tester.pump();
      await _workspace(tester, 'symptoms');
      expect(find.text('Keep your unfinished record?'), findsNothing);
      expect(input, findsNothing);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Keep your unfinished record?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Semantics>(_tabState('Symptoms')).properties.selected,
        isTrue,
      );
      await tester.tap(find.byKey(const Key('record-date')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('record-calendar-day-2026-10-07')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      await _workspace(tester, 'notes');
      expect(
        tester.widget<TextField>(input).controller!.text,
        'Synthetic retained note',
      );
      expect(await notes.getAll(), isEmpty);
      expect(
        find.bySemanticsLabel(
          RegExp(
            'Choose record date, Friday, October 9, 2026, Recording today',
          ),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'failed symptom draft and exact picker state survive modal close guard; retry saves once',
    (tester) async {
      final records = _FailOnceRecords();
      await tester.pumpWidget(
        MaterialApp(
          theme: ExperienceFoundation.careTheme(),
          home: RecordHubScreen(
            healthRecordRepository: records,
            captureNoteStore: InMemoryCaptureNoteStore(clock: _clock),
            initialSymptom: SymptomType.cramps,
            clock: _clock,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final degree = find.byKey(const Key('observation-degree-3'));
      await tester.ensureVisible(degree);
      await tester.tap(degree);
      await tester.pumpAndSettle();
      final state = tester.state(
        find.byType(ObservationPicker, skipOffstage: false),
      );
      expect(await records.getAll(), isEmpty);
      await tester.tap(find.byKey(const Key('observation-editor-close')));
      await tester.pumpAndSettle();
      expect(find.text('Keep your unfinished observation?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(
        tester.state(find.byType(ObservationPicker, skipOffstage: false)),
        same(state),
      );
      expect(tester.widget<InteractionSurface>(degree).selected, isTrue);
      expect(find.text('Saved locally'), findsNothing);
      await tester.ensureVisible(degree);
      await tester.tap(degree);
      await tester.pumpAndSettle();
      expect(records.creates, 2);
      expect(
        (await records.getAll()).single.severity,
        SymptomSeverity.moderate,
      );
      await tester.tap(find.byKey(const Key('observation-editor-close')));
      await tester.pumpAndSettle();
      await _workspace(tester, 'notes');
      await _workspace(tester, 'symptoms');
      expect(tester.state(find.byType(ObservationPicker)), same(state));
    },
  );

  testWidgets(
    'four workspace rail keeps all named categories reachable and day log edits the exact loaded note',
    (tester) async {
      final db = LetterHealthDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final facts = DriftRecordHubRepository(db, clock: _clock);
      final products = DriftRecordInterventionsRepository(db, clock: _clock);
      final notes = InMemoryCaptureNoteStore(clock: _clock);
      final source = await notes.save(
        CaptureNote(
          id: 'synthetic-workspace-note',
          text: 'Synthetic existing words',
          source: CaptureSource.typed,
          createdAt: _clock(),
          experiencedDate: _date,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ExperienceFoundation.careTheme(),
          home: RecordHubScreen(
            healthRecordRepository: InMemoryHealthRecordRepository(
              clock: _clock,
            ),
            captureNoteStore: notes,
            recordHubRepository: facts,
            interventionsRepository: products,
            clock: _clock,
          ),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();
      expect(
        tester.widget<Semantics>(_tabState('Symptoms')).properties.selected,
        isTrue,
      );
      expect(find.byKey(const Key('record-category-Sleep')), findsNothing);
      await _workspace(tester, 'dailyLife');
      for (final label in [
        'Sleep',
        'Activity/rest',
        'Appetite/cravings',
        'Significant event',
        'Basal body temperature',
      ]) {
        final entry = find.byKey(Key('record-category-$label'));
        await tester.ensureVisible(entry);
        expect(entry.hitTestable(), findsOneWidget);
      }
      await _workspace(tester, 'products');
      for (final label in [
        'What I tried',
        'Medication',
        'Supplement',
        'Birth control',
      ]) {
        final entry = find.byKey(Key('record-category-$label'));
        await tester.ensureVisible(entry);
        expect(entry.hitTestable(), findsOneWidget);
      }
      await tester.tap(find.byKey(const Key('record-saved-on-day')));
      await tester.pumpAndSettle();
      final saved = find.byKey(Key('record-log-note-${source.id}'));
      expect(saved, findsOneWidget);
      await tester.tap(saved);
      await tester.pumpAndSettle();
      expect(
        tester.widget<Semantics>(_tabState('Notes')).properties.selected,
        isTrue,
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('record-note')))
            .controller!
            .text,
        source.text,
      );
      expect(notes.notes.single.id, source.id);
      expect(notes.notes.single.createdAt, source.createdAt);
      expect((await tester.runAsync(facts.getAllFacts))!, isEmpty);
    },
  );
  testWidgets(
    'symptom focus starts at tapped label, reveals one editor and closes without writes',
    (tester) async {
      var saves = 0;
      await tester.pumpWidget(
        _host(
          ObservationPicker(
            experiencedDate: _date,
            provenance: HealthRecordProvenance.sameDay,
            pinnedSymptoms: const [SymptomType.anxiety, SymptomType.cramps],
            onSave: (draft) async {
              saves++;
              return InMemoryHealthRecordRepository(
                clock: _clock,
              ).create(draft);
            },
            careWorld: true,
          ),
        ),
      );
      final state = tester.state(find.byType(ObservationPicker));
      final origin = tester.getTopLeft(find.text('Cramps'));
      await tester.tap(find.byKey(const Key('observation-symptom-cramps')));
      await tester.pump();
      final travelling = find.byKey(const Key('observation-origin-title'));
      expect(tester.getTopLeft(travelling).dx, closeTo(origin.dx, .1));
      expect(tester.getTopLeft(travelling).dy, closeTo(origin.dy, .1));
      expect(find.byKey(const Key('observation-degree-3')), findsOneWidget);
      expect(
        tester
            .widget<Opacity>(find.byKey(const Key('observation-focus-reveal')))
            .opacity,
        0,
      );
      await tester.pump(const Duration(milliseconds: 140));
      expect(tester.getTopLeft(travelling), isNot(origin));
      final reveal = tester
          .widget<Opacity>(find.byKey(const Key('observation-focus-reveal')))
          .opacity;
      expect(reveal, greaterThan(0));
      expect(reveal, lessThan(1));
      expect(tester.state(find.byType(ObservationPicker)), same(state));
      await tester.pumpAndSettle();
      expect(travelling, findsNothing);
      expect(
        find.byKey(const Key('observation-browse-symptoms')),
        findsNothing,
      );
      expect(find.text('Change symptom'), findsOneWidget);
      await tester.tap(find.byKey(const Key('observation-close-symptom')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 140));
      expect(travelling, findsOneWidget);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('observation-browse-symptoms')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('observation-degree-3')), findsNothing);
      expect(tester.state(find.byType(ObservationPicker)), same(state));
      expect(saves, 0);
    },
  );

  testWidgets(
    'reduced motion focuses a deep symptom immediately with full degree labels',
    (tester) async {
      await tester.pumpWidget(_host(_picker(), reduceMotion: true));
      await tester.pump();
      expect(find.byKey(const Key('observation-origin-title')), findsNothing);
      expect(
        tester
            .widget<Opacity>(find.byKey(const Key('observation-focus-reveal')))
            .opacity,
        1,
      );
      expect(find.text('Not recorded'), findsOneWidget);
      await tester.tap(find.byKey(const Key('observation-close-symptom')));
      await tester.pump();
      expect(find.byKey(const Key('observation-degree-0')), findsNothing);
      expect(
        find.byKey(const Key('observation-browse-symptoms')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'enabling Reduce Motion during symptom expansion finishes without replacing picker state',
    (tester) async {
      await tester.pumpWidget(_host(_picker()));
      await tester.pump(const Duration(milliseconds: 100));
      final state = tester.state(find.byType(ObservationPicker));
      expect(find.byKey(const Key('observation-origin-title')), findsOneWidget);
      await tester.pumpWidget(_host(_picker(), reduceMotion: true));
      await tester.pump();
      expect(tester.state(find.byType(ObservationPicker)), same(state));
      expect(find.byKey(const Key('observation-origin-title')), findsNothing);
      expect(
        tester
            .widget<Opacity>(find.byKey(const Key('observation-focus-reveal')))
            .opacity,
        1,
      );
      await tester.tap(find.byKey(const Key('observation-close-symptom')));
      await tester.pump();
      expect(
        find.byKey(const Key('observation-browse-symptoms')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'same note action retries a failed write, acknowledges durability and resets for new draft',
    (tester) async {
      final notes = _FailOnceNoteStore();
      await tester.pumpWidget(
        MaterialApp(
          theme: ExperienceFoundation.careTheme(),
          home: RecordHubScreen(
            healthRecordRepository: InMemoryHealthRecordRepository(
              clock: _clock,
            ),
            captureNoteStore: notes,
            initialSection: RecordEntrySection.note,
            clock: _clock,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final input = find.byKey(const Key('record-note'));
      final action = find.byKey(const Key('record-note-save'));
      await tester.enterText(input, 'Synthetic retry note');
      await tester.pump();
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: action, matching: find.text('Try again')),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(input).controller!.text,
        'Synthetic retry note',
      );
      expect(await notes.getAll(), isEmpty);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: action, matching: find.text('Saved')),
        findsOneWidget,
      );
      expect(notes.saves, 2);
      expect((await notes.getAll()).single.text, 'Synthetic retry note');
      expect(
        find.descendant(
          of: find.byKey(const Key('record-status-Private note')),
          matching: find.text('Undo'),
        ),
        findsOneWidget,
      );
      await tester.enterText(input, 'A new unsaved thought');
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: action, matching: find.text('Save note')),
        findsOneWidget,
      );
      expect(find.text('Saved'), findsNothing);
      expect(notes.saves, 2);
    },
  );
}
