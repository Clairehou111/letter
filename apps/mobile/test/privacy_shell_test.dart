import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/privacy/domain/device_authenticator.dart';
import 'package:letter_mobile/features/privacy/domain/privacy_preferences.dart';
import 'package:letter_mobile/features/privacy/presentation/privacy_shell.dart';

final class FakeAuthenticator implements DeviceAuthenticator {
  bool result;
  int calls = 0;

  FakeAuthenticator(this.result);

  @override
  Future<bool> authenticate() async {
    calls += 1;
    return result;
  }

  @override
  Future<bool> canAuthenticate() async => true;
}

Widget app({
  required PrivacyPreferences preferences,
  required DeviceAuthenticator authenticator,
}) {
  return MaterialApp(
    home: PrivacyShell(
      preferences: preferences,
      ready: true,
      authenticator: authenticator,
      child: const Scaffold(body: Text('Sensitive cycle details')),
    ),
  );
}

void main() {
  testWidgets('covers content while inactive and uncovers on resume', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        preferences: const PrivacyPreferences(),
        authenticator: FakeAuthenticator(true),
      ),
    );
    expect(find.byKey(const Key('privacy-cover')), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.byKey(const Key('privacy-cover')), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byKey(const Key('privacy-cover')), findsNothing);
  });

  testWidgets('leaves content visible when screen cover is off', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        preferences: const PrivacyPreferences(screenCoverEnabled: false),
        authenticator: FakeAuthenticator(true),
      ),
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.byKey(const Key('privacy-cover')), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
  });

  testWidgets(
    'failed device authentication stays covered until retry succeeds',
    (tester) async {
      final authenticator = FakeAuthenticator(false);
      await tester.pumpWidget(
        app(
          preferences: const PrivacyPreferences(appLockEnabled: true),
          authenticator: authenticator,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('privacy-cover')), findsOneWidget);
      expect(find.byKey(const Key('unlock-letter')), findsOneWidget);

      authenticator.result = true;
      await tester.tap(find.byKey(const Key('unlock-letter')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('privacy-cover')), findsNothing);
      expect(authenticator.calls, 2);
    },
  );
}
