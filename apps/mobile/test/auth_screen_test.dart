import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/auth/data/dev_auth_service.dart';
import 'package:letter_mobile/features/auth/domain/auth_service.dart';
import 'package:letter_mobile/features/auth/presentation/auth_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

void main() {
  testWidgets('Apple sign-in stays hidden until its provider is enabled', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final service = DevAuthService();

      await tester.pumpWidget(MaterialApp(home: AuthScreen(service: service)));
      expect(find.byKey(const Key('auth-apple')), findsNothing);

      await tester.pumpWidget(
        MaterialApp(
          home: AuthScreen(service: service, appleSignInEnabled: true),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('auth-apple')), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('magic link creates the required account state', (tester) async {
    final service = DevAuthService();
    await tester.pumpWidget(MaterialApp(home: AuthScreen(service: service)));

    await tester.enterText(
      find.byKey(const Key('auth-email')),
      'person@example.com',
    );
    await tester.tap(find.byKey(const Key('auth-magic-link')));
    await tester.pumpAndSettle();

    expect(service.current.status, AuthStatus.authenticated);
    expect(service.current.email, 'person@example.com');
    expect(find.byKey(const Key('auth-link-sent')), findsOneWidget);
    expect(find.text('Sign-in link sent'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('auth-magic-link')))
          .onPressed,
      isNull,
    );

    await tester.enterText(
      find.byKey(const Key('auth-email')),
      'another@example.com',
    );
    await tester.pump();
    expect(find.text('Email me a sign-in link'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('auth-magic-link')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('an existing account can sign in with a password', (
    tester,
  ) async {
    final service = DevAuthService();
    await tester.pumpWidget(MaterialApp(home: AuthScreen(service: service)));

    expect(find.byKey(const Key('auth-password')), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('auth-password-toggle')));
    await tester.tap(find.byKey(const Key('auth-password-toggle')));
    await tester.pump();

    await tester.enterText(
      find.byKey(const Key('auth-email')),
      'review@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('auth-password')),
      'review-password',
    );
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('auth-password-sign-in')));
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('auth-password-sign-in')))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const Key('auth-password-sign-in')));
    await tester.pumpAndSettle();

    expect(service.current.status, AuthStatus.authenticated);
    expect(service.current.email, 'review@example.com');
  });

  testWidgets('password sign-in starts disabled without credentials', (
    tester,
  ) async {
    final service = DevAuthService();
    await tester.pumpWidget(MaterialApp(home: AuthScreen(service: service)));
    await tester.ensureVisible(find.byKey(const Key('auth-password-toggle')));
    await tester.tap(find.byKey(const Key('auth-password-toggle')));
    await tester.pump();

    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('auth-password-sign-in')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('magic-link rate limit gives a specific retry message', (
    tester,
  ) async {
    final service = _ThrowingAuthService(
      const supabase.AuthException('rate limit', statusCode: '429'),
    );
    await tester.pumpWidget(MaterialApp(home: AuthScreen(service: service)));

    await tester.enterText(
      find.byKey(const Key('auth-email')),
      'person@example.com',
    );
    await tester.tap(find.byKey(const Key('auth-magic-link')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Too many sign-in emails were requested. Wait a few minutes and try again.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('reach the sign-in service'), findsNothing);
  });

  testWidgets('magic-link failure never exposes provider details', (
    tester,
  ) async {
    final service = _ThrowingAuthService(
      const supabase.AuthException('secret@example.com token=abc'),
    );
    await tester.pumpWidget(MaterialApp(home: AuthScreen(service: service)));

    await tester.enterText(
      find.byKey(const Key('auth-email')),
      'person@example.com',
    );
    await tester.tap(find.byKey(const Key('auth-magic-link')));
    await tester.pumpAndSettle();

    expect(find.textContaining('could not start sign-in'), findsOneWidget);
    expect(find.textContaining('secret@example.com'), findsNothing);
    expect(find.textContaining('token=abc'), findsNothing);
  });

  testWidgets('server-side email failure does not blame the connection', (
    tester,
  ) async {
    final service = _ThrowingAuthService(
      const supabase.AuthException(
        'unexpected_failure',
        statusCode: '500',
        code: 'unexpected_failure',
      ),
    );
    await tester.pumpWidget(MaterialApp(home: AuthScreen(service: service)));

    await tester.enterText(
      find.byKey(const Key('auth-email')),
      'person@example.com',
    );
    await tester.tap(find.byKey(const Key('auth-magic-link')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        "Letter Within's email service is temporarily unavailable. Please try again in a few minutes.",
      ),
      findsOneWidget,
    );
    expect(find.textContaining('reach the sign-in service'), findsNothing);
  });

  testWidgets('network auth failure does not guess at its cause', (
    tester,
  ) async {
    final service = _ThrowingAuthService(
      const supabase.AuthException(
        'ClientException: HandshakeException: connection terminated',
        code: 'retryable_fetch',
      ),
    );
    await tester.pumpWidget(MaterialApp(home: AuthScreen(service: service)));

    await tester.enterText(
      find.byKey(const Key('auth-email')),
      'person@example.com',
    );
    await tester.tap(find.byKey(const Key('auth-magic-link')));
    await tester.pumpAndSettle();

    expect(find.textContaining('reach the sign-in service'), findsOneWidget);
    expect(find.textContaining('VPN'), findsNothing);
    expect(find.textContaining('HandshakeException'), findsNothing);
  });

  testWidgets('timed-out auth request uses the shared service message', (
    tester,
  ) async {
    final service = _ThrowingAuthService(TimeoutException('provider details'));
    await tester.pumpWidget(MaterialApp(home: AuthScreen(service: service)));

    await tester.enterText(
      find.byKey(const Key('auth-email')),
      'person@example.com',
    );
    await tester.tap(find.byKey(const Key('auth-magic-link')));
    await tester.pumpAndSettle();

    expect(find.textContaining('reach the sign-in service'), findsOneWidget);
    expect(find.textContaining('VPN'), findsNothing);
    expect(find.textContaining('provider details'), findsNothing);
  });

  test('returning expired account keeps local-data access', () async {
    final service = DevAuthService();
    await service.signInWithApple();
    service.expireSession();

    expect(service.current.canOpenLocalData, isTrue);
    expect(service.current.requiresServerReauthentication, isTrue);
  });
}

final class _ThrowingAuthService implements AuthService {
  _ThrowingAuthService(this.error);

  final Object error;
  final _controller = StreamController<AuthState>.broadcast();

  @override
  AuthState get current => const AuthState(status: AuthStatus.signedOut);

  @override
  Future<void> deleteAccount() async {}

  @override
  Future<void> dispose() => _controller.close();

  @override
  Future<AuthState> initialize() async => current;

  @override
  Future<void> sendMagicLink(String email) => Future<void>.error(error);

  @override
  Future<void> signInWithPassword(String email, String password) =>
      Future<void>.error(error);

  @override
  Future<void> signInWithApple() => Future<void>.error(error);

  @override
  Future<void> signOut() async {}

  @override
  Stream<AuthState> watch() => _controller.stream;
}
