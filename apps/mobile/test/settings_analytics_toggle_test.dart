import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/experience/experience_release_ports.dart';
import 'package:letter_mobile/experience/theme/experience_foundation.dart';
import 'package:letter_mobile/experience/you/you_experience.dart';
import 'package:letter_mobile/features/auth/domain/auth_service.dart';
import 'package:letter_mobile/features/comfort_kit/application/comfort_experience_controller.dart';
import 'package:letter_mobile/features/comfort_kit/domain/comfort_kit.dart';
import 'package:letter_mobile/features/comfort_window/domain/comfort_reminder_preference.dart';
import 'package:letter_mobile/features/comfort_window/domain/comfort_window.dart';
import 'package:letter_mobile/features/cycle/domain/cycle_prediction.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/local_backup/domain/local_backup_models.dart';
import 'package:letter_mobile/features/privacy/domain/privacy_preferences.dart';

void main() {
  testWidgets('anonymous analytics is explicit opt-in and reversible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final port = _YouPort();
    await tester.pumpWidget(
      MaterialApp(
        theme: ExperienceFoundation.lightTheme(),
        home: Scaffold(
          body: YouExperience(port: port, backupPort: const _BackupPort()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final row = find.byKey(const Key('analytics-consent-toggle'));
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    final toggle = find.descendant(of: row, matching: find.byType(Switch));

    expect(tester.widget<Switch>(toggle).value, isFalse);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(port.current.analyticsConsent, AnalyticsConsent.granted);
    expect(tester.widget<Switch>(toggle).value, isTrue);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(port.current.analyticsConsent, AnalyticsConsent.optedOut);
    expect(tester.widget<Switch>(toggle).value, isFalse);
  });

  testWidgets('About & support shows the support email', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ExperienceFoundation.lightTheme(),
        home: Scaffold(
          body: YouExperience(
            port: _YouPort(),
            backupPort: const _BackupPort(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final about = find.byKey(const Key('about-support-disclosure'));
    await tester.scrollUntilVisible(
      about,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('About & support'));
    await tester.pumpAndSettle();
    expect(find.text('support@letterwithin.app'), findsOneWidget);
  });

  testWidgets('iOS account deletion uses store-neutral billing copy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ExperienceFoundation.lightTheme().copyWith(
          platform: TargetPlatform.iOS,
        ),
        home: Scaffold(
          body: YouExperience(
            port: _YouPort(),
            backupPort: const _BackupPort(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete server account'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('keeps renewing until you cancel'),
      findsOneWidget,
    );
    expect(find.textContaining('If you have a subscription'), findsOneWidget);
    expect(find.textContaining('App Store'), findsNothing);
    expect(find.textContaining('Google Play'), findsNothing);
    expect(find.textContaining('Restore a previous purchase'), findsOneWidget);
    await tester.tap(find.text('Keep account'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Android account deletion uses store-neutral billing copy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ExperienceFoundation.lightTheme().copyWith(
          platform: TargetPlatform.android,
        ),
        home: Scaffold(
          body: YouExperience(
            port: _YouPort(),
            backupPort: const _BackupPort(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete server account'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('keeps renewing until you cancel'),
      findsOneWidget,
    );
    expect(find.textContaining('If you have a subscription'), findsOneWidget);
    expect(find.textContaining('Google Play'), findsNothing);
    expect(find.textContaining('App Store'), findsNothing);
    expect(find.textContaining('Restore a previous purchase'), findsOneWidget);
  });

  testWidgets('Comfort reminder opt-in stays on before evidence is reliable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var snapshot = _comfortSnapshot(reliable: false);
    final saves = <(bool, int)>[];

    Future<ComfortExperienceSnapshot> save({
      required bool enabled,
      required int leadDays,
    }) async {
      saves.add((enabled, leadDays));
      snapshot = _comfortSnapshot(
        reliable: false,
        reminder: ComfortReminderPreference(
          enabled: enabled,
          leadDays: leadDays,
          updatedAt: DateTime.utc(2026, 9, 25),
        ),
      );
      return snapshot;
    }

    await tester.pumpWidget(
      MaterialApp(
        theme: ExperienceFoundation.lightTheme(),
        home: Scaffold(
          body: YouExperience(
            port: _YouPort(),
            backupPort: const _BackupPort(),
            loadComfortExperience: () async => snapshot,
            saveComfortReminder: save,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final row = find.byKey(const Key('comfort-reminder-toggle'));
    await tester.scrollUntilVisible(
      row,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    final toggle = find.descendant(of: row, matching: find.byType(Switch));
    expect(tester.widget<Switch>(toggle).value, isFalse);
    expect(tester.widget<Switch>(toggle).onChanged, isNotNull);
    expect(find.textContaining('turn on now'), findsOneWidget);
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(saves.single, (true, 2));
    expect(tester.widget<Switch>(toggle).value, isTrue);
    expect(find.textContaining('no reminder is scheduled yet'), findsOneWidget);
    final timing = find.byKey(const Key('comfort-reminder-timing'));
    expect(timing, findsOneWidget);
    expect(
      tester
          .widget<InkWell>(
            find.descendant(of: timing, matching: find.byType(InkWell)),
          )
          .onTap,
      isNotNull,
    );
    await tester.ensureVisible(timing);
    await tester.tap(timing);
    await tester.pumpAndSettle();
    expect(find.text('Choose a quiet reminder'), findsOneWidget);
    await tester.tap(find.text('1 day before'));
    await tester.tap(find.byKey(const Key('save-comfort-reminder')));
    await tester.pumpAndSettle();
    expect(saves.last, (true, 1));
  });

  testWidgets('Comfort reminder timing is explicit and reversible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var snapshot = _comfortSnapshot(reliable: true);
    final saves = <(bool, int)>[];

    Future<ComfortExperienceSnapshot> save({
      required bool enabled,
      required int leadDays,
    }) async {
      saves.add((enabled, leadDays));
      snapshot = _comfortSnapshot(
        reliable: true,
        reminder: ComfortReminderPreference(
          enabled: enabled,
          leadDays: leadDays,
          updatedAt: DateTime.utc(2026, 9, 25),
        ),
      );
      return snapshot;
    }

    await tester.pumpWidget(
      MaterialApp(
        theme: ExperienceFoundation.lightTheme(),
        home: Scaffold(
          body: YouExperience(
            port: _YouPort(),
            backupPort: const _BackupPort(),
            loadComfortExperience: () async => snapshot,
            saveComfortReminder: save,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final row = find.byKey(const Key('comfort-reminder-toggle'));
    await tester.scrollUntilVisible(
      row,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final toggle = find.descendant(of: row, matching: find.byType(Switch));
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(saves.last, (true, 2));
    expect(find.textContaining('On —'), findsOneWidget);

    final timing = find.text('Timing');
    await tester.scrollUntilVisible(
      timing,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(timing);
    await tester.pumpAndSettle();
    final timingAction = find.descendant(
      of: find.byKey(const Key('comfort-reminder-timing')),
      matching: find.byType(InkWell),
    );
    expect(tester.widget<InkWell>(timingAction).onTap, isNotNull);
    await tester.tap(timingAction);
    await tester.pumpAndSettle();
    expect(find.text('Choose a quiet reminder'), findsOneWidget);
    await tester.tap(find.text('1 day before'));
    await tester.tap(find.byKey(const Key('save-comfort-reminder')));
    await tester.pumpAndSettle();
    expect(saves.last, (true, 1));
    expect(find.textContaining('1 day before · 09:00 local'), findsOneWidget);

    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(saves.last, (false, 1));
  });

  testWidgets('Comfort reminder remains usable at 200 percent text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final snapshot = _comfortSnapshot(
      reliable: true,
      reminder: ComfortReminderPreference(
        enabled: true,
        leadDays: 2,
        updatedAt: DateTime.utc(2026, 9, 25),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ExperienceFoundation.lightTheme(),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: YouExperience(
              port: _YouPort(),
              backupPort: const _BackupPort(),
              loadComfortExperience: () async => snapshot,
              saveComfortReminder:
                  ({required bool enabled, required int leadDays}) async =>
                      snapshot,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final row = find.byKey(const Key('comfort-reminder-toggle'));
    await tester.scrollUntilVisible(
      row,
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(row, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Care companion can be named, renamed, and removed locally', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final port = _YouPort(const PrivacyPreferences(careCompanionName: 'Miso'));

    await tester.pumpWidget(
      MaterialApp(
        theme: ExperienceFoundation.lightTheme(),
        home: Scaffold(
          body: YouExperience(port: port, backupPort: const _BackupPort()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final field = find.byKey(const Key('care-companion-name-field'));
    await tester.scrollUntilVisible(
      field,
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.widget<TextField>(field).controller?.text, 'Miso');
    var save = find.widgetWithText(FilledButton, 'Save name');
    expect(tester.widget<FilledButton>(save).onPressed, isNull);

    await tester.enterText(field, '  Nori  ');
    await tester.pump();
    save = find.widgetWithText(FilledButton, 'Save name');
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(port.current.careCompanionName, 'Nori');
    expect(tester.widget<TextField>(field).controller?.text, 'Nori');

    final remove = find.byKey(const Key('remove-care-companion-name'));
    expect(remove, findsOneWidget);
    expect(find.text('Remove name'), findsOneWidget);
    expect(find.textContaining('Use “Your cat” instead'), findsNothing);
    await tester.ensureVisible(remove);
    await tester.pumpAndSettle();
    final removeButton = tester.widget<TextButton>(remove);
    expect(removeButton.onPressed, isNotNull);
    removeButton.onPressed!();
    await tester.pumpAndSettle();
    expect(port.current.careCompanionName, isNull);
    expect(find.byKey(const Key('remove-care-companion-name')), findsNothing);
  });

  testWidgets(
    'low-frequency Settings sections stay collapsed until requested',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: ExperienceFoundation.lightTheme(),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: YouExperience(
                port: _YouPort(),
                backupPort: const _BackupPort(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Backup & restore'),
        260,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Backup & restore'));
      await tester.pumpAndSettle();
      expect(find.text('Create a backup'), findsNothing);
      await tester.tap(find.text('Backup & restore'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Create a backup'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Create a backup'), findsOneWidget);
      expect(find.text('Restore from a backup'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

ComfortExperienceSnapshot _comfortSnapshot({
  required bool reliable,
  ComfortReminderPreference reminder = const ComfortReminderPreference(),
}) {
  const today = LocalDate(2026, 9, 25);
  const kit = ComfortKitComposition(items: <ComfortKitItem>[]);
  const prediction = CyclePrediction(
    predictedMensesStart: LocalDate(2026, 10, 2),
    predictedMensesEnd: LocalDate(2026, 10, 5),
    midpoint: LocalDate(2026, 10, 3),
    medianCycleDays: 29,
    minimumCycleDays: 28,
    maximumCycleDays: 30,
    intervalCount: 4,
    confidence: PredictionConfidence.medium,
    predictedLutealStart: LocalDate(2026, 9, 17),
    predictedLutealEnd: LocalDate(2026, 9, 21),
  );
  final window = reliable
      ? const ComfortWindowPrediction(
          algorithmVersion: comfortWindowAlgorithmVersion,
          candidate: ComfortWindowCandidate(
            offsetStart: -5,
            offsetEnd: -1,
            votingCycleCount: 4,
            supportingCycleCount: 4,
            averageLift: 0.48,
            harderInsideDays: 10,
            confidence: ComfortWindowConfidence.clearer,
            cycles: <ComfortWindowCycleEvidence>[],
          ),
          forecastStart: LocalDate(2026, 9, 27),
          forecastEnd: LocalDate(2026, 10, 4),
          periodPrediction: prediction,
        )
      : null;
  return ComfortExperienceSnapshot(
    today: today,
    window: window,
    kit: kit,
    windowState: ComfortKitWindowState.resolve(
      kit: kit,
      today: today,
      forecastStart: window?.forecastStart,
      forecastEnd: window?.forecastEnd,
    ),
    reminder: reminder,
  );
}

final class _YouPort implements YouExperiencePort {
  _YouPort([this.current = const PrivacyPreferences()]);

  PrivacyPreferences current;

  @override
  AuthState get account =>
      const AuthState(status: AuthStatus.authenticated, userId: 'local-test');

  @override
  PrivacyPreferences get privacy => current;

  @override
  Stream<AuthState> watchAccount() => Stream<AuthState>.value(account);

  @override
  Future<void> savePrivacy(PrivacyPreferences preferences) async {
    current = preferences;
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<void> deleteServerAccount() async {}
}

final class _BackupPort implements BackupExperiencePort {
  const _BackupPort();

  @override
  String get localDestinationDescription => 'a local test folder';

  @override
  Future<bool> hasStoredPassphrase() async => false;

  @override
  Future<ExperienceFileReceipt> exportEncrypted({
    required String passphrase,
    required bool rememberPassphrase,
  }) async =>
      const ExperienceFileReceipt(outcome: ExperienceFileOutcome.cancelled);

  @override
  Future<LocalBackupImportPreview?> prepareImport({
    required String passphrase,
    required LocalBackupImportPolicy policy,
  }) async => null;

  @override
  Future<void> commitPreparedImport() async {}

  @override
  Future<void> discardPreparedImport() async {}
}
