import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:letter_mobile/experience/components/interaction_controls.dart';
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
import 'package:letter_mobile/features/record_hub/presentation/record_hub_screen.dart';
import 'package:letter_mobile/features/record_hub/presentation/record_entry_section.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

final _fixtureNow = DateTime(2026, 10, 9, 12);
const _today = LocalDate(2026, 10, 9);
const _key = '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff';
const _build17Canvas = Color(0xFF1E1224);
const _schemaVersion = 18;
const _captureStates = [
  '1x-today-pinned-order',
  '1x-today-pinned-full-screen',
  '1x-symptom-zero-saved',
  '1x-symptom-zero-removed',
  '1x-symptom-undo-restored',
  '1x-symptom-impact-saved',
  '1x-today-return-after-close',
  '1x-record-full-screen-scroll',
  '1x-today-bleeding-expanded',
];
final _expectedFrames = _captureStates.length;
const _productionFingerprint =
    '22fe6548ffde6378e4e327b1ce6576c77b9f0dc3eff5ae154cab72021eab7722';
const _hostDriver = bool.fromEnvironment('NATIVE_VISUAL_HOST_DRIVER');
var _renderExceptionCount = 0;
int? _observedSchemaVersion;

Finder _tab(String label) => find.byWidgetPredicate(
  (widget) => widget is Semantics && widget.properties.label == label,
);
Finder get _recordAction => _tab('Record today or another date');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('V5 Today shortcuts and full-page symptoms on isolated review7A', (
    tester,
  ) async {
    _renderExceptionCount = 0;
    _observedSchemaVersion = null;
    expect(Platform.isIOS, isTrue);
    expect(_productionFingerprint, isNot(startsWith('pending-')));
    expect(
      tester.view.physicalSize / tester.view.devicePixelRatio,
      const Size(402, 874),
    );
    final directory = await Directory(
      path.join(
        (await getTemporaryDirectory()).path,
        'record-hub-ui-pilot-v5-${DateTime.now().microsecondsSinceEpoch}',
      ),
    ).create(recursive: true);
    final database = File(path.join(directory.path, 'synthetic.sqlite'));
    LocalHealthStore openStore() => createNativeLocalHealthStoreForDatabase(
      databaseFile: database,
      loadKey: () async => _key,
      clock: () => _fixtureNow,
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
    const pins = [
      SymptomType.anxiety,
      SymptomType.cramps,
      SymptomType.headache,
    ];
    await store.recordHubRepository!.setPins(SymptomPins(pins));
    final originalZero = await store.healthRecordRepository.create(
      HealthRecordDraft(
        symptom: SymptomType.cramps,
        severity: SymptomSeverity.notPresent,
        experiencedDate: _today,
        provenance: HealthRecordProvenance.sameDay,
      ),
    );
    // Extra fictional saved rows give the normal Record catalog a real scroll.
    for (final symptom in [
      SymptomType.bloating,
      SymptomType.fatigue,
      SymptomType.irritability,
      SymptomType.lowMood,
      SymptomType.backPain,
    ]) {
      await store.healthRecordRepository.create(
        HealthRecordDraft(
          symptom: symptom,
          severity: SymptomSeverity.mild,
          experiencedDate: _today,
          provenance: HealthRecordProvenance.sameDay,
        ),
      );
    }
    await tester.pumpWidget(_nativeApp(store, entitlement, 1));
    await _settle(tester);
    final initialCount = (await store.healthRecordRepository.getAll()).length;
    final initialSources = await _sourceCollections(store);
    final anxiety = find.byKey(const Key('today-pinned-anxiety'));
    final cramps = find.byKey(const Key('today-pinned-cramps'));
    final headache = find.byKey(const Key('today-pinned-headache'));
    await _reach(tester, anxiety);
    expect(tester.widget<InteractionSurface>(anxiety).selected, isFalse);
    expect(tester.widget<InteractionSurface>(cramps).selected, isTrue);
    expect(tester.widget<InteractionSurface>(headache).selected, isFalse);
    expect(
      tester.widget<InteractionSurface>(anxiety).semanticLabel,
      contains('Not recorded'),
    );
    expect(
      tester.widget<InteractionSurface>(cramps).semanticLabel,
      contains('Not present'),
    );
    expect(
      tester.getTopLeft(anxiety).dx,
      lessThan(tester.getTopLeft(cramps).dx),
    );
    expect(
      tester.getTopLeft(cramps).dx,
      lessThan(tester.getTopLeft(headache).dx),
    );
    expect((await store.recordHubRepository!.getPins())!.symptoms, pins);
    final todayRoute = ModalRoute.of(tester.element(anxiety));
    await artifacts.capture(tester, '1x-today-pinned-order', textScale: 1);
    await _motionSignal(tester, 'start');
    await tester.tap(anxiety);
    await _settle(tester);
    _expectFullPage(tester);
    final shortcutRecord = tester.widget<RecordHubScreen>(
      find.byType(RecordHubScreen, skipOffstage: false),
    );
    expect(shortcutRecord.initialSymptom, SymptomType.anxiety);
    expect(shortcutRecord.returnAfterSymptomEdit, isTrue);
    expect(shortcutRecord.origin, RecordOrigin.today);
    expect(shortcutRecord.initialDate, _today);
    expect(
      await _sourceCollections(store),
      initialSources,
      reason: 'Opening a pinned symptom performs no source write.',
    );
    expect(_currentDegree(tester), 'Not recorded');
    await artifacts.capture(
      tester,
      '1x-today-pinned-full-screen',
      textScale: 1,
    );
    final zeroDegree = find.byKey(const Key('observation-degree-0'));
    await _tap(tester, zeroDegree);
    await _until(
      tester,
      () async =>
          (await store.healthRecordRepository.getAll()).length ==
          initialCount + 1,
    );
    final savedZero = (await store.healthRecordRepository.getAll()).singleWhere(
      (record) => record.symptom == SymptomType.anxiety,
    );
    expect(savedZero.severity, SymptomSeverity.notPresent);
    expect(savedZero.experiencedDate, _today);
    expect(savedZero.provenance, HealthRecordProvenance.sameDay);
    expect(
      savedZero.recordedAt.millisecondsSinceEpoch,
      _fixtureNow.millisecondsSinceEpoch,
    );
    expect(_currentDegree(tester), 'Not present');
    await artifacts.capture(tester, '1x-symptom-zero-saved', textScale: 1);
    await _tap(tester, zeroDegree);
    await _until(
      tester,
      () async =>
          (await store.healthRecordRepository.getAll()).length == initialCount,
    );
    expect(_currentDegree(tester), 'Not recorded');
    await artifacts.capture(tester, '1x-symptom-zero-removed', textScale: 1);
    await _tap(tester, find.text('Undo').last);
    await _until(
      tester,
      () async => (await store.healthRecordRepository.getAll()).any(
        (r) => r.id == savedZero.id,
      ),
    );
    final restored = (await store.healthRecordRepository.getAll()).singleWhere(
      (record) => record.id == savedZero.id,
    );
    expect(restored.severity, savedZero.severity);
    expect(restored.experiencedDate, savedZero.experiencedDate);
    expect(restored.recordedAt, savedZero.recordedAt);
    expect(restored.updatedAt, savedZero.updatedAt);
    expect(_currentDegree(tester), 'Not present');
    await artifacts.capture(tester, '1x-symptom-undo-restored', textScale: 1);
    await _tap(tester, find.byKey(const Key('observation-editor-impact')));
    await _tap(tester, find.text(FunctionalImpact.workOrSchool.label));
    await _tap(tester, find.text('Save impact'));
    await _until(
      tester,
      () async => (await store.healthRecordRepository.getAll()).any(
        (record) =>
            record.id == savedZero.id &&
            record.functionalImpacts.contains(FunctionalImpact.workOrSchool),
      ),
    );
    final impacted = (await store.healthRecordRepository.getAll()).singleWhere(
      (record) => record.id == savedZero.id,
    );
    expect(impacted.severity, SymptomSeverity.notPresent);
    expect(impacted.experiencedDate, _today);
    expect(impacted.recordedAt, savedZero.recordedAt);
    expect(impacted.functionalImpacts, {FunctionalImpact.workOrSchool});
    expect(
      (await store.recordHubRepository!.getDateFacts(_today)).impact,
      isNull,
    );
    await artifacts.capture(tester, '1x-symptom-impact-saved', textScale: 1);
    await _tap(tester, find.byKey(const Key('observation-editor-close')));
    expect(
      find.byKey(const Key('observation-fullscreen-editor')),
      findsNothing,
    );
    expect(find.byType(RecordHubScreen, skipOffstage: false), findsNothing);
    await _reach(tester, anxiety);
    expect(ModalRoute.of(tester.element(anxiety)), same(todayRoute));
    expect(tester.widget<InteractionSurface>(anxiety).selected, isTrue);
    expect(
      tester.widget<InteractionSurface>(anxiety).semanticLabel,
      contains('Not present'),
    );
    await artifacts.capture(
      tester,
      '1x-today-return-after-close',
      textScale: 1,
    );

    final sourcesAfterEdits = await _sourceCollections(store);
    await _tap(tester, _recordAction);
    final ordinaryRecord = tester.widget<RecordHubScreen>(
      find.byType(RecordHubScreen),
    );
    expect(ordinaryRecord.returnAfterSymptomEdit, isFalse);
    final recordRoute = ModalRoute.of(
      tester.element(find.byType(RecordHubScreen)),
    );
    final scroll = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byKey(const Key('record-workspace-scroll-symptoms')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(scroll.position.maxScrollExtent, greaterThan(0));
    scroll.position.jumpTo(math.min(80, scroll.position.maxScrollExtent));
    await _settle(tester);
    final target = find.byKey(const Key('observation-symptom-headache'));
    await _reach(tester, target);
    final priorOffset = scroll.position.pixels;
    expect(priorOffset, greaterThan(0));
    await tester.tap(target);
    await _settle(tester);
    _expectFullPage(tester);
    expect(_currentDegree(tester), 'Not recorded');
    await artifacts.capture(
      tester,
      '1x-record-full-screen-scroll',
      textScale: 1,
    );
    await _tap(tester, find.byKey(const Key('observation-editor-close')));
    expect(find.byType(RecordHubScreen), findsOneWidget);
    expect(
      ModalRoute.of(tester.element(find.byType(RecordHubScreen))),
      same(recordRoute),
    );
    expect(scroll.position.pixels, closeTo(priorOffset, .5));
    expect(await _sourceCollections(store), sourcesAfterEdits);
    await _doneRecord(tester);

    await _tap(tester, find.byKey(const Key('today-bleeding-shortcut')));
    final bleedingRecord = tester.widget<RecordHubScreen>(
      find.byType(RecordHubScreen),
    );
    expect(bleedingRecord.initialSection, RecordEntrySection.bleeding);
    expect(bleedingRecord.origin, RecordOrigin.today);
    expect(bleedingRecord.initialDate, _today);
    final none = find.byKey(const Key('record-flow-none'));
    await _reach(tester, none);
    expect(none.hitTestable(), findsOneWidget);
    expect(await _sourceCollections(store), sourcesAfterEdits);
    await artifacts.capture(tester, '1x-today-bleeding-expanded', textScale: 1);
    await _doneRecord(tester);
    expect(ModalRoute.of(tester.element(anxiety)), same(todayRoute));
    expect(await _sourceCollections(store), sourcesAfterEdits);
    await _motionSignal(tester, 'stop');
    await tester.pumpWidget(const SizedBox.shrink());
    await _settle(tester);
    await store.close();
    closed = true;
    final raw = sqlite3.open(database.path);
    try {
      raw.execute("PRAGMA key = '$_key';");
      _observedSchemaVersion = raw.userVersion;
      expect(_observedSchemaVersion, 18);
    } finally {
      raw.close();
    }
    final reopened = openStore();
    try {
      expect(await _sourceCollections(reopened), sourcesAfterEdits);
      expect((await reopened.recordHubRepository!.getPins())!.symptoms, pins);
      final records = await reopened.healthRecordRepository.getAll();
      expect(records.length, initialCount + 1);
      final keptZero = records.singleWhere(
        (record) => record.id == originalZero.id,
      );
      expect(keptZero.severity, SymptomSeverity.notPresent);
      expect(keptZero.updatedAt, originalZero.updatedAt);
      final finalAnxiety = records.singleWhere(
        (record) => record.id == savedZero.id,
      );
      expect(finalAnxiety.severity, SymptomSeverity.notPresent);
      expect(finalAnxiety.functionalImpacts, {FunctionalImpact.workOrSchool});
      expect(finalAnxiety.recordedAt, savedZero.recordedAt);
      expect(
        records.any((record) => record.symptom == SymptomType.headache),
        isFalse,
      );
    } finally {
      await reopened.close();
    }
    expect(_renderExceptionCount, 0);
    expect(
      artifacts.images.map((image) => image['file']).toList(),
      _captureStates.map((state) => 'ios-$state.png').toList(),
    );
    binding.reportData?.addAll({
      'pinnedOrderAndZeroVerified': true,
      'zeroRemovalUndoImpactVerified': true,
      'exactTodayReturnVerified': true,
      'ordinaryRecordScrollVerified': true,
      'bleedingOpeningCancellationVerified': true,
      'durableReopenVerified': true,
      'recordScrollOffset': priorOffset,
    });
    await artifacts.finish();
  });
}

void _expectFullPage(WidgetTester tester) {
  final page = find.byKey(const Key('observation-fullscreen-editor'));
  expect(page, findsOneWidget);
  expect(tester.getSize(page), const Size(402, 874));
  expect(find.byKey(const Key('observation-editor-date')), findsOneWidget);
}

String? _currentDegree(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const Key('observation-current-degree')))
    .data;

