# Release 2.0 Validation

Status: automated and native-Simulator run complete; SP6/LV3 replacement art
installed and visually verified; qualified clinical review and final
physical-device validation pending

Original Release 2.0 validation run: 2026-09-30. The latest CR follow-up is
recorded below.

## 2026-10-02 owner scope and PostHog configuration

- The owner retained the existing SP6/LV3 Care entry and the optional analytics
  control. The temporary compile-time gate, asset exclusion, and hidden-control
  work was discarded before commit; tracked source remains at Build 14 HEAD.
  Clinical review remains open for SP6/LV3 art, locations, instructions, and
  safety wording. The existing internal release requirement is not signed off.
- PostHog's empty `Default project` in the LetterHealth organization was
  renamed `Letter Within` (project ID `534876`, US Cloud). Its public project
  token and US ingestion host were added to this worktree's Git-ignored
  `apps/mobile/config/release.local.json`. Format, host, and required release
  fields were checked; no events were sent. Build 14 remains unconfigured.
- This is local configuration for a later archive, not a new build or device
  validation. Publish accurate optional-analytics policy text and update App
  Store Connect's privacy answers for the configured build before App Review.
  The current public policy and answers still reflect dormant PostHog.
- The owner reports updating the App Store Connect prices. The earlier read-only
  check found `letter_monthly` US $6.99 (target $7.99), `letter_yearly` US
  $29.99 (target $39.99), and `letter_lifetime` US $99.99 (already at target).
  App Store Connect's new prices still need a fresh storefront/device check.
  Only US and Canada were available storefronts at the earlier check.
- RevenueCat's current `letter_default` Offering maps the monthly, annual, and
  lifetime packages to both the Apple and Test Store product IDs, all attached
  to the `letter_plus` entitlement. The Test Store products were updated in
  place through the official RevenueCat CLI: `letter_monthly` USD $6.99 to
  $7.99, `letter_yearly` USD $29.99 to $39.99, and `letter_lifetime` USD $79.99
  to $99.99. Read-back of all three prices succeeded, and Offering verification
  still showed the same current Offering, product IDs, and entitlement. This
  changes Test Store prices only; Apple production prices come from App Store
  Connect/StoreKit. RevenueCat's Offering verification still returned an old
  Apple monthly USD $6.99 price and a yearly CNY price, so fresh device checks
  of localized StoreKit prices and purchase sheets remain required. The
  Offering verification also noted no attached RevenueCat-hosted paywall; the
  Flutter app uses its own Plus screen.
- App Store Connect's `1.0 Rejected` state refers to the September 30 review
  of old Build 12, not Build 14. Apple cited Google Play wording in the binary
  (2.3.10) and missing usable Privacy Policy / Terms of Use links in both the
  subscription purchase flow and metadata (3.1.2(c)). A later candidate needs
  direct verification of those fixes and accurate App Review notes before a
  new submission; no reply or resubmission was made here.

## 2026-10-01 Build 14 TestFlight handoff

- Build source: local `main` commit `1d8f540` (the integrated release commit is
  `4d67694`). Version is `1.0.0+14`; bundle ID is `app.letterwithin`.
- Final build preflight: `flutter analyze --no-pub` reported no issues;
  `flutter test --no-pub --concurrency=4 -r expanded` passed **684 tests,
  1 existing skip, 0 failures**. The signed IPA and archive report version
  1.0.0 (14), and deep code-signature verification passed. IPA SHA-256:
  `1ef6f7a8eb5d142aa51967c4744ed46c9ebb010486bb5b3b816ca17883f477a0`.
- Xcode Organizer reported **Letter Within 1.0.0 (14) uploaded**. App Store
  Connect's TestFlight Build Uploads row showed it received at Oct 1, 2026
  11:26 PM local time. After processing, the TestFlight build detail showed
  **Ready to Submit** and the existing Internal Testers group with two testers.
  This TestFlight status is not an App Review submission, and no physical-iPhone
  case has been executed in this handoff.
- The ordered physical-device cases and evidence format are in
  `physical-iphone-build-14-checklist.md`. No App Review submission, website
  edit, production PostHog/RevenueCat change, or git push occurred.

## 2026-10-01 integration sign-off (local source only)

