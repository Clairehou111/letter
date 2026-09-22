# Validation checklist

- [x] A lifecycle transition to inactive, hidden, paused, or detached displays an
      opaque neutral cover before sensitive content can be shown in an app snapshot.
- [x] Device authentication is optional, persists locally, and fails closed.
- [x] Cycle Check-in defaults to enabled for a new preference record.
- [x] The scheduled day equals `predictedMensesEnd + 1` in local calendar time.
- [x] No prediction, disabled preference, or denied permission leaves no pending
      check-in.
- [x] Period mutations replace or cancel the previous pending check-in.
- [x] Notification copy and payload contain no health data and never say “late”.
- [x] A notification tap cannot bypass the app lock.
- [x] Existing cycle prediction tests remain unchanged and green.
- [x] Privacy and notification controls work at 320 logical pixels and 200% text.
- [x] `flutter analyze` passes.
- [x] Full `flutter test` passes (611 tests on 2026-08-08).
- [x] Native configuration passes Swift parse, plist lint, and Android XML lint.

Native validation notes:

- The post-upgrade iOS simulator build succeeded with deployment target 14.0;
  `Runner.app` installed and launched on an iPhone 17 simulator, and the
  second post-launch screenshot rendered onboarding correctly. This does not
  replace real-device, accessibility, or release validation.
- Android licenses are accepted, NDK `28.2.13676358` is repaired, and the API
  37 ARM64 Pixel emulator `emulator-5554` is available. The debug APK built and
  launched as `app.letterwithin`; the onboarding screenshot was visually
  healthy and the AndroidRuntime/Flutter startup log was empty.
