import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/design_system/letter_theme.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/cycle/domain/period_record.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';
import 'package:letter_mobile/features/insights/presentation/spectrum_log_view_model.dart';
import 'package:letter_mobile/features/insights/presentation/hormonal_spectrum_strip.dart';
import 'package:letter_mobile/features/patterns/domain/pattern_source.dart';

void main() {
  test('adapts confirmed records to local d-14..d-1 columns', () {
    final snapshot = PatternSourceSnapshot(
      healthRecords: [
        _record(
          id: 'physical-old',
          symptom: SymptomType.headache,
          date: const LocalDate(2026, 8, 10),
          severity: SymptomSeverity.moderate,
          updatedAt: DateTime.utc(2026, 8, 10, 12),
        ),
        _record(
          id: 'physical-new',
          symptom: SymptomType.headache,
          date: const LocalDate(2026, 8, 10),
          severity: SymptomSeverity.extreme,
          updatedAt: DateTime.utc(2026, 8, 11, 12),
        ),
        _record(
          id: 'mood',
          symptom: SymptomType.irritability,
          date: const LocalDate(2026, 9, 6),
          severity: SymptomSeverity.mild,
          updatedAt: DateTime.utc(2026, 9, 6, 12),
        ),
        _record(
          id: 'unconfirmed',
          symptom: SymptomType.fatigue,
          date: const LocalDate(2026, 9, 7),
          severity: SymptomSeverity.severe,
          userConfirmed: false,
          updatedAt: DateTime.utc(2026, 9, 7, 12),
        ),
      ],
      periods: [
        _period('august', const LocalDate(2026, 8, 20)),
        _period('september', const LocalDate(2026, 9, 20)),
      ],
    );

    final data = SpectrumLogViewModel.fromSource(snapshot).data;

    expect(data.records.map((record) => record.id), ['physical-new', 'mood']);
    expect(data.cyclesCovered, 2);
    expect(data.confirmedCountFor(SymptomKey.all), 2);
    expect(data.confirmedCountFor(SymptomKey.physical), 1);
    expect(data.confirmedCountFor(SymptomKey.mood), 1);
    expect(data.daysFor(SymptomKey.physical)[-10], 5);
    expect(data.daysFor(SymptomKey.mood)[-14], 2);
    expect(data.daysFor(SymptomKey.all)[-9], isNull);
    expect(data.daysFor(SymptomKey.all).keys, containsAll(dayKeys));
    expect(
      symptomLabels.keys,
      containsAll(<SymptomKey>[
        SymptomKey.all,
        SymptomKey.physical,
        SymptomKey.mood,
        SymptomKey.energy,
        SymptomKey.sleep,
      ]),
    );
    expect(symptomLabels.values, isNot(contains('Pain')));
  });

  test('uses daily peaks, cross-cycle median, variation, and cycle trend', () {
    final data = SpectrumLogAdapter.fromSource(
      PatternSourceSnapshot(
        healthRecords: [
          _record(
            id: 'aug-minimal',
            symptom: SymptomType.headache,
            date: const LocalDate(2026, 8, 10),
            severity: SymptomSeverity.minimal,
            updatedAt: DateTime.utc(2026, 8, 10, 8),
          ),
          _record(
            id: 'aug-extreme',
            symptom: SymptomType.cramps,
            date: const LocalDate(2026, 8, 10),
            severity: SymptomSeverity.extreme,
            updatedAt: DateTime.utc(2026, 8, 10, 9),
          ),
          _record(
            id: 'sep-mild',
            symptom: SymptomType.headache,
            date: const LocalDate(2026, 9, 10),
            severity: SymptomSeverity.mild,
            updatedAt: DateTime.utc(2026, 9, 10, 8),
          ),
          _record(
            id: 'oct-severe',
            symptom: SymptomType.headache,
            date: const LocalDate(2026, 10, 10),
            severity: SymptomSeverity.severe,
            updatedAt: DateTime.utc(2026, 10, 10, 8),
          ),
        ],
        periods: [
          _period('august', const LocalDate(2026, 8, 20)),
          _period('september', const LocalDate(2026, 9, 20)),
          _period('october', const LocalDate(2026, 10, 20)),
        ],
      ),
    );

    final day = data.summariesFor(SymptomKey.physical)[-10]!;
    expect(day.typical, 4);
    expect(day.minimum, 2);
    expect(day.maximum, 5);
    expect(day.cycleCount, 3);
    expect(day.hasLimitedEvidence, isFalse);
    expect(data.trendsFor(SymptomKey.physical).map((point) => point.typical), [
      5,
      2,
      4,
    ]);
    expect(
      data.trendsFor(SymptomKey.physical).map((point) => point.ratedDayCount),
      everyElement(1),
    );
  });

  test(
    'keeps boundaries, latest duplicates, typicals, and filter coverage',
    () {
      final snapshot = PatternSourceSnapshot(
        healthRecords: [
          _record(
            id: 'boundary-d14',
            symptom: SymptomType.headache,
            date: const LocalDate(2026, 8, 6),
            severity: SymptomSeverity.mild,
            updatedAt: DateTime.utc(2026, 8, 6, 12),
          ),
          _record(
            id: 'boundary-d1',
            symptom: SymptomType.irritability,
            date: const LocalDate(2026, 8, 19),
            severity: SymptomSeverity.moderate,
            updatedAt: DateTime.utc(2026, 8, 19, 12),
          ),
          _record(
            id: 'outside-d15',
            symptom: SymptomType.fatigue,
            date: const LocalDate(2026, 8, 5),
            severity: SymptomSeverity.extreme,
            updatedAt: DateTime.utc(2026, 8, 5, 12),
          ),
          _record(
            id: 'duplicate-old',
            symptom: SymptomType.headache,
            date: const LocalDate(2026, 9, 6),
            severity: SymptomSeverity.mild,
            updatedAt: DateTime.utc(2026, 9, 6, 10),
          ),
          _record(
            id: 'duplicate-new',
            symptom: SymptomType.headache,
            date: const LocalDate(2026, 9, 6),
            severity: SymptomSeverity.severe,
            updatedAt: DateTime.utc(2026, 9, 6, 12),
          ),
          _record(
            id: 'edited-down-old',
            symptom: SymptomType.headache,
            date: const LocalDate(2026, 9, 8),
            severity: SymptomSeverity.extreme,
            updatedAt: DateTime.utc(2026, 9, 8, 10),
          ),
          _record(
            id: 'edited-down-new',
            symptom: SymptomType.headache,
            date: const LocalDate(2026, 9, 8),
            severity: SymptomSeverity.minimal,
            updatedAt: DateTime.utc(2026, 9, 8, 12),
          ),
          _record(
            id: 'later-cycle-maximum',
            symptom: SymptomType.headache,
            date: const LocalDate(2026, 10, 6),
            severity: SymptomSeverity.extreme,
            updatedAt: DateTime.utc(2026, 10, 6, 12),
          ),
          _record(
            id: 'sleep-one-cycle',
            symptom: SymptomType.sleepiness,
            date: const LocalDate(2026, 9, 19),
            severity: SymptomSeverity.mild,
            updatedAt: DateTime.utc(2026, 9, 19, 12),
          ),
          _record(
            id: 'no-later-anchor',
            symptom: SymptomType.fatigue,
            date: const LocalDate(2026, 10, 21),
            severity: SymptomSeverity.extreme,
            updatedAt: DateTime.utc(2026, 10, 21, 12),
          ),
        ],
        periods: [
          _period('august', const LocalDate(2026, 8, 20)),
          _period('september', const LocalDate(2026, 9, 20)),
          _period('october', const LocalDate(2026, 10, 20)),
        ],
      );

      final data = SpectrumLogAdapter.fromSource(snapshot);
      final ids = data.records.map((record) => record.id).toSet();

      expect(ids, containsAll(['boundary-d14', 'boundary-d1']));
      expect(ids, isNot(contains('outside-d15')));
      expect(ids, isNot(contains('duplicate-old')));
      expect(ids, contains('duplicate-new'));
      expect(ids, isNot(contains('edited-down-old')));
      expect(ids, contains('edited-down-new'));
      expect(ids, isNot(contains('no-later-anchor')));
      expect(data.daysFor(SymptomKey.physical)[-14], 4);
      expect(data.summariesFor(SymptomKey.physical)[-14]!.minimum, 2);
      expect(data.summariesFor(SymptomKey.physical)[-14]!.maximum, 5);
      expect(data.daysFor(SymptomKey.physical)[-12], 1);
      expect(data.daysFor(SymptomKey.all)[-14], 4);
      expect(data.daysFor(SymptomKey.all)[-1], 2.5);
      expect(data.daysFor(SymptomKey.all)[-13], isNull);
      expect(data.cyclesCoveredFor(SymptomKey.all), 3);
      expect(data.cyclesCoveredFor(SymptomKey.physical), 3);
      expect(data.cyclesCoveredFor(SymptomKey.mood), 1);
      expect(data.cyclesCoveredFor(SymptomKey.sleep), 1);
      expect(data.cyclesCoveredFor(SymptomKey.energy), 0);
    },
  );

  testWidgets(
    'Spectrum Log filters and opens source details in a bottom sheet',
    (tester) async {
      final data = SpectrumLogAdapter.fromSource(
        PatternSourceSnapshot(
          healthRecords: [
            _record(
              id: 'sleep',
              symptom: SymptomType.sleepiness,
              date: const LocalDate(2026, 9, 6),
              severity: SymptomSeverity.mild,
              updatedAt: DateTime.utc(2026, 9, 6, 12),
            ),
          ],
          periods: [_period('september', const LocalDate(2026, 9, 20))],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: LetterTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(child: SpectrumLog(data: data)),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Spectrum Log'), findsOneWidget);
      expect(find.text('Physical'), findsOneWidget);
      expect(find.text('Mood'), findsOneWidget);
      expect(find.text('Energy'), findsOneWidget);
      expect(find.text('Sleep'), findsOneWidget);
      expect(find.textContaining('1 confirmed rating'), findsOneWidget);

      await tester.tap(find.text('Sleep'));
      await tester.pump();
      expect(find.textContaining('1 confirmed rating'), findsOneWidget);
      expect(find.text('d-14'), findsOneWidget);
      final day14 = find.byKey(const Key('spectrum-day--14'));
      expect(day14, findsOneWidget);
      expect(tester.getSize(day14).width, greaterThanOrEqualTo(44));
      expect(tester.getSize(day14).height, greaterThanOrEqualTo(44));
      expect(
        tester.getSemantics(day14).label,
        contains('14 days before period'),
      );

      await tester.tap(day14);
      await tester.pumpAndSettle();
      expect(find.text('14 DAYS BEFORE PERIOD'), findsOneWidget);
      expect(find.text('Typical · Mild'), findsOneWidget);
      expect(find.textContaining('Sleepiness · Mild'), findsOneWidget);
      expect(find.textContaining('Same day'), findsOneWidget);

      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('spectrum-day--13')));
      await tester.pumpAndSettle();
      expect(find.text('13 DAYS BEFORE PERIOD'), findsOneWidget);
      expect(find.text('No confirmed rating for this day.'), findsOneWidget);
    },
  );

  testWidgets('Spectrum Log fits 320px at 200 percent text', (tester) async {
    final data = SpectrumLogAdapter.fromSource(
      PatternSourceSnapshot(
        healthRecords: [
          _record(
            id: 'sleep',
            symptom: SymptomType.sleepiness,
            date: const LocalDate(2026, 9, 6),
            severity: SymptomSeverity.mild,
            updatedAt: DateTime.utc(2026, 9, 6, 12),
          ),
        ],
        periods: [_period('september', const LocalDate(2026, 9, 20))],
      ),
    );

    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: LetterTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 900),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: SingleChildScrollView(child: SpectrumLog(data: data)),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    final day14 = find.byKey(const Key('spectrum-day--14'));
    expect(day14, findsOneWidget);
    final verticalScroll = find
        .byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        )
        .first;
    await tester.scrollUntilVisible(day14, 300, scrollable: verticalScroll);
    await tester.tap(day14);
    await tester.pumpAndSettle();
    expect(find.text('14 DAYS BEFORE PERIOD'), findsOneWidget);
    expect(find.textContaining('Sleepiness · Mild'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders a varied three-cycle Spectrum Log at phone size', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    final data = SpectrumLogAdapter.fromSource(
      PatternSourceSnapshot(
        healthRecords: [
          _record(
            id: 'aug-physical',
            symptom: SymptomType.headache,
            date: const LocalDate(2026, 8, 6),
            severity: SymptomSeverity.mild,
            updatedAt: DateTime.utc(2026, 8, 6, 9),
          ),
          _record(
            id: 'aug-mood',
            symptom: SymptomType.irritability,
            date: const LocalDate(2026, 8, 11),
            severity: SymptomSeverity.severe,
            updatedAt: DateTime.utc(2026, 8, 11, 20),
          ),
          _record(
            id: 'aug-energy',
            symptom: SymptomType.fatigue,
            date: const LocalDate(2026, 8, 15),
            severity: SymptomSeverity.moderate,
            updatedAt: DateTime.utc(2026, 8, 15, 16),
          ),
          _record(
            id: 'aug-sleep',
            symptom: SymptomType.sleepiness,
            date: const LocalDate(2026, 8, 19),
            severity: SymptomSeverity.severe,
            updatedAt: DateTime.utc(2026, 8, 19, 22),
          ),
          _record(
            id: 'sep-physical',
            symptom: SymptomType.headache,
            date: const LocalDate(2026, 9, 6),
            severity: SymptomSeverity.extreme,
            updatedAt: DateTime.utc(2026, 9, 6, 8),
          ),
          _record(
            id: 'sep-mood',
            symptom: SymptomType.irritability,
            date: const LocalDate(2026, 9, 10),
            severity: SymptomSeverity.mild,
            updatedAt: DateTime.utc(2026, 9, 10, 18),
          ),
          _record(
            id: 'sep-sleep',
            symptom: SymptomType.sleepiness,
            date: const LocalDate(2026, 9, 14),
            severity: SymptomSeverity.severe,
            updatedAt: DateTime.utc(2026, 9, 14, 23),
          ),
          _record(
            id: 'sep-energy',
            symptom: SymptomType.fatigue,
            date: const LocalDate(2026, 9, 19),
            severity: SymptomSeverity.moderate,
            updatedAt: DateTime.utc(2026, 9, 19, 12),
          ),
          _record(
            id: 'oct-physical',
            symptom: SymptomType.headache,
            date: const LocalDate(2026, 10, 7),
            severity: SymptomSeverity.moderate,
            updatedAt: DateTime.utc(2026, 10, 7, 10),
          ),
          _record(
            id: 'oct-mood',
            symptom: SymptomType.irritability,
            date: const LocalDate(2026, 10, 12),
            severity: SymptomSeverity.severe,
            updatedAt: DateTime.utc(2026, 10, 12, 19),
          ),
          _record(
            id: 'oct-energy',
            symptom: SymptomType.fatigue,
            date: const LocalDate(2026, 10, 17),
            severity: SymptomSeverity.mild,
            updatedAt: DateTime.utc(2026, 10, 17, 15),
          ),
        ],
        periods: [
          _period('august', const LocalDate(2026, 8, 20)),
          _period('september', const LocalDate(2026, 9, 20)),
          _period('october', const LocalDate(2026, 10, 20)),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: LetterTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(child: SpectrumLog(data: data)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('11 confirmed ratings · 3 cycles covered'),
      findsOneWidget,
    );
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('../goldens/spectrum_log_varied_390x844.png'),
    );
  });
}

HealthRecord _record({
  required String id,
  required SymptomType symptom,
  required LocalDate date,
  required SymptomSeverity severity,
  required DateTime updatedAt,
  bool userConfirmed = true,
}) {
  return HealthRecord(
    id: id,
    symptom: symptom,
    severity: severity,
    functionalImpacts: const {},
    experiencedDate: date,
    recordedAt: updatedAt,
    updatedAt: updatedAt,
    provenance: HealthRecordProvenance.sameDay,
    userConfirmed: userConfirmed,
    vocabularyVersion: healthRecordVocabularyVersion,
  );
}

PeriodRecord _period(String id, LocalDate start) {
  final timestamp = DateTime.utc(start.year, start.month, start.day, 8);
  return PeriodRecord(
    id: id,
    startDate: start,
    endDate: start.addDays(4),
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}
