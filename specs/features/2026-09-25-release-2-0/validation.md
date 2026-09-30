# Release 2.0 Validation

Status: automated and native-Simulator run complete; SP6/LV3 replacement art
installed and visually verified; qualified clinical review and final
physical-device validation pending

Last automated run: 2026-09-30

- `flutter test --no-pub --concurrency=4`: 646 passed, 1 skipped by its existing platform
  condition.
- `uv run pytest`: 30 passed for the API.
- `uv run ruff format --check .`, `uv run ruff check .`, and strict Pyright:
  all API checks passed.
- `flutter analyze`: no issues.
- iPhone 17 Simulator native-storage acceptance: 3 passed (default-key
  reopen, SQLCipher plaintext/wrong-key/backup behavior, and schema-10
  migration).
- The approved Care handoff manifest retains SHA-256
  `37dc669e3621c80da1dd31b1c0277a71068f388e0563dbe51d4216a3a400b572`;
  20 of 24 mapped product targets still match their approved hashes. The four
  intentional divergences are `care_experience.dart` (accessible action ink),
  `letter_experience_shell.dart` (Release 2 navigation/report wiring),
  `you_experience.dart` (denser disclosure sections and companion reset), and
  `privacy_preferences.dart` (restoring the local-only companion default).
  Thirteen of the 15 original illustrations plus the body, editorial-art, and
  toolkit implementations still match their approved hashes. The two expected
  illustration changes are the owner-supplied SP6/LV3 v3 locator replacements.
- Focused privacy validation passed after removing the obsolete iOS Face ID
  usage description and Android biometric permission; Screen Cover remains.
- `plutil -lint ios/Runner/Info.plist` and `git diff --check` passed.
- `flutter build ios --simulator --debug` and `flutter build apk --debug`
  passed. The iOS build installed and launched on the booted iPhone 17
  simulator; smoke evidence is stored at
  `apps/mobile/.artifacts/release-2-validation/launch-smoke-2026-09-29.png`.
- Automated contrast checks now lock body ink at 4.5:1 and chart/hairline
  boundaries at 3:1 across Dusk, Deep Dusk, Care refuge depths, and warm paper.
  Multi-stop coral action surfaces now use a dedicated action gradient and
  dark-plum ink that meets 4.5:1 at every gradient stop; decorative embers
  retain the original deeper gradient.

## Automated

- Comfort Window classification, eligibility, candidate enumeration, support,
  lift, confidence, tie-breaking, projection, and suppression fixtures pass.
- Current-cycle exclusion, record edit/delete recomputation, time-zone changes,
  restart determinism, and reminder cancellation pass.
- Today and Settings reminder tests cover reliable-gate silence, explicit
  opt-in, stored `Not now`, 0/1/2-day timing, 09:00 copy, disabling, and 200%
  text scaling.
- Comfort Kit eligibility, ordering, lifecycle, remove/replace/suppress, and
  entitlement boundaries pass.
- Quick note history/edit/delete and explicit Kit inclusion pass; all free text
  is absent from prediction inputs.
- Database migration and backup/restore preserve existing records and generated
  reports.
- The most recent three months retain a limited free in-app factual preview.
  Tests require paid Plus for longer/custom/all ranges and for Visit Summary,
  raw CSV, and Clinical Pattern Report file generation. No-card Preview may
  unlock in-app depth but cannot generate files; every export rechecks live
  entitlement in both presentation and the production file port.
- Analytics payload tests prove absence of account ids, health fields, dates,
  free text, Care mode/outcome/duration, and per-use timestamps.
- Navigation and deep-link tests prove four tabs and Settings/report
  reachability. Notification destinations dismiss Settings, Reports, and modal
  sheets through `maybePop`; a refusing `PopScope` keeps the current draft and
  does not switch the hidden tab.
- Consent withdrawal opts PostHog out, closes native workers, and clears the
  exact file-backed project queues on iOS and Android. Ordinary app disposal
  closes workers without deleting consented queued events.
- iOS local health storage is excluded from system backup, receives data
  protection, and migrates the database key to a ThisDeviceOnly Keychain
  accessibility class. Android continues to declare backup disabled.
- Care journey coverage follows the Release 2 contract: My body needs care opens
  the symptom chooser before a self-paced practice, Everyday care opens its
  ritual list, and completion remains an explicit user action.
- Privacy-preference round trips include the optional local Care companion name.
- Companion tests cover unchanged, renamed, persisted, and explicitly cleared
  names; the name remains outside Care records, analytics, reports, and exports.
