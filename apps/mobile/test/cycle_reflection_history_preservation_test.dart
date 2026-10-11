import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/experience/cycle/cycle_experience.dart';
import 'package:letter_mobile/experience/theme/experience_foundation.dart';
import 'package:letter_mobile/features/care/data/drift_care_memory_repository.dart';
import 'package:letter_mobile/features/care/data/in_memory_care_memory_repository.dart';
import 'package:letter_mobile/features/care/domain/care_memory.dart';
import 'package:letter_mobile/features/care/domain/care_memory_repository.dart';
import 'package:letter_mobile/features/cycle/data/drift_period_repository.dart';
import 'package:letter_mobile/features/cycle/data/in_memory_period_repository.dart';
import 'package:letter_mobile/features/cycle/data/letter_health_database.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/cycle/domain/period_record.dart';
import 'package:letter_mobile/features/cycle/presentation/cycle_reflection_history.dart';
import 'package:letter_mobile/features/health_records/data/in_memory_health_record_repository.dart';

final _savedAt = DateTime.utc(2026, 6, 2);
CycleReflection _source({
  String id = 'original',
  String? periodId,
  int day = 1,
}) => CycleReflection(
  id: id,
  startingPeriodId: periodId,
  cycleStartDay: LocalDate(2026, 6, day).epochDay,
  observation: 'My original words',
  need: ReflectionNeed.autonomy,
  whatHelped: 'A quiet walk',
  futureSelfNote: 'Leave room for rest',
  createdAt: _savedAt,
  updatedAt: _savedAt,
);

PeriodRecord _period(String id, LocalDate start) => PeriodRecord(
  id: id,
  startDate: start,
  endDate: start.addDays(2),
  createdAt: _savedAt,
  updatedAt: _savedAt,
);

