import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/comfort_window/data/comfort_reminder_preference_repositories.dart';
import 'package:letter_mobile/features/cycle/data/in_memory_period_repository.dart';
import 'package:letter_mobile/features/patterns/domain/pattern_source.dart';
import 'package:letter_mobile/features/record_hub/domain/comfort_window_projection.dart';
import 'package:letter_mobile/features/check_in/domain/moment_check_in.dart';
import 'package:letter_mobile/features/cycle/domain/cycle_prediction.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/cycle/domain/period_record.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';
import 'package:letter_mobile/features/notifications/application/comfort_window_scheduler.dart';
import 'package:letter_mobile/features/notifications/domain/local_notification_port.dart';
import 'package:letter_mobile/features/privacy/data/secure_privacy_preferences_repository.dart';
import 'package:letter_mobile/features/record_hub/domain/comfort_window.dart';
import 'package:letter_mobile/features/record_hub/domain/record_hub_facts.dart';
import 'package:letter_mobile/features/record_hub/domain/record_programme.dart';

const day = LocalDate(2026, 10, 8);
final stamp = DateTime.utc(2026, 10, 8, 12);
HealthRecord symptom(
  LocalDate date,
  int score, {
  SymptomType type = SymptomType.cramps,
  HealthRecordProvenance timing = HealthRecordProvenance.sameDay,
  DateTime? updated,
}) => HealthRecord(
  id: '$date-${type.name}-$score',
  symptom: type,
  severity: SymptomSeverity.fromScore(score),
  functionalImpacts: const {},
  experiencedDate: date,
  recordedAt: stamp,
  updatedAt: updated ?? stamp,
  provenance: timing,
  userConfirmed: true,
  vocabularyVersion: healthRecordVocabularyVersion,
);
DailyImpactRecord impact(
  LocalDate date,
  int score, {
  HealthRecordProvenance timing = HealthRecordProvenance.sameDay,
}) => RecordHubFact(
  metadata: RecordFactMetadata(
    id: '$date-impact',
    experiencedDate: date,
    recordedAt: stamp,
    updatedAt: stamp,
    originalProvenance: timing,
    provenance: timing,
  ),
  value: DailyImpactDraft(experiencedDate: date, overall: score),
);
RecordProgramme programme({
  LocalDate? start,
  List<SymptomType> core = const [SymptomType.cramps],
}) {
  final date = start ?? day;
  return RecordProgramme(
    id: 'fictional-programme',
    startDate: date,
    createdAt: stamp,
    updatedAt: stamp,
    configurations: [
      RecordProgrammeConfig(
        id: 'fictional-config-v1',
        version: 1,
        effectiveDate: date,
        symptoms: core,
      ),
    ],
  );
}

({
  List<PeriodRecord> periods,
  List<HealthRecord> symptoms,
  List<DailyImpactRecord> impacts,
  RecordProgramme programme,
  LocalDate today,
})
repeated({int intervals = 4, bool allHarder = false}) {
  const first = LocalDate(2026, 5, 1);
  final periods = [
    for (var i = 0; i <= intervals; i++)
      PeriodRecord(
        id: 'fictional-cycle-$i',
        startDate: first.addDays(i * 28),
        endDate: first.addDays(i * 28 + 4),
        createdAt: stamp,
        updatedAt: stamp,
      ),
  ];
  final symptoms = <HealthRecord>[];
  final impacts = <DailyImpactRecord>[];
  for (var i = 1; i <= intervals; i++) {
    for (var offset = -14; offset <= 3; offset++) {
      final date = first.addDays(i * 28 + offset);
      final score = allHarder || (offset >= -5 && offset <= -3) ? 3 : 0;
      symptoms.add(symptom(date, score));
      impacts.add(impact(date, score));
    }
  }
  return (
    periods: periods,
    symptoms: symptoms,
    impacts: impacts,
    programme: programme(start: first),
    today: periods.last.startDate.addDays(14),
  );
}

