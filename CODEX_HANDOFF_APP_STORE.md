# Letter Within App Store / RevenueCat Handoff

## Start here

Start the new Codex session in the coherent release worktree:

```text
/Users/clairehou/pyProjects/pms-research-agent/.worktrees/letter-main
```

Ask the new session to read this file completely, inspect the current worktree,
and continue from the approval gate below.

The original rescue worktree at
`/Users/clairehou/pyProjects/pms-research-agent/product/letter` contains
substantial unrelated changes. Preserve it and do not use it for release work.
In the release worktree, preserve the known untracked validation artifacts and
do not reset, discard, overwrite, broadly reformat, push, purchase, or submit
anything unless explicitly requested.

## Source sessions

This handoff was reconstructed from these archived Codex sessions:

- `01a0b9f5-4bae-7532-a8c9-aaba978d2b5a`: initial App Store / RevenueCat handoff.
- `01a0bd97-52c6-7d61-a130-27f1c1ec56d0`: continuation containing the latest state.

Keep those sessions archived. Do not resume them; they contain large contexts.

## Launch decision and boundaries

- First launch: United States and Canada only.
- Leave every other storefront disabled.
- Do not submit the app or any product to App Review without explicit approval.
- Do not treat Canada as legally identical to the United States.
- Canadian privacy, cross-border processing, health-data wording,
  subscription/refund disclosures, and French/Quebec implications still need a
  release review.
- Supabase is deployed in West US and is used for auth/account/entitlement
  functions; health records remain local. Confirm the related Canadian
  disclosures before launch.
- RevenueCat market statistics are commercial evidence, not legal justification.

## Identifiers and mappings

- Bundle ID: `app.letterwithin`
- App Store Connect app ID: `6800270326`
- Subscription group: `22304067`
- RevenueCat project: `2722a566`
- RevenueCat App Store app: `app5506df4454`
- Entitlement: `letter_plus` / `entl2747cf60fe`
- Default offering: `letter_default` / `ofrngc0b2f74489`

Products:

| Product | Apple ID | RevenueCat ID | Package | Price |
| --- | --- | --- | --- | --- |
| `letter_monthly` | `6800577122` | `prod2080a18c61` | `$rc_monthly` | US$6.99 |
| `letter_yearly` | `6800577443` | `prodedcef227f9` | `$rc_annual` | US$29.99 upfront/year |
| `letter_lifetime` | `6800577621` | `prod79b0b928a0` | `$rc_lifetime` | US$79.99 non-consumable |

All three App Store products are attached to `letter_plus`. Preserve the three
existing Test Store products and their mappings.

## Completed and verified

App Store Connect showed the following for monthly, yearly, and lifetime:

- Exactly Canada + United States enabled: `2 of 175` storefronts each.
- US base prices saved as US$6.99, US$29.99, and US$79.99 respectively.
- The 175-region price tables are conversion tables; they do not change the
  two-storefront availability restriction.
- English (U.S.) localizations saved for all three products:
  - `Letter Within Plus Monthly`
  - `Letter Within Plus Yearly`
  - `Letter Within Plus Lifetime`
  - Description: `Unlock Plus preparation, patterns, and extended reports`
- All three products still showed `Prepare for Submission` after localization.
- RevenueCat mappings, offering, and entitlement were rechecked and remained
  correct.

The native RevenueCat QA harness still returned error 23 because Apple returned
none of the three products. Product mappings and RevenueCat credentials appeared
correct. Missing App Review screenshots were the leading metadata blocker;
StoreKit propagation delay could still be secondary.

## Current state after screenshot approval (2026-09-21)

The synthetic-data Plus-plan screenshot was recaptured from the native iPhone
17 simulator, shown to the user, and explicitly approved. The exact PNG was
uploaded to the App Review screenshot field for monthly, yearly, and lifetime.
App Store Connect finished processing the image on all three product pages and
showed the persisted review-image thumbnail. The temporary source is currently
at `/tmp/letter-plus-review.png` (1206 x 2622; SHA-256
`9b1ffd486799ba826ce57fc157b6f2df57cdbe66a7b164e78201220d4a73fb95`) but may
disappear after restart.

