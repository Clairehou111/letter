import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/experience/records/observation_picker.dart';
import 'package:letter_mobile/experience/theme/experience_foundation.dart';
import 'package:letter_mobile/features/capture/domain/capture_models.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/health_records/data/in_memory_health_record_repository.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';
import 'package:letter_mobile/features/health_records/domain/health_record_repository.dart';
import 'package:letter_mobile/features/record_hub/presentation/record_hub_screen.dart';

const _date = LocalDate(2026, 10, 9);
DateTime _clock() => DateTime(2026, 10, 9, 12);
Finder _degree(int value) => find.byKey(Key('observation-degree-$value'));
final _page = find.byKey(const Key('observation-fullscreen-editor'));
final _close = find.byKey(const Key('observation-editor-close'));

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Widget _record(
  HealthRecordRepository repository, {
  bool directReturn = false,
  SymptomType symptom = SymptomType.cramps,
}) => RecordHubScreen(
  healthRecordRepository: repository,
  captureNoteStore: InMemoryCaptureNoteStore(clock: _clock),
  initialSymptom: symptom,
  initialDate: _date,
  returnAfterSymptomEdit: directReturn,
  clock: _clock,
);

final class _FailOnceRepository implements HealthRecordRepository {
  final delegate = InMemoryHealthRecordRepository(clock: _clock);
  int attempts = 0;
  @override
  Future<HealthRecord> create(HealthRecordDraft draft) {
    if (++attempts == 1) {
      throw const HealthRecordException(HealthRecordFailure.storageUnavailable);
    }
    return delegate.create(draft);
  }

  @override
  Future<List<HealthRecord>> getAll() => delegate.getAll();
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

final class _PendingRestoreRepository implements HealthRecordRepository {
  final delegate = InMemoryHealthRecordRepository(clock: _clock);
  final restoreGate = Completer<void>();
  int restores = 0;
  @override
  Future<HealthRecord> create(HealthRecordDraft draft) =>
      delegate.create(draft);
  @override
  Future<List<HealthRecord>> getAll() => delegate.getAll();
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
  }) async {
    restores++;
    await restoreGate.future;
    return delegate.restore(record, expectedCurrent: expectedCurrent);
  }

  @override
  Future<void> close() => delegate.close();
}

