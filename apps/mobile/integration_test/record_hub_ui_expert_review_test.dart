import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:letter_mobile/experience/letter_experience_shell.dart';
import 'package:letter_mobile/experience/theme/experience_foundation.dart';
import 'package:letter_mobile/experience/cycle/cycle_experience.dart';
import 'package:letter_mobile/experience/care/care_experience.dart';
import 'package:letter_mobile/experience/reports/reports_experience.dart';
import 'package:letter_mobile/experience/reports/letter_report_experience_port.dart';
import 'package:letter_mobile/experience/you/you_experience.dart';
import 'package:letter_mobile/experience/today/today_experience.dart';
import 'package:letter_mobile/features/entitlement/presentation/entitlement_scope.dart';
import 'package:letter_mobile/features/auth/domain/auth_service.dart';
import 'package:letter_mobile/features/comfort_kit/application/comfort_experience_controller.dart';
import 'package:letter_mobile/features/entitlement/data/local_entitlement_repository.dart';
import 'package:letter_mobile/features/health_data/data/local_health_store.dart';
import 'package:letter_mobile/features/health_data/data/local_health_store_factory_native.dart';
import 'package:letter_mobile/features/patterns/data/repository_pattern_source.dart';
import 'package:letter_mobile/features/privacy/domain/privacy_preferences.dart';
import 'package:letter_mobile/features/record_hub/domain/record_hub_facts.dart';
import 'package:letter_mobile/features/record_hub/domain/comfort_window.dart';
import 'package:letter_mobile/features/record_hub/domain/comfort_window_projection.dart';
import 'package:letter_mobile/features/record_hub/presentation/record_hub_screen.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

const _build17Canvas = Color(0xFF1E1224);
const _schemaVersion = 18;
const _fixtureRevision = 4;
// Historical review walk: only the retired preparation journey is maintained
// here. Other older interactions have not been revalidated against V3. The
// current native acceptance walk is record_hub_ui_pilot_test.dart.
const _fixtureMaintenanceStatus =
    'Historical review partial maintenance only; other older interactions '
    'not validated against V3. Revision 4 is not evidence of a runnable '
    'current walk. Current native acceptance uses the new UI pilot fixture.';
const _capturePlanChanges = {
  'removedState': 'review-22b-preparation-plan',
  'replacementState': 'review-22b-comfort-kit',
  'plannedCaptureCountDelta': 0,
  'reason':
      'Preparation plan entrance was retired; use the existing Comfort Kit journey.',
};
const _hostDriver = true;
const _today = LocalDate(2026, 10, 9);
const _key = '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff';
final _fixtureNow = DateTime(2026, 10, 9, 12);
var _writeNow = _fixtureNow;
var _renderExceptionCount = 0;
final _issues = <String>[];
var _retiredPreparationEntranceAbsent = false;

Finder _tab(String label) => find
    .byWidgetPredicate((w) => w is Semantics && w.properties.label == label)
    .hitTestable();
