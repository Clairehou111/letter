# Letter Within Mobile

Flutter application for Letter Within's iOS and Android clients.

## Commands

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter run
```

Running without service configuration uses the local development adapters. It
keeps the complete tracking and Care experience available, and the local Plus
adapter can exercise the premium loop without contacting a store.

For a configured build, copy `config/release.example.json` to an ignored local
file, replace the placeholders with public client keys, and run:

```bash
flutter run --dart-define-from-file=config/release.local.json
```

Use separate RevenueCat configuration for development and store distribution:

- local debug builds may use a RevenueCat Test Store `test_...` key;
- iOS TestFlight/App Store releases must use the iOS `appl_...` key;
- Android Play releases must use the Android `goog_...` key.

TestFlight still sends purchases to Apple's sandbox when the production iOS
key is used, so testers are not charged. Release startup validation rejects
Test Store keys to prevent uploading a build that RevenueCat will terminate.

The configured build requires an account and uses Supabase Auth, RevenueCat,
and optional consent-gated PostHog analytics. Never put a Supabase service-role
key or another server secret in this file. RevenueCat products and the
`letter_plus` entitlement must also exist in the store and RevenueCat
dashboards before real purchases can succeed.

`LETTER_APPLE_SIGN_IN_ENABLED` defaults to `false`. Set it to `true` only after
the Apple provider and callback are fully configured in Supabase; otherwise the
app deliberately hides the Apple button.

Mobile release builds fail closed when the target platform's public Supabase or
RevenueCat values are missing. Android release builds also require an upload
keystore: copy `android/key.properties.example` to the ignored
`android/key.properties`, provide the private signing values locally, then run
`flutter build appbundle --dart-define-from-file=config/release.local.json`.
Debug builds keep using the local adapters and normal debug signing.

Build iOS archives through the checked release wrapper so production defines
cannot be omitted:

```bash
tool/build_ios_release.sh --build-number=7
```

Today reads the real encrypted local health repositories (Drift +
SQLite3MultipleCiphers on native, memory-only on the Web preview). Health
records never leave the device unless a feature specification defines a
purpose-specific consent boundary.

The generated API client is located at
`lib/api/generated/letter_api_client.dart`. Regenerate it from the repository
root after updating the FastAPI contract.