- Integrated the UI audit commit `128ea8e` with the Today/Cycle and privacy
  follow-up. Cycle now computes the visible estimate from its completed local
  read on first load as well as after revisions, so two eligible starts do not
  briefly appear as forming while the shell's derived read is pending.
  Generation checks keep older Cycle day-editor and backfill reads, Plus plan
  retries, and the existing Today/Cycle/Shell/Care/Patterns reads from
  replacing newer state. Rapid Today mood choices serialize repository writes
  and keep only the latest choice visible.
- Both ordinary and out-of-order paths were exercised: initial two-start
  Cycle load, single revision and day-editor edit/delete, backfill day save,
  rapid revisions ending in deletion, sequential and rapid mood saves,
  ordinary Plus retry after a store error, account setup retry, Comfort Kit
  authored-item display, and onboarding load/retry and privacy goldens.
  The first integration full run exposed two stale Cycle test assumptions:
  one fallback fixture contained a valid interval, and one day-editor test
  needed to scroll to a now-lower row. Both tests were corrected and passed
  alone and in the final full run.
- Final `flutter analyze --no-pub`: no issues. Final
  `flutter test --no-pub --concurrency=4 -r expanded`: **684 passed, 1 existing
  skip, 0 failed**. `git diff --check`: clean. These results are from the
  integrated worktree after all source and test edits.
- The current source launched in an iOS 26.5 iPhone SE (3rd generation)
  Simulator debug session using `tool/manual_qa_app.dart`'s synthetic
  `tracker-cycle` frame. The Cycle ring and estimate rendered without a crash
  or persistent drawing artifact. This is a native layout smoke check; it does
  not exercise local encrypted storage, account login, or store transactions.
  The committed UI audit evidence covers a formal-app iPhone 17 Plus sheet
  and Comfort Kit, plus a Patterns large-text check. Onboarding was verified
  with widget journeys and privacy goldens, not a fresh native screenshot in
  this integration pass.
- The published [privacy policy](https://letterwithin.app/privacy) still lists
  app settings as local and omits optional product analytics from data that can
  leave the device (rechecked 2026-10-01). The prepared disclosure wording and
  App Store Connect review tasks are in
  `artifacts/app-store/APP_PRIVACY_DRAFT.md`. Neither public page nor
  production PostHog/RevenueCat configuration was changed.
- Source is ready for an owner-authorized next candidate build, but this is
  not App Review sign-off. The website owner and App Store Connect owner must
  align policy and privacy answers with the configured PostHog SDK; a qualified
  clinician must sign SP6/LV3 art, wording, pressure guidance, and safety copy;
  device QA must verify login, real products/localized prices, purchase and
  restore, notifications, and sharing on a physical iPhone. The Apple EULA
  opens on Android too; it must get an Android-appropriate destination before
  an Android subscription release, while it does not block this iOS code
  integration. No archive, upload, push, deployment, or App Review submission
  occurred.

## 2026-10-01 CR follow-up

- After the Today/Cycle audit and CR follow-up, `flutter analyze --no-pub`
  reports no issues. `flutter test --no-pub --concurrency=4 -r expanded`
  passed **677 tests with one existing skip**. An earlier concurrent full run
  had one onboarding load-wait timeout; that test passed alone and in the
  subsequent full run. This timing failure is recorded rather than erased.
  Another review session was editing the same worktree during this run;
  repeat the final gate after its changes are integrated and committed.
- A controlled null-shell-model test verifies that Cycle shows its first
  one-interval estimate after a record revision. Controlled out-of-order reads
  verify that Today, Cycle, and Patterns keep the latest snapshot. Shell and
  Care also reject older asynchronous derived/Kit loads. These checks do not
  replace native end-to-end mutation testing.
- The public privacy policy and the published App Store Connect privacy answers
  still describe the earlier dormant-analytics release. The current opt-in
  PostHog path requires policy and declaration alignment before App Store
  review submission. The exact website copy and disclosure audit are tracked
  in `artifacts/app-store/APP_PRIVACY_DRAFT.md`; the website has not been edited
  in this release worktree.
- The historical App Lock and complete free report-preview requirements are
  marked as superseded in their original feature specifications. SP6/LV3
  clinical approval and physical-device purchase/restore checks remain open.
- The Plus Terms of Use link currently opens Apple's Standard EULA on every
  platform. This is appropriate to recheck for the iOS submission and requires
  a platform-appropriate destination before an Android subscription release.

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
