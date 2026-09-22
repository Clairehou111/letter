# Letter Within App Store / RevenueCat Handoff

## Start here

Start the new Codex session in the actual Git repository:

```text
/Users/clairehou/pyProjects/pms-research-agent/product/letter
```

Ask the new session to read this file completely, inspect the current worktree,
and continue from the approval gate below.

The worktree contains substantial pre-existing changes. Preserve them. Do not
reset, discard, overwrite, broadly reformat, commit, push, purchase, or submit
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
