import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:letter_mobile/experience/letter_experience_shell.dart';
import 'package:letter_mobile/experience/theme/experience_foundation.dart';
import 'package:letter_mobile/features/auth/domain/auth_service.dart';
import 'package:letter_mobile/features/comfort_kit/application/comfort_experience_controller.dart';
import 'package:letter_mobile/features/patterns/data/repository_pattern_source.dart';
import 'package:letter_mobile/features/entitlement/data/local_entitlement_repository.dart';
import 'package:letter_mobile/features/health_data/data/local_health_store.dart';
import 'package:letter_mobile/features/health_data/data/local_health_store_factory_native.dart';
import 'package:letter_mobile/features/privacy/domain/privacy_preferences.dart';
import 'package:letter_mobile/features/record_hub/domain/record_hub_facts.dart';
import 'package:letter_mobile/features/record_hub/domain/comfort_window.dart';
import 'package:letter_mobile/features/record_hub/domain/comfort_window_projection.dart';
import 'package:letter_mobile/features/record_hub/domain/record_session.dart';
import 'package:letter_mobile/features/record_hub/presentation/record_context_editor.dart';
import 'package:letter_mobile/features/record_hub/presentation/record_hub_screen.dart';
import 'package:letter_mobile/features/record_hub/presentation/record_programme_screen.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

// Entirely fictional local sources. The fixture never opens the production DB.
final _fixtureNow = DateTime(2026, 10, 9, 12);
const _today = LocalDate(2026, 10, 9);
const _historical = LocalDate(2026, 10, 7);
const _key = '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff';
var _renderExceptionCount = 0;
const _hostDriver = bool.fromEnvironment('NATIVE_VISUAL_HOST_DRIVER');
// Owner scope: one normal iPhone viewport, default platform text size only.
const _build17Canvas = Color(0xFF1E1224);
const _schemaVersion = 18;

