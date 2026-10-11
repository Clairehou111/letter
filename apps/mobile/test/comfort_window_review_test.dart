import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/comfort_window/data/comfort_reminder_preference_repositories.dart';
import 'package:letter_mobile/features/comfort_window/domain/comfort_reminder_preference.dart';
import 'package:letter_mobile/features/cycle/data/in_memory_period_repository.dart';
import 'package:letter_mobile/features/patterns/domain/pattern_source.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';
import 'package:letter_mobile/features/notifications/application/comfort_window_scheduler.dart';
import 'package:letter_mobile/features/notifications/domain/local_notification_port.dart';
import 'package:letter_mobile/features/record_hub/domain/comfort_window.dart';
import 'package:letter_mobile/features/record_hub/domain/record_hub_facts.dart';
import 'package:letter_mobile/features/record_hub/domain/record_programme.dart';

const _date = LocalDate(2026, 10, 9);
final _stamp = DateTime.utc(2026, 10, 9, 12);

HealthRecord _symptom({
  String id = 'fictional-rating',
  bool confirmed = true,
  int vocabulary = healthRecordVocabularyVersion,
  int score = 0,
  DateTime? updated,
  SymptomType type = SymptomType.cramps,
}) => HealthRecord(
  id: id,
  symptom: type,
  severity: SymptomSeverity.fromScore(score),
  functionalImpacts: const {},
  experiencedDate: _date,
  recordedAt: _stamp,
  updatedAt: updated ?? _stamp,
  provenance: HealthRecordProvenance.sameDay,
  userConfirmed: confirmed,
  vocabularyVersion: vocabulary,
);

final _impact = RecordHubFact<DailyImpactDraft>(
  metadata: RecordFactMetadata(
    id: 'fictional-impact',
    experiencedDate: _date,
    recordedAt: _stamp,
    updatedAt: _stamp,
    originalProvenance: HealthRecordProvenance.sameDay,
    provenance: HealthRecordProvenance.sameDay,
  ),
  value: DailyImpactDraft(experiencedDate: _date, overall: 0),
);

RecordProgramme _programme({bool paused = false}) => RecordProgramme(
  id: 'fictional-programme',
  startDate: _date.addDays(-10),
  createdAt: _stamp,
  updatedAt: _stamp,
  configurations: [
    RecordProgrammeConfig(
      id: 'fictional-core-before',
      version: 1,
      effectiveDate: _date.addDays(-10),
      symptoms: [SymptomType.cramps],
    ),
    RecordProgrammeConfig(
      id: 'fictional-core-after',
      version: 2,
      effectiveDate: _date.addDays(1),
      symptoms: [SymptomType.cramps, SymptomType.anxiety],
    ),
  ],
  pauses: paused
      ? [RecordProgrammePause(id: 'fictional-pause', startDate: _date)]
      : [],
);

