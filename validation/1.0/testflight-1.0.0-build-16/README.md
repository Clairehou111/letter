# TestFlight 1.0.0 (16) — integration and Mac validation

## Source and preflight

- Release source: local `main` commit `db287e58664a48d703a5a07c797be8952433f91d`.
  `apps/mobile/pubspec.yaml` is `1.0.0+16`. The release configuration had
  nonempty Supabase, Apple RevenueCat, and PostHog public tokens/host; no
  token values are recorded here.
- Review scope: all local commits after Build 15 source `4ec9f74`, including
  account deletion and reconnection, Plus plan selection and disclosure,
  Comfort Window timing, optional analytics, and offline entitlement.
  Independent CR found and the release source fixes same-account stale store
  reads, missing legal links during plan change, a no-op Comfort Timing row,
  and concurrent purchase/Restore actions.
- `flutter analyze --no-pub`: no issues. Full
  `flutter test --no-pub --concurrency=4 -r compact`: **727 passed, 1 existing
  skipped, 0 failed**. `git diff --check`: passed. The focused repository,
  Plus, and Settings suites also passed. Tests include ordinary sequential
  purchase/refresh, stale reads after purchase and Restore, valid store
  revocation, plan-change legal links, pending purchase controls, and early
  Comfort Timing configuration.
- Release wrapper: `tool/build_ios_release.sh --build-number=16` from
  `apps/mobile`. Xcode archive and IPA report **1.0.0 (16)**, bundle
  `app.letterwithin`, iOS deployment target 15.0. Archive signature passed
  `codesign --verify --deep --strict`. Local IPA:
  `apps/mobile/build/ios/ipa/Letter Within.ipa`, SHA-256
  `c9dda6a7573295e135d963e72a8d0eb1a70a30809db26ff17ba80189968b7352`.

## TestFlight distribution

- Xcode Organizer reports **Uploaded** at 2026-10-02 16:22 JST. App Store
  Connect Build Uploads showed version 1.0.0 (16), created 16:22,
  **Processing** when last checked; the web status lagged installation.
- The existing internal group distributed Build 16 to Mac TestFlight. TestFlight
  offered 1.0.0 (16), update and launch succeeded, and the installed app's
  `CFBundleVersion` is **16**. This upload is for TestFlight only; no App Review
  submission is authorized or recorded.

## Mac TestFlight regression

Target: the **distributed Build 16**, not the local IPA or a debug simulator.
This Apple Silicon Mac can install the app through the existing internal
TestFlight group. Record the installed build number before counting any case
as passed. Use synthetic records and a disposable Letter Within account for
account deletion. Do not delete an existing account without its owner's
explicit action-time approval.

