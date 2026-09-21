/// Public service configuration injected with `--dart-define` at build time.
/// No environment-specific values are committed to the application bundle.
final class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabasePublishableKey,
    required this.revenueCatAppleApiKey,
    required this.revenueCatGoogleApiKey,
    required this.posthogApiKey,
    required this.posthogHost,
    this.appleSignInEnabled = false,
  });

  /// Supabase project URL (e.g. https://xxx.supabase.co).
  final String supabaseUrl;

  /// Supabase publishable key (starts with sb_publishable_).
  /// Safe in client code — access is enforced by Row-Level Security.
  final String supabasePublishableKey;

  /// RevenueCat public Apple API key.
  final String revenueCatAppleApiKey;

  /// RevenueCat public Google/Play API key.
  final String revenueCatGoogleApiKey;

  /// PostHog project API key (or empty string to disable).
  final String posthogApiKey;

  /// PostHog instance host (e.g. https://us.posthog.com).
  final String posthogHost;

  /// Whether the configured Supabase project is ready for Apple OAuth.
  /// Defaults off so an unavailable provider is never advertised to users.
  final bool appleSignInEnabled;

  bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

  bool get hasPostHog => posthogApiKey.isNotEmpty && posthogHost.isNotEmpty;

  /// Public client values that must exist before a mobile store build may run.
  /// PostHog stays optional because analytics is consent-gated and non-critical.
  List<String> missingMobileReleaseValues({
    required bool requireAppleRevenueCat,
    required bool requireGoogleRevenueCat,
  }) => [
    if (supabaseUrl.isEmpty) 'LETTER_SUPABASE_URL',
    if (supabasePublishableKey.isEmpty) 'LETTER_SUPABASE_PUBLISHABLE_KEY',
    if (requireAppleRevenueCat && revenueCatAppleApiKey.isEmpty)
      'LETTER_REVENUECAT_APPLE_API_KEY',
    if (requireGoogleRevenueCat && revenueCatGoogleApiKey.isEmpty)
      'LETTER_REVENUECAT_GOOGLE_API_KEY',
    if (requireAppleRevenueCat &&
        revenueCatAppleApiKey.isNotEmpty &&
        !revenueCatAppleApiKey.startsWith('appl_'))
      'LETTER_REVENUECAT_APPLE_API_KEY (must use the appl_ App Store key)',
    if (requireGoogleRevenueCat &&
        revenueCatGoogleApiKey.isNotEmpty &&
        !revenueCatGoogleApiKey.startsWith('goog_'))
      'LETTER_REVENUECAT_GOOGLE_API_KEY (must use the goog_ Play Store key)',
  ];

  static const authRedirectUrl = 'app.letterwithin://login-callback';

  static const fromEnvironment = AppConfig(
    supabaseUrl: String.fromEnvironment('LETTER_SUPABASE_URL'),
    supabasePublishableKey: String.fromEnvironment(
      'LETTER_SUPABASE_PUBLISHABLE_KEY',
    ),
    revenueCatAppleApiKey: String.fromEnvironment(
      'LETTER_REVENUECAT_APPLE_API_KEY',
    ),
    revenueCatGoogleApiKey: String.fromEnvironment(
      'LETTER_REVENUECAT_GOOGLE_API_KEY',
    ),
    posthogApiKey: String.fromEnvironment('LETTER_POSTHOG_PROJECT_TOKEN'),
    posthogHost: String.fromEnvironment(
      'LETTER_POSTHOG_HOST',
      defaultValue: 'https://us.i.posthog.com',
    ),
    appleSignInEnabled: bool.fromEnvironment(
      'LETTER_APPLE_SIGN_IN_ENABLED',
      defaultValue: false,
    ),
  );

  /// Dev-only config: all services run local/no-op. The app is fully
  /// functional without any external service.
  static const dev = AppConfig(
    supabaseUrl: '',
    supabasePublishableKey: '',
    revenueCatAppleApiKey: '',
    revenueCatGoogleApiKey: '',
    posthogApiKey: '',
    posthogHost: '',
  );
}