Finder get _record => find
    .byWidgetPredicate(
      (w) =>
          w is Semantics &&
          w.properties.label == 'Record today or another date',
    )
    .hitTestable();

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'Native Build17 UI expert review, isolated synthetic sources and normal iPhone',
    (tester) async {
      expect(Platform.isIOS, isTrue);
      final directory = await Directory(
        path.join(
          (await getTemporaryDirectory()).path,
          'ui-expert-review-${DateTime.now().microsecondsSinceEpoch}',
        ),
      ).create(recursive: true);
      final store = createNativeLocalHealthStoreForDatabase(
        databaseFile: File(path.join(directory.path, 'synthetic.sqlite')),
        loadKey: () async => _key,
        clock: () => _writeNow,
      );
      // This local deterministic paid state demonstrates Clinical UI only.
      // No RevenueCat purchase, entitlement mutation or network call takes place.
      final entitlement = LocalEntitlementRepository(
        initial: const EntitlementState(status: EntitlementStatus.activePaid),
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await store.close();
        await entitlement.dispose();
      });
      await _seed(store);
      final artifacts = _NativeArtifacts(binding, directory);
      Future<void> capture(String name) =>
          artifacts.capture(tester, 'review-$name', textScale: 1);
      Future<void> reset() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(_app(store, entitlement));
        await _settle(tester);
      }

      Future<void> section(String name, Future<void> Function() run) async {
        await reset();
        try {
          await run();
        } catch (error) {
          _issues.add('$name: ${error.runtimeType}: $error');
        }
        binding.reportData?['interactionIssues'] = _issues;
      }

      await section('Today More drawer', () async {
        await _scrollTo(
          tester,
          find.text('More'),
          find.byType(TodayExperience),
        );
        await capture('01c-today-moment-section');
        await tester.tap(find.text('More'));
        await _settle(tester);
        await capture('01d-today-more-moment-drawer');
      });
      await section('Today and Record', () async {
        await capture('01-today');
        await tester.tap(_record);
        await tester.pump(const Duration(milliseconds: 120));
        await capture('01b-record-route-opening');
        await _settle(tester);
        await capture('02-record-top');
        await tester.tap(find.byKey(const Key('record-date')));
        await _settle(tester);
        await capture('03-day-calendar');
        final previous = find.byKey(
          const Key('record-calendar-previous-month'),
        );
        final pointer = await tester.startGesture(tester.getCenter(previous));
        await tester.pump(const Duration(milliseconds: 130));
        await capture('04-calendar-month-pressed');
        await pointer.up();
        await _settle(tester);
        await capture('05-calendar-month-released');
        await tester.tap(find.byKey(const Key('record-calendar-next-month')));
        await _settle(tester);
        await tester.tap(
          find.byKey(const Key('record-calendar-day-2026-10-07')),
        );
        await _settle(tester);
        await capture('06-record-historical');
        final cramps = find.widgetWithText(ActionChip, 'Cramps').first;
        await tester.ensureVisible(cramps);
        await tester.tap(cramps);
        await _settle(tester);
        await capture('07-symptom-picker');
        final zero = find.text('Not present').first;
        await tester.ensureVisible(zero);
        final choicePointer = await tester.startGesture(tester.getCenter(zero));
        await tester.pump(const Duration(milliseconds: 130));
        await capture('08-degree-choice-pressed');
        await choicePointer.up();
        await _settle(tester);
        await capture('09-degree-choice-released');
        await _scrollTo(
          tester,
          find.text('Daily impact').first,
          find.byType(RecordHubScreen),
        );
        await capture('09b-record-impact');
        await _scrollTo(
          tester,
          find.text('Bleeding').first,
          find.byType(RecordHubScreen),
        );
        await capture('09c-record-bleeding');
        await _scrollTo(
          tester,
          find.byKey(const Key('record-note')),
          find.byType(RecordHubScreen),
        );
        await capture('10-record-lower-note-and-history');
        await tester.enterText(
          find.byKey(const Key('record-note')),
          'Fictional historical note for private UI review.',
        );
        FocusManager.instance.primaryFocus?.unfocus();
        await _settle(tester);
        await tester.ensureVisible(find.text('Save note'));
        await capture('10b-note-save-enabled');
        final savePointer = await tester.startGesture(
          tester.getCenter(find.text('Save note')),
        );
        await tester.pump(const Duration(milliseconds: 130));
        await capture('10c-note-save-pressed');
        await savePointer.up();
        await _settle(tester);
        await capture('10d-note-save-released');
        await _scrollTo(
          tester,
          find.widgetWithText(OutlinedButton, 'Sleep'),
          find.byType(RecordHubScreen),
        );
        await tester.tap(find.widgetWithText(OutlinedButton, 'Sleep'));
        await _settle(tester);
        await capture('11-sleep-editor');
      });
      await section('Cycle and period editor', () async {
        await tester.tap(_tab('Cycle'));
        await _settle(tester);
        await capture('12-cycle');
        final edit = find.widgetWithText(OutlinedButton, 'Edit dates').first;
        await _scrollTo(tester, edit, find.byType(CycleExperience));
        await tester.tap(edit);
        await tester.pump(const Duration(milliseconds: 120));
        await capture('12b-period-editor-opening');
        await _settle(tester);
        await capture('13-existing-period-start-end-editor');
        final start = find.widgetWithText(OutlinedButton, '2026-10-03');
        final dateButtons = find.byType(OutlinedButton).hitTestable();
        await tester.tap(start.evaluate().isEmpty ? dateButtons.first : start);
        await _settle(tester);
        await capture('14-period-start-material-date-picker');
        await tester.tap(find.text('Cancel').last);
        await _settle(tester);
        await tester.tap(find.byType(OutlinedButton).hitTestable().last);
        await _settle(tester);
        await capture('15-period-end-material-date-picker');
      });
      await section('Care journey', () async {
        await tester.tap(_tab('Care'));
        await _settle(tester);
        await capture('16-care-landing');
        await tester.tap(
          find
              .byWidgetPredicate(
                (w) =>
                    w is Semantics &&
                    (w.properties.label?.startsWith('I want to explode.') ??
                        false),
              )
              .hitTestable()
              .first,
        );
        await _settle(tester);
        await capture('17-care-active-scene');
        if (find.byKey(const Key('care-scene-menu')).evaluate().isNotEmpty) {
          await tester.tap(find.byKey(const Key('care-scene-menu')));
          await _settle(tester);
          await capture('18-care-scene-controls');
        }
        await tester.tap(
          find.byKey(const Key('care-break-complete')).hitTestable(),
        );
        await _settle(tester);
        await capture('19-care-completed-checkback');
      });
      await section('Patterns and programme', () async {
        await tester.tap(_tab('Patterns'));
        await _settle(tester);
        await capture('20-patterns-top');
        final scroll = find.byType(Scrollable).hitTestable().first;
        await tester.drag(scroll, const Offset(0, -600));
        await _settle(tester);
        await capture('21-patterns-lower');
        final programmeEntrance = find
            .byKey(const Key('pattern-record-entrance'))
            .hitTestable();
        await tester.tap(programmeEntrance);
        await _settle(tester);
        await capture('22-optional-programme');
      });
      await section(
        'Retired preparation entrance and existing Comfort Kit',
        () async {
          await tester.tap(_tab('Patterns'));
          await _settle(tester);
          expect(
            find.byKey(const Key('preparation-plan-entrance')),
            findsNothing,
          );
          expect(find.text('Preparation plan'), findsNothing);
          _retiredPreparationEntranceAbsent = true;
          binding.reportData?['retiredPreparationEntranceAbsent'] = true;
          await tester.tap(_tab('Care'));
          await _settle(tester);
          final kit = find.text('Your comfort kit');
          await _scrollTo(tester, kit, find.byType(CareExperience));
          await tester.tap(kit.hitTestable().first);
          await _settle(tester);
          expect(
            find.text('Things that helped before, kept close.'),
            findsOneWidget,
          );
          await capture('22b-comfort-kit');
          await tester.tap(find.text('Back to care').hitTestable().first);
          await _settle(tester);
          expect(
            find.text('Things that helped before, kept close.'),
            findsNothing,
          );
        },
      );
      await section('Settings and reports', () async {
        await tester.tap(find.byTooltip('Settings').hitTestable().first);
        await _settle(tester);
        await capture('23-settings-top');
        await _scrollTo(
          tester,
          find.text('Clinician reports'),
          find.byType(YouExperience),
        );
        await capture('24-settings-reports-and-local-tools');
        await tester.tap(find.text('Clinician reports'));
        await _settle(tester);
        await capture('25-reports-factual-top');
        await tester.tap(
          find.widgetWithText(ChoiceChip, 'Clinical pattern report'),
        );
        await _settle(tester);
        await capture('26-reports-clinical-top');
        // The matrix comes from the actual source-selected report port and
        // full completed cycle spans. The fixture does not fabricate its model.
        await _scrollTo(
          tester,
          find.text('Cyclical symptom matrix'),
          find.byType(ReportsExperience),
        );
        await capture('27-reports-clinical-matrix');
      });
      binding.reportData?['interactionIssues'] = _issues;
      binding.reportData?['entitlementFixture'] =
          'Synthetic local activePaid through global EntitlementScope for actual Patterns/Clinical UI review only; no real purchase';
      binding.reportData?['motionObservation'] =
          'Pointer-down 130ms and released frames for calendar month and symptom degree; scene completion uses actual user-facing Enough control, not forced timers';
      await artifacts.finish();
      expect(_renderExceptionCount, 0);
      expect(artifacts.images.length, greaterThanOrEqualTo(18));
      expect(
        _issues,
        isEmpty,
        reason:
            'Review fixture interactions need correction; preserved images remain usable with manifest limitations.',
      );
    },
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 250)),
  );
  await tester.pump(const Duration(milliseconds: 700));
  _collectRenderException(tester);
}

