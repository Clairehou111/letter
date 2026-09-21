import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/letter_app.dart';
import 'config/app_config.dart';
import 'features/auth/data/supabase_auth_service.dart';
import 'features/analytics/data/posthog_analytics_service.dart';
import 'features/entitlement/data/revenue_cat_entitlement_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const config = AppConfig.fromEnvironment;
  final isAppleMobile = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  final isGoogleMobile =
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  if (kReleaseMode && (isAppleMobile || isGoogleMobile)) {
    final missing = config.missingMobileReleaseValues(
      requireAppleRevenueCat: isAppleMobile,
      requireGoogleRevenueCat: isGoogleMobile,
    );
    if (missing.isNotEmpty) {
      throw StateError(
        'Missing public mobile release configuration: ${missing.join(', ')}',
      );
    }
  }
  if (!config.hasSupabase) {
    runApp(const LetterApp());
    return;
  }

  await Supabase.initialize(
    url: config.supabaseUrl,
    publishableKey: config.supabasePublishableKey,
  );
  final authService = SupabaseAuthService(
    client: Supabase.instance.client,
    redirectUrl: AppConfig.authRedirectUrl,
  );
  final analyticsService = PosthogAnalyticsService(
    projectToken: config.posthogApiKey,
    host: config.posthogHost,
  );
  final entitlementRepository = RevenueCatEntitlementRepository(
    appUserId: authService.current.userId ?? '',
    appleApiKey: config.revenueCatAppleApiKey,
    googleApiKey: config.revenueCatGoogleApiKey,
    store: isAppleMobile
        ? RevenueCatStore.apple
        : isGoogleMobile
        ? RevenueCatStore.google
        : null,
  );
  runApp(
    LetterApp(
      authService: authService,
      analyticsService: analyticsService,
      entitlementRepository: entitlementRepository,
      requireAuthentication: true,
      appleSignInEnabled: config.appleSignInEnabled,
    ),
  );
}
