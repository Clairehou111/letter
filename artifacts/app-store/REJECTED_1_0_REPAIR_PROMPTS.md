# Rejected 1.0 release — handoff prompts

Checked 2026-10-02: App Store Connect version **1.0 Rejected** still attaches
**1.0.0 (12)**. The five-item submission contains the app version, subscription
group, Monthly, Yearly, and Lifetime. Apple cited 2.3.10 for Google Play text
in the iOS binary and 3.1.2(c) for missing functional Privacy Policy / Terms
of Use links in the purchase flow and metadata. Apple requests a screen
recording in the reply and explanatory App Review Notes. The ten storefront
screenshots were uploaded on 2026-09-24 and need a current-UI audit. The live
privacy page currently shows the October 2 optional-analytics copy; App Store
Connect App Privacy currently shows eight published data types.

## Prompt A — App Store Connect repair, before the new build

```text
Work on Letter Within's existing rejected iOS version 1.0 in App Store Connect
(app ID 6800270326, submission 71fb461c-dead-493a-bc4f-f8ade898b693).
Read Apple's September 30 review message and current fields before changing
anything. The rejection is for old Build 12, under 2.3.10 and 3.1.2(c).

Prepare the rejected release for a corrected binary. Verify the live Privacy
Policy URL https://letterwithin.app/privacy and the Standard Apple EULA URL
https://www.apple.com/legal/internet-services/itunes/dev/stdeula/ in metadata.
Compare the live policy, published App Privacy answers, support page, current
source, and subscription product metadata. Correct only proven metadata issues.
Audit the ten existing screenshots against the final current UI and prepare
replacement screenshots from synthetic data. Verify a working review account is
entered in App Review Information without putting credentials in chat.
Draft precise Review Notes describing the iPhone route to Plus, plan names,
periods, localized price, Privacy Policy and Terms links, Restore, and the
account/review path. Draft an App Review reply for the final candidate, and a
short redacted iPhone screen-recording shot list that opens both legal links.

Do not attach Build 16, remove the five paid items, change storefront coverage,
change manual release, send the App Review reply, press Update Review or
Resubmit to App Review, or upload/build a new binary yet. Leave a field-by-field
change log and any outstanding approval/action as the final step.

Repository context: /Users/clairehou/pyProjects/pms-research-agent/.worktrees/letter-main
Read artifacts/app-store/APP_STORE_METADATA_DRAFT.md,
artifacts/app-store/APP_PRIVACY_DRAFT.md, artifacts/app-store/README.md,
validation/testflight-1.0.0-build-16/README.md, and
specs/features/2026-09-25-release-2-0/physical-iphone-build-16-checklist.md.
Preserve unrelated untracked validation materials and .DS_Store; stage only
reviewed files. Do not push or deploy.
```

## Prompt B — current screenshots and website claims

```text
Audit Letter Within's launch-facing visuals and web claims against the current
Flutter release UI. The website source is
/Users/clairehou/pyProjects/letter-cycle-companion, with privacy copy in
src/routes/privacy.tsx. The live https://letterwithin.app/privacy page was
observed on October 2 with the optional PostHog paragraph; verify it again
rather than assuming it is stale. Check /support and /account-deletion as well.
Do not make up pricing, clinical claims, platform availability, or privacy
behavior. Keep the app's readable health records local and analytics opt-in
wording aligned with the published eight-type App Store privacy declaration.

The App Store Connect version 1.0 currently has ten 2026-09-24 screenshots. UI
has changed substantially. Make a shot-by-shot keep/replace list, then prepare
replacement 6.9-inch screenshots from the real latest app UI with synthetic
records and accurate Plus states. Preserve the current storytelling order where
it still works. Review every caption at storefront scale. Do not upload assets
or deploy the site before owner review. Report exact source paths and what is
ready for App Store Connect.
```

## Prompt C — final archive and resubmission, use only after readiness

```text
The owner has finished Build 16 physical-iPhone acceptance and approved the
final release changes. In the Letter Within release worktree, first audit HEAD,
status, all diffs, the Build 16 iPhone results, the current screenshots, the
live privacy page, and the existing rejected ASC 1.0 submission. Resolve any
open code or review issues, including the Mac report-share fix committed after
Build 16. Obtain qualified clinical review of the retained SP6/LV3 locator,
pressure guidance, and safety copy, or record the owner's revised launch-scope
decision before App Review. Run flutter analyze --no-pub, the complete
flutter test --no-pub,
flutter build ios --simulator --debug --no-pub if needed for an integration
check, and git diff --check. Record exact outcomes; do not reuse earlier test
counts as final evidence.

Finish metadata and current screenshots first. After the owner confirms the
candidate and authorizes upload, archive and upload one new numbered
TestFlight/App Store build as the last asset-preparation step. Verify the
uploaded build's bundle version, release configuration, signing, processing
state, and installed TestFlight behavior. Attach that verified new build to the
existing rejected version 1.0, update Review Notes, and capture Apple's
requested legal-link recording on that exact build.
Show the exact App Review reply and final submission state for owner approval
before sending the reply or pressing Resubmit. Keep manual release, United
States + Canada availability, and the existing three paid products. Never
attach Build 16 as the review candidate. Preserve untracked validation and
.DS_Store files; do not push or deploy unrelated projects.
```

## Deferred App Review reply template

Send only after the final build and recording are present and checked.
Replace bracketed fields with observed facts:

```text
Hello App Review,

Thank you for reviewing Letter Within 1.0. We addressed both issues in the
replacement build [BUILD NUMBER].

For Guideline 2.3.10, we removed Google Play references from the iOS app.

For Guideline 3.1.2(c), the Plus purchase flow shows each subscription's name,
period, and localized full price. It includes working Privacy Policy and Terms
of Use links, including when viewing plan-change options. The Privacy Policy
URL is in App Store Connect's Privacy Policy field; the Apple Standard EULA URL
is in the App Description. The attached recording on iPhone [DEVICE / iOS]
shows the Plus screen and opens both links.

The App Review Notes include the review account and the route to the purchase
flow. Please let us know if you need any other information.
```

## Review Notes draft

Prepare now; save in App Store Connect only after verifying the final build's
exact labels, current review-account credentials, and iPhone recording:

```text
REVIEW ACCESS
Use the review account credentials in the fields above. Choose “Use a password
instead” on the sign-in screen, then complete the three-step onboarding.
Readable health records remain on the device; this account begins without real
health entries.

SUBSCRIPTIONS AND LEGAL LINKS
Open Letter Within Plus from You or a gated Patterns/Reports feature. The Plus
sheet shows the Apple-provided Monthly, Yearly, and one-time Lifetime options.
Select a subscription to see its period and localized full price before the
Apple purchase confirmation. The Privacy Policy and Terms of Use links are on
the Plus sheet below the purchase action; tap each to open the corresponding
public page. The same links remain available when viewing plan choices for an
active subscription. A free account can use Restore a previous purchase.

The iOS app contains no Google Play purchasing reference. The Privacy Policy
field points to https://letterwithin.app/privacy and the app description links
the Apple Standard EULA. The attached recording shows both links on iPhone.

OTHER REVIEW PATHS
Today and Cycle accept synthetic period/symptom entries; Care is free; Patterns
and Reports show the Plus distinction. The app does not use AI or diagnose.
```
