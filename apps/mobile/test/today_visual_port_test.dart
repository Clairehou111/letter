import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/experience/today/today_visual_port.dart';
import 'package:letter_mobile/features/capture/domain/capture_models.dart';
import 'package:letter_mobile/features/check_in/data/in_memory_moment_check_in_repository.dart';
import 'package:letter_mobile/features/check_in/domain/moment_check_in.dart';
import 'package:letter_mobile/features/cycle/data/in_memory_period_repository.dart';
import 'package:letter_mobile/features/cycle/domain/bleeding_flow.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/cycle/domain/period_record.dart';
import 'package:letter_mobile/features/health_records/data/in_memory_health_record_repository.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';

void main() {
  const today = LocalDate(2026, 8, 15);
  final timestamp = DateTime(2026, 8, 15, 12);

  RepositoryTodayVisualPort buildPort({
    required InMemoryPeriodRepository periods,
    required InMemoryMomentCheckInRepository moods,
    required InMemoryHealthRecordRepository symptoms,
    void Function()? onChanged,
    Future<String?> Function()? loadRememberedHelpLine,
  }) {
    return RepositoryTodayVisualPort(
      periodRepository: periods,
      checkInRepository: moods,
      healthRecordRepository: symptoms,
      captureNoteStore: InMemoryCaptureNoteStore(),
      today: () => today,
      now: () => timestamp,
      onCycleDataChanged: onChanged ?? () {},
      onOpenCare: () {},
      loadRememberedHelpLine: loadRememberedHelpLine,
    );
  }

  test('Today and Cycle share mood, flow, color, and symptom facts', () async {
    var changes = 0;
    final periods = InMemoryPeriodRepository(
      seed: <PeriodRecord>[
        PeriodRecord(
          id: 'current',
          startDate: const LocalDate(2026, 8, 13),
          endDate: null,
          createdAt: timestamp,
          updatedAt: timestamp,
        ),
      ],
      clock: () => timestamp,
      idGenerator: () => 'period-id',
    );
    final moods = InMemoryMomentCheckInRepository(
      clock: () => timestamp,
      idGenerator: () => 'mood-${changes++}',
    );
    final symptoms = InMemoryHealthRecordRepository(
      clock: () => timestamp,
      idGenerator: () => 'symptom-${changes++}',
    );
    final port = buildPort(
      periods: periods,
      moods: moods,
      symptoms: symptoms,
      onChanged: () => changes += 1,
    );

    await port.saveMood(MomentCheckInState.low);
    await port.saveMood(MomentCheckInState.calm);
    var snapshot = await port.load();
    expect(snapshot.mood, MomentCheckInState.calm);
    expect(await moods.getAll(), hasLength(1));

    await port.setFlow(BleedingFlow.medium);
    await port.setColor(BleedingColor.darkRed);
    snapshot = await port.load();
    expect(snapshot.flowRecord?.flow, BleedingFlow.medium);
    expect(snapshot.flowRecord?.color, BleedingColor.darkRed);

    // Cycle reads these exact rows, not a Today-only aggregate.
    final flowRows = await periods.getAllFlowDays();
    expect(flowRows.single.flow, BleedingFlow.medium);
    expect(flowRows.single.color, BleedingColor.darkRed);

    await port.saveSymptom(SymptomType.cramps, SymptomSeverity.mild);
    await port.saveSymptom(SymptomType.cramps, SymptomSeverity.severe);
    snapshot = await port.load();
    expect(snapshot.symptoms, hasLength(1));
    expect(snapshot.symptoms.single.severity, SymptomSeverity.severe);

    final cycleRecords = await symptoms.getAll();
    expect(cycleRecords, hasLength(1));
    expect(cycleRecords.single.symptom, SymptomType.cramps);
    expect(cycleRecords.single.severity, SymptomSeverity.severe);

    await port.removeSymptom(cycleRecords.single.id);
    expect((await port.load()).symptoms, isEmpty);
    expect(await symptoms.getAll(), isEmpty);
    expect(changes, greaterThan(0));
  });

  test(
    'period transitions and Cycle date edits remain reflected in Today',
    () async {
      final periods = InMemoryPeriodRepository(
        clock: () => timestamp,
        idGenerator: () => 'period-id',
      );
      final moods = InMemoryMomentCheckInRepository(clock: () => timestamp);
      final symptoms = InMemoryHealthRecordRepository(clock: () => timestamp);
      final port = buildPort(
        periods: periods,
        moods: moods,
        symptoms: symptoms,
      );

      expect((await port.load()).canRecordFlow, isFalse);
      await port.startPeriod();
      await port.setFlow(BleedingFlow.light);
      expect((await port.load()).flowRecord?.flow, BleedingFlow.light);

      final period = (await periods.getAll()).single;
      // This is the same date-edit mutation Cycle performs. Flow outside the
      // revised range is removed by the period repository and Today reloads it.
      await periods.update(
        period.id,
        const PeriodDraft(
          startDate: LocalDate(2026, 8, 13),
          endDate: LocalDate(2026, 8, 14),
        ),
        today: today,
      );
      final afterCycleEdit = await port.load();
      expect(afterCycleEdit.flowRecord, isNull);
      expect(afterCycleEdit.canRecordFlow, isFalse);
    },
  );

  test('remembered help is optional context and never blocks Today', () async {
    final periods = InMemoryPeriodRepository(clock: () => timestamp);
    final moods = InMemoryMomentCheckInRepository(clock: () => timestamp);
    final symptoms = InMemoryHealthRecordRepository(clock: () => timestamp);
    final withEvidence = buildPort(
      periods: periods,
      moods: moods,
      symptoms: symptoms,
      loadRememberedHelpLine: () async =>
          'Apply warmth helped twice before — your check-backs say so.',
    );

    expect(
      (await withEvidence.load()).rememberedHelpLine,
      'Apply warmth helped twice before — your check-backs say so.',
    );

    final unavailable = buildPort(
      periods: periods,
      moods: moods,
      symptoms: symptoms,
      loadRememberedHelpLine: () async => throw StateError('unavailable'),
    );
    expect((await unavailable.load()).rememberedHelpLine, isNull);
  });
}