Future<void> _showHistory(
  WidgetTester tester,
  CareMemoryRepository repository, {
  List<PeriodRecord> completed = const [],
  VoidCallback? onChanged,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ExperienceFoundation.lightTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: CycleReflectionHistory(
            key: UniqueKey(),
            repository: repository,
            completedPeriods: completed,
            revision: 0,
            onChanged: onChanged ?? () {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _edit(WidgetTester tester, String id) async {
  await tester.tap(find.byKey(ValueKey('saved-cycle-reflection-$id')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('edit-cycle-reflection-$id')));
  await tester.pumpAndSettle();
}

Finder _field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Future<void> _tapEditorAction(WidgetTester tester, String label) async {
  tester.testTextInput.hide();
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text(label).last);
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Cycle uses its history and has no standalone letter entrance', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(402, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: ExperienceFoundation.lightTheme(),
        home: CycleExperience(
          periodRepository: InMemoryPeriodRepository(),
          healthRecordRepository: InMemoryHealthRecordRepository(),
          careMemoryRepository: InMemoryCareMemoryRepository(
            cycleReflections: [_source()],
          ),
          onCycleDataChanged: () {},
          now: DateTime(2026, 7, 15),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cycle-letter-archive')), findsNothing);
    expect(find.text('Cycle letter archive'), findsNothing);
    await tester.scrollUntilVisible(find.text('Saved reflections'), 250);
    expect(
      find.byKey(const ValueKey('saved-cycle-reflection-original')),
      findsOneWidget,
    );
  });

  testWidgets(
    'resolver avoids duplicates and exposes current and unlinked originals',
    (tester) async {
      final completed = _period('completed', const LocalDate(2026, 6, 1));
      final linked = _source(id: 'linked', periodId: completed.id);
      final unlinked = _source(id: 'same-date-original');
      final current = _source(
        id: 'current',
        periodId: 'current-period',
        day: 10,
      );
      await _showHistory(
        tester,
        InMemoryCareMemoryRepository(
          cycleReflections: [linked, unlinked, current],
        ),
        completed: [completed],
      );
      expect(
        find.byKey(const ValueKey('saved-cycle-reflection-linked')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('saved-cycle-reflection-same-date-original')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('saved-cycle-reflection-current')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('saved-cycle-reflection-same-date-original')),
      );
      await tester.pumpAndSettle();
      expect(find.text('What I needed\nAutonomy'), findsOneWidget);
      expect(find.text('What helped\nA quiet walk'), findsOneWidget);
    },
  );

  testWidgets(
    'editing a saved original retains need, source metadata and other words',
    (tester) async {
      final source = _source(periodId: 'removed-period');
      final updatedAt = _savedAt.add(const Duration(days: 1));
      final repository = InMemoryCareMemoryRepository(
        cycleReflections: [source],
        clock: () => updatedAt,
      );
      var changes = 0;
      await _showHistory(tester, repository, onChanged: () => changes++);
      await _edit(tester, source.id);
      await tester.enterText(_field('What was hard'), 'My corrected words');
      await _tapEditorAction(tester, 'Save letter');
      final saved = (await repository.getCycleReflections()).single;
      expect(saved.id, source.id);
      expect(saved.startingPeriodId, source.startingPeriodId);
      expect(saved.cycleStartDay, source.cycleStartDay);
      expect(saved.createdAt, source.createdAt);
      expect(saved.updatedAt, updatedAt);
      expect(saved.need, source.need);
      expect(saved.whatHelped, source.whatHelped);
      expect(saved.futureSelfNote, source.futureSelfNote);
      expect(saved.observation, 'My corrected words');
      expect(changes, 1);
      expect(find.byType(TextField), findsNothing);
    },
  );

  testWidgets(
    'discard guard keeps draft until explicit discard without a write',
    (tester) async {
      final source = _source();
      final repository = InMemoryCareMemoryRepository(
        cycleReflections: [source],
      );
      await _showHistory(tester, repository);
      await _edit(tester, source.id);
      await tester.enterText(_field('What was hard'), 'Unsaved draft');
      await _tapEditorAction(tester, 'Close');
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(_field('What was hard')).controller!.text,
        'Unsaved draft',
      );
      await _tapEditorAction(tester, 'Close');
      await tester.tap(find.text('Discard draft'));
      await tester.pumpAndSettle();
      expect((await repository.getCycleReflections()).single, same(source));
      expect(find.byType(TextField), findsNothing);
    },
  );

  testWidgets('deletion confirms and leaves other saved originals intact', (
    tester,
  ) async {
    final source = _source();
    final other = _source(id: 'other', day: 2);
    final repository = InMemoryCareMemoryRepository(
      cycleReflections: [source, other],
    );
    await _showHistory(tester, repository);
    await _edit(tester, source.id);
    await _tapEditorAction(tester, 'Delete reflection');
    await tester.tap(find.text('Keep reflection'));
    await tester.pumpAndSettle();
    expect(await repository.getCycleReflections(), hasLength(2));
    await _tapEditorAction(tester, 'Delete reflection');
    await tester.tap(find.widgetWithText(TextButton, 'Delete reflection').last);
    await tester.pumpAndSettle();
    expect((await repository.getCycleReflections()).single, same(other));
  });

  testWidgets('a changed source cannot be overwritten from an older draft', (
    tester,
  ) async {
    final source = _source();
    final repository = InMemoryCareMemoryRepository(cycleReflections: [source]);
    await _showHistory(tester, repository);
    await _edit(tester, source.id);
    await tester.enterText(_field('What was hard'), 'My stale draft');
    await repository.saveCycleReflection(
      source.cycleStartDay,
      const CycleReflectionDraft(
        observation: 'New saved original',
        need: ReflectionNeed.connection,
      ),
    );
    await _tapEditorAction(tester, 'Save letter');
    expect(
      find.textContaining('This saved reflection changed.'),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(_field('What was hard')).controller!.text,
      'My stale draft',
    );
    expect(
      (await repository.getCycleReflections()).single.observation,
      'New saved original',
    );
  });

  testWidgets('Cycle read refresh does not discard an open reflection draft', (
    tester,
  ) async {
    final repository = InMemoryCareMemoryRepository(
      cycleReflections: [_source()],
    );
    final revision = ValueNotifier(0);
    addTearDown(revision.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: ExperienceFoundation.lightTheme(),
        home: Scaffold(
          body: ValueListenableBuilder<int>(
            valueListenable: revision,
            builder: (_, value, _) => SingleChildScrollView(
              child: CycleReflectionHistory(
                key: ValueKey(value),
                repository: repository,
                completedPeriods: const [],
                revision: value,
                onChanged: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _edit(tester, 'original');
    await tester.enterText(
      _field('What was hard'),
      'Draft survives a read refresh',
    );
    revision.value++;
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(_field('What was hard')).controller!.text,
      'Draft survives a read refresh',
    );
    await _tapEditorAction(tester, 'Save letter');
    expect(
      (await repository.getCycleReflections()).single.observation,
      'Draft survives a read refresh',
    );
  });

  testWidgets(
    'durable originals stay reachable after date correction, merge and period deletion',
    (tester) async {
      final database = LetterHealthDatabase(NativeDatabase.memory());
      addTearDown(() => database.close());
      var next = 0;
      final periods = DriftPeriodRepository(
        database,
        clock: () => _savedAt,
        idGenerator: () => 'p-${next++}',
        closeDatabase: false,
      );
      final care = DriftCareMemoryRepository(
        database,
        clock: () => _savedAt,
        idGenerator: () => 'r-${next++}',
        closeDatabase: false,
      );
      const today = LocalDate(2026, 7, 15);
      PeriodDraft draft(int start, int end) => PeriodDraft(
        startDate: LocalDate(2026, 6, start),
        endDate: LocalDate(2026, 6, end),
      );
      late PeriodRecord first, later;
      late CycleReflection original, absorbed;
      await tester.runAsync(() async {
        first = await periods.create(draft(1, 3), today: today);
        later = await periods.create(draft(7, 9), today: today);
        original = await care.saveCycleReflection(
          first.startDate.epochDay,
          const CycleReflectionDraft(
            observation: 'First original',
            need: ReflectionNeed.boundaries,
          ),
          startingPeriodId: first.id,
        );
        absorbed = await care.saveCycleReflection(
          later.startDate.epochDay,
          const CycleReflectionDraft(
            observation: 'Later original',
            need: ReflectionNeed.restOrPhysicalCapacity,
          ),
          startingPeriodId: later.id,
        );
        final correction = await periods.previewWrite(
          draft(2, 3),
          editingId: first.id,
          today: today,
        );
        await periods.confirmWrite(correction, today: today);
      });
      Future<void> renderDurableSources(Set<String> visibleIds) async {
        final sources = await tester.runAsync(care.getCycleReflections);
        final remainingPeriods = await tester.runAsync(periods.getAll);
        final snapshot = InMemoryCareMemoryRepository(
          cycleReflections: sources!,
        );
        await _showHistory(tester, snapshot, completed: remainingPeriods!);
        final reachableInDetails = <String>{};
        for (final period in remainingPeriods) {
          final linked = await snapshot.getCycleReflection(
            period.startDate.epochDay,
            startingPeriodId: period.id,
          );
          if (linked != null) reachableInDetails.add(linked.id);
        }
        for (final source in sources) {
          expect(
            visibleIds.contains(source.id) ||
                reachableInDetails.contains(source.id),
            isTrue,
          );
          expect(
            find.byKey(ValueKey('saved-cycle-reflection-${source.id}')),
            visibleIds.contains(source.id) ? findsOneWidget : findsNothing,
          );
          if (visibleIds.contains(source.id)) {
            expect(
              find.text(
                'Original cycle date: ${LocalDate.fromEpochDay(source.cycleStartDay)}',
              ),
              findsOneWidget,
            );
          }
          final before = source.id == original.id ? original : absorbed;
          expect(source.cycleStartDay, before.cycleStartDay);
          expect(source.createdAt, before.createdAt);
          expect(source.updatedAt, before.updatedAt);
          expect(source.observation, before.observation);
          expect(source.need, before.need);
        }
      }

      // Date corrections preserve the reference: the normal detail still
      // opens the original, with its unchanged anchor, so it is not duplicated.
      await renderDurableSources({});
      await tester.runAsync(() async {
        final merge = await periods.previewWrite(draft(4, 6), today: today);
        await periods.confirmWrite(merge, today: today);
      });
      await renderDurableSources({absorbed.id});
      await tester.runAsync(() => periods.delete(first.id));
      await renderDurableSources({original.id, absorbed.id});
      final retained = await tester.runAsync(care.getCycleReflections);
      expect(
        retained!.every((source) => source.startingPeriodId == null),
        isTrue,
      );
    },
  );
}
