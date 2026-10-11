import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/experience/cycle/cycle_experience.dart';
import 'package:letter_mobile/experience/theme/experience_foundation.dart';
import 'package:letter_mobile/features/care/data/in_memory_care_memory_repository.dart';
import 'package:letter_mobile/features/cycle/data/in_memory_period_repository.dart';
import 'package:letter_mobile/features/cycle/domain/bleeding_flow.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/cycle/domain/period_record.dart';
import 'package:letter_mobile/features/cycle/presentation/period_range_editor.dart';
import 'package:letter_mobile/features/health_records/data/in_memory_health_record_repository.dart';

const _today = LocalDate(2026, 10, 10);
final _now = DateTime(2026, 10, 10, 12);

Future<void> _pump(
  WidgetTester tester,
  List<PeriodRangeSelection> changes, {
  LocalDate? start,
  LocalDate? end,
  bool ongoing = false,
  bool reduce = false,
  double scale = 1,
}) async {
  tester.view.physicalSize = const Size(402, 874);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: ExperienceFoundation.lightTheme(),
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(402, 874),
          textScaler: TextScaler.linear(scale),
          disableAnimations: reduce,
        ),
        child: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: PeriodRangeEditor(
              today: _today,
              initialStartDate: start,
              initialEndDate: end,
              initialOngoing: ongoing,
              onChanged: changes.add,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapDay(WidgetTester tester, LocalDate day) async {
  final finder = find.byKey(Key('period-range-day-$day'));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _openCycleEditor(
  WidgetTester tester,
  InMemoryPeriodRepository repository, {
  VoidCallback? changed,
}) async {
  tester.view.physicalSize = const Size(402, 874);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: ExperienceFoundation.lightTheme(),
      home: CycleExperience(
        periodRepository: repository,
        healthRecordRepository: InMemoryHealthRecordRepository(),
        careMemoryRepository: InMemoryCareMemoryRepository(),
        now: _now,
        onCycleDataChanged: changed ?? () {},
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Current cycle').last);
  await tester.tap(find.text('Current cycle').last);
  await tester.pumpAndSettle();
  final edit = find.widgetWithText(OutlinedButton, 'Edit dates').last;
  await tester.ensureVisible(edit);
  await tester.tap(edit);
  await tester.pumpAndSettle();
  expect(find.byType(PeriodRangeEditor), findsOneWidget);
  expect(find.byType(DatePickerDialog), findsNothing);
}

PeriodRecord _period({bool ongoing = false}) => PeriodRecord(
  id: 'period-source',
  startDate: const LocalDate(2026, 10, 4),
  endDate: ongoing ? null : const LocalDate(2026, 10, 6),
  createdAt: DateTime.utc(2026, 10, 4),
  updatedAt: DateTime.utc(2026, 10, 6),
);

void main() {
  testWidgets('first tap chooses Start and second tap permits a same-day End', (
    tester,
  ) async {
    final changes = <PeriodRangeSelection>[];
    await _pump(tester, changes);
    await _tapDay(tester, const LocalDate(2026, 10, 8));
    expect(changes.single.startDate, const LocalDate(2026, 10, 8));
    expect(changes.single.endDate, isNull);
    expect(changes.single.isComplete, isFalse);
    await _tapDay(tester, const LocalDate(2026, 10, 8));
    expect(changes.last.endDate, changes.last.startDate);
    expect(changes.last.isComplete, isTrue);
    expect(changes.last.ongoing, isFalse);
    final semantics = tester.ensureSemantics();
    expect(find.bySemanticsLabel(RegExp('Start and End')), findsOneWidget);
    semantics.dispose();
  });

  testWidgets(
    'range continues across weeks and months with only true boundaries rounded',
    (tester) async {
      final changes = <PeriodRangeSelection>[];
      await _pump(tester, changes);
      await tester.tap(find.byKey(const Key('period-range-previous-month')));
      await tester.pumpAndSettle();
      await _tapDay(tester, const LocalDate(2026, 9, 29));
      await tester.tap(find.byKey(const Key('period-range-next-month')));
      await tester.pumpAndSettle();
      await _tapDay(tester, const LocalDate(2026, 10, 3));
      expect(changes.last.startDate, const LocalDate(2026, 9, 29));
      expect(changes.last.endDate, const LocalDate(2026, 10, 3));
      for (var day = 1; day <= 3; day++) {
        expect(
          find.byKey(Key('period-range-band-2026-10-0$day')),
          findsOneWidget,
        );
      }
      final continuation =
          tester
                  .widget<Container>(
                    find.byKey(const Key('period-range-band-2026-10-01')),
                  )
                  .decoration!
              as BoxDecoration;
      expect(continuation.borderRadius, const BorderRadius.horizontal());
      final endpoint =
          tester
                  .widget<Container>(
                    find.byKey(const Key('period-range-band-2026-10-03')),
                  )
                  .decoration!
              as BoxDecoration;
      expect(
        endpoint.borderRadius,
        const BorderRadius.horizontal(right: Radius.circular(17)),
      );
      await tester.tap(find.byKey(const Key('period-range-previous-month')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('period-range-band-2026-09-30')),
        findsOneWidget,
      );
      expect(changes.last.endDate, const LocalDate(2026, 10, 3));
    },
  );

  testWidgets(
    'direct endpoint editing preserves the other endpoint and rejects reversed edits',
    (tester) async {
      final changes = <PeriodRangeSelection>[];
      await _pump(
        tester,
        changes,
        start: const LocalDate(2026, 10, 2),
        end: const LocalDate(2026, 10, 6),
      );
      await tester.tap(find.byKey(const Key('period-range-start')));
      await tester.pumpAndSettle();
      await _tapDay(tester, const LocalDate(2026, 10, 3));
      expect(changes.last.startDate, const LocalDate(2026, 10, 3));
      expect(changes.last.endDate, const LocalDate(2026, 10, 6));
      await tester.tap(find.byKey(const Key('period-range-end')));
      await tester.pumpAndSettle();
      final count = changes.length;
      await _tapDay(tester, const LocalDate(2026, 10, 1));
      expect(changes, hasLength(count));
      expect(
        find.textContaining('End must be on or after Start'),
        findsOneWidget,
      );
      await _tapDay(tester, const LocalDate(2026, 10, 7));
      expect(changes.last.startDate, const LocalDate(2026, 10, 3));
      expect(changes.last.endDate, const LocalDate(2026, 10, 7));
      await tester.tap(find.byKey(const Key('period-range-start')));
      await tester.pumpAndSettle();
      await _tapDay(tester, const LocalDate(2026, 10, 8));
      expect(changes.last.startDate, const LocalDate(2026, 10, 3));
      expect(changes.last.endDate, const LocalDate(2026, 10, 7));
      expect(
        find.textContaining('Start must be on or before End'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'ongoing selection leaves End null and explicit End turns ongoing off',
    (tester) async {
      final changes = <PeriodRangeSelection>[];
      await _pump(tester, changes);
      await _tapDay(tester, const LocalDate(2026, 10, 4));
      await tester.tap(find.byKey(const Key('period-range-ongoing')));
      await tester.pumpAndSettle();
      expect(changes.last.ongoing, isTrue);
      expect(changes.last.endDate, isNull);
      expect(changes.last.isComplete, isTrue);
      final extension =
          tester
                  .widget<Container>(
                    find.byKey(const Key('period-range-band-2026-10-10')),
                  )
                  .decoration!
              as BoxDecoration;
      expect(extension.borderRadius, const BorderRadius.horizontal());
      await tester.tap(find.byKey(const Key('period-range-end')));
      await tester.pumpAndSettle();
      expect(changes.last.ongoing, isFalse);
      expect(changes.last.isComplete, isFalse);
      await _tapDay(tester, const LocalDate(2026, 10, 9));
      expect(changes.last.endDate, const LocalDate(2026, 10, 9));
      expect(changes.last.isComplete, isTrue);
    },
  );

  testWidgets(
    'future dates cannot be selected; day controls are at least 44 points',
    (tester) async {
      final changes = <PeriodRangeSelection>[];
      await _pump(tester, changes);
      final future = find.byKey(const Key('period-range-day-2026-10-11'));
      await tester.ensureVisible(future);
      await tester.tap(future);
      await tester.pumpAndSettle();
      expect(changes, isEmpty);
      final enabled = find.byKey(const Key('period-range-day-2026-10-10'));
      final size = tester.getSize(enabled);
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
      final semantics = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.byKey(const Key('period-range-start'))),
        matchesSemantics(
          label: 'Start, Choose date',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );

      expect(
        tester.getSemantics(future),
        matchesSemantics(
          label: 'Sunday, October 11, 2026, Future date',
          isButton: true,
          hasEnabledState: true,
          hasSelectedState: true,
          isEnabled: false,
          isSelected: false,
        ),
      );
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const Key('period-range-next-month')),
            )
            .onPressed,
        isNull,
      );
      semantics.dispose();
    },
  );

  testWidgets(
    'large text stays reachable and Reduce Motion removes transitions',
    (tester) async {
      final changes = <PeriodRangeSelection>[];
      await _pump(tester, changes, scale: 2, reduce: true);
      expect(
        tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher)).duration,
        Duration.zero,
      );
      await tester.ensureVisible(
        find.byKey(const Key('period-range-previous-month')),
      );
      await tester.tap(find.byKey(const Key('period-range-previous-month')));
      await tester.pumpAndSettle();
      expect(find.text('September 2026'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale).first).duration,
        Duration.zero,
      );
    },
  );

  testWidgets(
    'canceling the integrated period sheet writes no period or daily flow',
    (tester) async {
      final period = _period();
      final repository = InMemoryPeriodRepository(
        seed: [period],
        clock: () => _now,
      );
      await repository.setFlow(
        period.id,
        const LocalDate(2026, 10, 5),
        BleedingFlow.light,
        today: _today,
      );
      final originalFlow = (await repository.getAllFlowDays()).single;
      var changes = 0;
      await _openCycleEditor(tester, repository, changed: () => changes++);
      await _tapDay(tester, const LocalDate(2026, 10, 8));
      await _tapDay(tester, const LocalDate(2026, 10, 9));
      await tester.ensureVisible(find.text('Cancel').last);
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      final saved = (await repository.getAll()).single;
      expect(saved.id, period.id);
      expect(saved.startDate, period.startDate);
      expect(saved.endDate, period.endDate);
      expect(saved.createdAt, period.createdAt);
      expect(saved.updatedAt, period.updatedAt);
      expect(
        (await repository.getAllFlowDays()).single.updatedAt,
        originalFlow.updatedAt,
      );
      expect(
        (await repository.getAllFlowDays()).single.flow,
        BleedingFlow.light,
      );
      expect(changes, 0);
    },
  );

  testWidgets(
    'existing ongoing period saves through the original boundary without daily-flow imputation',
    (tester) async {
      final period = _period(ongoing: true);
      final repository = InMemoryPeriodRepository(
        seed: [period],
        clock: () => _now,
      );
      var changes = 0;
      await _openCycleEditor(tester, repository, changed: () => changes++);
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const Key('period-range-ongoing')),
            )
            .value,
        isTrue,
      );
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Save'));
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      final saved = (await repository.getAll()).single;
      expect(saved.id, period.id);
      expect(saved.startDate, period.startDate);
      expect(saved.endDate, isNull);
      expect(await repository.getAllFlowDays(), isEmpty);
      expect(changes, 1);
    },
  );
}