ComfortWindowResult? analyze(
  ({
    List<PeriodRecord> periods,
    List<HealthRecord> symptoms,
    List<DailyImpactRecord> impacts,
    RecordProgramme programme,
    LocalDate today,
  })
  source,
) => const ComfortWindowEngine().analyze(
  periods: source.periods,
  symptoms: source.symptoms,
  impacts: source.impacts,
  moments: const [],
  programmes: [source.programme],
  today: source.today,
);

void main() {
  const engine = ComfortWindowEngine();
  ComfortDayEvidence classify({
    List<HealthRecord> symptoms = const [],
    List<DailyImpactRecord> impacts = const [],
    List<MomentCheckIn> moments = const [],
    List<RecordProgramme>? programmes,
  }) => engine.classify(
    date: day,
    symptoms: symptoms,
    impacts: impacts,
    moments: moments,
    programmes: programmes ?? [programme()],
  );
  test(
    'explicit complete core and independent impact zeros alone prove non-hard',
    () {
      expect(
        classify(
          symptoms: [symptom(day, 0)],
          impacts: [impact(day, 0)],
        ).classification,
        ComfortDayClass.nonHard,
      );
      expect(
        classify(symptoms: [symptom(day, 0)]).classification,
        ComfortDayClass.partial,
      );
      expect(
        classify(impacts: [impact(day, 0)]).classification,
        ComfortDayClass.partial,
      );
      expect(
        classify(
          symptoms: [symptom(day, 0)],
          impacts: [impact(day, 0)],
          programmes: [],
        ).classification,
        ComfortDayClass.partial,
      );
      expect(
        classify(
          symptoms: [symptom(day, 0)],
          impacts: [impact(day, 0)],
          programmes: [
            programme(core: [SymptomType.cramps, SymptomType.anxiety]),
          ],
        ).classification,
        ComfortDayClass.partial,
      );
    },
  );
  test(
    'Moment positive is partial, difficult is harder, legacy date unknown proves neither',
    () {
      MomentCheckIn moment(MomentCheckInState state, {bool legacy = false}) =>
          MomentCheckIn(
            id: 'fictional-moment',
            state: state,
            occurredAt: stamp,
            createdAt: stamp,
            experiencedDate: legacy ? null : day,
            provenance: legacy
                ? HealthRecordProvenance.timingUnknown
                : HealthRecordProvenance.sameDay,
          );
      expect(
        classify(moments: [moment(MomentCheckInState.good)]).classification,
        ComfortDayClass.partial,
      );
      expect(
        classify(moments: [moment(MomentCheckInState.low)]).classification,
        ComfortDayClass.harder,
      );
      expect(
        classify(
          moments: [moment(MomentCheckInState.low, legacy: true)],
        ).classification,
        ComfortDayClass.unobserved,
      );
    },
  );
  test(
    'recall/unknown and recalled replacement do not revive superseded same-day evidence',
    () {
      for (final timing in [
        HealthRecordProvenance.laterRecall,
        HealthRecordProvenance.timingUnknown,
      ]) {
        expect(
          classify(
            symptoms: [symptom(day, 5, timing: timing)],
            impacts: [impact(day, 5, timing: timing)],
          ).classification,
          ComfortDayClass.unobserved,
        );
      }
      expect(
        classify(
          symptoms: [
            symptom(day, 3),
            symptom(
              day,
              0,
              timing: HealthRecordProvenance.laterRecall,
              updated: stamp.add(const Duration(days: 1)),
            ),
          ],
        ).classification,
        ComfortDayClass.unobserved,
      );
      expect(
        classify(
          symptoms: [symptom(day, 0)],
          impacts: [impact(day, 2)],
        ).classification,
        ComfortDayClass.harder,
      );
    },
  );
  test(
    'same sources select deterministic native versioned window after input reorder',
    () {
      final source = repeated();
      final result = analyze(source)!;
      expect(result.strength, ComfortWindowStrength.clearer);
      expect(result.startOffset, -5);
      expect(result.endOffset, -3);
      expect(result.supportCount, 4);
      expect(result.reliable, isTrue);
      expect(result.examinedCycles.every((cycle) => cycle.eligible), isTrue);
      expect(
        result.votes.every(
          (vote) => vote.outsideObserved >= 5 && vote.insideHarder >= 2,
        ),
        isTrue,
      );
      final reversed = engine.analyze(
        periods: source.periods.reversed,
        symptoms: source.symptoms.reversed,
        impacts: source.impacts.reversed,
        moments: const [],
        programmes: [source.programme],
        today: source.today,
      )!;
      expect(
        jsonEncode(reversed.canonicalEvidence),
        jsonEncode(result.canonicalEvidence),
      );
      expect(
        result.canonicalEvidence['algorithmVersion'],
        ComfortWindowResult.algorithmVersion,
      );
      expect(
        [reversed.startOffset, reversed.endOffset, reversed.averageLift],
        [result.startOffset, result.endOffset, result.averageLift],
      );
      expect(
        result.votes
            .expand((vote) => vote.evidence.days)
            .every((d) => d.date.isBefore(source.periods.last.startDate)),
        isTrue,
      );
    },
  );
  test(
    'persistent harder days still have facts but cannot meet Comfort Window9/3',
    () {
      expect(analyze(repeated(allHarder: true)), isNull);
      final result = analyze(repeated(intervals: 2))!;
      expect(result.strength, ComfortWindowStrength.emerging);
      expect(result.reliable, isFalse);
    },
  );
  test(
    'six most recent completed windows only; current-cycle writes cannot retrain',
    () {
      final source = repeated(intervals: 8);
      final before = analyze(source)!;
      expect(before.examinedCycles, hasLength(6));
      source.symptoms.add(symptom(source.today, 5));
      source.impacts.add(impact(source.today, 5));
      final after = analyze(source)!;
      expect(
        [
          after.startOffset,
          after.endOffset,
          after.supportCount,
          after.averageLift,
        ],
        [
          before.startOffset,
          before.endOffset,
          before.supportCount,
          before.averageLift,
        ],
      );
    },
  );
  test(
    'forecast gate preserves low-confidence/spread/display-width and two-day surface window',
    () {
      final result = analyze(repeated())!;
      expect(
        result.preparationVisibleOn(result.rangeStart!.addDays(-3)),
        isFalse,
      );
      expect(
        result.preparationVisibleOn(result.rangeStart!.addDays(-2)),
        isTrue,
      );
      expect(result.preparationVisibleOn(result.rangeEnd!.addDays(1)), isFalse);
      expect(
        result
            .reminderAt(today: result.rangeStart!.addDays(-3), leadDays: 2)!
            .hour,
        9,
      );
      expect(
        result.reminderAt(today: result.rangeStart!.addDays(1), leadDays: 0),
        isNull,
      );
      final p = result.prediction!;
      CyclePrediction change({
        PredictionConfidence? confidence,
        int? maximum,
        int? intervals,
        LocalDate? end,
      }) => CyclePrediction(
        predictedMensesStart: p.predictedMensesStart,
        predictedMensesEnd: end ?? p.predictedMensesEnd,
        midpoint: p.midpoint,
        medianCycleDays: p.medianCycleDays,
        minimumCycleDays: p.minimumCycleDays,
        maximumCycleDays: maximum ?? p.maximumCycleDays,
        intervalCount: intervals ?? p.intervalCount,
        confidence: confidence ?? p.confidence,
        predictedLutealStart: p.predictedLutealStart,
        predictedLutealEnd: p.predictedLutealEnd,
      );
      for (final prediction in [
        change(confidence: PredictionConfidence.low),
        change(intervals: 1),
        change(maximum: p.minimumCycleDays + 8),
        change(end: p.predictedMensesStart.addDays(9)),
      ]) {
        final restricted = ComfortWindowResult(
          startOffset: result.startOffset,
          endOffset: result.endOffset,
          strength: result.strength,
          votes: result.votes,
          examinedCycles: result.examinedCycles,
          prediction: prediction,
        );
        expect(restricted.reliable, isFalse);
        expect(projectComfortWindow(restricted)!.canOfferReminder, isFalse);
      }
    },
  );
  test(
    'Build17 projection preserves explicit-zero identity, evidence and gate',
    () {
      final result = analyze(repeated())!;
      final projected = projectComfortWindow(result)!;
      expect(projected.sourceAlgorithmId, ComfortWindowResult.algorithmVersion);
      expect(projected.sourceEvidence, result.canonicalEvidence);
      expect(
        projected.sourceCycleIds,
        result.votes.map((vote) => vote.evidence.cycleId).toList(),
      );
      expect(projected.forecastStart, result.rangeStart);
      expect(projected.forecastEnd, result.rangeEnd);
      expect(projected.canOfferReminder, result.reliable);
      expect(projectComfortWindow(null), isNull);
      expect(
        () => projected.sourceEvidence['algorithmVersion'] = 'changed',
        throwsUnsupportedError,
      );
      final emerging = analyze(repeated(intervals: 2))!;
      expect(projectComfortWindow(emerging)!.canOfferReminder, isFalse);
    },
  );

  test(
    'legacy default-on preference never opts into new reminder; v4 preserves explicit lead/dismissal',
    () {
      final legacy = PrivacyPreferencesCodec.decode(
        jsonEncode({'version': 3, 'cycle_check_in': true}),
      );
      expect(legacy.comfortWindowReminderEnabled, isFalse);
      expect(legacy.comfortWindowReminderLeadDays, 2);
      final selected = legacy.copyWith(
        comfortWindowReminderEnabled: true,
        comfortWindowReminderLeadDays: 1,
        comfortWindowInvitationDismissed: true,
      );
      expect(
        PrivacyPreferencesCodec.decode(
          PrivacyPreferencesCodec.encode(selected),
        ),
        selected,
      );
    },
  );
  test(
    'reminder cancels by default, asks only explicit opt-in, and schedules neutral9local reliable only',
    () async {
      final source = repeated();
      final result = analyze(source)!;
      final preferences = InMemoryComfortReminderPreferenceRepository();
      final port = _Notifications();
      final scheduler = ComfortWindowScheduler(
        InMemoryPeriodRepository(),
        _PatternSource(),
        preferences,
        port,
        loadWindow: () async => projectComfortWindow(result),
        now: () => result.rangeStart!.addDays(-5).asLocalDateTime,
      );
      await scheduler.reconcile(requestPermission: true);
      expect(port.requests, 0);
      expect(port.cancelled, 1);
      expect(port.scheduled, isNull);
      await preferences.save(
        (await preferences.load()).copyWith(enabled: true),
      );
      await scheduler.reconcile();
      expect(port.requests, 0);
      expect(port.scheduled, isNull);
      await scheduler.reconcile(requestPermission: true);
      expect(port.requests, 1);
      expect(
        port.scheduled,
        DateTime(
          result.rangeStart!.year,
          result.rangeStart!.month,
          result.rangeStart!.day - 2,
          9,
        ),
      );
      expect(port.payload, ComfortWindowScheduler.notificationPayload);
      expect(port.body, 'Open Letter Within when you have a moment.');
      await preferences.save(
        (await preferences.load()).copyWith(enabled: false),
      );
      await scheduler.reconcile();
      expect(port.scheduled, isNull);
    },
  );
}

class _Notifications implements ComfortNotificationPort {
  int requests = 0, cancelled = 0;
  DateTime? scheduled;
  String? payload, body;
  NotificationAuthorization authorization = NotificationAuthorization.unknown;
  @override
  Future<NotificationAuthorization> authorizationStatus() async =>
      authorization;
  @override
  Future<NotificationAuthorization> requestAuthorization() async {
    requests++;
    return authorization = NotificationAuthorization.granted;
  }

  @override
  Future<void> cancelComfortReminder() async {
    cancelled++;
    scheduled = null;
  }

  @override
  Future<void> scheduleComfortReminder({
    required DateTime scheduledAt,
    required String title,
    required String body,
    required String payload,
  }) async {
    scheduled = scheduledAt;
    this.payload = payload;
    this.body = body;
  }
}

final class _PatternSource implements PatternSourceReader {
  @override
  Future<PatternSourceSnapshot> read() async =>
      throw StateError('The explicit Record Hub projection must be used.');
}
