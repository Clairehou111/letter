/// Typed app configuration. Real values come from environment or a secrets
/// file at build time. Never commit real keys.
///
/// In production, replace the defaults via a build-time injection or a
/// platform-specific secure store. The dev defaults point at local-only
/// implementations so the app runs without any external service.
final class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.revenueCatAppleApiKey,
    required this.revenueCatGoogleApiKey,
    required this.posthogApiKey,
    required this.posthogHost,
  });

  /// Supabase project URL (e.g. https://xxx.supabase.co).
  final String supabaseUrl;

  /// Supabase anonymous key (public, safe in client code).
  final String supabaseAnonKey;

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
    supabaseAnonKey: '',
    revenueCatAppleApiKey: '',
    revenueCatGoogleApiKey: '',
    posthogApiKey: '',
    posthogHost: '',
  );
}
