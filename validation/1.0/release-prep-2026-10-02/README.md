# Letter Within 1.0 App Review resubmission — 2026-10-03

## State and boundaries

- Worktree HEAD at start: `1c12928e8f20a93b85e341037b12ef3835017f53`.
- App Store Connect (ASC) iOS 1.0 is **Waiting for Review** under submission `71fb461c-dead-493a-bc4f-f8ade898b693`, with Build **1.0.0 (17)** attached. Monthly, Yearly, Lifetime, and the subscription group also show Waiting for Review. Manual release remains selected.
- Build 17 was built and uploaded after the original read-only audit. The earlier candidate-v4 through candidate-v8 screenshot drafts were superseded by the nine titled candidate-v9 screenshots on October 3; their 01–09 order persisted after reloading the ASC version page. With the owner's authorization to modify and submit, Build 12 was detached, Build 17 selected, Review Notes saved, the legal-links recording attached to the rejection reply, and the revised version resubmitted on October 3.

## ASC field review and submitted change

| Field | Observed | Prepared action |
| --- | --- | --- |
| 6.9-inch screenshots | Ten light candidate-v3 images were present at the initial audit | The approved nine-image `candidate-v9/final/` set replaced the earlier drafts on October 3. Superseded capture drafts were removed from the working tree; the original harness captures were not uploaded. |
| Review Notes | Old short note covered password sign-in, onboarding, local records, no AI; it omitted the corrected purchase route and legal links | Saved a Build 17 note on October 3. Review credentials remained solely in ASC's dedicated fields. |
| App Review sign-in | Sign-in required is checked and credential fields exist; on October 3 the owner confirmed the dedicated account has no Plus | Keep this account for the reviewer to inspect purchase terms and both links. The entitlement check is owner-reported; this Mac's Build 17 installation could not sign in because its local records belong to another account. If needed, put a separate paid account in ASC, never in chat. |
| App Description / EULA | Description ends with Apple's Standard EULA URL | No copy change indicated. Verify the destination again with the final build. |
| App Privacy | Published Privacy Policy URL is `https://letterwithin.app/privacy`; eight published data types | No change indicated by this read-only audit. |
| Other listing fields | Promotional text, description, keywords, Support URL, Marketing URL, app identity and manual release were read | No proven correction this pass. Recheck current copy with the final archive and privacy audit. |

Apple's September 30 message cites 2.3.10 (Google Play text in the iOS binary) and 3.1.2(c) (functional Privacy Policy and Terms of Use links in the purchase flow). Apple asks for a screen recording in the reply that opens both links and for the same explanation in Review Notes. A substantial UI update receives review as part of the resubmitted version and its content; the previous review does not approve the new UI.

### Superseded Review Notes draft

```text
Build 17 updates Letter Within to a dark interface across Today, Cycle, Care, Patterns, and Plus. The nine iPhone screenshots were refreshed to match this build. The iOS app no longer shows Google Play purchasing text. The Plus purchase flow shows each subscription's name, period, and full localized price, with working Privacy Policy and Terms of Use links below the purchase action and when changing a plan. The App Review reply includes a short iPhone Build 17 recording that opens both links from the purchase flow.

Use the dedicated review account in the sign-in fields above. Tap “Use a password instead” and complete the three-step onboarding. This account has no Plus, so the purchase flow is visible. Its health record set is empty and remains on the device; synthetic entries may be added in Today and Cycle. Care is free. Open Patterns, tap “See plans,” then tap Privacy Policy and Terms of Use below the purchase button. Monthly and Yearly are selectable. Restore a previous purchase is on the free Plus screen. Please do not make a purchase unless needed for review.

The App Privacy field links https://letterwithin.app/privacy. The App Description contains the Apple Standard EULA link. Letter Within does not use AI or provide diagnosis or emergency care.
```

The final note must describe only controls observed on the exact review build. The owner confirmed the dedicated review account has no Plus on October 3; this Mac's Build 17 installation could not independently sign in due to its local-account owner marker. Confirm the recording is attached to the reply and the legal destinations before saving. A separate Plus-enabled review account may be provided through ASC if needed for paid features.

### Recording and superseded reply draft

The owner supplied a physical-iPhone TestFlight recording and confirmed that it came from Build 17. The build number is not visible in the frames, so the recording alone does not establish build provenance. A 28.97-second excerpt at `validation/1.0/testflight-1.0.0-build-17/app-review-legal-links-clip.mp4` shows the no-Plus purchase screen with Monthly and Yearly terms, then opens Privacy Policy and Apple's Standard EULA from that screen. The clip omits unrelated navigation and the later sandbox purchase attempt; the original is preserved on the owner's Desktop. Do not describe the clip as proving a successful purchase or subscription management.