void _collectRenderException(WidgetTester tester) {
  if (tester.takeException() != null) _renderExceptionCount++;
}

Future<void> _scrollTo(WidgetTester tester, Finder target, Finder scope) async {
  final scroll = find
      .descendant(of: scope, matching: find.byType(Scrollable))
      .first;
  await tester.scrollUntilVisible(
    target,
    400,
    scrollable: scroll,
    maxScrolls: 45,
  );
  await _settle(tester);
}

Future<void> _seed(LocalHealthStore store) async {
  final starts = [
    const LocalDate(2026, 7, 15),
    const LocalDate(2026, 8, 12),
    const LocalDate(2026, 9, 9),
    const LocalDate(2026, 10, 3),
  ];
  for (final start in starts) {
    await store.periodRepository.create(
      PeriodDraft(startDate: start, endDate: start.addDays(4)),
      today: _today,
    );
  }
  _writeNow = DateTime(2026, 7, 15, 12);
  await store.programmeRepository!.enroll(
    startDate: starts.first,
    symptoms: [SymptomType.cramps, SymptomType.anxiety],
  );
  await store.recordHubRepository!.setPins(
    SymptomPins([SymptomType.cramps, SymptomType.anxiety]),
  );
  for (final start in starts) {
    for (final offset in [-8, -5, -3, -1, 0, 1, 4, 7]) {
      final date = start.addDays(offset);
      if (date.isAfter(_today)) continue;
      _writeNow = DateTime(date.year, date.month, date.day, 12);
      await store.healthRecordRepository.create(
        HealthRecordDraft(
          symptom: SymptomType.cramps,
          severity: offset >= -5 && offset < 0
              ? SymptomSeverity.moderate
              : SymptomSeverity.notPresent,
          experiencedDate: date,
          provenance: HealthRecordProvenance.sameDay,
        ),
      );
      await store.recordHubRepository!.upsertImpact(
        DailyImpactDraft(
          experiencedDate: date,
          overall: offset >= -5 && offset < 0 ? 3 : 0,
        ),
      );
    }
  }
  _writeNow = _fixtureNow;
  await store.recordHubRepository!.upsertSleep(
    SleepDraft(
      experiencedDate: const LocalDate(2026, 10, 7),
      quality: SleepQuality.restful,
      duration: RecordedDuration.bucket(DurationBucket.sleep5To7Hours),
    ),
  );
  await store.captureNoteStore.save(
    CaptureNote(
      id: 'expert-synthetic-note',
      text: 'Synthetic note for local UI review only.',
      source: CaptureSource.typed,
      createdAt: _fixtureNow,
      experiencedDate: _today,
      keepInComfortKit: true,
    ),
  );
  for (var i = 0; i < 2; i++) {
    final date = DateTime(2026, 9, 27 + i, 12);
    await store.careMemoryRepository.saveOutcome(
      CareActionCompletion(
        mode: CareMode.physical,
        actionId: 'warmth',
        actionLabel: 'Apply warmth',
        occurredAt: date,
      ),
      CareOutcome.better,
    );
  }
}

