# TestFlight 1.0.0 (17) — release verification

## Build provenance

- Source HEAD: `cf12e70` (`fix: keep experience sheets below iPhone safe area`). The production tree also includes the Mac share result timeout fix from `c3620b1`.
- Build command: `apps/mobile/tool/build_ios_release.sh --build-number=17`, using the existing local release config; no secret values are recorded here.
- Full Flutter suite before archive: **731 passed, 1 existing skipped, 0 failed**. `flutter analyze --no-pub`: no issues. `git diff --check`: passed before the archive.
- Archive and IPA: iOS 1.0.0 (17), bundle `app.letterwithin`, minimum iOS 15.0. Archive `codesign --verify --deep --strict`: passed.
- IPA: `apps/mobile/build/ios/ipa/Letter Within.ipa`; SHA-256 `4309848b38ad43a8ae4aa9316e6b3d568fda5bb38d12238f0a8945d411d40375`.
- Only the production safe-area source file was committed for this build. Manual QA tool changes, screenshot assets, and existing untracked validation material were not staged into the build commit.

## Distribution and regressions

| Gate | Result | Evidence / next check |
| --- | --- | --- |
| Xcode Organizer upload | Pass | Organizer showed “App upload complete”; ASC Build Uploads showed 1.0.0 (17) Complete on October 2 at 22:11 JST. Internal Testers group has 2 testers. |
| Installed TestFlight build | Pass on Mac | TestFlight lists 1.0.0 (17); `/Applications/Letter Within.app/WrappedBundle/Info.plist` reports version 1.0.0 (17), and the installed app launched. TestFlight also showed a transient “couldn’t connect to App Store Connect” alert when Open was clicked; this did not prevent the app from running. A physical iPhone install still needs confirmation. |
| Mac Reports sharing | Pass | On the existing disposable synthetic-record account, Export Visit Summary opened the native share sheet. Escape canceled sharing; a repeat export opened it again. Copy returned to Reports with Export enabled. Canceling the Save dialog returned with Export enabled. Saving a PDF to `/private/tmp/letter-build17-visit-summary-regression.pdf` completed; a further export reopened the share sheet, and Escape again returned with Export enabled. No persistent spinner was observed. |
| iPhone purchase and legal links | Pass for disclosure links; purchase management pending | Owner confirmed the physical-iPhone recording came from TestFlight Build 17, although the build number is not shown in the video. The no-Plus purchase sheet visibly shows Yearly US$39.99/year, Monthly US$7.99/month, a purchase action with the selected price, and Privacy Policy and Terms of Use. The recording opens `letterwithin.app/privacy` and Apple's Standard EULA from that screen. It does not prove a new purchase or subscription management. |
| Dedicated App Review account Plus state | Owner confirmed: no Plus | On October 3 the owner checked the dedicated review account and confirmed it has no Plus entitlement. This is an owner-reported account check, not a successful sign-in on this Mac's Build 17 installation: that installation is bound to a different account's local records and showed the account-mismatch warning. The no-Plus account can expose the purchase flow to App Review. |
| Sandbox subscription management | Pending | Check the developer sandbox account's subscriptions on physical iPhone while the accelerated TestFlight transaction is active; Build 16's empty ordinary list is inconclusive. |
| Clinical/privacy release gates | Pending | SP6/LV3 qualified clinical sign-off and final privacy disclosure comparison remain recorded in the Build 16 report. |

Read-only privacy check on October 3: ASC currently publishes eight types (Purchase History, User ID, Email Address, Device ID, Other Usage Data, Coarse Location, Product Interaction, Other Diagnostic Data). App code defaults analytics consent to `notSet`; `PosthogAnalyticsService` starts opted out, disables automatic lifecycle capture and session replay, and accepts only fixed operational event fields after opt-in. This narrows the app-authored event payload, but does not establish every native SDK's transmitted fields or verify ASC's purposes and identity linkage. The final disclosure comparison therefore remains open.

On October 3, the owner authorized the replacement review submission. ASC iOS 1.0 now links Build 17 and shows Waiting for Review, with manual release selected. Nine titled candidate-v9 screenshots replaced the ten candidate-v4 images and remained in 01–09 order after reload; the 6.5-inch slot inherits them. Review Notes were updated, the legal-links clip was attached to the rejection reply, and that reply was sent before resubmission. See [the ASC action record](../release-prep-2026-10-02/README.md#asc-actions-completed-on-october-3).

## App Review recording

- Original owner-supplied iPhone screen recording: `/Users/clairehou/Desktop/0d5074dce124ca0a1985e0dcc5572e77.mp4`, 65.77 seconds, SHA-256 `85594f059d709c670b3f70d1c733d23f207e83625d35b724a400f21c869eaf3d`. The original was read but not modified or copied into the worktree. The owner confirmed it was captured on Build 17; the recording itself does not show the build number.
- Review excerpt: `app-review-legal-links-clip.mp4`, 28.97 seconds, H.264 592 × 1280, no audio, SHA-256 `f1eca37a0891f1e426549fc595f7a1e752f7519799aa1a51e5a78fedf0603565`. It joins source intervals 0–18 and 28–39 seconds, retaining the purchase-page-to-Privacy and purchase-page-to-EULA demonstrations. The cut removes unrelated Safari navigation and the later sandbox purchase attempt; it does not alter the visible app or legal pages.
- The clip was attached to the rejection reply in ASC on October 3. The message thread showed the sent reply and this attachment after reload.
