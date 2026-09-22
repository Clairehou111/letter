# Angry And Overloaded Impulse Buffer Validation

Status: validated for shared logic, web preview, and native encrypted-storage
acceptance; manual product review remains separate

## Automated Checks

- [x] Shatter changes visibly on every tap
- [x] Shatter completes at 20 taps
- [x] Shatter completes after 20 seconds
- [x] Skip reaches the same low-stimulation transition
- [x] reduced motion preserves all state information
- [x] safety and exit remain available in every acute stage
- [x] empty and over-4,000-character drafts are rejected
- [x] unsealed drafts save, resume, and delete explicitly
- [x] review states the exact cooldown consequence
- [x] sealing uses exactly 24 hours from injected UTC time
- [x] locked content is absent from visible text and semantics
- [x] locked envelope shows remaining time
- [x] locked envelope can be deleted unopened after confirmation
- [x] ready envelope does not reveal content automatically
- [x] ready envelope can be kept sealed for another 24 hours
- [x] only Open privately reveals ready content
- [x] opened content can be edited and resealed
- [x] failed operations remain explicit and retryable
- [x] only one active impulse record is supported
- [x] native period and impulse repositories are configured to share one database
- [x] migration from schema 1 preserves period rows
- [x] Web repository is memory-only
- [x] no API, LLM, analytics, clinical score, or CareEvent is created
- [x] 320-pixel width at 200 percent text does not overflow
- [x] primary controls meet the 44-pixel target
- [x] angry-flow visual baselines are reviewed
- [x] repository-wide validation passes: API 6 tests, Flutter 100 tests
- [x] Flutter Web build passes

## Native Checks

- [x] iOS opens the shared encrypted database with SQLite3MultipleCiphers
  available
- [x] Android opens the shared encrypted database with SQLite3MultipleCiphers
  available
- [x] real schema 10-to-11 migration preserves period rows and the cycle
  reflection `startingPeriodId`
- [x] reopening with the secure key preserves records in the shared database
- [x] opening without the correct key cannot read the shared database
- [x] the encrypted file contains no searchable acceptance-test plaintext;
  focused repository tests separately cover private impulse-draft behavior
- [x] the secure key and encrypted data survive a second launch of the same
  installed app without reinstall

Native acceptance evidence was exercised on Android API 37 (`emulator-5554`)
and an iPhone 17 iOS 26.5 simulator using
`integration_test/native_storage_acceptance_test.dart`. Drift repository and
in-memory migration tests remain complementary; they are not the basis for
the device encryption claims above. The native acceptance sentinel is a
synthetic capture note, so this evidence proves the shared database boundary
rather than claiming a separately seeded impulse draft on each device.

## Evidence

- `python3 tools/validate.py`: passed
- API tests: 6 passed
- Flutter tests: 100 passed
- `flutter analyze`: no issues
- `flutter build web`: passed, including the Wasm dry run
- 390x844 Chromium review: onboarding, Today, Care gate, and six-impact
  Shatter scene rendered without blank output, overlap, or unstable controls
- reviewed goldens: `angry_shatter_390x844.png` and
  `angry_locked_390x844.png`

## Manual Product Review

1. Enter `I want to explode` and confirm the first tap changes only the crystal.
2. Complete and skip Shatter; confirm both stop on a quiet screen.
3. Draft raw text and confirm no recipient or send surface exists.
4. Read the seal consequence and confirm it does not promise external control.
5. Seal, leave Care, return, and confirm no draft text is visible.
6. Delete one locked envelope unopened.
7. Advance past 24 hours and confirm the envelope stays closed until requested.
8. Open privately, rewrite, and reseal.
9. Confirm other four Care entrances retain their finite shells.

## Merge Gate

- [x] the impulse buffer is local-first with native encryption configured
- [x] native encrypted-storage and migration verification is evidenced
- [x] the cooldown is honest, finite, and user-controlled
- [x] sealed content is not rendered before unlock
- [x] existing period data survives migration
- [x] no clinical inference or external transmission was added
- [x] local changes are committed
- [ ] user explicitly requests merge