Post-upload checks:

- All three products still show `Prepare for Submission` and an `Add for
  Review` button. Do not click that button without explicit approval.
- Monthly, yearly, and lifetime remain limited to `2 of 175` storefronts.
- The native RevenueCat QA target was rerun after the upload. It now fetched
  and rendered all three StoreKit products at US$6.99, US$29.99, and US$79.99;
  the earlier error-23/configuration-error state did not recur.
- No purchase, App Review submission, or storefront expansion was attempted.
- The signed-in RevenueCat dashboard was audited read-only after the native
  fetch succeeded:
  - App Store app `app5506df4454` is named `Letter Within (App Store)` and uses
    bundle ID `app.letterwithin`.
  - `letter_default` / `ofrngc0b2f74489` is the default offering and contains
    `$rc_monthly`, `$rc_annual`, and `$rc_lifetime`.
  - Each package contains both the matching App Store product and its preserved
    Test Store product.
  - `letter_plus` / `entl2747cf60fe` has all six products attached: monthly,
    yearly, and lifetime for both App Store and Test Store.

Next steps:

1. When release/legal readiness is confirmed, obtain explicit approval before
   clicking `Add for Review` for any product or attaching the products to a new
   app-version submission. App Store Connect says each first product must be
   submitted with a new app version.
2. Stop before any purchase, App Review submission, or expansion to another
   storefront.

Use the Chrome-control skill for signed-in RevenueCat and App Store Connect work.
Existing tabs may be stale, so prefer fresh signed-in tabs and verify state
before repeating any saved action. Use Computer Use only when needed to operate
the simulator and capture the local screenshot.

Product URLs:

- Monthly: `https://appstoreconnect.apple.com/apps/6800270326/distribution/subscriptions/6800577122`
- Yearly: `https://appstoreconnect.apple.com/apps/6800270326/distribution/subscriptions/6800577443`
- Lifetime: `https://appstoreconnect.apple.com/apps/6800270326/distribution/iaps/6800577621`

Native QA command:

```sh
cd /Users/clairehou/pyProjects/pms-research-agent/product/letter/apps/mobile
flutter run -d 11DDCBA4-0711-4BBF-96B1-EA47792E3E87 \
  -t tool/manual_qa_app.dart \
  --dart-define-from-file=config/release.local.json
```

## Last known app validation

Before the App Store work, the archived session recorded:

- `flutter analyze` passed.
- Focused tests: 58/58 passed.
- Full `flutter test`: 511 passed with one intentional skip.
- Native app-switcher privacy cover visually verified.
- RevenueCat configuration errors distinguished from offline errors.
- PostHog retained but dormant; do not delete it.
- App Lock UI removed and dormant setting forced off.
- Cycle bleeding visuals and clinical report period-day counting were aligned.

Treat these as last-known results, not current proof. Rerun relevant checks if
the worktree has changed.

## Build 8 release (2026-09-21)

- The primary Cycle day editor now uses the same shared
  `DegreeGraphics.flowChoice` and `DegreeGraphics.bleedingColorChoice` controls
  as Today and Cycle backfill. The rebuilt iPhone 17 simulator was checked with
  both flow and color rows visible.
- `flutter analyze` passed with zero issues.
- The focused Today/Cycle consistency set passed 22 tests.
- The full Flutter suite passed 511 tests with one intentional skip.
- The coherent mobile release snapshot was committed as `e2efeaf` (`release:
  formalize build 8 mobile snapshot`). Local and remote `main` were
  fast-forwarded to this exact commit. Unrelated working-tree edits were left
  uncommitted and untouched.
- Signed App Store archive metadata: version `1.0.0`, build `8`, bundle
  `app.letterwithin`, team `S8ZWHC62QR`.
- IPA SHA-256: `4448d3bc8cd67e41a628a62203a99c7b8e0f48a0e2060b0aafc15f436f92fe01`.
- Xcode upload succeeded. App Store Connect upload UUID:
  `ea983a0c-35de-4e58-9093-3daf2bf3f752`.
