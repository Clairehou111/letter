import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/experience/today/today_visual_port.dart';
import 'package:letter_mobile/features/capture/domain/capture_models.dart';
import 'package:letter_mobile/features/care/data/in_memory_care_memory_repository.dart';
import 'package:letter_mobile/features/check_in/domain/moment_check_in.dart';
import 'package:letter_mobile/features/comfort_kit/application/comfort_experience_controller.dart';
import 'package:letter_mobile/features/comfort_kit/data/in_memory_comfort_kit_repository.dart';
import 'package:letter_mobile/features/comfort_window/data/comfort_reminder_preference_repositories.dart';
import 'package:letter_mobile/features/comfort_window/domain/comfort_reminder_preference.dart';
import 'package:letter_mobile/features/comfort_window/domain/comfort_window.dart';
import 'package:letter_mobile/features/cycle/data/letter_health_database.dart';
import 'package:letter_mobile/features/cycle/domain/cycle_prediction.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';
import 'package:letter_mobile/features/patterns/domain/pattern_source.dart';
import 'package:letter_mobile/features/record_hub/domain/comfort_window.dart'
    as record;
import 'package:letter_mobile/features/record_hub/domain/comfort_window_projection.dart';

import 'comfort_window_record_hub_test.dart' as synthetic;

void main() {
  test(
    'authoritative null suppresses a legacy forecast and keeps the real Kit',
    () async {
      final source = _legacySource();
      final now = synthetic.repeated().today.asLocalDateTime;
      final notes = await _keptNotes(now);
      final baseline = await _controller(
        source: source,
        notes: notes,
        now: now,
      ).load();
      expect(
        baseline.window,
        isNotNull,
        reason: 'The legacy evidence would otherwise generate a forecast.',
      );
      var calls = 0;
      final snapshot = await _controller(
        source: source,
        notes: notes,
        now: now,
        loadWindow: () async {
          calls++;
          return null;
        },
      ).load();
      expect(calls, 1);
      expect(snapshot.window, isNull);
      expect(snapshot.canConfigureReminder, isFalse);
      expect(snapshot.windowState.proactivelyVisible, isFalse);
      expect(snapshot.kit.isFormed, isTrue);
      expect(snapshot.kit.visibleItems.single.body, 'Synthetic kept words.');
    },
  );

  test(
    'explicit-zero projection carries its exact evidence alongside Build17 Kit',
    () async {
      final result = synthetic.analyze(synthetic.repeated())!;
      final projected = projectComfortWindow(result)!;
      final now = result.rangeStart!.asLocalDateTime;
      final snapshot = await _controller(
        source: _legacySource(),
        notes: await _keptNotes(now),
        now: now,
        loadWindow: () async => projected,
      ).load();
      expect(snapshot.window, same(projected));
      expect(
        snapshot.window!.sourceAlgorithmId,
        record.ComfortWindowResult.algorithmVersion,
      );
      expect(snapshot.window!.sourceEvidence, result.canonicalEvidence);
      expect(snapshot.canConfigureReminder, isTrue);
      expect(snapshot.windowState.proactivelyVisible, isTrue);
      expect(snapshot.kit.visibleItems.single.body, 'Synthetic kept words.');
    },
  );

  test(
    'emerging and unreliable projections keep Kit quiet even inside forecast dates',
    () async {
      final clearer = synthetic.analyze(synthetic.repeated())!;
      final emerging = synthetic.analyze(synthetic.repeated(intervals: 2))!;
      final prediction = clearer.prediction!;
      final low = record.ComfortWindowResult(
        startOffset: clearer.startOffset,
        endOffset: clearer.endOffset,
        strength: clearer.strength,
        votes: clearer.votes,
        examinedCycles: clearer.examinedCycles,
        prediction: CyclePrediction(
          predictedMensesStart: prediction.predictedMensesStart,
          predictedMensesEnd: prediction.predictedMensesEnd,
          midpoint: prediction.midpoint,
          medianCycleDays: prediction.medianCycleDays,
          minimumCycleDays: prediction.minimumCycleDays,
          maximumCycleDays: prediction.maximumCycleDays,
          intervalCount: prediction.intervalCount,
          confidence: PredictionConfidence.low,
          predictedLutealStart: prediction.predictedLutealStart,
          predictedLutealEnd: prediction.predictedLutealEnd,
        ),
      );
      for (final result in [emerging, low]) {
        final now = result.rangeStart!.asLocalDateTime;
        final snapshot = await _controller(
          source: _legacySource(),
          notes: await _keptNotes(now),
          now: now,
          loadWindow: () async => projectComfortWindow(result),
        ).load();
        expect(snapshot.window, isNotNull);
        expect(snapshot.kit.isFormed, isTrue);
        expect(snapshot.canConfigureReminder, isFalse);
        expect(snapshot.windowState.proactivelyVisible, isFalse);
      }
    },
  );

  test(
    'Not now remains configured and off after reopening the durable Build17 store',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'synthetic-comfort-preference-',
      );
      final file = File('${directory.path}/preference.sqlite');
      var database = LetterHealthDatabase(NativeDatabase(file));
      addTearDown(() async {
        await database.close();
        await directory.delete(recursive: true);
      });
      final result = synthetic.analyze(synthetic.repeated())!;
      final now = result.rangeStart!.addDays(-5).asLocalDateTime;
      final notes = await _keptNotes(now);
      final controller = _controller(
        source: _legacySource(),
        notes: notes,
        now: now,
        reminders: DriftComfortReminderPreferenceRepository(database),
        loadWindow: () async => projectComfortWindow(result),
      );
      await controller.saveReminder(enabled: false, leadDays: 2);
      await database.close();
      database = LetterHealthDatabase(NativeDatabase(file));
      final reopened = await _controller(
        source: _legacySource(),
        notes: notes,
        now: now,
        reminders: DriftComfortReminderPreferenceRepository(database),
        loadWindow: () async => projectComfortWindow(result),
      ).load();
      expect(reopened.reminder.enabled, isFalse);
      expect(reopened.reminder.updatedAt, now.toUtc());
      final state = TodayComfortWindowState(
        forecastStart: reopened.window!.forecastStart,
        forecastEnd: reopened.window!.forecastEnd,
        preparationVisible: false,
        kitFormed: reopened.kit.isFormed,
        reminderConfigured: reopened.reminder.updatedAt != null,
        reminderEnabled: reopened.reminder.enabled,
        reminderLeadDays: reopened.reminder.leadDays,
        sourceCycleCount: reopened.window!.candidate.votingCycleCount,
        reminderHour: 17,
        reminderMinute: 35,
      );
      expect(state.reminderInvitationVisible, isFalse);
      expect(state.reminderTimeLabel, '17:35');
    },
  );
}

