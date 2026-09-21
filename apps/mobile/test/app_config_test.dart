import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/config/app_config.dart';

void main() {
  const configured = AppConfig(
    supabaseUrl: 'https://example.supabase.co',
    supabasePublishableKey: 'sb_publishable_example',
    revenueCatAppleApiKey: 'appl_example',
    revenueCatGoogleApiKey: 'goog_example',
    posthogApiKey: '',
    posthogHost: '',
  );

  test('complete public mobile configuration has no missing values', () {
    expect(
      configured.missingMobileReleaseValues(
        requireAppleRevenueCat: true,
        requireGoogleRevenueCat: true,
      ),
      isEmpty,
    );
  });

  test('release guard requires Supabase and only the target store key', () {
    expect(
      AppConfig.dev.missingMobileReleaseValues(
        requireAppleRevenueCat: true,
        requireGoogleRevenueCat: false,
      ),
      [
        'LETTER_SUPABASE_URL',
        'LETTER_SUPABASE_PUBLISHABLE_KEY',
        'LETTER_REVENUECAT_APPLE_API_KEY',
      ],
    );
  });

  test('release guard rejects RevenueCat Test Store keys', () {
    const testStoreConfigured = AppConfig(
      supabaseUrl: 'https://example.supabase.co',
      supabasePublishableKey: 'sb_publishable_example',
      revenueCatAppleApiKey: 'test_example',
      revenueCatGoogleApiKey: 'test_example',
      posthogApiKey: '',
      posthogHost: '',
    );

    expect(
      testStoreConfigured.missingMobileReleaseValues(
        requireAppleRevenueCat: true,
        requireGoogleRevenueCat: false,
      ),
      ['LETTER_REVENUECAT_APPLE_API_KEY (must use the appl_ App Store key)'],
    );
    expect(
      testStoreConfigured.missingMobileReleaseValues(
        requireAppleRevenueCat: false,
        requireGoogleRevenueCat: true,
      ),
      ['LETTER_REVENUECAT_GOOGLE_API_KEY (must use the goog_ Play Store key)'],
    );
  });

  test('optional analytics is not a release requirement', () {
    expect(
      configured.missingMobileReleaseValues(
        requireAppleRevenueCat: false,
        requireGoogleRevenueCat: false,
      ),
      isEmpty,
    );
  });

  test('Apple sign-in fails closed unless explicitly enabled', () {
    expect(configured.appleSignInEnabled, isFalse);
    expect(AppConfig.dev.appleSignInEnabled, isFalse);
  });
}