| Case | Build 16 result | Evidence and remaining limits |
| --- | --- | --- |
| TF16-01 Install/update, launch, account session, onboarding | Partial pass | TestFlight installed Build 16 over Build 15; launch succeeded and the existing local records remained. Sign out sealed those records, and signing back in with the same Apple test identity restored them. Fresh onboarding on Build 16 remains untested. |
| TF16-02 Account deletion and reconnection | Pass with limit | With the owner's confirmed disposable Apple test account, server-account deletion completed. Settings showed **Create or connect an account**; the deleted account's local records remained accessible. Opening and cancelling sign-in worked. Reconnecting the same Apple test identity created a signed-in account. This does not test another device. |
| TF16-03 Free Plus catalog and disclosure | Pass with transient store risk | After deletion, Plus requested an account through Settings → Account. The reconnected account initially had no Plus and loaded three Apple products in the Chinese storefront: Monthly ¥58/month, Yearly ¥298/year, Lifetime ¥698 once. The first two earlier catalog loads failed with a StoreKit error; retry later recovered without a configuration change. Legal links were present. |
| TF16-04 Purchase, Restore, and plan changes | Partial pass | Active Yearly date was shown. Yearly was disabled; Monthly and Lifetime could be selected and their localized billing terms shown. Privacy and Terms links opened their destinations. After account deletion and reconnection, Yearly was initially absent; tapping **Restore a previous purchase** recovered active Yearly with its renewal date, and the Restore button disappeared. No new transaction was completed. Manage subscription opened the Mac App Store subscriptions sheet, which showed only the Mac's production Apple Developer membership, not the TestFlight sandbox purchase. [Apple's StoreKit documentation](https://developer.apple.com/documentation/StoreKit/AppStore/showManageSubscriptions%28in%3A%29) says the management sheet is unsupported for iPhone apps running on Apple Silicon Mac; an iPhone test remains required. |
| TF16-05 Plus features and offline behavior | **Fail: export loading persists** | Paid Patterns and Clinician Reports opened with retained local records; report ranges changed. Visit Summary PDF export saved a local copy and opened the native share sheet. The owner confirmed that **Save and Copy complete but Reports keeps loading**; cancelling Save also left the spinner and disabled Clinical Pattern Report export for minutes. This is not limited to cancellation. Raw CSV and real offline operation remain untested. Repository tests cover store refresh/Restore failures and offline report export, but are not a TestFlight network test. The owner declined a whole-Mac network outage; no reliable installed per-app blocker was available. |
| TF16-06 Comfort Window and notification preferences | Partial pass | Enabled before reliable estimates, set Timing to one day before, and confirmed it persisted after leaving Settings. The UI said no reminder was scheduled yet. Restored the switch to Off after testing. Delivery on an iPhone remains untested. |
| TF16-07 Cycle, Today, Care, Patterns, reports | Partial pass | Today loaded retained local records after update and same-account sign-in. Cycle's first load showed a concrete usual-cycle estimate rather than a temporary forming state. On the disposable QA account, the current period start was changed from Sep 26 to Sep 27: Cycle immediately showed day 6 and Today matched. Editing it back to Sep 26 restored day 7 and the original estimate in both screens. Care and its Comfort Kit loaded; the SP6 safety gate and locator diagram opened. Patterns loaded all three sections from retained records, and Reports opened. Rapid overlapping edits and deletion on the distributed build remain untested. Rendering a point locator does not constitute clinical approval. |
| TF16-08 Optional analytics and support copy | Partial pass | The usage/error-report preference was Off, and About & support displayed `support@letterwithin.app`. No opt-in event payload was generated or inspected. |
| TF16-09 Visual and device integrations | Partial | Plus and Settings screens, Privacy Policy and Terms links rendered and opened on Mac. The Mac native share sheet listed AirDrop, Mail, Messages, Notes, Simulator, Freeform, Save, Copy, and Edit Extensions. **Save** opened a macOS save dialog with **iCloud Drive** in its expanded sidebar; our iCloud check stopped before saving. No Google Drive target or desktop app was present on this Mac. iPhone Dynamic Type, notification delivery, its share targets, and physical-device purchase management remain unverified. |

## Local simulator check of the follow-up fix

- A fresh iOS Simulator build from `c3620b1` was installed over the existing
  signed-in **Letter Account QA 2026-10-02** simulator, without uninstalling
  the app. Its account and local records persisted. This local build also has
  bundle version 16, but is **not** the distributed TestFlight Build 16.
- The simulator uses the RevenueCat Test Store (`test_` configuration). Its
  previous Plus state had expired at a store refresh, and Restore found no
  active purchase. A Test Store Monthly valid test purchase activated Plus;
  no Apple transaction sheet or real charge was used.
- Visit Summary PDF export opened the native iOS share sheet. Dismissing it,
  using **Copy**, and using **Save to Files → On My iPhone → Save** each returned
  to Reports with **Export Visit Summary** and **Export Clinical Pattern
  Report** enabled. Repeating the export also worked; no loading state stuck.
- This tests ordinary native iOS sharing on the fix source. The 15-second
  fallback applies only to an iOS app running on a Mac, so a new Mac TestFlight
  build is still needed to prove the specific Build 16 failure is resolved.

## Release gates

### 2026-10-02 physical iPhone subscription-management follow-up

The tester installed distributed Build 16 from TestFlight with an ordinary
iCloud/Apple Account, purchased a subscription inside Letter Within, and saw
the expected active plan. **Manage or cancel subscription** opened Apple's
Chinese-language Subscriptions page showing no items. This is **P16-05 partial
pass** for purchase/Plus display and **unresolved** for sandbox subscription
management. The screenshot does not show lost Plus access. Build 16 uses
RevenueCat `CustomerInfo.managementURL`, not a hard-coded Apple Developer or
Google Play destination. TestFlight purchases use Apple's sandbox even when
the tester starts from an ordinary account; RevenueCat Test Store is not used
by this release build. Inspect Settings → Developer → Sandbox Apple Account →
Manage → Subscriptions on the same iPhone while the accelerated transaction is
active. Record the result and the purchasing account context without recording
credentials. [Detailed finding and sources](../release-prep-2026-10-02/README.md#build-16-physical-iphone-p16-05-finding).

- **Build 16 is not an App Review candidate:** on this iOS app running on
  Apple Silicon Mac, the native share action can finish without returning a
  completion to Flutter; Reports then remains in its exporting state. A local
  source fix bounds the native result wait to 15 seconds only on iOS-on-Mac,
  using Apple's `ProcessInfo.isiOSAppOnMac`; iPhone sharing keeps its original
  unbounded wait. The saved-file receipt no longer claims an unconfirmed
  share did not happen. This fix is **not in Build 16** and needs a new
  TestFlight build and Save/Copy/Cancel regression. On Mac, a user who spends
  more than 15 seconds in the still-open share panel may see a local-save
  receipt when it eventually closes; a second export must also be checked.
  The follow-up source passed `flutter analyze --no-pub`, the complete
  `flutter test --no-pub --concurrency=4 -r compact` run (**731 passed,
  1 existing skipped, 0 failed**), and `flutter build ios --simulator --debug
  --no-pub`. Its tests cover immediate success, ordinary dismissal, delayed
  success, and a native completion that never returns.
- On 2026-10-02 the public `https://letterwithin.app/privacy` page was
  reloaded and showed the October 2 optional-analytics copy from the current
  website design. App Store Connect App Privacy showed its published eight
  data types and the same privacy URL. A final archive and an opted-in event
  still need comparison with those disclosures before App Review.
- SP6/LV3 locator, copy, pressure instruction, and safety text remain without
  qualified clinical sign-off while present in the build.
- Mac TestFlight on Apple Silicon is an iOS app compatibility environment; it
  cannot establish physical iPhone notification delivery, camera, system
  sharing, or iPhone-specific purchase behavior. Record those as unverified
  if they cannot be reproduced here. Android's Apple EULA destination is an
  Android-release issue, not a blocker for this iOS TestFlight build.
- The repository retains last confirmed Plus while store reads fail, even if
  a reported subscription end date passes during a long offline period. This
  favors access during outages and requires a later store reconciliation;
  record a separate boundary result before App Review.
