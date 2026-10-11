import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:async';
import 'dart:ui' show SemanticsAction;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:letter_mobile/experience/letter_experience_shell.dart';
import 'package:letter_mobile/experience/theme/experience_foundation.dart';
import 'package:letter_mobile/features/auth/domain/auth_service.dart';
import 'package:letter_mobile/features/comfort_kit/application/comfort_experience_controller.dart';
import 'package:letter_mobile/features/patterns/data/repository_pattern_source.dart';
import 'package:letter_mobile/features/entitlement/data/local_entitlement_repository.dart';
import 'package:letter_mobile/features/entitlement/presentation/entitlement_scope.dart';
import 'package:letter_mobile/features/health_data/data/local_health_store.dart';
import 'package:letter_mobile/features/health_data/data/local_health_store_factory_native.dart';
import 'package:letter_mobile/features/privacy/domain/privacy_preferences.dart';
import 'package:letter_mobile/features/record_hub/domain/record_hub_facts.dart';
import 'package:letter_mobile/features/record_hub/domain/comfort_window.dart';
import 'package:letter_mobile/features/record_hub/domain/comfort_window_projection.dart';
import 'package:letter_mobile/features/record_hub/domain/record_session.dart';
import 'package:letter_mobile/features/record_hub/presentation/record_context_editor.dart';
import 'package:letter_mobile/features/record_hub/presentation/record_hub_screen.dart';
import 'package:letter_mobile/features/record_hub/presentation/record_entry_section.dart';
import 'package:letter_mobile/features/record_hub/presentation/record_interventions_editor.dart';
import 'package:letter_mobile/features/record_hub/domain/record_interventions.dart';
import 'package:letter_mobile/experience/records/observation_picker.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

// Fictional sources in an isolated encrypted database; never the app DB.
final _fixtureNow = DateTime(2026, 10, 9, 12);
var _writeNow = _fixtureNow;
const _today = LocalDate(2026, 10, 9);
const _key = '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff';
const _build17Canvas = Color(0xFF1E1224);
const _schemaVersion = 18;
const _captureStates = [
  '1x-today-default',
  '1x-moment-pressed',
  '1x-moment-all12',
  '1x-moment-saved',
  '1x-record-default',
  '1x-symptom-origin-reveal',
  '1x-record-symptom-focused',
  '1x-record-degree-pressed',
  '1x-record-zero-saved',
  '1x-record-stage-90',
  '1x-record-pane-selected',
  '1x-record-daily-life',
  '1x-record-products',
  '1x-record-notes',
  '1x-record-note-saved',
  '1x-sleep-shortcut-editor',
  '1x-activity-editor-preview',
  '1x-appetite-editor-preview',
  '1x-event-editor-preview',
  '1x-temperature-wheel-preview',
  '1x-temperature-exact-preview',
  '1x-medication-editor-preview',
  '1x-supplement-editor-preview',
  '1x-birth-control-editor-preview',
  '1x-tried-action-editor-preview',
  '1x-checkback-editor-preview',
  '1x-period-range-band-preview',
  '1x-period-range-ongoing-preview',
];
final _expectedFrames = _captureStates.length;
const _productionFingerprint =
    '79a3afd21d53ce81ef2cc17d157964b9b17f1e687923ff4eabe3889c418a4892';
final _motionSamples = <Map<String, Object>>[];
const _hostDriver = bool.fromEnvironment('NATIVE_VISUAL_HOST_DRIVER');
const _newNote = 'Synthetic pilot note saved privately on this date.';
var _renderExceptionCount = 0;
int? _observedSchemaVersion;

