import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/analytics/data/dev_analytics_service.dart';
import 'package:letter_mobile/features/analytics/domain/analytics_service.dart';
import 'package:letter_mobile/features/auth/data/dev_auth_service.dart';
import 'package:letter_mobile/features/auth/domain/auth_service.dart';

DateTime _t() => DateTime.utc(2026);

void main() {
  group('AnalyticsService schema validation', () {
    test('allows operational events with safe properties', () {
      final payload = AnalyticsPayload(
        event: AnalyticsEvent.appOpened,
        properties: {'platform': 'ios', 'version': '1.0.0'},
        timestamp: _t(),
      );
      expect(payload.validate(), isNull);
    });

    test('rejects events with cycle date keys', () {
      final payload = AnalyticsPayload(
        event: AnalyticsEvent.appOpened,
        properties: {'cycleDate': '2026-07-30'},
        timestamp: _t(),
      );
      expect(payload.validate(), contains('cycleDate'));
    });

    test('rejects events with symptom keys', () {
      final payload = AnalyticsPayload(
        event: AnalyticsEvent.appOpened,
        properties: {'symptom': 'cramps'},
        timestamp: _t(),
      );
      expect(payload.validate(), contains('symptom'));
    });

    test('rejects events with care mode keys', () {
      final payload = AnalyticsPayload(
        event: AnalyticsEvent.appOpened,
        properties: {'careMode': 'heavy', 'careOutcome': 'better'},
        timestamp: _t(),
      );
      final violations = payload.validate()!;
      expect(violations, containsAll(['careMode', 'careOutcome']));
    });

    test('rejects events with pain or health record keys', () {
      final payload = AnalyticsPayload(
        event: AnalyticsEvent.routeLoadFailed,
        properties: {'painRating': 5, 'healthRecord': 'x', 'report': 'y'},
        timestamp: _t(),
      );
      expect(payload.validate()!.length, 3);
    });

    test('empty properties are valid', () {
      final payload = AnalyticsPayload(
        event: AnalyticsEvent.exportCompleted,
        properties: {},
        timestamp: _t(),
      );
      expect(payload.validate(), isNull);
    });
  });

  group('DevAnalyticsService', () {
    test('starts disabled and buffers events', () async {
      final service = DevAnalyticsService();
      expect(service.isEnabled, isFalse);
      await service.track(AnalyticsPayload(
        event: AnalyticsEvent.appOpened,
        properties: {'platform': 'test'},
        timestamp: _t(),
      ));
    });

    test('enable flushes buffered events', () async {
      final service = DevAnalyticsService();
      await service.track(AnalyticsPayload(
        event: AnalyticsEvent.appOpened,
        properties: {'platform': 'test'},
        timestamp: _t(),
      ));
      await service.enable();
      expect(service.isEnabled, isTrue);
    });

    test('rejects health-data payloads silently', () async {
      final service = DevAnalyticsService();
      await service.enable();
      await service.track(AnalyticsPayload(
        event: AnalyticsEvent.appOpened,
        properties: {'symptom': 'cramps'},
        timestamp: _t(),
      ));
    });

    test('disable clears buffer', () async {
      final service = DevAnalyticsService();
      await service.track(AnalyticsPayload(
        event: AnalyticsEvent.appOpened,
        properties: {},
        timestamp: _t(),
      ));
      await service.disable();
      expect(service.isEnabled, isFalse);
    });
  });

  group('DevAuthService', () {
    test('starts anonymous', () {
      final service = DevAuthService();
      expect(service.current.status, AuthStatus.anonymous);
      expect(service.current.isAuthenticated, isFalse);
    });

    test('signIn sets authenticated state', () async {
      final service = DevAuthService();
      final state = await service.signIn(email: 'test@letter.app');
      expect(state.status, AuthStatus.authenticated);
      expect(state.email, 'test@letter.app');
      expect(state.userId, isNotNull);
    });

    test('signUp sets authenticated state', () async {
      final service = DevAuthService();
      final state = await service.signUp(
        email: 'new@letter.app',
        password: 'password123',
      );
      expect(state.status, AuthStatus.authenticated);
      expect(state.email, 'new@letter.app');
    });

    test('signOut returns to anonymous', () async {
      final service = DevAuthService();
      await service.signIn();
      await service.signOut();
      expect(service.current.status, AuthStatus.anonymous);
    });

    test('deleteAccount returns to anonymous', () async {
      final service = DevAuthService();
      await service.signIn();
      await service.deleteAccount();
      expect(service.current.status, AuthStatus.anonymous);
    });

    test('watch emits state changes', () async {
      final service = DevAuthService();
      final states = <AuthState>[];
      final sub = service.watch().listen(states.add);
      await service.signIn();
      expect(states.length, 1);
      expect(states.single.status, AuthStatus.authenticated);
      await sub.cancel();
    });
  });
}