void main() {
  testWidgets(
    'pending parent Undo locks modal close and degree writes until exact restore completes',
    (tester) async {
      final repository = _PendingRestoreRepository();
      await tester.pumpWidget(
        MaterialApp(
          theme: ExperienceFoundation.careTheme(),
          home: _record(repository),
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, _degree(2));
      final source = (await repository.getAll()).single;
      await _tap(tester, find.byKey(const Key('observation-editor-remove')));
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(repository.restores, 1);
      expect(tester.widget<IconButton>(_close).onPressed, isNull);
      await tester.tap(_degree(4));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(_page, findsOneWidget);
      expect(await repository.getAll(), isEmpty);
      repository.restoreGate.complete();
      await tester.pumpAndSettle();
      final restored = (await repository.getAll()).single;
      expect(restored.id, source.id);
      expect(restored.updatedAt, source.updatedAt);
      expect(restored.severity, source.severity);
      expect(tester.widget<IconButton>(_close).onPressed, isNotNull);
      await _tap(tester, _close);
      expect(_page, findsNothing);
    },
  );

  testWidgets('discarding failed draft closes only editor and writes nothing', (
    tester,
  ) async {
    final repository = _FailOnceRepository();
    await tester.pumpWidget(MaterialApp(home: _record(repository)));
    await tester.pumpAndSettle();
    await _tap(tester, _degree(3));
    await _tap(tester, _close);
    await _tap(tester, find.text('Discard change'));
    expect(_page, findsNothing);
    expect(find.byType(RecordHubScreen), findsOneWidget);
    expect(await repository.getAll(), isEmpty);
    expect(repository.attempts, 1);
  });
  testWidgets(
    'full page retains exact source through degrees, remove and guarded Undo',
    (tester) async {
      final repository = InMemoryHealthRecordRepository(
        clock: _clock,
        idGenerator: () => 'synthetic-source',
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ExperienceFoundation.careTheme(),
          home: _record(repository),
        ),
      );
      await tester.pumpAndSettle();
      expect(_page, findsOneWidget);
      expect(find.byKey(const Key('observation-editor-date')), findsOneWidget);
      final owner = tester.state(
        find.byType(ObservationPicker, skipOffstage: false),
      );
      await _tap(tester, _degree(0));
      final first = (await repository.getAll()).single;
      expect(first.severity, SymptomSeverity.notPresent);
      await _tap(tester, _degree(5));
      final revised = (await repository.getAll()).single;
      expect(revised.id, first.id);
      expect(revised.recordedAt, first.recordedAt);
      expect(revised.severity, SymptomSeverity.extreme);
      await _tap(tester, _degree(5));
      expect(await repository.getAll(), isEmpty);
      await _tap(tester, find.text('Undo'));
      final restored = (await repository.getAll()).single;
      expect(restored.id, revised.id);
      expect(restored.updatedAt, revised.updatedAt);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('observation-current-degree')))
            .data,
        SymptomSeverity.extreme.label,
      );
      expect(
        tester.state(find.byType(ObservationPicker, skipOffstage: false)),
        same(owner),
      );
      await _tap(tester, _close);
      expect(_page, findsNothing);
      expect(find.byType(RecordHubScreen), findsOneWidget);
    },
  );

  testWidgets(
    'failed immediate save retains draft on guarded close and retries once',
    (tester) async {
      final repository = _FailOnceRepository();
      await tester.pumpWidget(
        MaterialApp(
          theme: ExperienceFoundation.careTheme(),
          home: _record(repository),
        ),
      );
      await tester.pumpAndSettle();
      final owner = tester.state(
        find.byType(ObservationPicker, skipOffstage: false),
      );
      await _tap(tester, _degree(3));
      expect(await repository.getAll(), isEmpty);
      expect(find.text('Saved locally'), findsNothing);
      await _tap(tester, _close);
      expect(find.text('Keep your unfinished observation?'), findsOneWidget);
      await _tap(tester, find.text('Keep editing'));
      expect(
        tester.state(find.byType(ObservationPicker, skipOffstage: false)),
        same(owner),
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('observation-current-degree')))
            .data,
        SymptomSeverity.moderate.label,
      );
      await _tap(tester, _degree(3));
      expect(repository.attempts, 2);
      expect(
        (await repository.getAll()).single.severity,
        SymptomSeverity.moderate,
      );
      await _tap(tester, _close);
      expect(find.text('Keep your unfinished observation?'), findsNothing);
    },
  );

  testWidgets(
    'retired medical source stays readable without enabling new entry or writes',
    (tester) async {
      var calls = 0;
      final record = HealthRecord(
        id: 'synthetic-medical-history',
        symptom: SymptomType.palpitations,
        severity: SymptomSeverity.mild,
        experiencedDate: _date,
        provenance: HealthRecordProvenance.sameDay,
        recordedAt: _clock(),
        updatedAt: _clock(),
        functionalImpacts: const {},
        userConfirmed: true,
        vocabularyVersion: healthRecordVocabularyVersion,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ExperienceFoundation.careTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ObservationPicker(
                experiencedDate: _date,
                provenance: HealthRecordProvenance.sameDay,
                fullScreenEditor: true,
                initialSymptom: SymptomType.palpitations,
                existingRecords: [record],
                onSave: (draft) async {
                  calls++;
                  return record;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_page, findsNothing);
      expect(find.text(SymptomType.palpitations.label), findsOneWidget);
      expect(find.textContaining('no longer offered'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'palpitations');
      await tester.pumpAndSettle();
      expect(_degree(2), findsNothing);
      expect(calls, 0);
    },
  );

  testWidgets(
    'pending save disables close and duplicate taps without abandoning committed source',
    (tester) async {
      final repository = InMemoryHealthRecordRepository(clock: _clock);
      final pending = Completer<HealthRecord>();
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ObservationPicker(
              experiencedDate: _date,
              provenance: HealthRecordProvenance.sameDay,
              fullScreenEditor: true,
              initialSymptom: SymptomType.cramps,
              onSave: (draft) {
                calls++;
                return pending.future;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(_degree(1));
      await tester.pump();
      expect(tester.widget<IconButton>(_close).onPressed, isNull);
      await tester.tap(_degree(2));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(_page, findsOneWidget);
      expect(calls, 1);
      final saved = await repository.create(
        const HealthRecordDraft(
          symptom: SymptomType.cramps,
          severity: SymptomSeverity.minimal,
          experiencedDate: _date,
          provenance: HealthRecordProvenance.sameDay,
        ),
      );
      pending.complete(saved);
      await tester.pumpAndSettle();
      await _tap(tester, _close);
      expect((await repository.getAll()).single.id, saved.id);
    },
  );

  testWidgets(
    'impact editor uses saved source and refuses an external source revision',
    (tester) async {
      var now = _clock();
      final repository = InMemoryHealthRecordRepository(clock: () => now);
      await tester.pumpWidget(
        MaterialApp(
          theme: ExperienceFoundation.careTheme(),
          home: _record(repository),
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, _degree(2));
      final source = (await repository.getAll()).single;
      await _tap(tester, find.byKey(const Key('observation-editor-impact')));
      await _tap(tester, find.text('Work or school'));
      await _tap(tester, find.text('Save impact'));
      final impacted = (await repository.getAll()).single;
      expect(impacted.id, source.id);
      expect(impacted.severity, source.severity);
      expect(impacted.functionalImpacts, {FunctionalImpact.workOrSchool});
      await _tap(tester, find.byKey(const Key('observation-editor-impact')));
      now = now.add(const Duration(minutes: 1));
      final external = await repository.update(
        source.id,
        const HealthRecordDraft(
          symptom: SymptomType.cramps,
          severity: SymptomSeverity.severe,
          experiencedDate: _date,
          provenance: HealthRecordProvenance.sameDay,
          functionalImpacts: {FunctionalImpact.sleep},
        ),
      );
      await _tap(tester, find.text('Save impact'));
      final retained = (await repository.getAll()).single;
      expect(retained.updatedAt, external.updatedAt);
      expect(retained.severity, external.severity);
      expect(retained.functionalImpacts, external.functionalImpacts);
      expect(_page, findsOneWidget);
    },
  );

  testWidgets(
    'ordinary full-page dismissal preserves parent catalog scroll and search',
    (tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: ExperienceFoundation.careTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              controller: scroll,
              child: Column(
                children: [
                  const SizedBox(height: 600),
                  ObservationPicker(
                    experiencedDate: _date,
                    provenance: HealthRecordProvenance.sameDay,
                    fullScreenEditor: true,
                  ),
                  const SizedBox(height: 800),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'worry');
      await tester.pumpAndSettle();
      final choice = find.text(SymptomType.anxiety.label).last;
      await tester.ensureVisible(choice);
      await tester.pumpAndSettle();
      final position = scroll.offset;
      await tester.tap(choice);
      await tester.pumpAndSettle();
      expect(_page, findsOneWidget);
      await _tap(tester, _close);
      expect(scroll.offset, position);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'worry',
      );
    },
  );

  testWidgets(
    'explicit Today shortcut returns directly to retained origin after close',
    (tester) async {
      final repository = InMemoryHealthRecordRepository(clock: _clock);
      await tester.pumpWidget(
        MaterialApp(
          theme: ExperienceFoundation.careTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _record(repository, directReturn: true),
                  ),
                ),
                child: const Text('Synthetic Today origin'),
              ),
            ),
          ),
        ),
      );
      await _tap(tester, find.text('Synthetic Today origin'));
      expect(_page, findsOneWidget);
      await _tap(tester, _degree(0));
      await _tap(tester, _close);
      expect(find.byType(RecordHubScreen), findsNothing);
      expect(find.text('Synthetic Today origin'), findsOneWidget);
      expect((await repository.getAll()).single.experiencedDate, _date);
    },
  );

  testWidgets(
    'full-page safe area and reduced motion remain readable at 320 and 2x',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: ExperienceFoundation.careTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: true,
              textScaler: const TextScaler.linear(2),
              padding: const EdgeInsets.only(top: 24, bottom: 20),
            ),
            child: child!,
          ),
          home: _record(
            InMemoryHealthRecordRepository(clock: _clock),
            symptom: SymptomType.anhedonia,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        ModalRoute.of(tester.element(_page))!.transitionDuration,
        Duration.zero,
      );
      expect(find.text(SymptomType.anhedonia.label), findsOneWidget);
      expect(
        tester.widget<Text>(find.text(SymptomType.anhedonia.label)).maxLines,
        isNull,
      );
      expect(tester.getSize(_close).width, greaterThanOrEqualTo(44));
      for (var degree = 0; degree <= 5; degree++) {
        await tester.ensureVisible(_degree(degree));
        expect(
          tester.getSize(_degree(degree)).height,
          greaterThanOrEqualTo(44),
        );
      }
      expect(tester.takeException(), isNull);
      await _tap(tester, _close);
      expect(_page, findsNothing);
    },
  );
}