Finder _tab(String label) => find.byWidgetPredicate(
  (widget) => widget is Semantics && widget.properties.label == label,
);
Finder get _recordAction => _tab('Record today or another date');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'Build17 UI pilot: normal review7A, truthful native writes and previews',
    (tester) async {
      _renderExceptionCount = 0;
      _observedSchemaVersion = null;
      _motionSamples.clear();
      _writeNow = _fixtureNow;
      expect(
        Platform.isIOS,
        isTrue,
        reason: 'This bounded pilot targets review7A iOS.',
      );
      expect(
        tester.view.physicalSize.width / tester.view.devicePixelRatio,
        closeTo(402, .5),
      );
      expect(
        tester.view.physicalSize.height / tester.view.devicePixelRatio,
        closeTo(874, .5),
      );
      final directory = await Directory(
        path.join(
          (await getTemporaryDirectory()).path,
          'record-hub-ui-pilot-${DateTime.now().microsecondsSinceEpoch}',
        ),
      ).create(recursive: true);
      final file = File(path.join(directory.path, 'synthetic.sqlite'));
      LocalHealthStore openStore() => createNativeLocalHealthStoreForDatabase(
        databaseFile: file,
        loadKey: () async => _key,
        clock: () => _writeNow,
      );
      final store = openStore();
      final entitlement = LocalEntitlementRepository();
      final artifacts = _NativeArtifacts(binding, directory);
      var closed = false;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        if (!closed) await store.close();
        await entitlement.dispose();
        await artifacts.finish();
      });
      for (final start in [
        const LocalDate(2026, 7, 11),
        const LocalDate(2026, 8, 8),
        const LocalDate(2026, 9, 5),
        const LocalDate(2026, 10, 3),
      ]) {
        await store.periodRepository.create(
          PeriodDraft(startDate: start, endDate: start.addDays(4)),
          today: _today,
        );
      }
      await store.recordHubRepository!.setPins(
        SymptomPins([SymptomType.cramps, SymptomType.anxiety]),
      );
      final sleep = await store.recordHubRepository!.upsertSleep(
        SleepDraft(
          experiencedDate: _today,
          quality: SleepQuality.restful,
          duration: RecordedDuration.exact(450),
        ),
      );
      _writeNow = _fixtureNow.subtract(const Duration(minutes: 1));
      await store.captureNoteStore.save(
        CaptureNote(
          id: 'pilot-fictional-note',
          text: 'A fictional quiet morning for UI review.',
          source: CaptureSource.typed,
          createdAt: _writeNow,
          experiencedDate: _today,
          keepInComfortKit: true,
        ),
      );
      _writeNow = _fixtureNow;
      final action = await store.interventionsRepository!.saveAction(
        TriedActionDraft(
          experiencedDate: _today,
          actions: [TriedActionSelection(TriedActionKind.heat)],
          bundle: false,
          status: TriedActionStatus.completed,
          target: 'Synthetic cramps target',
          duration: RecordedDuration.bucket(DurationBucket.care10Minutes),
        ),
      );
      final original = (await store.periodRepository.getAll()).firstWhere(
        (period) => period.startDate == const LocalDate(2026, 10, 3),
      );
      await store.periodRepository.setFlow(
        original.id,
        original.startDate,
        BleedingFlow.light,
        today: _today,
      );
      final flowsBefore = await store.periodRepository.getAllFlowDays();
      await tester.pumpWidget(_nativeApp(store, entitlement, 1));
      await _settle(tester);
      expect(ExperienceColors.canvas, _build17Canvas);
      expect(
        Theme.of(
          tester.element(find.byType(LetterExperienceShell)),
        ).scaffoldBackgroundColor,
        _build17Canvas,
      );
      expect(
        MediaQuery.textScalerOf(
          tester.element(find.byType(LetterExperienceShell)),
        ).scale(1),
        1,
      );
      await artifacts.capture(tester, '1x-today-default', textScale: 1);

      final moment = find.byKey(const Key('today-moment-card'));
      await _reach(tester, moment);
      final gesture = await tester.startGesture(tester.getCenter(moment));
      await tester.pump(const Duration(milliseconds: 120));
      await artifacts.capture(tester, '1x-moment-pressed', textScale: 1);
      await gesture.up();
      await _settle(tester);
      final semantics = tester.ensureSemantics();
      for (final feeling in MomentCheckInState.values) {
        final target = _tab(feeling.label);
        expect(target, findsOneWidget);
        expect(
          tester
              .getSemantics(target)
              .getSemanticsData()
              .hasAction(SemanticsAction.tap),
          isTrue,
        );
      }
      semantics.dispose();
      expect(find.text('More'), findsNothing);
      await artifacts.capture(tester, '1x-moment-all12', textScale: 1);
      await tester.tap(find.text('Calm'));
      await _until(
        tester,
        () async => (await store.momentCheckInRepository.getAll()).length == 1,
      );
      final savedMoment = (await store.momentCheckInRepository.getAll()).single;
      expect(savedMoment.state, MomentCheckInState.calm);
      expect(savedMoment.experiencedDate, _today);
      expect(savedMoment.provenance, HealthRecordProvenance.sameDay);
      expect(
        savedMoment.createdAt.millisecondsSinceEpoch,
        _fixtureNow.millisecondsSinceEpoch,
      );
      expect(find.text('Moment saved · tap to edit'), findsOneWidget);
      await artifacts.capture(tester, '1x-moment-saved', textScale: 1);

      await _reach(tester, find.text('Body'));
      await tester.tap(find.text('Body'));
      await _settle(tester);
      _expectRecord(tester, RecordEntrySection.body);
      await _doneRecord(tester);
      await _reach(tester, find.text('Private note'));
      await tester.tap(find.text('Private note'));
      await _settle(tester);
      _expectRecord(tester, RecordEntrySection.note);
      _expectWorkspace(tester, 'Notes');
      FocusManager.instance.primaryFocus?.unfocus();
      await _settle(tester);
      await _doneRecord(tester);
      await tester.tap(_recordAction);
      await _settle(tester);
      _expectRecord(tester, null);
      expect(find.byKey(const Key('record-date')), findsOneWidget);
      _expectWorkspace(tester, 'Symptoms');
      _expectStageBacking(tester);
      await artifacts.capture(tester, '1x-record-default', textScale: 1);
      await _motionSignal(tester, 'start');
      final cramps = find.descendant(
        of: find.byType(ObservationPicker),
        matching: find.text('Cramps'),
      );
      await _reach(tester, cramps);
      await tester.tap(cramps);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      await artifacts.capture(
        tester,
        '1x-symptom-origin-reveal',
        textScale: 1,
        wait: Duration.zero,
      );
      await _settle(tester);
      final degree = find.byKey(const Key('observation-degree-0'));
      await _reach(tester, degree);
      expect(
        find.byKey(const Key('observation-current-degree')),
        findsOneWidget,
      );
      await artifacts.capture(
        tester,
        '1x-record-symptom-focused',
        textScale: 1,
      );
      final degreeGesture = await tester.startGesture(tester.getCenter(degree));
      await tester.pump(const Duration(milliseconds: 120));
      await artifacts.capture(tester, '1x-record-degree-pressed', textScale: 1);
      await degreeGesture.up();
      await _until(
        tester,
        () async => (await store.healthRecordRepository.getAll()).length == 1,
      );
      final zero = (await store.healthRecordRepository.getAll()).single;
      expect(zero.symptom, SymptomType.cramps);
      expect(zero.severity, SymptomSeverity.notPresent);
      expect(zero.experiencedDate, _today);
      expect(zero.provenance, HealthRecordProvenance.sameDay);
      expect(
        zero.recordedAt.millisecondsSinceEpoch,
        _fixtureNow.millisecondsSinceEpoch,
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('observation-current-degree')))
            .data,
        'Not present',
      );
      await artifacts.capture(tester, '1x-record-zero-saved', textScale: 1);
      // Local symptom focus closes inside Record; the workspace stays mounted.
      await tester.tap(find.byKey(const Key('observation-close-symptom')));
      await _settle(tester);
      await tester.tap(find.byKey(const Key('record-workspace-dailyLife')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      _expectWorkspace(tester, 'Daily life');
      _measureStage(tester, 'forward', 1, 90);
      await artifacts.capture(
        tester,
        '1x-record-stage-90',
        textScale: 1,
        wait: Duration.zero,
      );
      await tester.pump(const Duration(milliseconds: 70));
      _measureStage(tester, 'forward', 1, 160);
      await artifacts.capture(
        tester,
        '1x-record-pane-selected',
        textScale: 1,
        wait: Duration.zero,
      );
      await _settle(tester);
      await artifacts.capture(tester, '1x-record-daily-life', textScale: 1);
      await _selectWorkspace(tester, 'products', 'Products');
      await artifacts.capture(tester, '1x-record-products', textScale: 1);
      await _selectWorkspace(tester, 'notes', 'Notes');
      await artifacts.capture(tester, '1x-record-notes', textScale: 1);
      // Real reverse handoffs are in the video, with draft-free source state.
      await _selectWorkspace(tester, 'products', 'Products');
      await _selectWorkspace(tester, 'dailyLife', 'Daily life');
      await _selectWorkspace(tester, 'symptoms', 'Symptoms');
      await _selectWorkspace(tester, 'notes', 'Notes');
      final note = find.byKey(const Key('record-note'));
      await _reach(tester, note);
      await tester.enterText(note, _newNote);
      FocusManager.instance.primaryFocus?.unfocus();
      await _settle(tester);
      await _reach(tester, find.byKey(const Key('record-note-save')));
      await tester.tap(find.byKey(const Key('record-note-save')));
      await _until(
        tester,
        () async => (await store.captureNoteStore.getAll()).any(
          (note) => note.text == _newNote,
        ),
      );
      final savedNote = (await store.captureNoteStore.getAll()).singleWhere(
        (note) => note.text == _newNote,
      );
      expect(savedNote.experiencedDate, _today);
      expect(
        savedNote.createdAt.millisecondsSinceEpoch,
        _fixtureNow.millisecondsSinceEpoch,
      );
      await _reach(
        tester,
        find.byKey(const Key('record-status-Private note')),
        requireHitTarget: false,
      );
      expect(
        find.byKey(const Key('record-status-Private note')),
        findsOneWidget,
      );
      await artifacts.capture(tester, '1x-record-note-saved', textScale: 1);
      await _motionSignal(tester, 'stop');
      await _doneRecord(tester);
      await _reach(tester, find.text('Sleep'));
      await tester.tap(find.text('Sleep'));
      await _settle(tester);
      _expectRecord(tester, RecordEntrySection.sleep);
      final editor = tester.widget<RecordContextEditor>(
        find.byType(RecordContextEditor),
      );
      expect(editor.type, RecordContextType.sleep);
      expect(editor.date, _today);
      await _reach(
        tester,
        find.byKey(const Key('record-duration-sleep5To7Hours')),
      );
      await tester.tap(find.byKey(const Key('record-duration-sleep5To7Hours')));
      await _settle(tester);
      await _reach(tester, find.byKey(const Key('sleep-quality-0')));
      await tester.tap(find.byKey(const Key('sleep-quality-0')));
      await _settle(tester);
      await artifacts.capture(tester, '1x-sleep-shortcut-editor', textScale: 1);
      await _cancelEditor(tester);
      _expectWorkspace(tester, 'Daily life');
      await _doneRecord(tester);
      expect(
        (await store.recordHubRepository!.getDateFacts(
          _today,
        )).sleep!.metadata.id,
        sleep.metadata.id,
      );

      await tester.tap(_recordAction);
      await _settle(tester);
      _expectRecord(tester, null);
      final beforePreviews = await _sourceCollections(store);
      await _previewEditors(tester, store, artifacts, action);
      expect(
        await _sourceCollections(store),
        beforePreviews,
        reason:
            'All child selections are drafts; cancellation must preserve every stored source.',
      );
      final unchangedSleep = (await store.recordHubRepository!.getDateFacts(
        _today,
      )).sleep!;
      expect(unchangedSleep.value.duration!.exactMinutes, 450);
      expect(unchangedSleep.value.quality, SleepQuality.restful);
      expect(unchangedSleep.metadata.updatedAt, sleep.metadata.updatedAt);
      await _doneRecord(tester);

      await tester.tap(_tab('Cycle'));
      await _settle(tester);
      final edit = find.widgetWithText(OutlinedButton, 'Edit dates').first;
      await _reach(tester, edit);
      await tester.tap(edit);
      await _settle(tester);
      expect(find.text('Edit period dates'), findsOneWidget);
      await tester.tap(find.byKey(const Key('period-range-start')));
      await tester.tap(find.byKey(const Key('period-range-day-2026-10-02')));
      await tester.tap(find.byKey(const Key('period-range-end')));
      await tester.tap(find.byKey(const Key('period-range-day-2026-10-06')));
      await _settle(tester);
      expect(
        find.byKey(const Key('period-range-band-2026-10-04')),
        findsOneWidget,
      );
      final future = tester.widget<Semantics>(
        find.byKey(const Key('period-range-day-2026-10-10')),
      );
      expect(future.properties.enabled, isFalse);
      _expectUnchangedPeriod(await store.periodRepository.getAll(), original);
      await artifacts.capture(
        tester,
        '1x-period-range-band-preview',
        textScale: 1,
      );
      await _reach(tester, find.byKey(const Key('period-range-ongoing')));
      await tester.tap(find.byKey(const Key('period-range-ongoing')));
      await _settle(tester);
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const Key('period-range-ongoing')),
            )
            .value,
        isTrue,
      );
      expect(find.text('No end date yet'), findsOneWidget);
      _expectUnchangedPeriod(await store.periodRepository.getAll(), original);
      await artifacts.capture(
        tester,
        '1x-period-range-ongoing-preview',
        textScale: 1,
      );
      await _reach(tester, find.text('Cancel'));
      await tester.tap(find.text('Cancel'));
      await _settle(tester);
      expect(find.text('Edit period dates'), findsNothing);
      expect(
        find.byKey(const Key('cycle-letter-archive'), skipOffstage: false),
        findsNothing,
      );
      expect(find.text('Cycle letter archive'), findsNothing);
      _expectUnchangedPeriod(await store.periodRepository.getAll(), original);
      expect(
        (await store.periodRepository.getAllFlowDays())
            .map(
              (flow) => (
                flow.periodId,
                flow.date,
                flow.flow,
                flow.color,
                flow.createdAt,
                flow.updatedAt,
              ),
            )
            .toList(),
        flowsBefore
            .map(
              (flow) => (
                flow.periodId,
                flow.date,
                flow.flow,
                flow.color,
                flow.createdAt,
                flow.updatedAt,
              ),
            )
            .toList(),
      );

      await tester.tap(_tab('Patterns'));
      await _settle(tester);
      expect(
        tester.widget<Semantics>(_tab('Patterns')).properties.selected,
        isTrue,
      );
      expect(
        find.byKey(const Key('preparation-plan-entrance'), skipOffstage: false),
        findsNothing,
      );
      expect(find.text('My preparation plan'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await _settle(tester);
      await store.close();
      closed = true;
      final raw = sqlite3.open(file.path);
      try {
        raw.execute("PRAGMA key = '$_key';");
        _observedSchemaVersion = raw.userVersion;
        expect(_observedSchemaVersion, _schemaVersion);
      } finally {
        raw.close();
      }
      final reopened = openStore();
      try {
        final roundTrip =
            (await reopened.healthRecordRepository.getAll()).single;
        expect(roundTrip.id, zero.id);
        expect(roundTrip.severity, SymptomSeverity.notPresent);
        expect(roundTrip.experiencedDate, zero.experiencedDate);
        expect(roundTrip.recordedAt, zero.recordedAt);
        expect(
          (await reopened.momentCheckInRepository.getAll()).single.id,
          savedMoment.id,
        );
        final roundTripNote = (await reopened.captureNoteStore.getAll())
            .singleWhere((note) => note.id == savedNote.id);
        expect(roundTripNote.text, _newNote);
        expect(roundTripNote.experiencedDate, _today);
        expect(
          (await reopened.captureNoteStore.getAll())
              .singleWhere((note) => note.id == 'pilot-fictional-note')
              .keepInComfortKit,
          isTrue,
        );
        expect(
          (await reopened.recordHubRepository!.getDateFacts(
            _today,
          )).sleep!.metadata.id,
          sleep.metadata.id,
        );
        _expectUnchangedPeriod(
          await reopened.periodRepository.getAll(),
          original,
        );
      } finally {
        await reopened.close();
      }
      expect(
        utf8.decode(await file.readAsBytes(), allowMalformed: true),
        isNot(contains(_newNote)),
      );
      expect(_renderExceptionCount, 0);
      expect(artifacts.images, hasLength(_expectedFrames));
      expect(
        artifacts.images.map((entry) => entry['file']).toList(),
        _captureStates.map((state) => 'ios-$state.png').toList(),
      );
      binding.reportData?['childPreviewCancellationVerified'] = true;
      binding.reportData?['durableReopenVerified'] = true;
      binding.reportData?['previewCancellationVerified'] = true;
      await artifacts.finish();
    },
  );
}