void main() {
  ComfortDayEvidence classify(
    List<HealthRecord> symptoms, {
    RecordProgramme? programme,
  }) => const ComfortWindowEngine().classify(
    date: _date,
    symptoms: symptoms,
    impacts: [_impact],
    moments: const [],
    programmes: [programme ?? _programme()],
  );

  test('unconfirmed symptoms cannot create a harder day', () {
    final day = classify([_symptom(confirmed: false, score: 5)]);
    expect(day.classification, ComfortDayClass.partial);
    expect(day.sourceIds, ['fictional-impact']);
  });

  test(
    'unconfirmed zeros cannot complete the configured non-hard denominator',
    () {
      final day = classify([_symptom(confirmed: false)]);
      expect(day.classification, ComfortDayClass.partial);
      expect(day.sourceIds, isNot(contains('fictional-rating')));
    },
  );

  test(
    'newer vocabulary suppresses superseded evidence without guessing meaning',
    () {
      final older = _symptom(score: 5);
      final newer = _symptom(
        id: 'fictional-newer-vocabulary',
        score: 0,
        vocabulary: healthRecordVocabularyVersion + 1,
        updated: _stamp.add(const Duration(hours: 1)),
      );
      final day = classify([older, newer]);
      expect(day.classification, ComfortDayClass.partial);
      expect(day.sourceIds, ['fictional-impact']);
    },
  );

  test(
    'historical explicit zeros trace the dated configuration, never later fields',
    () {
      final day = classify([_symptom()]);
      expect(day.classification, ComfortDayClass.nonHard);
      expect(day.configurationIds, ['fictional-core-before']);
      expect(day.sourceIds, ['fictional-impact', 'fictional-rating']);
      expect(
        classify([
          _symptom(),
        ], programme: _programme(paused: true)).classification,
        ComfortDayClass.partial,
      );
      expect(
        classify([
          _symptom(),
        ], programme: _programme(paused: true)).configurationIds,
        isEmpty,
      );
    },
  );

  test(
    'permission response after explicit opt-out cannot restore scheduling',
    () async {
      final preferences = (InMemoryComfortReminderPreferenceRepository()
        ..value = const ComfortReminderPreference(enabled: true));
      final port = _Notifications()
        ..permission = Completer<NotificationAuthorization>();
      var loads = 0;
      final scheduler = ComfortWindowScheduler(
        InMemoryPeriodRepository(),
        _PatternSource(),
        preferences,
        port,
        loadWindow: () async {
          loads++;
          return null;
        },
        now: () => _stamp,
      );
      final enable = scheduler.reconcile(requestPermission: true);
      await port.requestStarted.future;
      await preferences.save(const ComfortReminderPreference());
      final disable = scheduler.reconcile();
      port.permission!.complete(NotificationAuthorization.granted);
      await Future.wait([enable, disable]);
      expect(port.schedules, 0);
      expect(port.cancels, 1);
      expect(loads, 0);
      expect((await preferences.load()).enabled, isFalse);
      expect(scheduler.status, startsWith('Off'));
    },
  );

  test(
    'permission response honors persisted opt-out without another reconcile',
    () async {
      final preferences = InMemoryComfortReminderPreferenceRepository()
        ..value = const ComfortReminderPreference(enabled: true);
      final port = _Notifications()
        ..permission = Completer<NotificationAuthorization>();
      var loads = 0;
      final scheduler = ComfortWindowScheduler(
        InMemoryPeriodRepository(),
        _PatternSource(),
        preferences,
        port,
        loadWindow: () async {
          loads++;
          return null;
        },
        now: () => _stamp,
      );
      final enable = scheduler.reconcile(requestPermission: true);
      await port.requestStarted.future;
      await preferences.save(const ComfortReminderPreference());
      port.permission!.complete(NotificationAuthorization.granted);
      await enable;
      expect(port.schedules, 0);
      expect(port.cancels, 1);
      expect(loads, 0);
      expect(scheduler.status, startsWith('Off'));
    },
  );

  test(
    'unreadable evidence cancels pending reminder without exposing source text',
    () async {
      final port = _Notifications()
        ..authorization = NotificationAuthorization.granted;
      final scheduler = ComfortWindowScheduler(
        InMemoryPeriodRepository(),
        _PatternSource(),
        InMemoryComfortReminderPreferenceRepository()
          ..value = const ComfortReminderPreference(enabled: true),
        port,
        loadWindow: () async =>
            throw StateError('Synthetic source read failure'),
        now: () => _stamp,
      );
      await scheduler.reconcile();
      expect(port.cancels, 1);
      expect(port.schedules, 0);
      expect(port.requests, 0);
      expect(scheduler.status, isNot(contains('Synthetic')));
    },
  );
}

final class _Notifications implements ComfortNotificationPort {
  Completer<NotificationAuthorization>? permission;
  final requestStarted = Completer<void>();
  NotificationAuthorization authorization = NotificationAuthorization.unknown;
  int requests = 0, schedules = 0, cancels = 0;
  @override
  Future<NotificationAuthorization> authorizationStatus() async =>
      authorization;
  @override
  Future<NotificationAuthorization> requestAuthorization() async {
    requests++;
    requestStarted.complete();
    return permission!.future;
  }

  @override
  Future<void> cancelComfortReminder() async => cancels++;
  @override
  Future<void> scheduleComfortReminder({
    required DateTime scheduledAt,
    required String title,
    required String body,
    required String payload,
  }) async => schedules++;
}

final class _PatternSource implements PatternSourceReader {
  @override
  Future<PatternSourceSnapshot> read() async =>
      throw StateError('The explicit Record Hub projection must be used.');
}
