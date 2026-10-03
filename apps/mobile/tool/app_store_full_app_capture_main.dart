// Synthetic records in the complete LetterApp for native App Store capture.
// This entrypoint is never used by the release target. Navigate through the
// production shell and controls; do not mount feature pages directly.
import 'package:flutter/material.dart';
import 'package:letter_mobile/app/letter_app.dart';
import 'package:letter_mobile/features/capture/domain/capture_models.dart';
import 'package:letter_mobile/features/care/data/in_memory_care_memory_repository.dart';
import 'package:letter_mobile/features/care/domain/care_memory.dart';
import 'package:letter_mobile/features/care/domain/care_mode.dart';
import 'package:letter_mobile/features/check_in/data/in_memory_moment_check_in_repository.dart';
import 'package:letter_mobile/features/check_in/domain/moment_check_in.dart';
import 'package:letter_mobile/features/cycle/data/in_memory_period_repository.dart';
import 'package:letter_mobile/features/cycle/domain/bleeding_flow.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/cycle/domain/period_record.dart';
import 'package:letter_mobile/features/entitlement/data/local_entitlement_repository.dart';
import 'package:letter_mobile/features/entitlement/domain/entitlement.dart';
import 'package:letter_mobile/features/health_records/data/in_memory_health_record_repository.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';
import 'package:letter_mobile/features/onboarding/data/onboarding_repository.dart';
import 'package:letter_mobile/features/onboarding/domain/onboarding_profile.dart';

const _today = LocalDate(2026, 9, 19);
final _now = DateTime(2026, 9, 19, 12);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final periods = InMemoryPeriodRepository(
    seed: [
      _period('may', const LocalDate(2026, 5, 23), 4),
      _period('june', const LocalDate(2026, 6, 20), 4),
      _period('july', const LocalDate(2026, 7, 19), 4),
      _period('august', const LocalDate(2026, 8, 16), 4),
      PeriodRecord(
        id: 'current',
        startDate: const LocalDate(2026, 9, 15),
        endDate: null,
        createdAt: _now,
        updatedAt: _now,
      ),
    ],
    clock: () => _now,
  );
  for (final (date, flow, color) in [
    (
      const LocalDate(2026, 9, 15),
      BleedingFlow.medium,
      BleedingColor.brightRed,
    ),
    (const LocalDate(2026, 9, 16), BleedingFlow.heavy, BleedingColor.darkRed),
    (const LocalDate(2026, 9, 17), BleedingFlow.medium, BleedingColor.darkRed),
    (const LocalDate(2026, 9, 18), BleedingFlow.light, BleedingColor.brown),
    (_today, BleedingFlow.light, BleedingColor.brown),
  ]) {
    await periods.setFlow('current', date, flow, today: _today);
    await periods.setBleedingColor('current', date, color);
  }
  // A past day with an existing energy observation gives the Cycle day
  // editor a compact, truthful flow-and-symptom capture state.
  const observedPastDay = LocalDate(2026, 6, 22);
  await periods.setFlow(
    'june',
    observedPastDay,
    BleedingFlow.medium,
    today: _today,
  );
  await periods.setBleedingColor(
    'june',
    observedPastDay,
    BleedingColor.darkRed,
  );
  final notes = InMemoryCaptureNoteStore();
  await notes.save(
    CaptureNote(
      id: 'synthetic-note',
      text: 'Keep the evening quiet and set out the heating pad.',
      source: CaptureSource.typed,
      createdAt: _now,
      keepInComfortKit: true,
    ),
  );
  runApp(
    LetterApp(
      onboardingRepository: _ReadyOnboardingRepository(),
      periodRepository: periods,
      healthRecordRepository: InMemoryHealthRecordRepository(
        seed: _healthRecords(),
        clock: () => _now,
      ),
      momentCheckInRepository: InMemoryMomentCheckInRepository(
        seed: [
          MomentCheckIn(
            id: 'today-tender',
            state: MomentCheckInState.tender,
            occurredAt: _now,
            createdAt: _now,
          ),
        ],
        clock: () => _now,
      ),
      captureNoteStore: notes,
      careMemoryRepository: InMemoryCareMemoryRepository(
        records: _careRecords(),
        reflections: _careReflections(),
        cycleReflections: _cycleReflections(),
        clock: () => _now,
      ),
      entitlementRepository: LocalEntitlementRepository(
        initial: const EntitlementState(
          status: EntitlementStatus.activePaid,
          planId: 'letter_yearly',
        ),
      ),
      now: () => _now,
    ),
  );
}

