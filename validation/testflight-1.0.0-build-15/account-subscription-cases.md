# Account and subscription device cases

Use disposable Letter Within accounts **A** and **B**, separate email addresses,
and synthetic records. Keep the app installed between account switches so local
record ownership can be checked. Record the app build, iPhone model and iOS
version, app-account alias, Apple sandbox tester alias, time, result, and a
redacted screenshot for each case. Do not include health text or credentials in
the evidence. Back up any data you need before the destructive deletion case.

Build 15 has a known failure at A10–A12: after server account deletion, Plus
incorrectly says purchases are unavailable on this build and offers no path to
another account. Run those cases on a later build containing the local fix.

## Physical iPhone setup for Apple Sandbox

1. Use an iPhone with TestFlight Build 15 and an **authenticated, disposable**
   Letter Within account A. The installation where A was already deleted in
   Build 15 cannot reach the purchase flow; use another test installation, or
   wait for a build containing the account-connection fix. Do not clear local
   records merely to make a test pass.
2. Confirm the Sandbox Apple Account **P1** is listed in App Store Connect →
   Users and Access → Sandbox and has completed any Apple email verification.
   The Letter Within account A and Apple sandbox tester P1 are separate.
3. TestFlight purchases are automatically sandbox transactions. To use P1's
   specific sandbox settings on an iPhone, Apple instructs testers to sign out
   of the **production Apple Account under Media & Purchases**, then open
   Settings → Developer → Sandbox Apple Account and sign in as P1. Use a
   dedicated test iPhone if available: signing out of Media & Purchases can
   interrupt access to purchased content in other apps. Do not sign out of the
   device's main Apple Account or enter P1 in Sign in with Apple for the app.
4. Return to Letter Within → Plus. Run A01 and A03, then A04. Confirm the Apple
   purchase sheet shows the intended product and billing terms; note an
   “Environment: Sandbox” label if Apple displays one. Wait for the app to
   update, then verify `letter_plus` in the paid Patterns
   entry and run A05–A06. Record the exact step and screenshot if a prompt
   closes without confirmation; do not call that a successful purchase.
5. For a clean no-purchase comparison, use a separate sandbox tester P2 and
   app account B, ideally on a separate test installation. Run A07–A09 only
   after A's purchase/restore result is recorded. A10–A13 require a later
   binary with the deletion fix.

