# Encrypted Local Export And Import Validation

Status: validated (2026-08-04; Android smoke pass, post-upgrade iOS
build/install/launch/visual smoke validation, and native encrypted restore
acceptance complete; manual Files/share UX remains a release check)

- [x] Exported bytes contain no searchable plaintext health values.
- [x] Wrong key and tampered packages fail closed (integrity check).
- [x] Cancelled or failed imports do not alter existing records.
- [x] Replace and merge results match the preview exactly, including per-record change entries.
- [x] Merge correctly keeps the newer record by `updatedAt` timestamp; equal timestamps favour destination.
- [x] Per-record preview labels are derived from structured fields only — no free-text notes or impulse content leaked.
- [x] Migrations preserve stable IDs, dates, provenance, and deletion semantics.
- [x] No passphrase, package content, or health value enters logs or API calls.
- [x] Passphrase can be stored, reused, and forgotten via platform secure storage.
- [x] Export produces a timestamped filename and saves a local copy in the `letter/` subfolder.
- [x] The saved backup file—not a second temporary copy—is handed to the native
      destination sheet after local export; the user can choose an installed
      cloud provider or cancel.
- [x] In-app help dialog and `help.md` document the full export/import/merge workflow.
- [x] Analyzer and focused backup/export tests pass with `file_picker`
      `12.0.0-beta.7` and `share_plus` `13.1.0`. The former is pinned because
      stable 11.x does not register correctly with the current AGP 9 setup;
      the latter is pinned for `builtInKotlin=false` compatibility.
- [x] Native Android and iOS encrypted restore acceptance passes: wrong-key and
      tampered backups leave the destination unchanged, while a valid backup
      restores successfully.

Native restore evidence was exercised against the real encrypted local store on
an Android API 37 emulator (`emulator-5554`) and an iPhone 17 iOS 26.5
simulator. The same installed app was launched twice without reinstall; the
second launch recovered the secure database key and data, proving process-
restart persistence. The acceptance suite also verifies the real schema
10-to-11 migration and preserves the cycle-reflection `startingPeriodId`.
This validates storage and restore behavior, not the manual platform
Files/share UX.

Native smoke evidence: Android licenses accepted, NDK `28.2.13676358` repaired,
API 37 ARM64 Pixel emulator `emulator-5554` detected, and the debug APK was
successfully built, installed, and launched as `app.letterwithin`. The
Android onboarding screenshot was visually healthy and the startup
AndroidRuntime/Flutter error log was empty. After the file_picker/share_plus
upgrades, `flutter build ios --simulator` passed with deployment target 14.0;
`Runner.app` installed and launched on an iPhone 17 simulator, and the second
post-launch screenshot rendered onboarding correctly.
