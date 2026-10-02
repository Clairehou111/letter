# Release 2.0 Validation

Status: automated and native-Simulator run complete; SP6/LV3 replacement art
installed and visually verified; qualified clinical review and final
physical-device validation pending

Original Release 2.0 validation run: 2026-09-30. The latest CR follow-up is
recorded below.

## 2026-10-02 Plus plan loading investigation and diagnostic candidate

- The supplied screenshot showed the old “Purchases are not offered by this
  desktop build” fallback. That copy was removed from the source by `ea43409`
  during Build 13 preparation; it is absent from Build 14 source. The old
  fallback represented a missing authenticated UUID, selected mobile store,
  or public store key. It did not prove that the iPhone was treated as a
  desktop device. A network or offering request error followed a different
  path. The screenshot alone cannot identify which preflight value was absent.
- A fresh iOS 26.5 iPhone 17 Pro Max Simulator ran the native debug manual QA
  app with a temporary RevenueCat Test Store public key and a test UUID. Plus
  loaded all three current products: yearly US$39.99, monthly US$7.99, and
  lifetime US$99.99. This verifies the Test Store catalog and current Flutter
  load path; it is not a run of the signed Build 14 IPA or a real StoreKit
  purchase.
- The next source candidate adds fixed plan-load outcome and failure reason
  codes. A failure writes only its code to the local device log. If the user
  has enabled app analytics, `plan_catalog_load` also sends a typed success or
  failure event through PostHog. No account ID, product price, receipt, health
  record, or raw SDK exception is included in the event. PostHog still uses a
  random distinct ID, and Apple requires consent for usage collection even
  when considered anonymous. The Settings wording now describes the benefit
  and the provider more plainly. The privacy policy and App Store Connect
  answers must be revised before an analytics-configured build is submitted.
- No new archive, upload, purchase, App Review submission, or website change
  occurred. Build 14 remains unchanged; a physical iPhone run is still needed
  to determine whether its real StoreKit offering loads and purchase sheet
  shows the updated prices.
- Source verification after the diagnostic and Settings copy changes:
  `flutter analyze --no-pub` found no issues; full
  `flutter test --no-pub --concurrency=4 -r expanded` passed **688 tests,
  1 existing skip, 0 failures**; `git diff --check` passed. These are local
  source checks, not signed IPA or physical-device validation.

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
  The current App Store Connect pricing pages now show monthly US $7.99 / CA
  CAD $9.99 and yearly US $39.99 / CA CAD $49.99, with no upcoming price row.
  A physical-device StoreKit purchase-sheet check remains pending.
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
- After the owner enabled App Store Connect API access, a dedicated App Manager
  team API key was created and uploaded to RevenueCat's Letter Within App Store
  app. RevenueCat reports both the new App Store Connect API key and the
  existing In-App Purchase key as valid; the CLI independently reports both
  configured. All three Apple products now have `Ready to Submit` store status.
  RevenueCat's stored Apple price list still reads monthly USD $6.99, yearly
  CNY 198, and no lifetime price immediately after setup. Do not use these
  catalog records as a substitute for StoreKit product and purchase-sheet
  verification. No new build, purchase, or App Review submission occurred.
- App Store Connect's `1.0 Rejected` state refers to the September 30 review
  of old Build 12, not Build 14. Apple cited Google Play wording in the binary
  (2.3.10) and missing usable Privacy Policy / Terms of Use links in both the
  subscription purchase flow and metadata (3.1.2(c)). A later candidate needs
  direct verification of those fixes and accurate App Review notes before a
  new submission; no reply or resubmission was made here.

## 2026-10-02 Build 15 TestFlight handoff

- Owner requested Build 15 before internal testers began Build 14. The source
  was version-bumped and committed at `4ec9f74` as `1.0.0+15`; ignored release
  config contains the Letter Within PostHog public token and the Apple
  RevenueCat key. No secret values were committed or copied into this record.
- Preflight on the source before the version-only bump: `flutter analyze
  --no-pub` had no issues; the full `flutter test --no-pub` completed **688
  passed, 1 existing skip, 0 failures**. `git diff --check` passed.
- `tool/build_ios_release.sh --build-number=15` produced a signed
  `app.letterwithin` archive and IPA with version `1.0.0 (15)`. Deep code
  signature verification passed. IPA SHA-256:
  `97e4098de80b23008d14c967b979c99889a1feebbc720add3ab71a0a5ff1df6f`.
- Xcode Organizer reported **upload complete**. App Store Connect received
  Build 15 at Oct 2, 2026 02:08 local time and completed processing. TestFlight
  shows **Ready to Submit** and assignment to **Internal Testers** (2 testers).
  Physical-device acceptance is in progress; follow
  `validation/testflight-1.0.0-build-15/README.md`. No App Review submission
  occurred.
- Subsequent physical TestFlight testing found that after deleting the server
  account, Plus mislabeled missing account identity as purchases being
  unavailable on this build, Restore repeated the message, and Settings had no
  path to connect a new account. Local fixes and regression tests are recorded
  in the Build 15 validation file; they are **not in the uploaded binary**.
- An isolated iPhone 17 Pro simulator with a synthetic deleted-account state
  confirmed Settings → Account → replacement-account entry and Back,
  while a local mood record remained visible. This uses a fake store client;
  it does not verify a live Supabase account, RevenueCat Test Store, Apple
  purchase, or restore. The ordered account/subscription cases are in
  `validation/testflight-1.0.0-build-15/account-subscription-cases.md`.
- For the local deletion fix, `flutter analyze --no-pub` reported no issues;
  the full `flutter test --no-pub` passed **695 tests, 1 existing skip, 0
  failures**. Focused auth, Plus, Supabase and RevenueCat tests also passed.
