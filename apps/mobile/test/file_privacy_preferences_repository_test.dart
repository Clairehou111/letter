import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/privacy/data/file_privacy_preferences_repository.dart';
import 'package:letter_mobile/features/privacy/domain/privacy_preferences.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'letter-privacy-preferences-test-',
    );
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('returns defaults before a file exists', () async {
    final repository = FilePrivacyPreferencesRepository(directory);

    expect(await repository.load(), const PrivacyPreferences());
  });

  test('persists privacy preferences between repository instances', () async {
    final first = FilePrivacyPreferencesRepository(directory);
    const preferences = PrivacyPreferences(
      appLockEnabled: true,
      screenCoverEnabled: false,
      cycleCheckInEnabled: false,
      notificationPermissionRequested: true,
      analyticsConsent: AnalyticsConsent.optedOut,
    );

    await first.save(preferences);
    final second = FilePrivacyPreferencesRepository(directory);

    expect(await second.load(), preferences);
  });

  test('uses safe defaults for a malformed file', () async {
    final file = File('${directory.path}/privacy_preferences.json');
    await file.writeAsString('not-json');

    final repository = FilePrivacyPreferencesRepository(directory);

    expect(await repository.load(), const PrivacyPreferences());
  });
}