void _expectStageBacking(WidgetTester tester) {
  final stage = find.byKey(const Key('record-workspace-stage'));
  expect(stage, findsOneWidget);
  expect(tester.widget<Stack>(stage).children, hasLength(6));
  final boxes = find.descendant(of: stage, matching: find.byType(DecoratedBox));
  final theme = Theme.of(tester.element(stage));
  expect(
    (tester.widget<DecoratedBox>(boxes.at(0)).decoration as BoxDecoration)
        .color,
    theme.colorScheme.surfaceContainerHighest,
  );
  expect(
    (tester.widget<DecoratedBox>(boxes.at(1)).decoration as BoxDecoration)
        .color,
    theme.colorScheme.surfaceContainerHigh,
  );
}

void _measureStage(
  WidgetTester tester,
  String direction,
  int face,
  int requestedElapsed,
) {
  final incoming = find
      .descendant(
        of: find.byKey(ValueKey('record-stage-face-$face')),
        matching: find.byType(Opacity),
      )
      .first;
  final opacity = tester.widget<Opacity>(incoming).opacity;
  _motionSamples.add({
    'direction': direction,
    'face': face,
    'requestedElapsedMilliseconds': requestedElapsed,
    'observedIncomingOpacity': opacity,
    'observedIntermediate': opacity > 0 && opacity < 1,
  });
}

