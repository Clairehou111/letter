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
configuration failures and adds an explicit **Settings → Account** connection
path that keeps local records sealed from an unrelated sign-in. Plus points
to that location without hosting an account action. It has not been uploaded
to TestFlight. Retest delete account → Settings → Account → cancel, then create
a new account → Plus plans → restore on the next build. Keep Build 15 marked
failed for this path.

The isolated `Letter Account QA 2026-10-02` iPhone 17 Pro simulator earlier ran
the synthetic deleted-account scenario with a local mood record and fake store
client. Patterns → Plus showed the account-required message and then an account
action; Settings showed the new account action; the connection form explained deleted
account replacement; cancelling returned to the local record with its value
still present. This confirms the interface and local-only state path, **not**
real Supabase account creation, RevenueCat Test Store, or Apple billing. The
focused auth/Plus/repository test suite passed; the full local test result is
recorded in the release validation spec. The later local UI change removed
the Plus account action; current tests start reconnection in Settings → Account.

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

## 2026-10-02 Plus copy and Test Store plan-change follow-up

The previous no-link result reflected the old **Change or manage plan** action,
which depended entirely on a store-management URL. The local source now shows
**Change plan** on an active Monthly or Yearly screen. Opening it reveals the
other subscription and its store price; **Manage or cancel subscription** is a
separate action. The active-plan screen no longer preemptively explains
cancellation or repeats the price. The free catalog no longer claims that only
Lifetime works offline. Subscription cards still state renewal cadence and
link to the privacy policy and terms. Settings' Plus, report, analytics,
Comfort Window, and About summaries were shortened without changing their
controls or underlying behavior.

On the **complete app** in the isolated `Letter Apple Sandbox QA 2026-10-02`
iOS 26.5 simulator, an authenticated app account opened active **Monthly**,
selected **Change plan → Yearly → Continue with Yearly**, and used RevenueCat
Test Store's **Test valid purchase**. Reopening Plus showed active **Yearly**.
The tester then opened **Change plan → Monthly** and canceled the Test Store
purchase dialog; Yearly remained active and Plus showed **Purchase canceled**.
This verified that the Yearly purchase became visible and that cancellation
left the existing access intact. It did not establish that Test Store replaced
the earlier Monthly subscription. Repository tests also cover a deferred
store response without dropping an existing entitlement.

### Yearly to Monthly follow-up

A later **Yearly → Monthly** Test Store purchase returned the Yearly product
as the single `letter_plus` entitlement, so the previous Plus view kept
showing Yearly and its current-period date. Read-only inspection of this
test customer's RevenueCat profile showed **both Annual and Monthly active**,
with separate renewal times; the customer history contained new Monthly
purchases and renewals after the Annual purchase. This is overlapping Test
Store purchase history, not evidence of a scheduled Apple crossgrade. The
complete-app source now reads active subscription products separately. In an
overlap it shows the product with the latest store-reported purchase or
renewal, plus the **latest confirmed current-period end** across active
products as the minimum known Plus access horizon. It does not add the two
durations or call that horizon the final expiry of an auto-renewing plan.
It also notes that another subscription is active and removes the further
switch action in that state. A period ending within
24 hours includes the local time so accelerated Test Store renewals can be
distinguished. The singular date for an auto-renewing plan is the **next
renewal**, not its final expiry. A canceled plan instead shows its access-end
date. If the SDK still reports a single plan active with a past period date,
Plus labels that timestamp as the last reported period end instead of claiming
an upcoming renewal. Widget tests cover the ordinary single-plan state,
overlap selection, latest confirmed horizon, and that stale-period case.
This source change is not in Build 15; an Apple sandbox run is still needed
to validate actual same-group crossgrade timing and billing.

An earlier simulator check showed `Monthly · Last reported period ended Fri,
Oct 2, 2026 at 12:41 PM` and `Yearly · Renews on Fri, Oct 2, 2026 at 1:13
PM` side by side. The follow-up design uses the more recent product for the
heading and the later of those known period ends for Plus coverage. The
complete-app simulator now displays **Monthly**, **Current Plus access through
at least Fri, Oct 2, 2026 at 1:13 PM**, and a short notice that another store
subscription remains active. Test Store does not prove that Apple's same-group
crossgrade will produce an overlap; that requires Apple sandbox validation.
Final checks for this follow-up: `flutter analyze --no-pub` passed, the
complete `flutter test --no-pub --concurrency=4 -r expanded` suite passed
**710 tests with 1 existing skip**, and `git diff --check` passed.

