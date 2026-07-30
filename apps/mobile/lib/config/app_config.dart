/// Typed app configuration. Real values come from environment or a secrets
/// file at build time. Never commit real keys.
///
/// In production, replace the defaults via a build-time injection or a
/// platform-specific secure store. The dev defaults point at local-only
/// implementations so the app runs without any external service.
final class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabasePublishableKey,
    required this.revenueCatAppleApiKey,
    required this.revenueCatGoogleApiKey,
    required this.posthogApiKey,
    required this.posthogHost,
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

  bool get isConfigured => supabaseUrl.isNotEmpty;

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

  /// Production config for meetletter.app.
  /// Keys are placeholder until services are provisioned.
  static const meetletter = AppConfig(
    supabaseUrl: 'https://xliwvcbgwcguawffrmli.supabase.co',
    supabasePublishableKey: 'sb_publishable_GgnBqkhHhbzG762r9CThYw_XXlwqQcb',
    revenueCatAppleApiKey: '', // TODO: get from RevenueCat → Settings → API Keys
    revenueCatGoogleApiKey: '',
    posthogApiKey: '', // TODO: get from PostHog → Project Settings
    posthogHost: 'https://us.posthog.com',
  );
}