Future<String> _sourceCollections(LocalHealthStore store) async {
  final snapshot = await store.localBackupStore!.captureSnapshot();
  return jsonEncode(
    snapshot.collections.map((collection) => collection.toJson()).toList(),
  );
}

Future<void> _cancelEditor(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await _settle(tester);
  await tester.tap(find.byTooltip('Close editor'));
  await _settle(tester);
  if (find.text('Discard changes').evaluate().isNotEmpty) {
    await tester.tap(find.text('Discard changes'));
    await _settle(tester);
  }
  expect(find.byType(RecordContextEditor), findsNothing);
  expect(find.byType(RecordProductEditor), findsNothing);
  expect(find.byType(RecordActionEditor), findsNothing);
  expect(find.byType(RecordActionCheckbackEditor), findsNothing);
  expect(find.byType(RecordHubScreen), findsOneWidget);
}

Future<void> _pushPreview(WidgetTester tester, Widget editor) async {
  final context = tester.element(find.byType(RecordHubScreen));
  unawaited(
    Navigator.of(context).push<bool>(
      CupertinoPageRoute<bool>(builder: (_) => editor, fullscreenDialog: true),
    ),
  );
  await _settle(tester);
}

Future<void> _previewTap(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    final scroll = find.byType(Scrollable).first;
    tester.state<ScrollableState>(scroll).position.jumpTo(0);
    await _settle(tester);
    await tester.scrollUntilVisible(
      target,
      200,
      scrollable: scroll,
      maxScrolls: 25,
    );
  }
  await tester.ensureVisible(target);
  await _settle(tester);
  await tester.tap(target);
  await _settle(tester);
}

