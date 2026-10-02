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

The separate `Letter Account QA 2026-10-02` simulator then ran the real app
entry with an owner-confirmed disposable Letter Within account and the Apple
RevenueCat configuration. All three Apple sandbox products loaded; Restore
before purchase said no active subscription was found. A yearly purchase
attempt prompted for an Apple Account, but returned to Plus without a purchase
confirmation or entitlement. `Settings → Developer → Sandbox Apple Account`
still showed **Sign In** after a login attempt. Sanitized simulator store logs
contained `AMSErrorDomain Code=100` (authentication failed). The Sandbox Apple
Account and simulator authentication state were then checked separately. No
purchase, entitlement unlock, or post-purchase restore has passed; no credential
or account identifier is recorded here.

The owner confirmed the tester exists under App Store Connect **Users and
Access → Sandbox** and completed Apple's email verification. Retrying that
tester still left `Settings → Developer` at **Sign In**. A second independently
verified sandbox tester advanced through Apple's verification-code prompt on
the same simulator, then also returned to **Sign In**; sanitized recent store
logs again contained `AMSErrorDomain Code=100`. This points to Apple sandbox
authentication on that simulator, not a failed entitlement update. The second
tester was then tried on the separate clean `Letter Apple Sandbox QA` simulator:
its `Settings → Developer → Sandbox Apple Account` also returned to **Sign In**
without a visible error, and its sanitized system log recorded “The
authentication failed.” The Apple sandbox transaction path is **blocked on both
iOS 26.5 simulators**. Do not count purchase or restore as passed. A physical
iPhone is not currently connected to this Mac; validate with TestFlight on an
iPhone with an authenticated app account. Build 15's deleted-account install
cannot exercise this until a later build contains the local account fix.

Run the ordered [account and subscription cases](account-subscription-cases.md)
on the next build. The RevenueCat Test Store can separately check development
SDK purchase/restore, while TestFlight's Apple sandbox remains necessary for
the actual Apple products, prices, and payment sheet.

## 2026-10-02 isolated simulator Test Store restore

The clean `Letter Apple Sandbox QA 2026-10-02` iOS 26.5 simulator ran the debug
manual QA entry with an ignored local RevenueCat **Test Store** public key and
a synthetic UUID. No Test Store key was placed in a release build. The Test
Store catalog loaded yearly US$39.99, monthly US$7.99, and lifetime US$99.99.
Before purchase, Restore returned “No active subscription was found for this
store account.”

The tester selected Lifetime and used Test Store's **Test valid purchase**
action. The original manual QA shell displayed Plus as its root page, while
the production Plus flow closes its sheet on successful activation; that QA
navigation mismatch left a black root screen. A QA-only `LETTER_QA_STORE_FLOW`
flag now opens Plus through its production sheet route. After rebuilding and
relaunching with the same synthetic UUID, Restore closed the sheet normally;
reopening Plus displayed **Plus is active** and **Lifetime · US$99.99**.
Repeating Restore while active returned to the shell normally, and reopening
Plus still showed the lifetime entitlement. This confirms the debug SDK/Test
Store purchase persistence and Restore path across a relaunch.

The active Lifetime screen also exposed subscription cancellation copy. The
local source now describes continuing Lifetime Plus access and omits the
subscription-management button for that plan. Deterministic widget tests cover
both Lifetime and monthly active copy; this correction is not in Build 15.

This run does **not** validate Apple's Sandbox Apple Account login, StoreKit
transaction, App Store receipt, an actual TestFlight build, or Supabase account
reconnection. Both Apple Sandbox simulator sign-ins remain blocked as described
above; B15-02 still requires the physical iPhone TestFlight purchase/restore
sequence on a future build with the local account-deletion fix.

Final local checks for this QA-entry change: `flutter analyze --no-pub` found
no issues; the complete `flutter test --no-pub --concurrency=4 -r compact`
suite passed **697 tests, 1 existing skip, 0 failures** after the copy fix; and
`git diff --check` passed.

## 2026-10-02 full-app account and Restore follow-up

