import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/privacy/domain/privacy_preferences.dart';
import 'package:letter_mobile/features/privacy/presentation/privacy_shell.dart';

Widget app({required PrivacyPreferences preferences}) {
  return MaterialApp(
    home: PrivacyShell(
      preferences: preferences,
      child: const Scaffold(body: Text('Sensitive cycle details')),
    ),
  );
}

void main() {
  testWidgets('covers content while inactive and uncovers on resume', (
    tester,
  ) async {
    await tester.pumpWidget(app(preferences: const PrivacyPreferences()));
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
      app(preferences: const PrivacyPreferences(screenCoverEnabled: false)),
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.byKey(const Key('privacy-cover')), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
  });
}