Future<void> _previewEditors(
  WidgetTester tester,
  LocalHealthStore store,
  _NativeArtifacts artifacts,
  TriedActionRecord action,
) async {
  Widget contextEditor(RecordContextType type) => RecordContextEditor(
    type: type,
    date: _today,
    repository: store.recordHubRepository!,
    clock: () => _fixtureNow,
  );
  await _pushPreview(tester, contextEditor(RecordContextType.activity));
  expect(
    tester.widget<RecordContextEditor>(find.byType(RecordContextEditor)).date,
    _today,
  );
  await _previewTap(tester, find.text('Walking'));
  await _previewTap(
    tester,
    find.byKey(const Key('record-duration-activity21To40Minutes')),
  );
  await _previewTap(tester, find.byKey(const Key('activity-intensity-1')));
  await artifacts.capture(tester, '1x-activity-editor-preview', textScale: 1);
  await _cancelEditor(tester);

  await _pushPreview(tester, contextEditor(RecordContextType.appetite));
  await _previewTap(tester, find.byKey(const Key('craving-intensity-0')));
  await artifacts.capture(tester, '1x-appetite-editor-preview', textScale: 1);
  await _cancelEditor(tester);

  await _pushPreview(tester, contextEditor(RecordContextType.event));
  await _previewTap(tester, find.text('Acute stress'));
  await _previewTap(tester, find.byKey(const Key('event-intensity-1')));
  await artifacts.capture(tester, '1x-event-editor-preview', textScale: 1);
  await _cancelEditor(tester);

  await _pushPreview(tester, contextEditor(RecordContextType.temperature));
  expect(find.byKey(const Key('record-temperature-whole-wheel')), findsNothing);
  await _previewTap(tester, find.text('°C'));
  final wholeKey = find.byKey(const Key('record-temperature-whole-wheel'));
  await tester.ensureVisible(wholeKey);
  tester.widget<CupertinoPicker>(wholeKey).scrollController!.jumpToItem(38);
  await _settle(tester);
  final fractionKey = find.byKey(
    const Key('record-temperature-fraction-wheel'),
  );
  tester.widget<CupertinoPicker>(fractionKey).scrollController!.jumpToItem(57);
  await _settle(tester);
  final exact = find.byKey(const Key('record-temperature-exact'));
  expect(tester.widget<TextField>(exact).controller!.text, '37.56');
  await artifacts.capture(tester, '1x-temperature-wheel-preview', textScale: 1);
  await tester.ensureVisible(exact);
  await tester.enterText(exact, '36.555');
  FocusManager.instance.primaryFocus?.unfocus();
  await _settle(tester);
  expect(tester.widget<TextField>(exact).controller!.text, '36.555');
  await artifacts.capture(tester, '1x-temperature-exact-preview', textScale: 1);
  await _cancelEditor(tester);

  for (final (family, state) in [
    (ProductFamily.medication, '1x-medication-editor-preview'),
    (ProductFamily.supplement, '1x-supplement-editor-preview'),
    (ProductFamily.birthControl, '1x-birth-control-editor-preview'),
  ]) {
    await _pushPreview(
      tester,
      RecordProductEditor(
        date: _today,
        family: family,
        repository: store.interventionsRepository!,
        clock: () => _fixtureNow,
      ),
    );
    final product = tester.widget<RecordProductEditor>(
      find.byType(RecordProductEditor),
    );
    expect(product.family, family);
    expect(product.date, _today);
    await artifacts.capture(tester, state, textScale: 1);
    await _cancelEditor(tester);
  }

  await _pushPreview(
    tester,
    RecordActionEditor(
      date: _today,
      repository: store.interventionsRepository!,
      clock: () => _fixtureNow,
    ),
  );
  await _previewTap(tester, find.text('Heat/warmth'));
  await _previewTap(tester, find.text('Completed'));
  await _previewTap(
    tester,
    find.byKey(const Key('record-action-duration-care10Minutes')),
  );
  await artifacts.capture(
    tester,
    '1x-tried-action-editor-preview',
    textScale: 1,
  );
  await _cancelEditor(tester);

  await _pushPreview(
    tester,
    RecordActionCheckbackEditor(
      date: _today,
      repository: store.interventionsRepository!,
      action: action,
      clock: () => _fixtureNow,
    ),
  );
  expect(
    tester
        .widget<RecordActionCheckbackEditor>(
          find.byType(RecordActionCheckbackEditor),
        )
        .action
        .id,
    action.id,
  );
  await _previewTap(tester, find.text('Same'));
  await _previewTap(tester, find.byKey(const Key('record-checkback-degree-0')));
  await artifacts.capture(tester, '1x-checkback-editor-preview', textScale: 1);
  await _cancelEditor(tester);
}