- App Store Connect finished processing build 8. It shows `Complete` in Build
  Uploads and `Ready to Submit` in TestFlight, expires in 90 days, and is
  assigned to the existing `Internal Testers` group with 2 invited testers.
- No external testing group, beta-review submission, App Review submission,
  purchase, or storefront expansion was performed.

## Launch positioning and screenshot masters (2026-09-24)

The launch position is now fixed:

- Category: private period companion and tracker.
- Primary promise: `Cycle care for the days that feel heavier.`
- Primary trust promise: `Encrypted on your device. No AI.`
- Patterns and a clinician report must appear in the App Store screenshot set.
- `No AI` is a permanent product constraint, not a temporary campaign line.

The six approved local App Store masters are documented in
`artifacts/app-store/README.md` and recorded in
`artifacts/app-store/manifest.json`. Final JPEGs are under
`artifacts/app-store/iphone-69/final/` in this order:

1. Care for heavier days.
2. Encrypted on-device records and no AI.
3. Patterns across cycles, with missingness visible.
4. A bounded report for a clinician.
5. Tracking beyond period dates.
6. Optional check-back to remember what helped.

All six masters are 1290 × 2796 JPEGs with no alpha. They use real native
Flutter UI and synthetic records. The privacy and clinician-report frames were
freshly captured from production widgets on the iPhone 17 simulator; the report
contains a populated four-cycle synthetic history. The reusable composer is
`tool/compose_app_store_screenshot.swift`.

Product and implementation alignment completed in the working tree:

- Canonical specifications now prohibit AI/LLM processing and define patterns,
  reports, estimates, and candidate matching as deterministic and on-device.
- Dormant `CloudToolsPreference`, `cloud_tools` persistence, optional cloud NLP
  adapter, and `cloudSuggestion` source scaffolding were removed.
- Legacy onboarding JSON containing `cloud_tools` still decodes; new saves omit
  the retired field.
- Every Debug, Profile, and Release Xcode configuration now has
  `TARGETED_DEVICE_FAMILY = "1"` for the approved iPhone-only first release.
- `flutter analyze` passed with no issues; the full Flutter suite passed 553
  tests with one intentional skip.
- The release candidate is `1.0.0+11`. Build 11 was uploaded to App Store
  Connect and finished processing successfully.

Local build-11 archive validation:

- Signed archive: `apps/mobile/build/ios/archive/Runner.xcarchive`
- IPA: `apps/mobile/build/ios/ipa/Letter Within.ipa`
- IPA SHA-256:
  `998e2c923a2b89f11d1671a238a84c790d60ef5392a88f1c1ef27dc6c53fbb6e`
- Archive metadata: version `1.0.0`, build `11`, bundle `app.letterwithin`,
  deployment target iOS 15.0, device family iPhone only.
- Strict deep code-signature verification passed.
- This archive was built from local `main` at baseline commit `732dade` plus
  the release-preparation changes documented here.
- The scoped release package was committed on local `main` as `f8670c4`
  (`release: prepare build 11 launch package`). It has not been pushed.
- Xcode uploaded build 11 on 2026-09-24 at 03:45. App Store Connect shows the
  upload as `Complete` and the TestFlight build as `Ready to Submit`, expiring
  in 90 days. It remains assigned to the existing `Internal Testers` group
  with 2 invited testers.
- The owner-approved ten-frame v3 English (U.S.) App Store listing set is
  uploaded to the iPhone 6.9-inch display slot and verified in manifest order.
  App Store Connect is using that set for the 6.5-inch display slot as intended.
- The first three installation-sheet images are, in order: heavier-day care,
  encrypted on-device/no-AI privacy, and populated Today tracking. Cycle and
  mood Patterns are sixth and seventh; the populated clinician report is
  eighth.

No website asset, in-app purchase, product, beta review, or app version was
submitted or deployed during this pass. `Add for Review` was not clicked. Do
not purchase, add for review, submit, deploy, push, or expand storefronts
without explicit approval.