```text
Hello App Review,

Thank you for reviewing Letter Within 1.0. Replacement Build 17 uses the updated dark interface, and all nine iPhone screenshots match it. The iOS app no longer includes Google Play purchasing references.

The Plus purchase flow displays the subscription names, periods, and full localized prices. Privacy Policy and Terms of Use links appear below the purchase action and open their respective pages. The attached short recording from an iPhone running TestFlight Build 17 demonstrates both links from the no-Plus purchase screen. The Privacy Policy URL is in ASC's Privacy Policy field; the Apple Standard EULA URL is in the App Description. Review Notes describe the review account and route.

Thank you.
```

The completed ASC actions are summarized below; the drafts above were not sent verbatim. ASC retains the exact saved note and sent message.

### ASC actions completed on October 3

- Detached Build 12, selected Build 17, and saved the version. After reload, the version page still showed Build 17 and the nine candidate-v9 screenshots in 01–09 order.
- Saved Review Notes describing the dark UI, removal of Google Play text, subscription terms and legal links, the dedicated no-Plus account, and the route Patterns → See plans. The sign-in credentials stayed in ASC's dedicated fields and were not copied into this record.
- Attached `validation/1.0/testflight-1.0.0-build-17/app-review-legal-links-clip.mp4` to the existing rejection thread and sent an English reply explaining both fixes and the UI update. The thread showed the sent message and video attachment after reload.
- Used Update Review, then Resubmit to App Review. After reload, submission `71fb461c-dead-493a-bc4f-f8ade898b693` showed Waiting for Review for Build 17 and all four associated purchase items. The version page still selected manual release.

## Candidate-v4 screenshot audit

The former candidate-v4 harness captures were reviewed with `apps/mobile/tool/manual_qa_app.dart`, which mounts individual components or a test shell. Those superseded files were removed during the documentation cleanup; the retained v9 set and v8 provenance are documented under `artifacts/app-store/iphone-69/`.

| File | Visual/content check against current source and full app | ASC disposition |
| --- | --- | --- |
| `01-care-chooser.png` | Care choices and text match the complete app's Care route observed from its bottom tab. | Preserve as reference; recapture through full app. |
| `02-privacy.png` | Privacy explainer text and style match its current widget; harness opened it directly. | Preserve; recapture through actual onboarding/Settings path. |
| `03-today.png` | Today card, check-in, and bottom tab text match current widgets; synthetic Sep 19 state was not replayed through the full app. | Preserve; recapture with synthetic data in full app. |
| `04-cycle.png` | Cycle ring and current-cycle content match current widgets; screenshot used the test shell and synthetic history. | Preserve; recapture through full app. |
| `05-flow-days.png` | Current Cycle detail sheet and flow-day rows match current widgets; underlying saved dates were not replayed in full app. | Preserve; recapture through full app. |
| `06-day-editor.png` | Current day editor content matches current widget; direct fixture entry bypassed the saved-day route. | Preserve; recapture through full app. |
| `07-patterns-cycle.png` | Shows the current Mood & patterns section despite the filename; the harness bypassed the production Plus gate. | Preserve as reference; recapture with a Plus-enabled account through Patterns. |
| `08-patterns-cycle.png` | Shows the current Cycles & bleeding section; the harness bypassed the production Plus gate. | Preserve as reference; recapture with a Plus-enabled account through Patterns. |
| `09-what-helped.png` | Shows the current What helped section; the harness bypassed the production Plus gate. | Preserve as reference; recapture with a Plus-enabled account through Patterns. |
| `10-care-heavy.png` | **Wrong path.** It renders the old static `CareHeavyScene`. The complete app's “I feel heavy” route opened `CareBreakFlow` with blue rain, scene controls, and “crying is fine here.” | Preserve file for audit, **exclude from upload**, replace with a real-nav capture. |

`full-app-care-heavy.png` and `full-app-cycle-backfill-safe-area.png` are native captures from complete-app `lib/main.dart` on simulator `532588E3-4DF4-4630-ABE8-A807DDB90AC2`. The app was run as a local debug build from current source, not a Build 17 archive. The Backfill sheet's top edge remained below the status bar with `showExperienceSheet(useSafeArea: true)`, so the one-line source change was retained. These validation images are not storefront assets.

### Complete-app 6.9-inch source set

The former candidate-v4 full-app source set came from a dedicated screenshot simulator and a local debug-only complete-app capture entrypoint. Those superseded files were removed during the documentation cleanup. The retained v8 provenance and v9 upload manifest are the current screenshot record.

The earlier candidate-v4 set contained ten composed JPEGs and was superseded. The current candidate-v9 manifest records each retained source, caption, hash, and upload status; the owner-approved nine-file order persisted after reload.