void _expectWorkspace(WidgetTester tester, String label) {
  final tab = _tab('$label tab');
  expect(tab, findsOneWidget);
  expect(tester.widget<Semantics>(tab).properties.selected, isTrue);
}

Future<void> _selectWorkspace(
  WidgetTester tester,
  String key,
  String label,
) async {
  final tab = find.byKey(Key('record-workspace-$key'));
  await _reach(tester, tab);
  await tester.tap(tab);
  await _settle(tester);
  _expectWorkspace(tester, label);
}

Future<void> _motionSignal(WidgetTester tester, String command) async {
  if (!_hostDriver) return;
  await tester.runAsync(() async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.postUrl(
        Uri.parse('http://127.0.0.1:54327/$command'),
      );
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      await response.drain<void>();
      expect(
        response.statusCode,
        200,
        reason: 'The host must acknowledge actual native video recording.',
      );
    } finally {
      client.close(force: true);
    }
  });
}

void _expectRecord(WidgetTester tester, RecordEntrySection? section) {
  final record = tester.widget<RecordHubScreen>(
    find.byType(RecordHubScreen, skipOffstage: false),
  );
  expect(record.origin, RecordOrigin.today);
  expect(record.initialDate, _today);
  expect(record.initialSection, section);
}

Future<void> _doneRecord(WidgetTester tester) async {
  final done = find.widgetWithText(TextButton, 'Done').first;
  await _reach(tester, done);
  await tester.tap(done);
  await _settle(tester);
  expect(find.byType(RecordHubScreen), findsNothing);
}

void _expectUnchangedPeriod(List<PeriodRecord> periods, PeriodRecord original) {
  final current = periods.singleWhere((period) => period.id == original.id);
  expect(current.startDate, original.startDate);
  expect(current.endDate, original.endDate);
  expect(current.createdAt, original.createdAt);
  expect(current.updatedAt, original.updatedAt);
}

Future<void> _reach(
  WidgetTester tester,
  Finder target, {
  bool requireHitTarget = true,
}) async {
  expect(target, findsOneWidget);
  await tester.ensureVisible(target);
  await _settle(tester);
  if (requireHitTarget) {
    expect(target.hitTestable(), findsOneWidget);
  } else {
    final viewport =
        Offset.zero & (tester.view.physicalSize / tester.view.devicePixelRatio);
    expect(tester.getRect(target).overlaps(viewport), isTrue);
  }
}