- A focused 121-test regression batch covers empty data, one incomplete cycle,
  two completed cycles, multiple cycles, symptoms, Care check-backs, companion
  preference lifecycle, Reports entitlement transitions, and the acupressure
  journey. Five additional cross-layer tests use the same real Drift database
  behind production Today, Health Records, Patterns, Reports, and Comfort
  surfaces, including UI mutation followed by table and derived-view rechecks.
- Bleeding figures now pair color with dot, solid, ring, and hatch treatments;
  Pattern outcomes pair color with directional symbols; the in-app Twin Matrix
  pairs stable row colors with distinct shapes and direct labels.
- Custom Pattern chart points expose direct semantic labels, and the breathing
  options control now inherits Dynamic Type instead of disabling text scaling.
- New observations created while Cycle's day editor remains open retain their
  stable record identity immediately, so every saved symptom consistently
  exposes edit and delete actions without reopening the sheet.
- Care reflections and Cycle letters no longer impose or advertise a character
  limit. Long-text repository tests verify that authored writing is preserved
  exactly without truncation; blank submissions remain invalid.
- Care reflection and recovery sheets are dominant, non-dismissible writing
  surfaces so the underlying completion/exit actions do not compete for
  attention. The new warm-paper reflection desk and the unlocked in-app Twin
  Matrix have dedicated 390×844 visual baselines.
- Today keeps six immediate mood choices and moves lower-frequency choices
  behind `More`; Settings collapses backup and support detail by default; empty
  Patterns and Reports states include a direct route to Cycle.
- Two unreferenced alternate screens and the unused private Gravity Horizon
  legend/evidence helper block were removed after repository-wide usage checks:
  `patterns_experience.dart` and `today_experience_rebuilt.dart`.
- `dart format`, `flutter analyze`, `git diff --check`, focused tests, full
  `flutter test`, iOS Simulator build, and Android debug build pass. API code
  was not touched in this follow-up, so its previous pytest/lint/type results
  remain the applicable evidence.

## Visual And Native

- Fresh iOS screenshots cover all four destinations, Settings, reports,
  paywall, empty/loading/error states, and the complete Care manifest.
- The owner-supplied SP6/LV3 v3 locator assets were inspected at full size,
  300px width, in the iPhone 17 locator page, and in full-screen zoom. Evidence
  is under `apps/mobile/.artifacts/acupressure-v3-review/`; labels and landmarks
  remain unclipped and distinguishable. This visual QA is not clinical approval.
- The final smoke launch uses the current build on an iPhone 17 simulator. The
  current Today hierarchy, compact six-mood surface, navigation shell, and
  screen-cover-capable dark canvas render without clipping.
- Care coverage includes chooser; five active scenes; Explode held/closing/
  sealed; Physical selector plus four contexts; shared settled/check-back/
  reflection/completion states.
- Verify standard and large Dynamic Type, VoiceOver semantics, Reduce Motion,
  Increase Contrast, Quiet Dusk daylight legibility, safe areas, 44pt targets,
  keyboard, and compact supported iPhone widths. Simulator evidence does not
  substitute for a final physical-device daylight check.
- Verify one continuous background/surface system across onboarding, Today,
  Cycle, Patterns, Settings, report configuration, and every Care state. Care
  and Comfort may deepen the canvas but must not read as a separate app.
- Verify every text/background and control/background token pair with a contrast
  report; charts and state indicators remain understandable in grayscale.
- The revised in-app Twin Matrix was inspected through its seeded 390×844
  visual baseline; repeat on the physical device with Dynamic Type before
  release sign-off.
- Verify warm paper appears only for letters and in-app report reading, while
  exported clinician PDFs remain neutral, labeled, and grayscale-safe.
- The owner-approved Experience System and Impeccable review findings are
  integrated. No further generated redesign is required for this validation
  pass.

## Release Boundaries

- No real user data appears in fixtures or screenshots.
- SP6 and LV3 remain visible optional traditional point-location self-care
  entries. Their restrained claims and safety screen do not replace review.
  Final locator art, point text, self-pressure guidance, and safety copy require
  documented qualified clinical approval before shipping; unresolved location
  or safety findings block release of the affected content rather than silently
  hiding its approved entry.
- Navigation consumers must not assume the old `care-context-cramps` direct
  entry or an automatically selected Everyday care ritual.
- No work is written into the Release 1 worktree or `/private/tmp`.
- No push, merge, deployment, App Store submission, or production PostHog/
  RevenueCat mutation occurs without a separate explicit instruction.
