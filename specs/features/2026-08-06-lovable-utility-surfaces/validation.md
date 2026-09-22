# Validation

## Automated

- `flutter analyze`
- `flutter test`
- You opens Privacy, Backup, Welcome/privacy, and preserves bottom navigation.
- All Summary loading/failure states retain Back and retry paths.
- Backup success and restore commit success have persistent completion and Done.
- Restore cancel, invalid password/file, staged merge, staged replace, retry,
  discard, and commit preserve the existing data behavior.
- Summary custom range, note opt-in, Twin Matrix, PDF, and CSV outputs remain
  behaviorally equivalent to the pre-redesign implementation.
- Widget tests cover 320px width and 200% text for each redesigned family.

## Visual

- Compare production screens with the approved Lovable Flutter prototype at
  390x844, then inspect 320x700 and 200% text.
- Confirm no clipped text, unreachable action, hidden Back, fake toggle, or
  misleading backup/report wording.
- Confirm light/dark theme and reduced-motion behavior remain usable.

## Native

- [x] Rebuild and launch the current dependency set on an iOS Simulator after
      the file_picker/share_plus upgrades. The iOS deployment target is 14.0
      because of the file_picker requirement. `Runner.app` installed and
      launched on an iPhone 17 simulator; the post-launch second frame
      rendered onboarding correctly.
- [x] Android licenses accepted; NDK `28.2.13676358` repaired; API 37 ARM64
      Pixel emulator `emulator-5554` detected.
- [x] Debug APK built successfully and installed/launched as
      `app.letterwithin`.
- [x] Onboarding screenshot on Android was visually healthy.
- [x] AndroidRuntime/Flutter startup error log was empty.

## Results — 2026-08-06

- `flutter analyze`: passed with no issues.
- Focused utility tests: 21 passed.
- Full Flutter suite: 611 passed on 2026-08-08.
- Summary loading and failure states retain an explicit Back action.
- Privacy controls fit at 320px and 200% text.
- Updated only the intentional Summary 390x844 golden.
- `git diff --check`: passed.
- Post-upgrade iOS simulator build, install, launch, and visual onboarding
  validation passed on an iPhone 17 simulator.
- Android emulator startup evidence is now complete for this smoke pass;
  broader real-device, accessibility, and release validation remain pending.

## Dependency decisions

- `file_picker` remains pinned to `12.0.0-beta.7` because the official stable
  11.x line does not register correctly with the current AGP 9 setup.
- `share_plus` remains pinned to `13.1.0` because it is compatible with the
  project's `builtInKotlin=false` configuration.
- Analyzer and focused encrypted backup/export tests pass with these pins.