Future<void> _until(WidgetTester tester, Future<bool> Function() saved) async {
  for (var attempt = 0; attempt < 12; attempt++) {
    await _settle(tester);
    if (await saved()) return;
  }
  fail('The actual synthetic source write did not complete.');
}

Future<void> _settle(WidgetTester tester) async {
  // Native SQLite and authored continuous motion do not use pumpAndSettle.
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 200)),
  );
  await tester.pump(const Duration(milliseconds: 700));
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pump(const Duration(milliseconds: 500));
  _collectRenderException(tester);
}

void _collectRenderException(WidgetTester tester) {
  Object? issue;
  while ((issue = tester.takeException()) != null) {
    _renderExceptionCount++;
    debugPrint('Synthetic UI pilot render exception: $issue');
  }
}

Widget _nativeApp(
  LocalHealthStore store,
  LocalEntitlementRepository entitlement,
  double scale,
) => MaterialApp(
  debugShowCheckedModeBanner: false,
  key: ValueKey(scale),
  theme: ExperienceFoundation.lightTheme(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: EntitlementScope(repository: entitlement, child: child!),
  ),
  home: LetterExperienceShell(
    periodRepository: store.periodRepository,
    careMemoryRepository: store.careMemoryRepository,
    healthRecordRepository: store.healthRecordRepository,
    captureNoteStore: store.captureNoteStore,
    momentCheckInRepository: store.momentCheckInRepository,
    preparationRepository: store.preparationRepository,
    comfortKitRepository: store.comfortKitRepository,
    comfortReminderPreferenceRepository:
        store.comfortReminderPreferenceRepository,
    comfortExperienceController: ComfortExperienceController(
      patternSource: RepositoryPatternSource(
        healthRecords: store.healthRecordRepository,
        careMemory: store.careMemoryRepository,
        periods: store.periodRepository,
        momentCheckIns: store.momentCheckInRepository,
        readTransaction: store.readTransaction,
        now: () => _fixtureNow,
      ),
      careMemory: store.careMemoryRepository,
      quickNotes: store.captureNoteStore,
      kitRepository: store.comfortKitRepository,
      reminderRepository: store.comfortReminderPreferenceRepository,
      now: () => _fixtureNow,
      loadWindow: () => store.readTransaction.run(() async {
        final facts = await store.recordHubRepository!.getAllFacts();
        return projectComfortWindow(
          const ComfortWindowEngine().analyze(
            periods: await store.periodRepository.getAll(),
            symptoms: await store.healthRecordRepository.getAll(),
            impacts: facts
                .map((fact) => fact.impact)
                .whereType<DailyImpactRecord>(),
            moments: await store.momentCheckInRepository.getAll(),
            programmes: await store.programmeRepository!.getAll(),
            today: _today,
          ),
        );
      }),
    ),
    entitlementRepository: entitlement,
    reportPort: _SyntheticReportPort(),
    youPort: _SyntheticYouPort(),
    recordHubRepository: store.recordHubRepository,
    interventionsRepository: store.interventionsRepository,
    programmeRepository: store.programmeRepository,
    readTransaction: store.readTransaction,
    now: () => _fixtureNow,
    onCycleDataChanged: () async {},
  ),
);

