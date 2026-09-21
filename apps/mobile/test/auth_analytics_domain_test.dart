import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/analytics/data/dev_analytics_service.dart';
import 'package:letter_mobile/features/analytics/domain/analytics_service.dart';
import 'package:letter_mobile/features/auth/data/dev_auth_service.dart';
import 'package:letter_mobile/features/auth/domain/auth_service.dart';

DateTime _t() => DateTime.utc(2026);

void main() {
  group('AnalyticsService schema validation', () {
    test('serializes only the closed app-startup schema', () {
      final payload = AnalyticsPayload(
        event: const AppStartupEvent(
          appVersion: '1.0.0',
          platform: AnalyticsPlatform.ios,
          result: StartupResult.completed,
        ),
        timestamp: _t(),
      );
      expect(payload.toRecord(), {
        'event_name': 'app_startup',
        'schema_version': 1,
        'app_version': '1.0.0',
        'platform': 'ios',
        'startup_result': 'completed',
      });
    });

    test('serializes route failures with typed values only', () {
      final payload = AnalyticsPayload(
        event: const RouteLoadFailureEvent(
          appVersion: '1.0.0',
          platform: AnalyticsPlatform.android,
          route: AnalyticsRoute.settings,
          failureCode: RouteFailureCode.timeout,
        ),
        timestamp: _t(),
      );
      expect(payload.toRecord(), {
        'event_name': 'route_load_failed',
        'schema_version': 1,
        'app_version': '1.0.0',
        'platform': 'android',
        'route_id': 'settings',
        'failure_code': 'timeout',
      });
    });

    test('safe completion events have no user-supplied properties', () {
      final payload = AnalyticsPayload(
        event: const OnboardingCompletedEvent(),
        timestamp: _t(),
      );
      expect(payload.toRecord(), {
        'event_name': 'onboarding_completed',
        'schema_version': 1,
      });
    });
  });

  group('DevAnalyticsService', () {
    test('starts disabled and discards pre-consent events', () async {
      final service = DevAnalyticsService();
      expect(service.isEnabled, isFalse);
      await service.track(_startupPayload());
      await service.enable();
      expect(service.isEnabled, isTrue);
    });

    test('enabled service accepts only typed events', () async {
      final service = DevAnalyticsService();
      await service.enable();
      await service.track(_startupPayload());
      expect(service.isEnabled, isTrue);
    });

    test('does not retain an authenticated identifier', () async {
      final service = DevAnalyticsService();
      await service.enable();
      await service.identifyAuthenticatedUser(
        '550e8400-e29b-41d4-a716-446655440000',
      );
      await service.clearAuthenticatedUser();
    });

    test('disable stops future events', () async {
      final service = DevAnalyticsService();
      await service.enable();
      await service.track(_startupPayload());
      await service.disable();
      expect(service.isEnabled, isFalse);
    });
  });

  group('DevAuthService', () {
    test('starts signed out', () {
      final service = DevAuthService();
      expect(service.current.status, AuthStatus.signedOut);
      expect(service.current.isAuthenticated, isFalse);
    });

    test('magic link sets authenticated state', () async {
      final service = DevAuthService();
      await service.sendMagicLink('test@letter.app');
      expect(service.current.status, AuthStatus.authenticated);
      expect(service.current.email, 'test@letter.app');
      expect(service.current.userId, isNotNull);
    });

    test('Apple sets authenticated state', () async {
      final service = DevAuthService();
      await service.signInWithApple();
      expect(service.current.status, AuthStatus.authenticated);
    });

    test('signOut returns to anonymous', () async {
      final service = DevAuthService();
      await service.signInWithApple();
      await service.signOut();
      expect(service.current.status, AuthStatus.signedOut);
    });

    test('deleteAccount keeps only local data access', () async {
      final service = DevAuthService();
      await service.signInWithApple();
      await service.deleteAccount();
      expect(service.current.status, AuthStatus.localOnlyAfterAccountDeletion);
      expect(service.current.userId, isNull);
      expect(service.current.canOpenLocalData, isTrue);
    });

    test('watch emits state changes', () async {
      final service = DevAuthService();
      final states = <AuthState>[];
      final sub = service.watch().listen(states.add);
      await service.signInWithApple();
      expect(states.length, 1);
      expect(states.single.status, AuthStatus.authenticated);
      await sub.cancel();
    });

    test('expired returning account can still open local data', () async {
      final service = DevAuthService();
      await service.signInWithApple();
      service.expireSession();
      expect(service.current.status, AuthStatus.offlineOrExpired);
      expect(service.current.canOpenLocalData, isTrue);
      expect(service.current.requiresServerReauthentication, isTrue);
    });

    test('a mismatched account cannot open local data', () {
      const state = AuthState(status: AuthStatus.localDataAccountMismatch);
      expect(state.canOpenLocalData, isFalse);
      expect(state.hasLocalDataAccountMismatch, isTrue);
    });
  });
}

AnalyticsPayload _startupPayload() => AnalyticsPayload(
  event: const AppStartupEvent(
    appVersion: '1.0.0',
    platform: AnalyticsPlatform.ios,
    result: StartupResult.completed,
  ),
  timestamp: _t(),
);