PeriodRecord _period(String id, LocalDate start, int endOffset) => PeriodRecord(
  id: id,
  startDate: start,
  endDate: start.addDays(endOffset),
  createdAt: _now,
  updatedAt: _now,
);

List<HealthRecord> _healthRecords() {
  final facts = <(String, LocalDate, SymptomType, SymptomSeverity)>[
    (
      'may-cramps',
      const LocalDate(2026, 5, 23),
      SymptomType.cramps,
      SymptomSeverity.moderate,
    ),
    (
      'may-mood',
      const LocalDate(2026, 5, 25),
      SymptomType.lowMood,
      SymptomSeverity.mild,
    ),
    (
      'may-energy',
      const LocalDate(2026, 5, 24),
      SymptomType.lowEnergy,
      SymptomSeverity.moderate,
    ),
    (
      'may-irritable',
      const LocalDate(2026, 5, 26),
      SymptomType.irritability,
      SymptomSeverity.mild,
    ),
    (
      'may-cramps-later',
      const LocalDate(2026, 5, 27),
      SymptomType.cramps,
      SymptomSeverity.mild,
    ),
    (
      'june-cramps',
      const LocalDate(2026, 6, 20),
      SymptomType.cramps,
      SymptomSeverity.severe,
    ),
    (
      'june-energy',
      const LocalDate(2026, 6, 22),
      SymptomType.lowEnergy,
      SymptomSeverity.moderate,
    ),
    (
      'june-mood',
      const LocalDate(2026, 6, 19),
      SymptomType.lowMood,
      SymptomSeverity.moderate,
    ),
    (
      'june-irritable',
      const LocalDate(2026, 6, 21),
      SymptomType.irritability,
      SymptomSeverity.mild,
    ),
    (
      'june-anxiety',
      const LocalDate(2026, 6, 21),
      SymptomType.anxiety,
      SymptomSeverity.moderate,
    ),
    (
      'june-cramps-later',
      const LocalDate(2026, 6, 23),
      SymptomType.cramps,
      SymptomSeverity.mild,
    ),
    (
      'july-cramps',
      const LocalDate(2026, 7, 19),
      SymptomType.cramps,
      SymptomSeverity.mild,
    ),
    (
      'july-mood',
      const LocalDate(2026, 7, 21),
      SymptomType.irritability,
      SymptomSeverity.moderate,
    ),
    (
      'july-social',
      const LocalDate(2026, 7, 21),
      SymptomType.socialWithdrawal,
      SymptomSeverity.mild,
    ),
    (
      'july-energy',
      const LocalDate(2026, 7, 20),
      SymptomType.lowEnergy,
      SymptomSeverity.moderate,
    ),
    (
      'july-low-mood',
      const LocalDate(2026, 7, 22),
      SymptomType.lowMood,
      SymptomSeverity.mild,
    ),
    (
      'july-cramps-later',
      const LocalDate(2026, 7, 23),
      SymptomType.cramps,
      SymptomSeverity.mild,
    ),
    (
      'august-cramps',
      const LocalDate(2026, 8, 16),
      SymptomType.cramps,
      SymptomSeverity.severe,
    ),
    (
      'august-energy',
      const LocalDate(2026, 8, 18),
      SymptomType.lowEnergy,
      SymptomSeverity.severe,
    ),
    (
      'august-brain-fog',
      const LocalDate(2026, 8, 18),
      SymptomType.brainFog,
      SymptomSeverity.moderate,
    ),
    (
      'august-mood',
      const LocalDate(2026, 8, 16),
      SymptomType.lowMood,
      SymptomSeverity.moderate,
    ),
    (
      'august-irritable',
      const LocalDate(2026, 8, 19),
      SymptomType.irritability,
      SymptomSeverity.moderate,
    ),
    (
      'august-cramps-later',
      const LocalDate(2026, 8, 20),
      SymptomType.cramps,
      SymptomSeverity.mild,
    ),
    ('today-cramps', _today, SymptomType.cramps, SymptomSeverity.moderate),
    ('today-energy', _today, SymptomType.lowEnergy, SymptomSeverity.severe),
    (
      'today-sensitive',
      _today,
      SymptomType.hypersensitivity,
      SymptomSeverity.mild,
    ),
  ];
  return [
    for (final (id, date, symptom, severity) in facts)
      HealthRecord(
        id: id,
        symptom: symptom,
        severity: severity,
        functionalImpacts: const {},
        experiencedDate: date,
        recordedAt: DateTime.utc(date.year, date.month, date.day, 9),
        updatedAt: DateTime.utc(date.year, date.month, date.day, 9),
        provenance: date == _today
            ? HealthRecordProvenance.sameDay
            : HealthRecordProvenance.laterRecall,
        userConfirmed: true,
        vocabularyVersion: healthRecordVocabularyVersion,
      ),
  ];
}

