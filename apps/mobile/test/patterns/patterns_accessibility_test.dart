import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/design_system/letter_theme.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';
import 'package:letter_mobile/features/patterns/domain/patterns_experience_data.dart';
import 'package:letter_mobile/features/patterns/presentation/patterns_experience_screen.dart';

void main() {
  testWidgets(
    'trend chart scales canvas labels with bounded accessibility geometry',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      expect(
        TrendLineChart.resolvedLabelTextScale(const TextScaler.linear(3)),
        1.6,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: LetterTheme.light,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 700),
              textScaler: TextScaler.linear(3),
              disableAnimations: true,
            ),
            child: Scaffold(
              body: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: 300,
                  child: TrendLineChart(
                    values: const [28, 31, 25, 42, 29, 33],
                    xLabels: const [
                      'Jan 1',
                      'Jan 29',
                      'Mar 1',
                      'Mar 26',
                      'May 7',
                      'Jun 5',
                    ],
                    valueLabels: const [
                      '28d',
                      '31d',
                      '25d',
                      '42d',
                      '29d',
                      '33d',
                    ],
                    minY: 23,
                    maxY: 44,
                    grid: const [25, 34, 42],
                    semantics: 'Six completed cycle lengths',
                    pointKeys: const [
                      Key('point-1'),
                      Key('point-2'),
                      Key('point-3'),
                      Key('point-4'),
                      Key('point-5'),
                      Key('point-6'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        tester.getSize(find.byKey(const Key('patterns-trend-chart'))).height,
        greaterThan(220),
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Six completed cycle lengths',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('rhythm panel adapts without overflow at 320px large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: LetterTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 900),
            textScaler: TextScaler.linear(2.5),
            disableAnimations: true,
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: RhythmPanel(data: _patternsData(), onEdit: null),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final label in ['Everything', 'Cramps', 'Headache']) {
      final target = find
          .ancestor(of: find.text(label), matching: find.byType(InkWell))
          .first;
      expect(
        tester.getSize(target).height,
        greaterThanOrEqualTo(48),
        reason: '$label must meet Android 48dp and iOS 44pt guidance.',
      );
    }
    expect(find.text('Average bleeding length'), findsOneWidget);
    expect(find.text('Mid-cycle'), findsOneWidget);
    expect(find.text('Days before bleeding'), findsOneWidget);
    expect(
      find.byKey(const Key('patterns-rhythm-band-labels-stacked')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'normal-width rhythm filters wrap compactly instead of stacking',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: LetterTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: RhythmPanel(data: _patternsData(), onEdit: null),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final everything = tester.getRect(find.text('Everything'));
      final cramps = tester.getRect(find.text('Cramps'));
      expect((everything.center.dy - cramps.center.dy).abs(), lessThan(2));
      expect(cramps.left, greaterThan(everything.right));
    },
  );

  testWidgets('cycle flow days use their own full-width row', (tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: LetterTheme.light,
        home: PatternsExperienceScreen(data: _patternsData()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('patterns-tab-cycles')));
    await tester.pumpAndSettle();

    final firstStrip = find.byKey(const Key('patterns-flow-strip-first'));
    await tester.scrollUntilVisible(firstStrip, 500);
    final metadata = find.byKey(const Key('patterns-flow-metadata-first'));
    final firstDay = find.byKey(
      ValueKey(
        'patterns-flow-day-first-${const LocalDate(2026, 1, 1).epochDay}',
      ),
    );
    expect(
      tester.getTopLeft(firstDay).dy,
      greaterThan(tester.getBottomLeft(metadata).dy),
    );
    expect(tester.takeException(), isNull);
  });
}

PatternsExperienceData _patternsData() {
  const firstStart = LocalDate(2026, 1, 1);
  const secondStart = LocalDate(2026, 1, 29);
  const currentStart = LocalDate(2026, 2, 26);
  return const PatternsExperienceData(
    completedCycles: [
      PatternsCompletedCycle(
        periodId: 'first',
        startDate: firstStart,
        nextStartDate: secondStart,
        bleedingEndDate: LocalDate(2026, 1, 5),
        flowDays: [],
      ),
      PatternsCompletedCycle(
        periodId: 'second',
        startDate: secondStart,
        nextStartDate: currentStart,
        bleedingEndDate: LocalDate(2026, 2, 2),
        flowDays: [],
      ),
    ],
    currentCycle: PatternsCurrentCycle(
      periodId: 'current',
      startDate: currentStart,
      bleedingEndDate: LocalDate(2026, 3, 2),
      flowDays: [],
    ),
    symptoms: [
      PatternsSymptomRecord(
        id: 'cramps',
        date: LocalDate(2026, 1, 20),
        category: PatternsSymptomCategory.pain,
        label: 'Cramps',
        severity: SymptomSeverity.severe,
      ),
      PatternsSymptomRecord(
        id: 'headache',
        date: LocalDate(2026, 2, 20),
        category: PatternsSymptomCategory.pain,
        label: 'Headache',
        severity: SymptomSeverity.moderate,
      ),
    ],
    moods: [],
    care: [],
    today: LocalDate(2026, 3, 15),
  );
}
