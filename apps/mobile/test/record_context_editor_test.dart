import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/experience/theme/experience_foundation.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';
import 'package:letter_mobile/features/record_hub/domain/record_hub_facts.dart';
import 'package:letter_mobile/features/record_hub/domain/record_hub_repository.dart';
import 'package:letter_mobile/features/record_hub/presentation/record_context_editor.dart';

const _date = LocalDate(2026, 10, 8);

void main() {
  Future<void> open(
    WidgetTester tester,
    _EditorRepository repository,
    RecordContextType type, {
    DateTime Function()? clock,
    VoidCallback? onChanged,
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ExperienceFoundation.lightTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showRecordContextEditor(
                context,
                type: type,
                date: _date,
                repository: repository,
                onChanged: onChanged,
                clock: clock ?? () => DateTime(2026, 10, 8, 12),
              ),
              child: const Text('Origin Record'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Origin Record'));
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, String text) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final finder = find.text(text);
    if (finder.evaluate().isEmpty) {
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        finder,
        200,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(finder.last);
    await tester.pumpAndSettle();
    await tester.tap(finder.last);
    await tester.pump();
  }

  testWidgets(
    'inherits date, requires exact minutes and waits for durable save',
    (tester) async {
      final repository = _EditorRepository();
      var changes = 0;
      await open(
        tester,
        repository,
        RecordContextType.sleep,
        onChanged: () => changes++,
      );
      expect(find.text('Thursday, October 8, 2026'), findsOneWidget);
      expect(find.byType(CalendarDatePicker), findsNothing);
      await tapVisible(tester, 'Enter exact');
      await tapVisible(tester, 'Save sleep');
      expect(repository.sleepDraft, isNull);
      expect(
        find.text('Enter an exact duration in positive minutes.'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byType(TextField),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(find.byType(TextField), '390');
      await tapVisible(tester, 'Save sleep');
      expect(repository.sleepDraft!.experiencedDate, _date);
      expect(repository.sleepDraft!.duration!.exactMinutes, 390);
      expect(repository.sleepDraft!.duration!.bucket, isNull);
      expect(find.text('Saving on this device…'), findsOneWidget);
      expect(changes, 0);
      repository.sleepCompletion.complete(_savedSleep(repository.sleepDraft!));
      await tester.pumpAndSettle();
      expect(find.text('Origin Record'), findsOneWidget);
      expect(find.byType(RecordContextEditor), findsNothing);
      expect(changes, 1);
    },
  );

  testWidgets(
    'failed persistence keeps selected fields and unsaved exit guard',
    (tester) async {
      final repository = _EditorRepository();
      await open(tester, repository, RecordContextType.sleep);
      await tapVisible(tester, '5–7 h');
      await tapVisible(tester, 'Save sleep');
      repository.sleepCompletion.completeError(
        const RecordHubException(RecordHubFailure.storageUnavailable),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Your private record could not be saved. Try again.'),
        findsOneWidget,
      );
      expect(
        repository.sleepDraft!.duration!.bucket,
        DurationBucket.sleep5To7Hours,
      );
      await tester.tap(find.byTooltip('Close editor'));
      await tester.pumpAndSettle();
      expect(find.text('Leave without saving?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.byType(RecordContextEditor), findsOneWidget);
      await tester.tap(find.byTooltip('Close editor'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard changes'));
      await tester.pumpAndSettle();
      expect(find.text('Origin Record'), findsOneWidget);
    },
  );

  testWidgets(
    'temperature keeps manual unit method exact value and blank time',
    (tester) async {
      final repository = _EditorRepository();
      await open(tester, repository, RecordContextType.temperature);
      await tester.enterText(find.byType(TextField), '97.556');
      await tapVisible(tester, '°F');
      await tapVisible(tester, 'Manual other');
      await tapVisible(tester, 'Poor sleep');
      await tapVisible(tester, 'Save basal body temperature');
      final draft = repository.temperatureDraft!;
      expect(draft.enteredValue, 97.556);
      expect(draft.unit, TemperatureUnit.fahrenheit);
      expect(draft.method, TemperatureMethod.manualOther);
      expect(draft.experiencedDate, _date);
      expect(draft.measuredAt, isNull);
      expect(draft.flags, {TemperatureQualityFlag.poorSleep});
      repository.temperatureCompletion.complete(_savedTemperature(draft));
      await tester.pumpAndSettle();
      expect(find.byType(RecordContextEditor), findsNothing);
    },
  );

  testWidgets(
    'sleep quality zero stays distinct from blank and saves only on Save',
    (tester) async {
      final repository = _EditorRepository();
      await open(tester, repository, RecordContextType.sleep);
      final zero = find.byKey(const Key('sleep-quality-0'));
      await tester.ensureVisible(zero);
      await tester.tap(zero);
      await tester.pumpAndSettle();
      expect(repository.sleepDraft, isNull);
      await tapVisible(tester, 'Save sleep');
      expect(repository.sleepDraft!.quality, SleepQuality.veryPoor);
      expect(repository.sleepDraft!.quality!.score, 0);
      expect(repository.sleepDraft!.duration, isNull);
      repository.sleepCompletion.complete(_savedSleep(repository.sleepDraft!));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'craving zero can clear to blank without persisting or being relabeled',
    (tester) async {
      final repository = _EditorRepository();
      await open(tester, repository, RecordContextType.appetite);
      final zero = find.byKey(const Key('craving-intensity-0'));
      await tester.ensureVisible(zero);
      await tester.tap(zero);
      await tester.pumpAndSettle();
      expect(repository.appetiteDraft, isNull);
      await tester.tap(zero);
      await tester.pumpAndSettle();
      await tapVisible(tester, 'Save appetite/cravings');
      expect(repository.appetiteDraft, isNull);
      expect(
        find.text('Choose appetite or craving intensity.'),
        findsOneWidget,
      );
      await tester.ensureVisible(zero);
      await tester.tap(zero);
      await tester.pumpAndSettle();
      await tapVisible(tester, 'Save appetite/cravings');
      expect(repository.appetiteDraft!.cravingScore, 0);
      expect(repository.appetiteDraft!.appetite, isNull);
      repository.appetiteCompletion.complete(
        AppetiteRecord(metadata: _metadata(), value: repository.appetiteDraft!),
      );
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'activity uses its own duration family and three original intensity values',
    (tester) async {
      final repository = _EditorRepository();
      await open(tester, repository, RecordContextType.activity);
      await tapVisible(tester, 'Walking');
      final duration = find.byKey(
        const Key('record-duration-activity21To40Minutes'),
      );
      await tester.ensureVisible(duration);
      await tester.tap(duration);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('record-duration-sleep5To7Hours')),
        findsNothing,
      );
      final intensity = find.byKey(const Key('activity-intensity-2'));
      await tester.ensureVisible(intensity);
      await tester.tap(intensity);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('activity-intensity-3')), findsNothing);
      expect(repository.activityDraft, isNull);
      await tapVisible(tester, 'Save activity/rest');
      expect(
        repository.activityDraft!.duration!.bucket,
        DurationBucket.activity21To40Minutes,
      );
      expect(repository.activityDraft!.duration!.exactMinutes, isNull);
      expect(repository.activityDraft!.intensity, ActivityIntensity.hard);
      repository.activityCompletion.complete(
        ActivityRecord(metadata: _metadata(), value: repository.activityDraft!),
      );
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'event intensity retains its three-value enum and remains optional',
    (tester) async {
      final repository = _EditorRepository();
      await open(tester, repository, RecordContextType.event);
      await tapVisible(tester, 'Acute stress');
      final intensity = find.byKey(const Key('event-intensity-2'));
      await tester.ensureVisible(intensity);
      await tester.tap(intensity);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('event-intensity-3')), findsNothing);
      expect(repository.eventDraft, isNull);
      await tapVisible(tester, 'Save significant event');
      expect(repository.eventDraft!.intensity, ContextEventIntensity.high);
      repository.eventCompletion.complete(_savedEvent(repository.eventDraft!));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'switching temperature unit clears draft reading rather than reinterpreting it',
    (tester) async {
      final repository = _EditorRepository();
      await open(tester, repository, RecordContextType.temperature);
      expect(
        find.byKey(const Key('record-temperature-whole-wheel')),
        findsNothing,
      );
      await tester.enterText(
        find.byKey(const Key('record-temperature-exact')),
        '36.789',
      );
      await tapVisible(tester, '°C');
      expect(
        tester
            .widget<TextField>(
              find.byKey(const Key('record-temperature-exact')),
            )
            .controller!
            .text,
        '36.789',
      );
      expect(repository.temperatureDraft, isNull);
      await tapVisible(tester, '°F');
      expect(
        tester
            .widget<TextField>(
              find.byKey(const Key('record-temperature-exact')),
            )
            .controller!
            .text,
        isEmpty,
      );
      await tapVisible(tester, 'Save basal body temperature');
      expect(repository.temperatureDraft, isNull);
      expect(
        find.text('Enter a positive temperature reading.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'typed temperature validation and cancelled measured time retain original truth',
    (tester) async {
      final repository = _EditorRepository();
      await open(tester, repository, RecordContextType.temperature);
      for (final invalid in ['NaN', 'Infinity', '-1', '0']) {
        final field = find.byKey(const Key('record-temperature-exact'));
        await tester.scrollUntilVisible(
          field,
          -200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.enterText(field, invalid);
        await tapVisible(tester, 'Save basal body temperature');
        expect(repository.temperatureDraft, isNull);
        expect(
          find.text('Enter a positive temperature reading.'),
          findsOneWidget,
        );
      }
      await tester.scrollUntilVisible(
        find.byKey(const Key('record-temperature-exact')),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(
        find.byKey(const Key('record-temperature-exact')),
        '36.555',
      );
      await tapVisible(tester, 'Save basal body temperature');
      expect(
        find.text('Choose a temperature unit and manual method.'),
        findsOneWidget,
      );
      await tapVisible(tester, '°C');
      await tapVisible(tester, 'Manual oral');
      await tapVisible(tester, 'Add measured time');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Add measured time'), findsOneWidget);
      await tapVisible(tester, 'Save basal body temperature');
      expect(repository.temperatureDraft!.enteredValue, 36.555);
      expect(repository.temperatureDraft!.unit, TemperatureUnit.celsius);
      expect(repository.temperatureDraft!.method, TemperatureMethod.manualOral);
      expect(repository.temperatureDraft!.measuredAt, isNull);
      repository.temperatureCompletion.complete(
        _savedTemperature(repository.temperatureDraft!),
      );
      await tester.pumpAndSettle();
    },
  );

  testWidgets('clock rollback blocks child writes without changing the draft', (
    tester,
  ) async {
    final repository = _EditorRepository();
    var now = DateTime(2026, 10, 8, 12);
    await open(tester, repository, RecordContextType.sleep, clock: () => now);
    await tapVisible(tester, '5–7 h');
    now = DateTime(2026, 10, 7, 23);
    await tapVisible(tester, 'Save sleep');
    expect(repository.sleepDraft, isNull);
    expect(find.text('Choose today or an earlier date.'), findsOneWidget);
    expect(
      tester.widget<RecordContextEditor>(find.byType(RecordContextEditor)).date,
      _date,
    );
  });

  testWidgets('context choices fit a narrow viewport with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _EditorRepository();
    await open(tester, repository, RecordContextType.event, textScale: 1.8);
    await tapVisible(tester, 'Travel or time-zone change');
    expect(tester.takeException(), isNull);
    await tapVisible(tester, 'Save significant event');
    expect(
      repository.eventDraft!.type,
      ContextEventType.travelOrTimeZoneChange,
    );
    expect(repository.eventDraft!.intensity, isNull);
    expect(tester.takeException(), isNull);
    repository.eventCompletion.complete(_savedEvent(repository.eventDraft!));
    await tester.pumpAndSettle();
  });
}

RecordFactMetadata _metadata() => RecordFactMetadata(
  id: 'synthetic-context',
  experiencedDate: _date,
  recordedAt: DateTime.utc(2026, 10, 8, 12),
  updatedAt: DateTime.utc(2026, 10, 8, 12),
  originalProvenance: HealthRecordProvenance.sameDay,
  provenance: HealthRecordProvenance.sameDay,
);

SleepRecord _savedSleep(SleepDraft draft) =>
    SleepRecord(metadata: _metadata(), value: draft);
TemperatureRecord _savedTemperature(TemperatureDraft draft) =>
    TemperatureRecord(metadata: _metadata(), value: draft);
ContextEventRecord _savedEvent(ContextEventDraft draft) =>
    ContextEventRecord(metadata: _metadata(), value: draft);

class _EditorRepository implements RecordHubRepository {
  SleepDraft? sleepDraft;
  AppetiteDraft? appetiteDraft;
  ActivityDraft? activityDraft;
  TemperatureDraft? temperatureDraft;
  ContextEventDraft? eventDraft;
  final sleepCompletion = Completer<SleepRecord>();
  final appetiteCompletion = Completer<AppetiteRecord>();
  final activityCompletion = Completer<ActivityRecord>();
  final temperatureCompletion = Completer<TemperatureRecord>();
  final eventCompletion = Completer<ContextEventRecord>();

  @override
  Future<SleepRecord> upsertSleep(SleepDraft draft) {
    sleepDraft = draft;
    return sleepCompletion.future;
  }

  @override
  Future<AppetiteRecord> upsertAppetite(AppetiteDraft draft) {
    appetiteDraft = draft;
    return appetiteCompletion.future;
  }

  @override
  Future<ActivityRecord> saveActivity(ActivityDraft draft, {String? id}) {
    activityDraft = draft;
    return activityCompletion.future;
  }

  @override
  Future<TemperatureRecord> saveTemperature(
    TemperatureDraft draft, {
    String? id,
  }) {
    temperatureDraft = draft;
    return temperatureCompletion.future;
  }

  @override
  Future<ContextEventRecord> saveEvent(ContextEventDraft draft, {String? id}) {
    eventDraft = draft;
    return eventCompletion.future;
  }

  @override
  Never noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