List<CareRecord> _careRecords() {
  final facts = <(String, LocalDate, String, CareOutcome)>[
    (
      'warmth-1',
      const LocalDate(2026, 5, 24),
      'Apply warmth',
      CareOutcome.better,
    ),
    (
      'warmth-2',
      const LocalDate(2026, 6, 21),
      'Apply warmth',
      CareOutcome.better,
    ),
    (
      'warmth-3',
      const LocalDate(2026, 7, 20),
      'Apply warmth',
      CareOutcome.same,
    ),
    (
      'warmth-4',
      const LocalDate(2026, 8, 17),
      'Apply warmth',
      CareOutcome.better,
    ),
    (
      'quiet-1',
      const LocalDate(2026, 6, 22),
      'Quiet presence',
      CareOutcome.better,
    ),
    (
      'quiet-2',
      const LocalDate(2026, 7, 21),
      'Quiet presence',
      CareOutcome.same,
    ),
    (
      'quiet-3',
      const LocalDate(2026, 8, 18),
      'Quiet presence',
      CareOutcome.better,
    ),
  ];
  return [
    for (final (id, date, label, outcome) in facts)
      CareRecord(
        id: id,
        mode: CareMode.heavy,
        actionId: label == 'Apply warmth'
            ? 'care.body.warmth'
            : 'care.heavy.guided_scene',
        actionLabel: label,
        outcome: outcome,
        occurredAt: DateTime.utc(date.year, date.month, date.day, 12),
        createdAt: _now.toUtc(),
        updatedAt: _now.toUtc(),
        pinned: false,
      ),
  ];
}

List<CareReflection> _careReflections() => [
  CareReflection(
    id: 'synthetic-care-reflection',
    careRecordId: 'quiet-3',
    mode: CareMode.heavy,
    observation: 'The evening felt too loud.',
    need: ReflectionNeed.restOrPhysicalCapacity,
    whatHelped: 'Turning the lights down gave me room to pause.',
    futureSelfNote: 'You can make the room quieter before you decide anything.',
    createdAt: DateTime.utc(2026, 8, 18, 12),
    updatedAt: DateTime.utc(2026, 8, 18, 12),
  ),
];

List<CycleReflection> _cycleReflections() => [
  CycleReflection(
    id: 'synthetic-cycle-reflection',
    startingPeriodId: 'august',
    cycleStartDay: const LocalDate(2026, 8, 16).epochDay,
    observation: 'I needed more quiet during the first two days.',
    need: ReflectionNeed.restOrPhysicalCapacity,
    whatHelped: 'Leaving one evening open helped me rest.',
    futureSelfNote: 'A slower evening is enough of a plan.',
    createdAt: DateTime.utc(2026, 9, 10, 12),
    updatedAt: DateTime.utc(2026, 9, 10, 12),
  ),
  CycleReflection(
    id: 'synthetic-future-self-note',
    startingPeriodId: 'july',
    cycleStartDay: const LocalDate(2026, 7, 19).epochDay,
    observation: null,
    need: null,
    whatHelped: null,
    futureSelfNote:
        'You do not have to fill every hour. Leave one evening open and come back to what feels steady.',
    createdAt: DateTime.utc(2026, 7, 23, 12),
    updatedAt: DateTime.utc(2026, 9, 12, 12),
  ),
];

final class _ReadyOnboardingRepository implements OnboardingRepository {
  @override
  Future<OnboardingProfile?> load() async =>
      const bool.fromEnvironment('CAPTURE_ONBOARDING')
      ? null
      : OnboardingProfile();

  @override
  Future<void> save(OnboardingProfile profile) async {}

  @override
  Future<void> clear() async {}
}
