# Build 16 physical iPhone acceptance

Target: the **distributed TestFlight 1.0.0 (16)**, not a simulator build with
the same version number. Use disposable Letter Within accounts and synthetic
health records. Record iPhone model, iOS version, region/storefront, time zone,
TestFlight build, app-account alias, Sandbox Apple Account alias where relevant,
and Pass/Fail/Blocked for each case. Keep redacted evidence only; never record
passwords, verification codes, or real health entries.

TestFlight In-App Purchases use Apple's sandbox and do not charge the tester.
The Letter Within sign-in account, the TestFlight Apple Account, and the Sandbox
Apple Account serve different roles. Do not switch accounts mid-case without
recording which one changed. For Sandbox Account controls on a TestFlight app,
follow Apple's current device instructions; a second sandbox tester is useful
for a truly unpaid starting state. Do not buy with a production account.

## Run in this order

| ID | Actions on Build 16 | Expected result / evidence |
| --- | --- | --- |
| P16-01 Install and preserve data | Confirm TestFlight displays **1.0.0 (16)**. Update an installation containing synthetic Build 15 records; separately use a clean install only on a disposable device/account. Launch, background, force-quit, relaunch. | Update retains local records and settings; no crash, blank page, or stuck splash. Uninstall/reinstall is a different test and erases app-local data unless an OS backup restores it. |
| P16-02 Account lifecycle | Complete onboarding, sign in with the disposable Apple test identity, relaunch, sign out, and sign back in. On a disposable app account only, delete the account, open **You → Account → Create or connect an account**, and reconnect. | Session survives relaunch; signed-out local records stay protected; Account provides a reconnection route after deletion. Recreated server account must not be described as restoring local health data or automatically restoring a deleted purchase profile. |
| P16-03 Cycle and Care | With synthetic history, add two eligible period starts, reopen Cycle, edit a date, perform two rapid edits, delete the newest synthetic record, and relaunch. Compare Today, Cycle, and Patterns after each settled action. Open Care, Comfort Kit, and SP6/LV3 safety screens. | Cycle first load uses the available estimate without a temporary “forming” regression; latest edit/delete wins and deleted records do not reappear. SP6/LV3 rendering is a UI check only, not clinical approval. |
| P16-04 Free Plus and review links | With a signed-in app account that has no Plus, open Plus from a gated feature. Let offers load or use Retry. Record all three product names, periods, localized full prices, and Lifetime one-time status. Open **Privacy Policy** and **Terms of Use** from the purchase flow. Repeat after selecting another plan and after relaunch. | Three real Apple offers appear; the selected plan's renewal or one-time terms are clear before the Apple sheet. Both links open the intended public pages on iPhone. No Google Play or desktop-purchase copy appears in the iOS app. Record a redacted screen video of this route for Apple's 3.1.2(c) reply. |
| P16-05 Purchase and plan state | With a confirmed Sandbox Apple Account and disposable app account, buy one subscription. Check the Apple confirmation sheet before approving. Relaunch and reopen Plus, Patterns, and Reports. Expand plan choices; inspect the owned plan, the other subscription, and Lifetime. Open **Manage or cancel subscription**. | Plus activates and persists; current plan and access/renewal date are coherent; owned plan cannot be purchased again; alternatives show their full terms and legal links. Management opens the relevant iPhone sandbox subscription settings, not an Apple Developer membership page. Record whether Apple changes plans immediately or at renewal; do not infer additive durations. |
| P16-06 Restore and deletion boundary | While Plus is active, verify the redundant Restore action is hidden. Sign out and back in with the same app account. If using the disposable account-deletion case, delete it, reconnect the same identity, then tap **Restore a previous purchase** if Plus is absent. Use a separate fresh app and sandbox account for the unpaid state. | Same-account sign-in refreshes entitlement when the store is reachable; Restore can recover a store purchase after account recreation without a new charge. Deleting an app account does **not** cancel the Apple subscription. Never interpret a second sandbox tester's empty history as a failed restore for the first tester. |
| P16-07 Offline Plus | Confirm active Plus while online, then turn off **both Wi-Fi and cellular data** on the iPhone. Force-quit and relaunch. Open Today, Cycle, Care, Patterns, existing reports, and Plus. Export a report if an active entitlement is cached. Reconnect and refresh. | Recorded data and confirmed Plus features remain usable offline; a temporary store read failure does not remove access. On reconnect, the store's current entitlement reconciles. Record the last confirmed expiry and any long-offline boundary separately. |
| P16-08 Files and native sharing | With synthetic data and Plus, generate Visit Summary PDF, raw CSV, and Clinical Pattern Report. For each, dismiss the share sheet, repeat with **Copy**, and repeat with **Save to Files**. In Files, choose **On My iPhone**, then iCloud Drive if enabled; try Google Drive only if its Files provider is installed and enabled. Repeat export after each action. | A local file is created, contents and range are correct, and Reports buttons return from loading after Cancel, Copy, and Save. The iOS Files providers depend on installed apps and account setup. **If Build 16 hangs on iPhone, fail this case; the later Mac-only source fix does not prove an iPhone fix.** |
| P16-09 Reminder delivery | Turn Comfort Window reminder on before a reliable window exists; set lead time and relaunch. With eligible synthetic history or a natural window, grant notification permission, verify the scheduled local time, wait for actual delivery, tap it, then turn the reminder off. | Preference can be enabled early, with no notification scheduled until evidence qualifies. The iPhone receives and opens an eligible reminder; turning it off or invalidating history cancels it. If no qualifying window can be created, delivery is **Blocked**, never Pass based on Settings alone. |
| P16-10 iPhone presentation and privacy | Check Onboarding, Today, Cycle, Care, Patterns, Plus, Reports, and Settings at default and larger Dynamic Type. Check VoiceOver order on purchase and legal links, safe areas, Screen Cover in the app switcher, and analytics default Off after clean install. | Text/buttons remain reachable and legible, private records are hidden in switcher preview, and analytics opt-in survives relaunch without silently changing state. |

## Handoff

For every failure, record the case ID, exact tap sequence, timestamp/time zone,
expected versus observed result, build number, whether relaunch changes it, and
a redacted screenshot or short screen recording. Distinguish a TestFlight
sandbox transaction from RevenueCat Test Store simulation.

Build 16 has a known Mac TestFlight share-completion defect. The source fix is
committed after the Build 16 archive and is **not inside Build 16**. Physical
iPhone testing of P16-08 determines whether the distributed iPhone build is
affected, but does not validate that later source fix on Mac. Build 16 must not
be attached to App Review as the final candidate.