The future website redesign is handed off at
`/Users/clairehou/pyProjects/letter-cycle-companion/WEBSITE_REDESIGN_HANDOFF.md`.
It is comp-first and preserves this screenshot and message hierarchy. No website
source or deployment was changed by that handoff.

## Screenshot correction after owner review (2026-09-24)

The six screenshots previously visible in App Store Connect were rejected and
removed. The owner rejected the set because the Care and Patterns images were
obsolete, the clinician report did not communicate populated data, and the
strip looked coarse at storefront scale.

An eight-frame replacement candidate was created from fresh current native
iPhone 17 Pro Max captures. It is under
`artifacts/app-store/iphone-69/candidate-v2/` and documented in
`artifacts/app-store/SCREENSHOT_REDESIGN_BRIEF.md`. The replacement includes:

- Current Care chooser and immersive low-energy scene.
- Current encrypted Backup & restore controls as the on-device and no-AI
  proof.
- Current cycle and mood Patterns with realistic 28-30 day variation.
- A clinician matrix containing 43 confirmed synthetic records across four
  cycles.
- Current cycle tracking and a four-action What helped view.

OpenRouter Claude Sonnet 5 independently reviewed the screens and recommended
an eight-frame, data-first set. Privacy remains second, rather than Claude's
suggested closing position, because the owner explicitly fixed Care and privacy
as the top two launch messages.

Candidate v2 is local only and was never uploaded. The App Store submission
remains paused.

## Screenshot candidate v3 after tracker and color review (2026-09-24)

Candidate v2 was superseded after the owner requested three distinct tracker
proofs and identified that its outer rose/plum canvases did not match the real
app. Candidate v3 is under
`artifacts/app-store/iphone-69/candidate-v3/` and contains the full ten allowed
screenshots:

1. Current Care chooser — `Cycle care for the days that feel heavier.`
2. Backup & restore — `Encrypted on your device. No AI.`
3. Populated Today — flow, color, and three saved symptoms.
4. Current-cycle days — five populated flow and color rows.
5. Day symptom editing — saved flow, color, moderate pain, and a recorded
   symptom row.
6. Cycle patterns — realistic 28-30 day variation.
7. Mood patterns — 11 harder days across four cycles.
8. Clinician report — 43 confirmed synthetic records across four cycles.
9. Heavy Care scene — useful in-scene action and permanent exit.
10. What helped — four actions with recorded outcomes.

OpenRouter Claude Sonnet 5 reviewed four current native Care candidates:
Heavy, Focus, Body, and Space. It selected Heavy because that scene most
directly supports the fixed heavier-days promise. All four native options are
preserved under candidate v3 `source/` for audit.

The v3 compositor now uses only product tokens. Daylight frames extend
`#FBF7F3` with `#2A1626` ink and `#E4573D` ember. Care frames extend the real
`#2E1A33` to `#170D1C` Care world with `#F7EEE6` type. No marketing-only rose
or plum canvas remains.

All ten v3 finals are 1290 x 2796 JPEGs with no alpha. Hashes, order, Claude
decision, and approval gates are recorded in
`artifacts/app-store/iphone-69/candidate-v3/manifest.json`. The owner approved
candidate v3 on 2026-09-24, and all ten files were uploaded and verified in
manifest order that day. App Store Connect reports `10 of 10 Screenshots` for
the 6.9-inch set and derives the 6.5-inch set from it. This does not authorize
submitting the app version to App Review.

## Build 12 auth and complimentary-access decision (2026-09-24)

Build 11 requires authentication but its release configuration leaves
`LETTER_APPLE_SIGN_IN_ENABLED` unset, and the live Supabase Auth settings report
Apple disabled. Email access is magic-link-only, which is not a dependable App
Review login because the reviewer cannot access the owner's inbox.

The agreed build-12 direction is:

- Keep email magic link as the primary email signup and sign-in flow.
- Configure the Supabase Apple provider and enable the existing Apple sign-in
  UI for customers. The iOS Sign in with Apple entitlement is already present.
