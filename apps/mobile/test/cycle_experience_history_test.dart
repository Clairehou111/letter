import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/experience/cycle/cycle_experience.dart';
import 'package:letter_mobile/experience/records/observation_picker.dart';
import 'package:letter_mobile/features/care/data/in_memory_care_memory_repository.dart';
import 'package:letter_mobile/features/cycle/data/in_memory_period_repository.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/cycle/domain/period_record.dart';
import 'package:letter_mobile/features/health_records/data/in_memory_health_record_repository.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';
import 'package:letter_mobile/features/today/today_cycle_ring_model.dart';

PeriodRecord _period(String id, int month, int day) {
  final start = LocalDate(2026, month, day);
  return PeriodRecord(
    id: id,
    startDate: start,
    endDate: start.addDays(4),
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
}

void main() {
  testWidgets('Cycle derives today from the local date of a UTC instant', (
    tester,
  ) async {
    final instant = DateTime.utc(2026, 9, 21, 16, 30);
    final localToday = LocalDate.fromDateTime(instant.toLocal());
    final current = PeriodRecord(
      id: 'local-day-period',
      startDate: localToday,
      endDate: null,
      createdAt: instant,
      updatedAt: instant,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CycleExperience(
          periodRepository: InMemoryPeriodRepository(seed: [current]),
          healthRecordRepository: InMemoryHealthRecordRepository(),
          careMemoryRepository: InMemoryCareMemoryRepository(),
          onCycleDataChanged: () {},
          now: instant,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Current cycle'), findsOneWidget);
  });

  testWidgets('current cycle card opens daily flow and symptom entry', (
    tester,
  ) async {
    const today = LocalDate(2026, 7, 15);
    final current = PeriodRecord(
      id: 'open',
      startDate: today,
      endDate: null,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    final healthRecords = InMemoryHealthRecordRepository(
      seed: <HealthRecord>[
        HealthRecord(
          id: 'back-pain',
          symptom: SymptomType.backPain,
          severity: SymptomSeverity.minimal,
          functionalImpacts: const <FunctionalImpact>{},
          experiencedDate: today,
          recordedAt: DateTime.utc(2026, 7, 15, 12),
          updatedAt: DateTime.utc(2026, 7, 15, 12),
          provenance: HealthRecordProvenance.sameDay,
          userConfirmed: true,
          vocabularyVersion: healthRecordVocabularyVersion,
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CycleExperience(
          periodRepository: InMemoryPeriodRepository(seed: [current]),
          healthRecordRepository: healthRecords,
          careMemoryRepository: InMemoryCareMemoryRepository(),
          onCycleDataChanged: () {},
          now: DateTime(2026, 7, 15, 12),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Current cycle'));
    await tester.pumpAndSettle();

    expect(find.text('Current cycle'), findsWidgets);
    await tester.tap(find.text('Fill in days'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Fill in 7/15/2026 – ongoing'), findsOneWidget);
    await tester.tap(find.text('7/15/2026').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Pain & observations'), findsOneWidget);
    expect(find.text('What this day affected'), findsNothing);
  });

  testWidgets('an observation is shown once with its impact action', (
    tester,
  ) async {
    const today = LocalDate(2026, 7, 15);
    final record = HealthRecord(
      id: 'back-pain',
      symptom: SymptomType.backPain,
      severity: SymptomSeverity.minimal,
      functionalImpacts: const <FunctionalImpact>{},
      experiencedDate: today,
      recordedAt: DateTime.utc(2026, 7, 15, 12),
      updatedAt: DateTime.utc(2026, 7, 15, 12),
      provenance: HealthRecordProvenance.sameDay,
      userConfirmed: true,
      vocabularyVersion: healthRecordVocabularyVersion,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ObservationPicker(
              experiencedDate: today,
              provenance: HealthRecordProvenance.sameDay,
              existingRecords: <HealthRecord>[record],
              onEditImpacts: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('On record for this day'), findsOneWidget);
    expect(find.text('Daily impact not marked'), findsOneWidget);
    expect(find.byTooltip('Edit daily impact for Back pain'), findsOneWidget);
    expect(find.text('What this day affected'), findsNothing);
  });

  testWidgets('current cycle retains the next period-start entry', (
    tester,
  ) async {
    final current = PeriodRecord(
      id: 'current',
      startDate: const LocalDate(2026, 6, 16),
      endDate: const LocalDate(2026, 6, 20),
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CycleExperience(
          periodRepository: InMemoryPeriodRepository(seed: [current]),
          healthRecordRepository: InMemoryHealthRecordRepository(),
          careMemoryRepository: InMemoryCareMemoryRepository(),
          onCycleDataChanged: () {},
          now: DateTime(2026, 7, 15, 12),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Record a new period start'), findsOneWidget);
  });

  testWidgets('Cycle reloads a Today period end when its revision changes', (
    tester,
  ) async {
    const today = LocalDate(2026, 7, 15);
    final current = PeriodRecord(
      id: 'open',
      startDate: today,
      endDate: null,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    final periods = InMemoryPeriodRepository(seed: [current]);
    Widget build(int revision) => MaterialApp(
      home: CycleExperience(
        key: const ValueKey<String>('cycle'),
        periodRepository: periods,
        healthRecordRepository: InMemoryHealthRecordRepository(),
        careMemoryRepository: InMemoryCareMemoryRepository(),
        onCycleDataChanged: () {},
        revision: revision,
        now: DateTime(2026, 7, 15, 12),
      ),
    );

    await tester.pumpWidget(build(0));
    await tester.pumpAndSettle();
    expect(find.text('Current cycle'), findsOneWidget);

    await periods.update(
      current.id,
      const PeriodDraft(startDate: today, endDate: today),
      today: today,
    );
    await tester.pumpWidget(build(1));
    await tester.pumpAndSettle();

    expect(find.text('Current cycle'), findsOneWidget);
    expect(find.textContaining('Bleeding ended today'), findsOneWidget);
  });

  testWidgets(
    'same-day closed period remains the current cycle with full editing',
    (tester) async {
      const today = LocalDate(2026, 7, 15);
      final current = PeriodRecord(
        id: 'same-day',
        startDate: today,
        endDate: today,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CycleExperience(
            periodRepository: InMemoryPeriodRepository(seed: [current]),
            healthRecordRepository: InMemoryHealthRecordRepository(),
            careMemoryRepository: InMemoryCareMemoryRepository(),
            onCycleDataChanged: () {},
            now: DateTime(2026, 7, 15, 12),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Current cycle'), findsWidgets);
      expect(find.text('View all 1 periods'), findsNothing);
      await tester.tap(find.text('Current cycle'));
      await tester.pumpAndSettle();

      expect(find.text('Current cycle'), findsWidgets);
      expect(find.text('Edit dates'), findsWidgets);
      expect(find.text('Delete period'), findsOneWidget);
    },
  );

  testWidgets(
    'deleting an open period keeps the preceding closed period in Recent cycles',
    (tester) async {
      const today = LocalDate(2026, 7, 15);
      final previous = PeriodRecord(
        id: 'previous',
        startDate: const LocalDate(2026, 6, 16),
        endDate: const LocalDate(2026, 6, 20),
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      final active = PeriodRecord(
        id: 'active',
        startDate: today,
        endDate: null,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CycleExperience(
            periodRepository: InMemoryPeriodRepository(
              seed: [previous, active],
            ),
            healthRecordRepository: InMemoryHealthRecordRepository(),
            careMemoryRepository: InMemoryCareMemoryRepository(),
            onCycleDataChanged: () {},
            now: DateTime(2026, 7, 15, 12),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Current cycle'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete period'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this period?'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Current cycle'), findsOneWidget);
      expect(find.textContaining('6/16/2026'), findsOneWidget);
      expect(find.text('View all 1 periods'), findsNothing);
    },
  );

  testWidgets('Cycle keeps older periods accessible beyond the compact list', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final records = <PeriodRecord>[
      _period('jan', 1, 4),
      _period('feb', 2, 1),
      _period('mar', 3, 1),
      _period('mar-2', 3, 29),
      _period('apr', 4, 26),
      _period('may', 5, 24),
      _period('jun', 6, 21),
    ];
    const today = LocalDate(2026, 7, 15);
    await tester.pumpWidget(
      MaterialApp(
        home: CycleExperience(
          periodRepository: InMemoryPeriodRepository(seed: records),
          healthRecordRepository: InMemoryHealthRecordRepository(),
          careMemoryRepository: InMemoryCareMemoryRepository(),
          onCycleDataChanged: () {},
          ringModel: TodayCycleRingModel.fromRecords(
            records: records,
            today: today,
          ),
          now: DateTime(2026, 7, 15, 12),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final newestRecent = find.textContaining('6/21/2026');
    final olderRecent = find.textContaining('5/24/2026');
    expect(
      tester.getTopLeft(newestRecent.first).dy,
      lessThan(tester.getTopLeft(olderRecent.first).dy),
    );

    final allPeriods = find.text('View all 7 periods');
    expect(allPeriods, findsOneWidget);
    await tester.tap(allPeriods);
    await tester.pumpAndSettle();

    expect(find.text('All periods'), findsOneWidget);
    final newestAll = find.textContaining('6/21/2026', skipOffstage: false);
    final oldestAll = find.textContaining('1/4/2026', skipOffstage: false);
    expect(newestAll, findsWidgets);
    expect(oldestAll, findsWidgets);
    expect(
      tester.getTopLeft(newestAll.last).dy,
      lessThan(tester.getTopLeft(oldestAll.last).dy),
    );
  });

  testWidgets('limited prediction confidence is stated once', (tester) async {
    await tester.binding.setSurfaceSize(const Size(622, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final records = <PeriodRecord>[
      _period('june-1', 6, 1),
      _period('june-29', 6, 29),
    ];
    const today = LocalDate(2026, 7, 10);
    final ring = TodayCycleRingModel.fromRecords(
      records: records,
      today: today,
    );
    expect(ring.hasLimitedEstimate, isTrue);

    await tester.pumpWidget(
      MaterialApp(
        home: CycleExperience(
          periodRepository: InMemoryPeriodRepository(seed: records),
          healthRecordRepository: InMemoryHealthRecordRepository(),
          careMemoryRepository: InMemoryCareMemoryRepository(),
          onCycleDataChanged: () {},
          ringModel: ring,
          now: DateTime(2026, 7, 10, 12),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(' · limited history'), findsOneWidget);
    expect(find.textContaining('rough estimate'), findsNothing);
    expect(find.text(' est.'), findsNothing);
  });
}