The `Letter Account QA 2026-10-02` simulator ran the **full app** with the
owner-confirmed disposable Letter Within account. With the ordinary Apple
RevenueCat key, all three Apple prices loaded; pressing Start Plus still
requested Apple Sandbox authentication. Signing into the device's normal
iCloud Apple Account did not turn this into a Test Store purchase. The app must
be launched with a Test Store `test_` public key for that development path.

The same full app was then rebuilt with the ignored local Test Store config.
It loaded the Test Store catalog and displayed the native **Test Store
Purchase** simulation, without an Apple account prompt. A valid Lifetime test
purchase activated Plus; reopening the sheet showed **Plus is active** and
the **Lifetime** plan, with no redundant Restore button. Signing out moved
the app to its authentication gate, where neither local records nor Plus or
Restore were reachable. Signing back into the same account reopened its local
records and **automatically restored the active Lifetime entitlement without
tapping Restore**. This directly verifies that the normal account return path
loads a purchase already linked to the same RevenueCat app-user ID. Restore
remains available on the free Plus screen as a recovery action if that lookup
does not show an expected purchase.

During rapid sign-out/Plus actions, Flutter reported an unmounted shell
context. The local source now closes pushed routes when the account gate
closes and guards delayed Plus/account callbacks. A deterministic stale-action
test passes. The empty Restore response now says **Plus purchase** so it also
covers Lifetime. The redundant region/billing-variation footnote and the
repeated price on the active-plan view have been removed; purchase options
still use prices from the store catalog. These fixes are
local and not in TestFlight Build 15.

The active Monthly or Yearly screen now always offers **Change or manage
plan**. When RevenueCat supplies the store-management URL, it opens that
destination directly; when the current store environment supplies none, the
screen explains that a plan change is unavailable there. This includes the
RevenueCat Test Store, whose purchase simulation does not prove Apple's
Monthly-to-Yearly crossgrade. Lifetime remains a separate non-consumable
purchase rather than a subscription-group plan. Widget tests cover both the
store-link and no-link paths. The Lifetime active copy now emphasizes ongoing
Plus access without repeating billing terms. These changes are not in Build
15 and still need TestFlight verification on a physical iPhone.

Final source checks after this follow-up: `flutter analyze --no-pub` passed;
`flutter test --no-pub --concurrency=4 -r compact` passed **701 tests, 1
existing skip, 0 failures**; `git diff --check` passed. Apple StoreKit
purchase/restore and subscription management still require a physical iPhone
TestFlight run.

## 2026-10-02 full-app Monthly plan-change simulator run

The `Letter Apple Sandbox QA 2026-10-02` iOS 26.5 simulator was updated from
the manual QA shell to the **complete app** at local `main` commit `cd7b3d8`,
using the ignored local RevenueCat Test Store debug key. An authenticated
Letter Within account completed the real onboarding and opened Settings →
Letter Within Plus. That account already held the earlier Test Store Lifetime
purchase, so it could not exercise the Monthly screen. Its RevenueCat customer
profile showed one Test Store Lifetime transaction and no Apple transaction.
With the owner's explicit authorization, customer `05f4…3c0a` and its Test
Store purchase history were deleted in RevenueCat; the Supabase login and
on-device records were not deleted.

After signing back into the **complete app**, Plus showed the free catalog
with Yearly US$39.99, Monthly US$7.99, and Lifetime US$99.99. The tester
selected Monthly and completed Test Store's **Test valid purchase**. Reopening
Plus showed **Plus is active → Monthly**, no active-plan price or Restore
button, and the **Change or manage plan** action. Tapping that action produced
“Plan changes are unavailable for this purchase in the current store
environment.” The Test Store purchase did not provide a subscription
management URL. This run verifies the full-app free-to-Monthly transition and
the no-link management state. It does **not** verify an Apple Monthly-to-Yearly
crossgrade, charge, renewal date, or management destination. The latter still
requires an Apple sandbox/TestFlight purchase on a physical iPhone. Test Store
Monthly subscriptions renew on an accelerated schedule and expire after five
renewals, so this test entitlement is temporary.