- Add a visually secondary password sign-in path for existing accounts only.
  Create one dedicated App Review account with a password and put its
  credentials only in App Store Connect, never in the repository.
- Do not add public password signup until email verification, password reset,
  and recovery UX are deliberately implemented.

The password fallback is implemented. Focused auth tests pass 26/26, the full
Flutter suite passes 556 tests with one intentional skip, and `flutter analyze`
passes. A brand-new isolated iPhone 17 Pro simulator verified that the dedicated
App Review email/password account signs in and reaches onboarding. The account
is auto-confirmed in Supabase and the verified credential pair is not present
in this repository. On 2026-09-25, the App Review sign-in credentials, contact
information, and review notes were completed and saved in App Store Connect.
A post-save reload confirmed that the complete App Review information remained
present. No credential or personal contact value is recorded in this repository.

PostHog will remain in the binary for a future consented analytics release. It
must remain unconfigured, auto-init disabled, and forced opted out for 1.0.
Before enabling it later, update the consent UI, privacy policy, App Store
privacy answers, and final privacy report; never send health data or inferred
health state.

Complimentary access does not need a binary whitelist:

- Use RevenueCat granted `letter_plus` entitlements for the owner and a small
  trusted group, by authenticated customer ID and chosen duration.
- Use Apple offer codes for public free or discounted promotions after the app
  and products are approved.
- Keep pre-launch friends on TestFlight, where StoreKit purchases are sandboxed
  and do not charge them.

Do not hard-code friend email addresses or a permanent bypass into the app.

Native Apple sign-in is now implemented locally with Apple's native
authorization sheet, a SHA-256 nonce, and Supabase ID-token exchange. It no
longer uses an external-browser OAuth redirect, so an iPhone-only release does
not need an Apple OAuth secret or its six-month rotation. The
`sign_in_with_apple` and direct `crypto` dependencies are pinned in the mobile
package. Static analysis, the 26 focused auth tests, and an iOS Simulator debug
build all pass.

The Supabase Apple provider is live with Client ID `app.letterwithin`, no OAuth
secret, and "Allow users without an email" off. The public Auth settings report
Apple enabled, and the ignored release configuration has
`LETTER_APPLE_SIGN_IN_ENABLED=true`. A clean simulator verified that the app
shows `Continue with Apple` and invokes Apple's native authorization sheet. A
full Apple credential exchange was not completed because the isolated simulator
has no Apple Account signed in; the dedicated password account is the reliable
App Review path.

Supabase automatically links Apple and email identities when Apple returns the
same verified email; the production Claire account already shows both providers
on one user. Apple's Hide My Email relay address can instead create a separate
user. Letter Within never merges or uploads health records: matching user IDs
reopen that account's records on the same device, different user IDs leave the
records closed, and another device starts empty. A future account-settings
release should offer an explicit linked-sign-in-methods flow for relay-email and
provider-collision cases.

Build 12 release state:

- Local `main` includes `c6bdb3f` (`release: bump iOS build to 12`).
- Signed archive: `apps/mobile/build/ios/archive/Runner.xcarchive`.
- IPA: `apps/mobile/build/ios/ipa/Letter Within.ipa`.
- IPA SHA-256:
  `ceaa153fac20b26e9725e2e1f154a00bb5caaee2e2bb97cd3b60e14dd574905d`.
- Archive metadata: version `1.0.0`, build `12`, bundle `app.letterwithin`,
  deployment target iOS 15.0, device family iPhone only.
- Strict deep code-signature verification passed.
- Xcode uploaded build 12 to Apple on 2026-09-24 at 23:35 JST. App Store
  Connect finished processing it as `Ready to Submit`, and build 12 is attached
  to App Store version 1.0. The approved screenshot set remains intact at
  `10 of 10 Screenshots` in manifest order.
- Do not click `Add for Review` until the remaining metadata and privacy gates
  are complete and the owner gives explicit action-time approval. App Review
  contact information, sign-in credentials, and reviewer notes are complete.