ComfortExperienceController _controller({
  required PatternSourceSnapshot source,
  required CaptureNoteStore notes,
  required DateTime now,
  Future<ComfortWindowPrediction?> Function()? loadWindow,
  ComfortReminderPreferenceRepository? reminders,
}) => ComfortExperienceController(
  patternSource: _Source(source),
  careMemory: InMemoryCareMemoryRepository(),
  quickNotes: notes,
  kitRepository: InMemoryComfortKitRepository(),
  reminderRepository:
      reminders ?? InMemoryComfortReminderPreferenceRepository(),
  loadWindow: loadWindow,
  now: () => now,
);

Future<InMemoryCaptureNoteStore> _keptNotes(DateTime now) async {
  final notes = InMemoryCaptureNoteStore(clock: () => now);
  await notes.save(
    CaptureNote(
      id: 'synthetic-kept-note',
      text: 'Synthetic kept words.',
      source: CaptureSource.typed,
      createdAt: now.toUtc(),
      keepInComfortKit: true,
    ),
  );
  return notes;
}

PatternSourceSnapshot _legacySource() {
  final fixture = synthetic.repeated();
  return PatternSourceSnapshot(
    periods: fixture.periods,
    healthRecords: fixture.symptoms
        .where((source) => source.severity != SymptomSeverity.notPresent)
        .toList(),
    momentCheckIns: [
      for (final source in fixture.symptoms.where(
        (source) => source.severity == SymptomSeverity.notPresent,
      ))
        MomentCheckIn(
          id: 'synthetic-positive-${source.id}',
          state: MomentCheckInState.good,
          occurredAt: source.experiencedDate.asLocalDateTime,
          createdAt: source.experiencedDate.asLocalDateTime,
        ),
    ],
  );
}

final class _Source implements PatternSourceReader {
  const _Source(this.source);
  final PatternSourceSnapshot source;
  @override
  Future<PatternSourceSnapshot> read() async => source;
}