- A second clean simulator with the real Apple RevenueCat public key loaded
  yearly US$39.99, monthly US$7.99, and lifetime US$99.99 from Apple sandbox.
  Tapping purchase opened the Sandbox Apple Account sign-in dialog. Sandbox
  purchase, entitlement unlock, and restore remain pending tester sign-in.
- The real configured app on an isolated simulator, with an owner-confirmed
  test app account, loaded those Apple products and returned a no-purchase
  result for Restore. The attempted Sandbox Apple Account sign-in did not
  persist in `Settings → Developer`; sanitized store logs showed
  `AMSErrorDomain Code=100` (authentication failed). No sandbox transaction or
  Plus unlock has been counted as a pass.
- The owner verified the first App Store Connect Sandbox tester email. A
  second independently verified tester reached Apple's verification-code
  prompt, but the same iOS 26.5 simulator still returned to **Sign In** and
  logged an authentication failure. The second tester also returned to
  **Sign In** on a separate clean iOS 26.5 simulator, whose system log recorded
  authentication failure. Apple sandbox purchase is blocked at system sign-in
  on both simulators; no physical iPhone is connected to the Mac. Purchase,
  entitlement unlock, and post-purchase restore remain unverified.
- A separate debug-only RevenueCat Test Store run used a synthetic UUID on the
  clean simulator. Restore before purchase found no active subscription. After
  Test Store's valid Lifetime purchase and a relaunch, Restore activated Plus;
  reopening the sheet showed **Plus is active** and **Lifetime · US$99.99**.
  Repeated Restore retained access. The manual QA entry was adjusted behind a
  `LETTER_QA_STORE_FLOW` flag to open the production sheet route; successful
  activation previously popped its root page to a black screen. These results
  verify the SDK/Test Store path only; Apple StoreKit and TestFlight purchase
  and restore remain blocked pending physical iPhone validation. The final
  active Lifetime UI now describes continuing Plus access rather than subscription
  cancellation copy, with deterministic Lifetime and monthly widget checks. The
  local `flutter analyze --no-pub` and `git diff --check` passed; the complete
  `flutter test --no-pub --concurrency=4 -r compact` suite passed **697 tests,
  1 existing skip, 0 failures**.
- A later full-app Test Store run used the disposable authenticated app
  account. Lifetime test purchase activated Plus, the active sheet omitted
  Restore, sign-out reached the login gate, and the same app account reopened
  its on-device records **and Lifetime access without tapping Restore**. A
  sign-out/Plus timing test exposed an unmounted shell callback; route closure
  and mounted guards are now covered by a deterministic regression test. The
  empty Restore message now covers both subscriptions and Lifetime, and the
  redundant region footnote and active-plan price were removed. Active Monthly
  and Yearly now always show a **Change or manage plan** action; it opens the
  RevenueCat store-management URL when one exists and explains when the current
  store environment supplies no link. Lifetime stays a separate one-time
  product and its active copy emphasizes continuing Plus access. Widget tests
  cover both management-link cases; real Apple plan changes still need a
  physical iPhone. Final local analyze and `git diff --check` passed, and the
  full Flutter suite passed **701 tests, 1 existing skip, 0 failures**.
- A subsequent local follow-up moved Monthly ↔ Yearly changes into Plus itself:
  the active screen shows only the current plan until **Change plan** is
  opened, then offers the alternative subscription through the store purchase
  sheet. **Manage or cancel subscription** remains a separate store-link
  action. The complete app on the isolated iOS 26.5 simulator changed an
  active Test Store Monthly purchase to Yearly and reopened with Yearly active;
  canceling a proposed Yearly → Monthly change kept Yearly active. This is
  RevenueCat Test Store coverage, not Apple sandbox billing or effective-date
  verification. The same follow-up removed redundant Lifetime/offline claims
  and shortened visible Plus and Settings copy while retaining subscription
  renewal terms and privacy details where needed.

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
- Today and Settings reminder tests cover reliable-gate scheduling silence,
  early opt-in retained until evidence matures, automatic scheduling then,
  stored `Not now`, 0/1/2-day timing, 09:00 copy, disabling, and 200% text
  scaling.
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

- Plus shows the store-reported current plan and next renewal date, or the
  access-end date when renewal is off. For overlapping active Monthly and
  Yearly products, Plus names the product with the latest reported purchase
  or renewal and shows the latest confirmed current-period end across both as
  the minimum known access horizon; it never adds their durations. The
  2026-10-02 RevenueCat
  Test Store account showed both products active after a Yearly → Monthly
  purchase; the single entitlement still named Yearly. This test environment
  does not establish an Apple crossgrade. Confirm actual same-group timing,
  price, and management on Apple sandbox/TestFlight before release.
- A later plan/entitlement audit added non-concurrent tests for a catalog
  failure while Plus is already active. The store-backed repository now keeps
  the confirmed entitlement when only offerings fail. Lifetime access with
  a separate active subscription also retains a management link and shows a
  billing overlap notice. Neither change is in TestFlight Build 15.
- The next local Plus follow-up keeps **Change plan** available for active
  Monthly, Yearly, and Lifetime users, including when the store reports two
  active products. It opens the same Monthly, Yearly, Lifetime selector as the
  free offer. The displayed current product is disabled; the other two use
  the existing purchase flow. A short notice appears when buying Lifetime
  alongside an active subscription or adding a subscription to Lifetime.
  This replaces the earlier one-alternative and overlap-blocked selector
  described in the historical validation notes above. It is not in Build 15.

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