Apple's [TestFlight sandbox instructions](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testing-subscriptions-and-in-app-purchases-in-testflight/)
and [sandbox account setup](https://developer.apple.com/help/app-store-connect/test-in-app-purchases/create-a-sandbox-apple-account/)
describe the account separation and device steps. On 2026-10-02, two verified
Sandbox testers could not stay signed in on two iOS 26.5 simulators; Apple
purchase and restore therefore remain **unverified**, despite successful Apple
product loading and a no-purchase Restore result.

## Suggested order

| Case | Steps | Expected result |
| --- | --- | --- |
| A01 First account, free | Install fresh. Create A with a new email or sign in to a disposable A. Complete onboarding. Open Today, Cycle, Care, Patterns and Plus. | Free tracking, care and prediction are usable. Patterns' paid entry and Plus plans do not grant Plus before a purchase. Plus shows all three products with localized price and billing terms. |
| A02 Free data | In A, enter one synthetic period, a symptom, a note, and a Care action. Relaunch. | Entries remain visible. No purchase prompt blocks recording, safety, or backup entry. |
| A03 Restore without purchase | In A, tap Restore before buying. | Clear “no purchase found” or equivalent result; no Plus entitlement, no false “unavailable on this build” if products loaded. |
| A04 Purchase | With sandbox Apple tester **P1**, buy one product in A. Confirm the Apple purchase sheet and billing terms before accepting. | Purchase succeeds, `letter_plus` unlocks, paid Patterns becomes accessible, and the other free data remains intact. Capture product and displayed localized price. |
| A05 Relaunch and offline | Force close and reopen; then temporarily disconnect network and reopen once more. | Active Plus returns on a connected launch. Offline state does not claim the user has permanently lost Plus or delete records. Reconnect and refresh. |
| A05a Change subscription | With an active Monthly Apple subscription, open Plus → Change plan → Switch to Yearly. Check the Apple purchase sheet's price and effective date before confirming; reopen Plus after the store records the change. If Manage subscription appears, open it and check the App Store destination. Repeat Yearly → Monthly with a separate disposable subscription if needed. | The in-app action submits the other subscription to the store. The current plan and Plus access remain until the store makes the new plan effective. Apple may defer a same-level crossgrade until renewal. The single-plan view shows the store-reported next renewal for an auto-renewing plan or access-end date for a canceled plan. If the store reports two active products, the view names the product with the latest reported purchase or renewal and shows the latest confirmed current-period end as the minimum known Plus access horizon; the durations are never added. It notes the overlap and removes the further switch action. Management appears only when the store provides a destination; it is absent in Test Store. Lifetime is a separate purchase. |
| A06 Return to same account | In A, sign out, inspect the login screen, then sign back into A. Confirm whether Plus reappears automatically. Tap Restore only if the purchase is missing; the active Plus view does not show Restore. Test reinstall separately only after exporting an encrypted local-record backup. | Sign-out exposes neither records nor Restore. Returning to A restores access to its on-device records and normally reloads its Plus entitlement without another payment or manual Restore. If automatic lookup fails, the free Plus view offers Restore. |
| A07 Free account B | Sign out of A and sign in to a distinct B on the **same installation**. Inspect all tabs before purchasing. | A's local health records are closed to B, not shown as B's records. B does not inherit A's Plus merely from local data. Record any mismatch or entitlement transfer instead of assuming policy. |
| A08 B's own records | On a clean install or separate device for B, enter distinct synthetic records, relaunch, then inspect all free tabs and Plus. | B sees B's records; free tracking and Care work without Plus; paid Patterns stays locked until B has entitlement. |
| A09 Cross-account restore | In B, tap Restore while signed into P1, then repeat with a separate unpaid sandbox tester **P2** where possible. | Note the actual RevenueCat transfer/restore policy result. P2 must not manufacture a purchase. No A health data appears in B. Do not treat Apple tester identity and Letter Within account identity as the same thing. |
| A10 Delete A | Return to A with synthetic records, confirm the destructive account deletion, then inspect Today/Cycle/Care/Patterns and account settings. | Server account is deleted; local records remain readable on that device. Account settings clearly offers “Create or connect an account”. |
| A11 Plus after deletion | From Patterns open Plus and try the available account action. | Plus explains that an account is needed, with an account-settings action. It does not say purchases are unavailable on this build, and it does not present a dead Restore button. |
| A12 Cancel and reconnect | Open the new-account screen from settings, go Back, check local records, then reopen and connect a **new** account B. Inspect Plus before restoring. | Cancel leaves deleted-account local records readable. Explicit connection links those records to B; they do not silently open during an unrelated sign-in. B begins without Plus unless its own store entitlement or the configured transfer policy grants it. |
| A13 Restore after deletion | With B connected, tap Restore first with P2, then with P1 only if testing transfer is intended. | P2 reports no purchase; P1 follows the configured RevenueCat transfer policy. No duplicate charge. Record exact message and entitlement state. |
| A14 Network failure and retry | With a connected account, disable network, open Plus and tap retry; reconnect and retry. | Offline state is distinguishable from missing account and missing build configuration. Plans load again after reconnect. |
| A15 Sign-out and return | Sign out of B, inspect the auth gate, then sign back into B. | Signed-out state exposes neither B's records nor Plus/Restore. Returning to B restores access to B's local records and looks up B's Plus state automatically. |

## Simulator and store coverage

- A local simulator scenario can exercise A10–A12 UI, state transitions, local
  record ownership and error wording immediately. Widget and repository tests
  cover normal and delayed logout/login ordering. A synthetic store client is
  useful for deterministic account-state checks; it does **not** validate
  RevenueCat or Apple billing.
- RevenueCat Test Store can exercise SDK offerings, purchase, entitlement,
  restore, and Monthly ↔ Yearly purchase changes with its **Test Store public key** in a development build. Keep that
  key out of release builds. This checks RevenueCat integration, not the Apple
  purchase sheet, effective date, or App Store Connect prices.
- TestFlight uses Apple's sandbox for in-app purchases. Run A01, A03–A06,
  A09 and A13 on a physical iPhone with the configured Apple products before
  App Review. A10–A12 need a build containing the local deletion fix; Build 15
  is already known to fail them.
- Updating the installed app keeps its local container. Deleting the app
  removes the local encrypted health database; signing back in only recovers
  the account and linked Plus entitlement, not those local records. Use the
  explicit encrypted backup export/import for records before a reinstall.

## Result record

`Case | build/device/iOS | app account | sandbox tester | pass/fail/blocked | exact action order | redacted evidence`

If A07, A09, A12 or A13 shows an unexpected entitlement transfer, stop using
the affected test accounts for other cases and record the account and tester
aliases for a RevenueCat project-level investigation. Never include raw IDs in
shared screenshots.
