import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/cycle/domain/bleeding_flow.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';
import 'package:letter_mobile/features/record_hub/domain/record_hub_facts.dart';

void main() {
  const date = LocalDate(2026, 10, 8);
  final invalidValue = throwsA(
    isA<RecordHubException>().having(
      (exception) => exception.failure,
      'failure',
      RecordHubFailure.invalidValue,
    ),
  );

  test('pins retain explicit order without aliasing their input', () {
    final selected = [SymptomType.cramps, SymptomType.anxiety];
    final pins = SymptomPins(selected);
    selected[0] = SymptomType.fatigue;
    selected.add(SymptomType.fatigue);
    expect(pins.symptoms, [SymptomType.cramps, SymptomType.anxiety]);
    expect(
      () => pins.symptoms.add(SymptomType.fatigue),
      throwsUnsupportedError,
    );
    expect(() => SymptomPins([SymptomType.cramps]), invalidValue);
    expect(
      () => SymptomPins([SymptomType.cramps, SymptomType.cramps]),
      invalidValue,
    );
    expect(
      () => SymptomPins([SymptomType.cramps, SymptomType.concentration]),
      invalidValue,
    );
  });

  test('independent impact zero is explicit, domains remain optional', () {
    final domains = {DailyImpactDomain.hobbiesOrInterests};
    final impact = DailyImpactDraft(
      experiencedDate: date,
      overall: 0,
      domains: domains,
    );
    domains.clear();
    expect(impact.overall, 0);
    expect(impact.label, 'No impact');
    expect(impact.domains, {DailyImpactDomain.hobbiesOrInterests});
    expect(
      () => DailyImpactDraft(experiencedDate: date, overall: -1),
      invalidValue,
    );
    expect(
      () => DailyImpactDraft(experiencedDate: date, overall: 6),
      invalidValue,
    );
    expect(RecordHubDateFacts(date: date).impact, isNull);
  });

  test(
    'standalone spotting requires no period and none differs from absent',
    () {
      final spotting = BleedingFactDraft(
        experiencedDate: date,
        flow: BleedingFlow.spotting,
        color: BleedingColor.brown,
        clots: ClotObservation.notSure,
      );
      final none = BleedingFactDraft(experiencedDate: date, flow: null);
      expect(spotting.periodId, isNull);
      expect(spotting.noBleeding, isFalse);
      expect(none.noBleeding, isTrue);
      expect(RecordHubDateFacts(date: date).bleeding, isNull);
      expect(
        () => BleedingFactDraft(
          experiencedDate: date,
          flow: null,
          color: BleedingColor.pink,
        ),
        invalidValue,
      );
      expect(
        () => BleedingFactDraft(
          experiencedDate: date,
          flow: null,
          clots: ClotObservation.notPresent,
        ),
        invalidValue,
      );
    },
  );

  test(
    'duration categories retain overlaps and open ranges without midpoints',
    () {
      final lower = RecordedDuration.bucket(DurationBucket.sleep5To7Hours);
      final upper = RecordedDuration.bucket(DurationBucket.sleep7To9Hours);
      final open = RecordedDuration.bucket(DurationBucket.care30PlusMinutes);
      expect(lower.label, '5–7 h');
      expect(upper.label, '7–9 h');
      expect(open.label, '30+ min');
      expect(
        [lower, upper, open].map((value) => value.exactMinutes),
        everyElement(isNull),
      );
      expect(RecordedDuration.exact(390).exactMinutes, 390);
      expect(RecordedDuration.exact(390).bucket, isNull);
      expect(() => RecordedDuration.exact(0), invalidValue);
      expect(() => RecordedDuration.exact(-10), invalidValue);
      expect(
        () => SleepDraft(experiencedDate: date, duration: open),
        invalidValue,
      );
    },
  );

  test('sleep uses its own explicit quality scale and optional fields', () {
    final sleep = SleepDraft(
      experiencedDate: date,
      quality: SleepQuality.fromScore(0),
    );
    expect(sleep.quality!.label, 'Very poor');
    expect(sleep.duration, isNull);
    expect(SleepQuality.fromScore(5), SleepQuality.restful);
    expect(() => SleepQuality.fromScore(6), invalidValue);
    expect(() => SleepDraft(experiencedDate: date), invalidValue);
    expect(sleep.experiencedDate, date);
  });

  test('appetite and cravings can be selected independently', () {
    final cravings = AppetiteDraft(experiencedDate: date, cravingScore: 0);
    expect(cravings.appetite, isNull);
    expect(cravings.cravingScore, 0);
    final appetite = AppetiteDraft(
      experiencedDate: date,
      appetite: AppetiteLevel.aboutUsual,
    );
    expect(appetite.cravingScore, isNull);
    expect(() => AppetiteDraft(experiencedDate: date), invalidValue);
    expect(
      () => AppetiteDraft(experiencedDate: date, cravingScore: 6),
      invalidValue,
    );
  });

  test('custom context names must be nonblank and preserve exact strings', () {
    const exactName = '  My own activity  ';
    final activity = ActivityDraft(
      experiencedDate: date,
      type: ActivityType.other,
      customName: exactName,
    );
    expect(activity.customName, exactName);
    expect(activity.duration, isNull);
    expect(activity.intensity, isNull);
    expect(
      () => ActivityDraft(experiencedDate: date, type: ActivityType.other),
      invalidValue,
    );
    expect(
      () => ContextEventDraft(
        experiencedDate: date,
        type: ContextEventType.other,
        customName: ' ',
      ),
      invalidValue,
    );
  });

  test('manual temperature retains entered unit, value, time and quality', () {
    final flags = {TemperatureQualityFlag.poorSleep};
    final temperature = TemperatureDraft(
      experiencedDate: date,
      enteredValue: 97.556,
      unit: TemperatureUnit.fahrenheit,
      method: TemperatureMethod.manualOther,
      measuredAt: LocalMeasurementTime(7, 5),
      flags: flags,
    );
    flags.clear();
    expect(temperature.enteredValue, 97.556);
    expect(temperature.unit, TemperatureUnit.fahrenheit);
    expect(temperature.celsiusValue, closeTo(36.42, 0.000001));
    expect(temperature.measuredAt!.hour, 7);
    expect(temperature.measuredAt!.minute, 5);
    expect(temperature.flags, {TemperatureQualityFlag.poorSleep});
    for (final value in [0.0, -1.0, double.nan, double.infinity]) {
      expect(
        () => TemperatureDraft(
          experiencedDate: date,
          enteredValue: value,
          unit: TemperatureUnit.celsius,
          method: TemperatureMethod.manualOral,
        ),
        invalidValue,
      );
    }
    expect(() => LocalMeasurementTime(24, 0), invalidValue);
    expect(() => LocalMeasurementTime(7, 60), invalidValue);
  });

  test('typed facts preserve original and active timing separately', () {
    final recordedAt = DateTime.utc(2026, 10, 8, 1);
    final updatedAt = DateTime.utc(2026, 10, 9, 1);
    final record = DailyImpactRecord(
      metadata: RecordFactMetadata(
        id: 'synthetic-impact',
        experiencedDate: date,
        recordedAt: recordedAt,
        updatedAt: updatedAt,
        originalProvenance: HealthRecordProvenance.sameDay,
        provenance: HealthRecordProvenance.laterRecall,
        originalWriteZoneId: 'Asia/Tokyo',
        writeZoneId: 'America/Toronto',
        originalUtcOffsetMinutes: 540,
        utcOffsetMinutes: -240,
      ),
      value: DailyImpactDraft(experiencedDate: date, overall: 0),
    );
    expect(record.id, 'synthetic-impact');
    expect(record.metadata.recordedAt, recordedAt);
    expect(record.metadata.updatedAt, updatedAt);
    expect(record.metadata.originalProvenance, HealthRecordProvenance.sameDay);
    expect(record.metadata.provenance, HealthRecordProvenance.laterRecall);
    expect(record.metadata.originalUtcOffsetMinutes, 540);
    expect(record.metadata.utcOffsetMinutes, -240);
    expect(RecordHubDateFacts(date: date, impact: record).isEmpty, isFalse);
    expect(
      () => RecordHubDateFacts(date: date.addDays(1), impact: record),
      invalidValue,
    );
    expect(
      () => DailyImpactRecord(
        metadata: record.metadata,
        value: DailyImpactDraft(experiencedDate: date.addDays(1), overall: 0),
      ),
      invalidValue,
    );
  });

  test('day snapshot keeps distinct event IDs and immutable collections', () {
    final metadata = RecordFactMetadata(
      id: 'synthetic-event',
      experiencedDate: date,
      recordedAt: DateTime.utc(2026, 10, 8),
      updatedAt: DateTime.utc(2026, 10, 8),
      originalProvenance: HealthRecordProvenance.sameDay,
      provenance: HealthRecordProvenance.sameDay,
    );
    final events = [
      ContextEventRecord(
        metadata: metadata,
        value: ContextEventDraft(
          experiencedDate: date,
          type: ContextEventType.travelOrTimeZoneChange,
        ),
      ),
    ];
    final snapshot = RecordHubDateFacts(date: date, events: events);
    events.clear();
    expect(snapshot.events.single.id, 'synthetic-event');
    expect(() => snapshot.events.clear(), throwsUnsupportedError);
  });
}