The intermediate v5 through v8 review passes refined the order, Today proof,
Comfort Kit, and Cycle recording evidence. Their superseded draft files were
removed; candidate-v8's retained JPEGs and manifest preserve the provenance
used by v9. The day-editor capture was reached through Cycle → Cycle 2 →
6/22/2026 and uses synthetic records.

The owner asked to add a title above every image and then indicated the set
could be uploaded. The `candidate-v9/` set contains nine titled
1320 × 2868 JPEGs with all v8 app views fitted in full, no phone mockup, and
the existing captions unchanged. Full-image visual review found the native
Privacy content dense and the report category labels awkwardly wrapped, with
the next report card entering at the bottom; all other frames are complete.
The owner specifically confirmed deleting ten candidate-v4 screenshots and
uploading the nine v9 files. ASC processed the multi-file upload out of order;
Media Manager was used to restore the manifest's 01–09 order, which persisted
after returning to the iOS 1.0 version page. At the time of the screenshot
replacement, Build 12 remained attached and no Review Notes, reply, or review
submission changed; the later resubmission attached Build 17.

The QA harness review removed five direct old Care scene frames and switched Care fixtures to `OriginalCareAnimationPort`. Its remaining tracker, Patterns, report, privacy and backup fixtures still bypass production navigation and remain internal QA only.

## Auto-renewing subscription disclosure audit

The current source renders Monthly and Yearly plan names, StoreKit/RevenueCat's localized full price with `/ month` or `/ year`, and renewal cadence on the plan cards. The purchase action repeats the selected price. The free purchase section and active plan-change section both render clickable **Privacy Policy** and **Terms of Use** links. Both destinations returned HTTP 200 on October 2: `https://letterwithin.app/privacy` and Apple's Standard EULA. ASC's published App Privacy field contains the former URL; the App Description contains the latter. Thus the current source and visible metadata cover the listed disclosure fields. The owner-provided Build 17 recording opening both links from the purchase flow was attached to the reply; App Review will determine compliance for the resubmitted Build 17.

Apple reference: [auto-renewable subscription sign-up and pricing guidance](https://developer.apple.com/app-store/subscriptions/) and [Developer Program Schedule 2](https://developer.apple.com/support/terms/apple-developer-program-license-agreement/).

## Build 16 physical iPhone P16-05 finding

The tester installed Build 16 through TestFlight using an ordinary iCloud/Apple Account, bought a subscription in the app, and saw the expected active plan. Tapping “Manage or cancel subscription” opened Apple's Chinese-language Subscriptions page showing no subscriptions (redacted tester screenshot inspected locally). This shows the opened system view's contents, not loss of Letter Within entitlement.

Build 16 uses RevenueCat's Apple `CustomerInfo.managementURL` and opens that URI externally; there is no hard-coded Apple Developer URL. TestFlight purchases use Apple's sandbox even when initiated by an ordinary tester account. RevenueCat Test Store is a different environment and is not in a TestFlight release build. The observed empty standard account page is consistent with a production-vs-sandbox management context mismatch. The exact sandbox account/transaction visible in iOS settings has not yet been observed, so a broken sandbox-management handoff cannot be ruled out.

Reproduce with a disposable app account: record the installed TestFlight build and Apple purchase confirmation; buy Monthly or Yearly; confirm Plus active after relaunch; tap management; separately inspect iPhone Settings → Developer → Sandbox Apple Account → Manage → Subscriptions for the same test purchase, or follow Apple's current TestFlight instructions to sign into a dedicated Sandbox Apple Account before purchase. Record the purchase time and compare before the accelerated test subscription expires. If it appears only in sandbox settings, this is a TestFlight management-route limitation, and production code should retain the store-provided management URL. If the same purchase is absent there while Plus remains active, collect a redacted transaction/product identifier and RevenueCat sandbox customer record for diagnosis. A production purchase must later be checked after approval; if its management route is also empty for the purchasing account, treat that as a product bug.

P16-05: **Partial pass** — Apple sandbox purchase and Plus plan display passed by tester report; management opened an empty system page, so sandbox management remains unresolved. No new app code change was justified by this screenshot alone.

Sources: [Apple TestFlight subscription testing](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testing-subscriptions-and-in-app-purchases-in-testflight/), [Apple sandbox subscription management](https://developer.apple.com/documentation/storekit/testing-disabling-auto-renew), [RevenueCat Test Store](https://www.revenuecat.com/docs/test-and-launch/sandbox/test-store), [RevenueCat Apple/TestFlight sandbox](https://www.revenuecat.com/docs/test-and-launch/sandbox/apple-app-store), [Apple App Review submission scope](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/overview-of-submitting-for-review).