Future<String> _sourceCollections(LocalHealthStore store) async => jsonEncode(
  (await store.localBackupStore!.captureSnapshot()).collections
      .map((collection) => collection.toJson())
      .toList(),
);

Future<void> _reach(WidgetTester tester, Finder target) async {
  expect(target, findsOneWidget);
  await tester.ensureVisible(target);
  await _settle(tester);
  expect(target.hitTestable(), findsOneWidget);
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await _reach(tester, target);
  await tester.tap(target);
  await _settle(tester);
}

Future<void> _doneRecord(WidgetTester tester) async {
  await _tap(tester, find.widgetWithText(TextButton, 'Done').first);
  expect(find.byType(RecordHubScreen, skipOffstage: false), findsNothing);
}

Future<void> _until(WidgetTester tester, Future<bool> Function() ready) async {
  for (var attempt = 0; attempt < 12; attempt++) {
    await _settle(tester);
    if (await ready()) return;
  }
  fail('Synthetic source operation did not complete.');
}

Future<void> _settle(WidgetTester tester) async {
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
    debugPrint('Synthetic V5 fixture render exception: $issue');
  }
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
      expect(response.statusCode, 200);
    } finally {
      client.close(force: true);
    }
  });
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
      'revision': 'Record V5 Today shortcuts and full-page symptoms',
      'productionFingerprint': _productionFingerprint,
      'plannedStates': _captureStates,
      'entryRoute':
          'Actual Today pinned and Bleeding shortcuts plus ordinary Record; shared native full-page symptom writer',
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
    if (state == '1x-today-pinned-order' ||
        state == '1x-today-pinned-full-screen') {
      _sentinelFrames[state] = bytes;
    }
    final today = _sentinelFrames['1x-today-pinned-order'];
    final editor = _sentinelFrames['1x-today-pinned-full-screen'];
    if (today != null && editor != null) {
      expect(
        listEquals(today, editor),
        isFalse,
        reason:
            'Native Today and its full-page symptom editor must be distinct.',
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
      'revision': 'Record V5 Today shortcuts and full-page symptoms',
      'productionFingerprint': _productionFingerprint,
      'plannedStates': _captureStates,
      'entryRoute':
          'Actual Today pinned and Bleeding shortcuts plus ordinary Record; shared native full-page symptom writer',
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
      'revision': 'Record V5 Today shortcuts and full-page symptoms',
      'productionFingerprint': _productionFingerprint,
      'plannedStates': _captureStates,
      'entryRoute':
          'Actual Today pinned and Bleeding shortcuts plus ordinary Record; shared native full-page symptom writer',
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