## Plan and entitlement scenario audit

The later local source audit found that a failing plan-catalog request could
replace an already-confirmed paid entitlement with an unavailable state.
Catalog failure now leaves the active Plus plan, period end, and renewal flag
intact; a non-paying user still sees the catalog error. The active Lifetime
screen now warns if a separate subscription is also active and keeps the
store-management link visible when RevenueCat supplies one. Non-concurrent
repository and widget regressions cover both cases. These changes are local
and require a later build.

Build 15's deleted-account route remains a known failure. The local
account-required Plus copy, Account connection screen, cancel path, and
explicit relinking of on-device records have widget and isolated simulator
coverage, but real account deletion followed by new Supabase registration and
Apple purchase restore is still unverified in TestFlight. The next Apple
Sandbox run must also cover Monthly/Yearly effective timing, cancellation
through access end, renewal/expiration, restore to the same app account, and
cross-account restore under the project's transfer behavior.
Final local checks for this audit: `flutter analyze --no-pub` passed;
complete `flutter test --no-pub --concurrency=4 -r expanded` passed
**712 tests with 1 existing skip**; `git diff --check` passed.

This remains a debug Test Store result. A physical iPhone with TestFlight and
Apple sandbox must still confirm the real subscription sheet, effective date,
charge, restore, and management URL. Build 15 has none of these new changes;
its account-deletion failure remains open until a later build is uploaded.

## Local follow-up: Account, Comfort Window, and support

The current local source puts the deleted-account reconnection action in
**Settings → Account**. The Plus account-required state points there without
hosting a separate account action. The account connection and cancel flow is
covered by the existing full-app widget test. Build 15 still contains the old
behavior; the revised path needs a later TestFlight build for device acceptance.

Settings now saves Comfort Window reminder opt-in and lead time even before a
reliable forecast exists. It requests iOS notification permission on explicit
opt-in. While evidence is insufficient, the switch stays on and no reminder is
scheduled; later eligible local evidence triggers scheduling automatically.
Turning the switch off cancels the pending reminder. The early-opt-in UI,
controller persistence, and deferred scheduler path have separate tests.
**About & support** now shows `support@letterwithin.app`.

On the next device build, test Account reconnection after deletion and the
early Comfort Window opt-in, including notification permission, later
eligibility, and disabling. The complete-app simulator can exercise the current
UI, while delivery at the scheduled time still needs an iPhone check.

The authenticated **Letter Apple Sandbox QA 2026-10-02** complete-app simulator
was hot-restarted with this source. Settings displayed the unchecked but enabled
Comfort Window switch with the early-opt-in explanation, and the expanded
About & support section visibly displayed `support@letterwithin.app`. The
simulator account was preserved; no account deletion or notification-permission
change was made during this visual check. The deleted-account state and
pre-eligibility opt-in were exercised in non-concurrent widget/controller and
scheduler tests. Final local checks: `flutter analyze --no-pub` passed;
complete `flutter test --no-pub --concurrency=4 -r expanded` passed
**715 tests with 1 existing skip**; `git diff --check` passed.

## 2026-10-02 account deletion and Test Store entitlement

After deleting the server account, signing up again with the same email or
Apple identity creates a new Supabase UUID. That UUID is the RevenueCat App
User ID, so the old Test Store Monthly/Yearly entitlement does not appear on
the new customer. This is expected for Test Store: its simulated purchases have
no Apple or Google purchase history for cross-ID Restore. RevenueCat support
[confirms Test Store restore/sync is unsupported](https://community.revenuecat.com/sdks-51/are-syncpurchases-and-restorepurchases-sdk-calls-meant-to-work-on-the-revenuecat-test-store-7779?postid=26311).
The RevenueCat project was read-only checked: **Transfer to new App User ID**
is selected and no separate sandbox restore behavior is enabled.

This Test Store result does not establish how an Apple purchase behaves after
account deletion. The next physical-iPhone Apple Sandbox case must buy with
P1, delete the app account, create a new account, and use Restore with that
same Sandbox Apple Account. Do not make a second Apple purchase to work around
a failed restore. The local deletion confirmation now explains that account
deletion does not cancel an App Store or Google Play subscription and points to
Restore on a new account. `flutter analyze --no-pub`, the focused Settings
test, and `git diff --check` passed for that copy change.