Finder _tab(String label) => find.byWidgetPredicate(
  (widget) => widget is Semantics && widget.properties.label == label,
);
Finder get _recordAction => find.byWidgetPredicate(
  (widget) =>
      widget is Semantics &&
      widget.properties.label == 'Record today or another date',
);
Finder _dateLabel(String text) => find.widgetWithText(OutlinedButton, text);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets(
    'V-03/05/27/29 native synthetic Record visual and source round-trip',
    (tester) async {
      _renderExceptionCount = 0;
      expect(
        Platform.isIOS || Platform.isAndroid,
        isTrue,
        reason:
            'This acceptance fixture must run in a native iOS or Android app.',
      );
      final directory = await Directory(
        path.join(
          (await getTemporaryDirectory()).path,
          'record-hub-visual-${DateTime.now().microsecondsSinceEpoch}',
        ),
      ).create(recursive: true);
      final databaseFile = File(path.join(directory.path, 'synthetic.sqlite'));
      LocalHealthStore openStore() => createNativeLocalHealthStoreForDatabase(
        databaseFile: databaseFile,
        loadKey: () async => _key,
        clock: () => _fixtureNow,
      );
      final store = openStore();
      final entitlement = LocalEntitlementRepository();
      final artifacts = _NativeArtifacts(binding, directory);
      var storeClosed = false;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        if (!storeClosed) await store.close();
        await entitlement.dispose();
      });

      await store.periodRepository.create(
        const PeriodDraft(
          startDate: LocalDate(2026, 10, 3),
          endDate: LocalDate(2026, 10, 5),
        ),
        today: _today,
      );
      await store.recordHubRepository!.setPins(
        SymptomPins([SymptomType.cramps, SymptomType.anxiety]),
      );
      // A real recalled source supplies the historical saved-record indicator.
      await store.recordHubRepository!.upsertImpact(
        DailyImpactDraft(experiencedDate: _historical, overall: 0),
      );
      HealthRecord? firstSymptom;
      SleepRecord? firstSleep;

      expect(ExperienceColors.canvas, _build17Canvas);
      for (final scale in [1.0]) {
        final phase = '${scale.toInt()}x';
        await tester.pumpWidget(_nativeApp(store, entitlement, scale));
        await _settle(tester);
        expect(
          Theme.of(
            tester.element(find.byType(LetterExperienceShell)),
          ).scaffoldBackgroundColor,
          _build17Canvas,
        );
        if (Platform.isAndroid && scale == 1) {
          // Current integration_test restores the surface in its own teardown.
          await binding.convertFlutterSurfaceToImage();
          await tester.pump();
        }
        for (final label in ['Today', 'Cycle', 'Care', 'Patterns']) {
          expect(_tab(label), findsOneWidget);
        }
        expect(
          tester.widget<Semantics>(_tab('Today')).properties.selected,
          isTrue,
        );
        expect(find.text('Fri, Oct 9'), findsWidgets);
        await artifacts.capture(
          tester,
          '$phase-today-default',
          textScale: scale,
        );

        await tester.tap(_recordAction);
        await _settle(tester);
        expect(find.byType(RecordHubScreen), findsOneWidget);
        expect(_dateLabel('Friday, October 9, 2026'), findsOneWidget);
        final record = tester.widget<RecordHubScreen>(
          find.byType(RecordHubScreen),
        );
        expect(record.origin, RecordOrigin.today);
        expect(record.initialDate, _today);
        expect(
          find.descendant(
            of: find.byType(RecordHubScreen),
            matching: find.text('More'),
          ),
          findsNothing,
        );
        await artifacts.capture(
          tester,
          '$phase-record-today',
          textScale: scale,
        );

        await tester.tap(find.byKey(const Key('record-date')));
        await _settle(tester);
        expect(
          find.byKey(const Key('record-calendar-day-2026-10-07')),
          findsOneWidget,
        );
        expect(
          tester
              .widget<InkWell>(
                find.byKey(const Key('record-calendar-day-2026-10-10')),
              )
              .onTap,
          isNull,
        );
        await artifacts.capture(tester, '$phase-calendar', textScale: scale);
        await tester.tap(
          find.byKey(const Key('record-calendar-day-2026-10-07')),
        );
        await _settle(tester);
        expect(_dateLabel('Wednesday, October 7, 2026'), findsOneWidget);
        expect(
          (await store.periodRepository.getAllFlowDays()).where(
            (flow) => flow.date == _historical,
          ),
          isEmpty,
        );
        await artifacts.capture(
          tester,
          '$phase-record-historical-nonbleeding',
          textScale: scale,
        );

        await tester.ensureVisible(
          find.widgetWithText(ActionChip, 'Cramps').first,
        );
        await tester.tap(find.widgetWithText(ActionChip, 'Cramps').first);
        await _settle(tester);
        await tester.ensureVisible(find.text('Not present').first);
        if (scale == 1) {
          await tester.tap(find.text('Not present').first);
          await _settle(tester);
        }
        final symptom = (await store.healthRecordRepository.getAll())
            .singleWhere(
              (source) =>
                  source.symptom == SymptomType.cramps &&
                  source.experiencedDate == _historical,
            );
        expect(symptom.severity, SymptomSeverity.notPresent);
        expect(symptom.provenance, HealthRecordProvenance.laterRecall);
        firstSymptom ??= symptom;
        expect(symptom.id, firstSymptom.id);
        expect(
          symptom.recordedAt.isAtSameMomentAs(firstSymptom.recordedAt),
          isTrue,
        );
        await artifacts.capture(
          tester,
          '$phase-record-explicit-zero',
          textScale: scale,
        );

        final sleepEntry = find.widgetWithText(OutlinedButton, 'Sleep');
        await tester.ensureVisible(sleepEntry);
        await tester.tap(sleepEntry);
        await _settle(tester);
        expect(find.byType(RecordContextEditor), findsOneWidget);
        expect(
          tester
              .widget<RecordContextEditor>(find.byType(RecordContextEditor))
              .date,
          _historical,
        );
        expect(find.text('Wednesday, October 7, 2026'), findsOneWidget);
        await artifacts.capture(
          tester,
          '$phase-sleep-child-inherited-date',
          textScale: scale,
        );
        if (scale == 1) {
          final childScroll = find
              .descendant(
                of: find.byType(RecordContextEditor),
                matching: find.byType(Scrollable),
              )
              .first;
          await tester.scrollUntilVisible(
            find.text('5 Restful'),
            200,
            scrollable: childScroll,
          );
          await tester.tap(find.text('5 Restful'));
          await tester.pump();
          await tester.scrollUntilVisible(
            find.text('Save sleep'),
            200,
            scrollable: childScroll,
          );
          await tester.tap(find.text('Save sleep'));
        } else {
          await tester.tap(find.byTooltip('Close editor'));
        }
        await _settle(tester);
        expect(find.byType(RecordContextEditor), findsNothing);
        expect(_dateLabel('Wednesday, October 7, 2026'), findsOneWidget);
        final sleep = (await store.recordHubRepository!.getDateFacts(
          _historical,
        )).sleep!;
        expect(sleep.value.quality, SleepQuality.restful);
        expect(sleep.metadata.provenance, HealthRecordProvenance.laterRecall);
        firstSleep ??= sleep;
        expect(sleep.id, firstSleep.id);

        await tester.tap(find.text('Done').last);
        await _settle(tester);
        expect(find.byType(RecordHubScreen), findsNothing);
        expect(
          tester.widget<Semantics>(_tab('Today')).properties.selected,
          isTrue,
        );
        expect(find.text('Fri, Oct 9'), findsWidgets);
        await tester.tap(_tab('Patterns'));
        await _settle(tester);
        if (await store.programmeRepository!.getCurrent() == null) {
          await store.programmeRepository!.enroll(
            startDate: _today,
            symptoms: [SymptomType.cramps, SymptomType.anxiety],
          );
        }
        // Capture the production optional programme widget as a native route.
        // This does not claim an onboarding or Patterns-entry navigation gate.
        final shellContext = tester.element(find.byType(LetterExperienceShell));
        Navigator.of(shellContext).push<void>(
          MaterialPageRoute(
            builder: (context) => Theme(
              data: ExperienceFoundation.lightTheme(),
              child: RecordProgrammeScreen(
                programmeRepository: store.programmeRepository!,
                healthRecordRepository: store.healthRecordRepository,
                recordHubRepository: store.recordHubRepository!,
                periodRepository: store.periodRepository,
                clock: () => _fixtureNow,
                onOpenRecord: (date, symptom) =>
                    Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => Theme(
                          data: ExperienceFoundation.lightTheme(),
                          child: RecordHubScreen(
                            healthRecordRepository:
                                store.healthRecordRepository,
                            captureNoteStore: store.captureNoteStore,
                            recordHubRepository: store.recordHubRepository,
                            interventionsRepository:
                                store.interventionsRepository,
                            periodRepository: store.periodRepository,
                            initialDate: date,
                            initialSymptom: symptom,
                            origin: RecordOrigin.patterns,
                            clock: () => _fixtureNow,
                          ),
                        ),
                      ),
                    ),
              ),
            ),
          ),
        );
        await _settle(tester);
        expect(find.byType(RecordProgrammeScreen), findsOneWidget);
        await artifacts.capture(
          tester,
          '$phase-optional-programme',
          textScale: scale,
        );
        Navigator.of(tester.element(find.byType(RecordProgrammeScreen))).pop();
        await _settle(tester);
        expect(
          tester.widget<Semantics>(_tab('Patterns')).properties.selected,
          isTrue,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      }

      await store.close();
      storeClosed = true;
      final reopened = openStore();
      try {
        final symptom = (await reopened.healthRecordRepository.getAll()).single;
        expect(symptom.id, firstSymptom!.id);
        expect(symptom.experiencedDate, _historical);
        expect(symptom.severity.score, 0);
        expect(symptom.provenance, firstSymptom.provenance);
        expect(symptom.originalProvenance, firstSymptom.originalProvenance);
        expect(symptom.writeZoneName, firstSymptom.writeZoneName);
        expect(
          symptom.writeZoneOffsetMinutes,
          firstSymptom.writeZoneOffsetMinutes,
        );
        expect(
          symptom.recordedAt.isAtSameMomentAs(firstSymptom.recordedAt),
          isTrue,
        );
        expect(
          symptom.updatedAt.isAtSameMomentAs(firstSymptom.updatedAt),
          isTrue,
        );
        final sleep = (await reopened.recordHubRepository!.getDateFacts(
          _historical,
        )).sleep!;
        expect(sleep.id, firstSleep!.id);
        expect(sleep.metadata.provenance, firstSleep.metadata.provenance);
        expect(
          sleep.metadata.originalProvenance,
          firstSleep.metadata.originalProvenance,
        );
        expect(
          sleep.metadata.originalWriteZoneId,
          firstSleep.metadata.originalWriteZoneId,
        );
        expect(
          sleep.metadata.recordedAt.isAtSameMomentAs(
            firstSleep.metadata.recordedAt,
          ),
          isTrue,
        );
        expect(
          (await reopened.programmeRepository!.getCurrent())!
              .configurations
              .single
              .symptoms,
          [SymptomType.cramps, SymptomType.anxiety],
        );
      } finally {
        await reopened.close();
      }
      await artifacts.finish();
      // flutter test removes its installed app after completion. Keep the
      // synthetic PNG container available briefly for the host evidence copy.
      if (!_hostDriver) {
        debugPrint('NATIVE_VISUAL_EXPORT_READY ${directory.path}');
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(seconds: 20)),
        );
      }
      expect(
        _renderExceptionCount,
        0,
        reason:
            'Native rendering raised exceptions. Review the persisted native PNGs before acceptance.',
      );
    },
  );
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
  if (tester.takeException() != null) _renderExceptionCount++;
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
    child: child!,
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
      'databaseSchemaVersion': _schemaVersion,
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
  }) async {
    await tester.pump(const Duration(milliseconds: 100));
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
    final phase = state.split('-').first;
    if (state == '$phase-today-default' ||
        state == '$phase-record-today' ||
        state == '$phase-calendar') {
      _sentinelFrames[state] = bytes;
    }
    final today = _sentinelFrames['$phase-today-default'];
    final record = _sentinelFrames['$phase-record-today'];
    final calendar = _sentinelFrames['$phase-calendar'];
    if (today != null && record != null && calendar != null) {
      expect(
        !listEquals(today, record) &&
            !listEquals(today, calendar) &&
            !listEquals(record, calendar),
        isTrue,
        reason:
            'Native Today, Record and calendar frames must be distinct; '
            'a repeated launch screen or stale native window is not acceptance.',
      );
    }
  }

  Future<void> _manifest() =>
      File(path.join(directory.path, 'manifest.json')).writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'fixture': 'entirely synthetic',
          'sourceBaseline': 'Build17 cf12e70',
          'databaseSchemaVersion': _schemaVersion,
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
      'databaseSchemaVersion': _schemaVersion,
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