Widget _app(LocalHealthStore store, LocalEntitlementRepository entitlement) =>
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ExperienceFoundation.lightTheme(),
      builder: (context, child) =>
          EntitlementScope(repository: entitlement, child: child!),
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
                    .map((f) => f.impact)
                    .whereType<DailyImpactRecord>(),
                moments: await store.momentCheckInRepository.getAll(),
                programmes: await store.programmeRepository!.getAll(),
                today: _today,
              ),
            );
          }),
        ),
        entitlementRepository: entitlement,
        reportPort: LetterReportExperiencePort(
          periodRepository: store.periodRepository,
          careMemoryRepository: store.careMemoryRepository,
          healthRecordRepository: store.healthRecordRepository,
          momentCheckInRepository: store.momentCheckInRepository,
          captureNoteStore: store.captureNoteStore,
          entitlementRepository: entitlement,
          readTransaction: store.readTransaction,
          recordHubRepository: store.recordHubRepository,
          recordInterventionsRepository: store.interventionsRepository,
          now: () => _fixtureNow,
        ),
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
      'fixtureRevision': _fixtureRevision,
      'fixtureMaintenanceStatus': _fixtureMaintenanceStatus,
      'capturePlanChanges': _capturePlanChanges,
      'retiredPreparationEntranceAbsent': _retiredPreparationEntranceAbsent,
      'datePickerImplementation':
          'Flutter Material date picker in a native iOS app; not an iOS system date picker',
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

  Future<void>
  _manifest() => File(path.join(directory.path, 'manifest.json')).writeAsString(
    const JsonEncoder.withIndent('  ').convert({
      'fixture': 'entirely synthetic',
      'interactionIssues': _issues,
      'reviewPurpose':
          'Independent GPT UI review; normal iPhone/default type only',
      'sourceBaseline': 'Build17 cf12e70',
      'databaseSchemaVersion': _schemaVersion,
      'fixtureRevision': _fixtureRevision,
      'fixtureMaintenanceStatus': _fixtureMaintenanceStatus,
      'capturePlanChanges': _capturePlanChanges,
      'retiredPreparationEntranceAbsent': _retiredPreparationEntranceAbsent,
      'datePickerImplementation':
          'Flutter Material date picker in a native iOS app; not an iOS system date picker',
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
      'fixtureRevision': _fixtureRevision,
      'fixtureMaintenanceStatus': _fixtureMaintenanceStatus,
      'capturePlanChanges': _capturePlanChanges,
      'retiredPreparationEntranceAbsent': _retiredPreparationEntranceAbsent,
      'datePickerImplementation':
          'Flutter Material date picker in a native iOS app; not an iOS system date picker',
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