final class _NativeArtifacts {
  _NativeArtifacts(this.binding, this.directory) {
    binding.reportData = {
      'nativeVisualArtifactDirectory': directory.path,
      'nativeVisualManifest': path.join(directory.path, 'manifest.json'),
      'nativeScreenshotCount': 0,
      'sourceBaseline': 'Build17 cf12e70',
      'reviewDevice': 'review7A',
      'expectedScreenshotCount': _expectedFrames,
      'revision': 'Record V3 shared component and Stage',
      'productionFingerprint': _productionFingerprint,
      'plannedStates': _captureStates,
      'motionSamples': _motionSamples,
      'childPreviewRoute':
          'Actual typed editor pushed from Record with isolated repository and selected date; cancel/discard only',
      'databaseSchemaVersion': _observedSchemaVersion,
      'expectedDatabaseSchemaVersion': _schemaVersion,
      'canvasArgb': _build17Canvas.toARGB32(),
    };
  }
  final IntegrationTestWidgetsFlutterBinding binding;
  final Directory directory;
  final List<Map<String, Object>> images = [];
  final Map<String, List<int>> _sentinelFrames = {};
  Future<void> capture(
    WidgetTester tester,
    String state, {
    required double textScale,
    Duration wait = const Duration(milliseconds: 100),
  }) async {
    await tester.pump(wait);
    await tester.runAsync(
      () => binding.waitUntilFirstFrameRasterized.timeout(
        const Duration(seconds: 10),
      ),
    );
    expect(binding.firstFrameRasterized, isTrue);
    // Persist the native frame for one batched visual review even on failure.
    // The final zero-exception assertion remains a required acceptance gate.
    _collectRenderException(tester);
    final name = '${Platform.isIOS ? 'ios' : 'android'}-$state';
    final bytes = await binding.takeScreenshot(name);
    expect(bytes.length, greaterThan(24));
    expect(bytes.take(8).toList(), [137, 80, 78, 71, 13, 10, 26, 10]);
    final png = ByteData.sublistView(Uint8List.fromList(bytes));
    final width = png.getUint32(16, Endian.big);
    final height = png.getUint32(20, Endian.big);
    expect(width, greaterThan(0));
    expect(height, greaterThan(0));
    await File(
      path.join(directory.path, '$name.png'),
    ).writeAsBytes(bytes, flush: true);
    images.add({
      'file': '$name.png',
      'pixelWidth': width,
      'pixelHeight': height,
      'textScale': textScale,
      'devicePixelRatio': tester.view.devicePixelRatio,
      'logicalWidth':
          tester.view.physicalSize.width / tester.view.devicePixelRatio,
      'logicalHeight':
          tester.view.physicalSize.height / tester.view.devicePixelRatio,
    });
    // The driver transports native PNGs to its host callback without printing
    // their byte arrays. Plain flutter test exports the isolated temp files.
    if (!_hostDriver) binding.reportData?.remove('screenshots');
    binding.reportData?['nativeScreenshotCount'] = images.length;
    binding.reportData?['nativeImages'] = images;
    binding.reportData?['nativePlatform'] = Platform.operatingSystem;
    await _manifest();
    const phase = '1x';
    if (state == '$phase-today-default' ||
        state == '$phase-record-default' ||
        state == '$phase-moment-all12') {
      _sentinelFrames[state] = bytes;
    }
    final today = _sentinelFrames['$phase-today-default'];
    final record = _sentinelFrames['$phase-record-default'];
    final calendar = _sentinelFrames['$phase-moment-all12'];
    if (today != null && record != null && calendar != null) {
      expect(
        !listEquals(today, record) &&
            !listEquals(today, calendar) &&
            !listEquals(record, calendar),
        isTrue,
        reason:
            'Native Today, Record and Moment sheet frames must be distinct; '
            'a repeated launch screen or stale native window is not acceptance.',
      );
    }
  }

  Future<void>
  _manifest() => File(path.join(directory.path, 'manifest.json')).writeAsString(
    const JsonEncoder.withIndent('  ').convert({
      'fixture': 'entirely synthetic',
      'sourceBaseline': 'Build17 cf12e70',
      'reviewDevice': 'review7A',
      'expectedScreenshotCount': _expectedFrames,
      'revision': 'Record V3 shared component and Stage',
      'productionFingerprint': _productionFingerprint,
      'plannedStates': _captureStates,
      'motionSamples': _motionSamples,
      'childPreviewRoute':
          'Actual typed editor pushed from Record with isolated repository and selected date; cancel/discard only',
      'databaseSchemaVersion': _observedSchemaVersion,
      'expectedDatabaseSchemaVersion': _schemaVersion,
      'canvasArgb': _build17Canvas.toARGB32(),
      'platform': Platform.operatingSystem,
      'capture': 'native integration_test captureScreenshot',
      'renderExceptionCount': _renderExceptionCount,
      'images': images,
    }),
    flush: true,
  );
  Future<void> finish() async {
    await _manifest();
    binding.reportData = {
      ...?binding.reportData,
      'nativeVisualArtifactDirectory': directory.path,
      'nativeVisualManifest': path.join(directory.path, 'manifest.json'),
      'nativeScreenshotCount': images.length,
      'renderExceptionCount': _renderExceptionCount,
      'nativeImages': images,
      'nativePlatform': Platform.operatingSystem,
      'sourceBaseline': 'Build17 cf12e70',
      'reviewDevice': 'review7A',
      'expectedScreenshotCount': _expectedFrames,
      'revision': 'Record V3 shared component and Stage',
      'productionFingerprint': _productionFingerprint,
      'plannedStates': _captureStates,
      'motionSamples': _motionSamples,
      'childPreviewRoute':
          'Actual typed editor pushed from Record with isolated repository and selected date; cancel/discard only',
      'databaseSchemaVersion': _observedSchemaVersion,
      'expectedDatabaseSchemaVersion': _schemaVersion,
      'canvasArgb': _build17Canvas.toARGB32(),
    };
  }
}

final class _SyntheticYouPort implements YouExperiencePort {
  @override
  AuthState get account => const AuthState(status: AuthStatus.offlineOrExpired);
  @override
  PrivacyPreferences get privacy => const PrivacyPreferences();
  @override
  Stream<AuthState> watchAccount() => const Stream.empty();
  @override
  Future<void> savePrivacy(PrivacyPreferences preferences) async {}
  @override
  Future<void> signOut() async {}
  @override
  Future<void> deleteServerAccount() async {}
}

final class _SyntheticReportPort implements ReportExperiencePort {
  @override
  Future<SummaryExportInput> load() async => const SummaryExportInput(
    periodDays: [],
    predictions: [],
    healthRecords: [],
    checkIns: [],
    careRecords: [],
    notes: [],
  );
  @override
  Future<ExperienceFileReceipt> export({
    required SummaryDateRange range,
    required Set<String> selectedNoteIds,
    required ReportExportFormat format,
  }) async =>
      const ExperienceFileReceipt(outcome: ExperienceFileOutcome.cancelled);
}
