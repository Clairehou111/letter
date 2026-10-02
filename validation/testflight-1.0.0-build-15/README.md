# TestFlight 1.0.0 (15) — release and device validation

## Build and upload

- Source: local `letter-main` `main` commit `4ec9f74`; `pubspec.yaml` is
  `1.0.0+15`. No tracked source changes were present during archive creation.
- Release wrapper: `apps/mobile/tool/build_ios_release.sh --build-number=15`.
  The ignored release config passed nonempty public Supabase, Apple RevenueCat
  `appl_...`, and PostHog `phc_...`/US-host checks. No key values are recorded
  here. Build 14 used an empty PostHog token; Build 15 uses the configured
  project, still behind the default-off analytics control.
- Source preflight before the version-only bump: `flutter analyze --no-pub`
  found no issues; full `flutter test --no-pub` finished with **688 passed,
  1 existing skip, 0 failures**. `git diff --check` passed after the bump.
- Xcode archive and IPA: `1.0.0 (15)`, bundle `app.letterwithin`, iOS deployment
  target 15.0. Archive code signature passed `codesign --verify --deep --strict`.
  IPA: `apps/mobile/build/ios/ipa/Letter Within.ipa`; SHA-256
  `97e4098de80b23008d14c967b979c99889a1feebbc720add3ab71a0a5ff1df6f`.
- Xcode Organizer reported **Letter Within 1.0.0 (15) uploaded**. App Store
  Connect received it at Oct 2, 2026 02:08 local time, then completed
  processing. The TestFlight build is **Ready to Submit** and assigned to the
  existing **Internal Testers** group (2 testers). There are no reported
  installs, sessions, crashes, or feedback yet. This is a TestFlight upload,
  not an App Review submission.

## Physical iPhone run

Status: **in progress**. A tester found the account-deletion/Plus failure below
on Build 15. Use synthetic local records and a disposable app
account. Record device model, iOS version, TestFlight build number, tester and
app-account aliases, local time, Pass/Fail/Blocked, and redacted evidence.

Run D01–D12 in
[`physical-iphone-build-14-checklist.md`](../../specs/features/2026-09-25-release-2-0/physical-iphone-build-14-checklist.md),
substituting **Build 15** for Build 14 throughout. Add these Build 15 checks:

1. **B15-01 — Plus catalog on first load.** With a fresh account without Plus,
   open Plus immediately after sign-in, then after relaunch. Confirm monthly,
   annual, and lifetime products and localized Apple prices load. Repeat once
   after a temporary network loss and recovery. If the catalog is missing,
   capture the fixed local `plan_catalog_load` reason and exact action order;
   do not copy raw account or health information into the report.
2. **B15-02 — Purchase and restore.** On a physical iPhone TestFlight install,
   use a sandbox tester for one purchase, confirm Plus unlocks, relaunch, and
   restore. Check a separate fresh unpaid account/tester so an existing Apple
   entitlement does not make the initial-offer test inconclusive.
3. **B15-03 — Optional analytics.** Check analytics is off before consent and
   no PostHog event is sent. Turn it on, trigger a Plus catalog refresh, and
   inspect the `plan_catalog_load` event in the Letter Within project: result
   and fixed reason only, with no account ID, error string, dates, symptoms,
   notes, or Care details. Review SDK-added fields and IP/region handling
   against the published App Store Connect declaration. Turn the control off,
   trigger another refresh, and confirm no new event appears. If the off-state
   cannot be observed reliably, mark it Blocked rather than Pass.
4. **B15-04 — Website and clinical gates.** Before App Review, verify the live
   privacy page reflects optional PostHog analytics and the App Store Connect
   label remains aligned with the actual Build 15 event. SP6/LV3 image,
   wording, pressure guidance, and safety still lack qualified clinical
   sign-off; retain this as an open release gate while the feature remains.

Do not submit Build 15 for App Review based on upload or automated tests alone.

## Observed TestFlight finding — account deletion and Plus

On 2026-10-02, a tester deleted the server account in Build 15 and then opened
Plus. The sheet showed “Purchases unavailable” and “Purchases are unavailable on
this build”; Restore repeated the same message. The account screen offered no
way to create or connect another account. This is a **Build 15 failure**, not
evidence of a missing RevenueCat key or an App Store catalog failure: the
entitlement repository no longer has an authenticated account UUID after
deletion. The server account itself cannot be recovered; local records remain
on the device.

The local `main` fix separates the missing-account state from store
configuration failures, routes Plus to Account settings, and adds an explicit
new-account connection path that keeps local records sealed from an unrelated
sign-in. It has not been uploaded to TestFlight. Retest delete account → Plus →
Account settings → cancel, then create a new account → Plus plans → restore on
the next build. Keep Build 15 marked failed for this path.

The isolated `Letter Account QA 2026-10-02` iPhone 17 Pro simulator ran the
synthetic deleted-account scenario with a local mood record and fake store
client. Patterns → Plus showed the account-required message and account action;
settings showed the new account action; the connection form explained deleted
account replacement; cancelling returned to the local record with its value
still present. This confirms the interface and local-only state path, **not**
real Supabase account creation, RevenueCat Test Store, or Apple billing. The
focused auth/Plus/repository test suite passed; the full local test result is
recorded in the release validation spec.

Separately, a clean `Letter Apple Sandbox QA 2026-10-02` iPhone 17 Pro simulator
ran the existing manual QA entry with the ignored Apple RevenueCat public key
and a synthetic RevenueCat app-user ID. The actual Apple sandbox catalog loaded
three products: yearly **US$39.99**, monthly **US$7.99**, and lifetime
**US$99.99**. A purchase attempt opened Apple's Sandbox Apple Account sign-in
dialog. Purchase, entitlement unlock, and restore are pending sandbox tester
sign-in; do not mark these cases passed from catalog display alone. This QA
entry bypasses Supabase auth and therefore cannot validate the deleted-account
reconnection path by itself.

Run the ordered [account and subscription cases](account-subscription-cases.md)
on the next build. The RevenueCat Test Store can separately check development
SDK purchase/restore, while TestFlight's Apple sandbox remains necessary for
the actual Apple products, prices, and payment sheet.
