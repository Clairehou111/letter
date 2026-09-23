# Release Candidate Validation — 1.0.0 (11)

Status: **local candidate built; not uploaded**

Date prepared: 2026-09-24

## Candidate identity

- Branch: local `main`
- Baseline commit: `732dade`
- Source version: `1.0.0+11`
- Bundle identifier: `app.letterwithin`
- Device family: iPhone only
- Deployment target: iOS 15.0
- IPA: `apps/mobile/build/ios/ipa/Letter Within.ipa`
- IPA SHA-256:
  `998e2c923a2b89f11d1671a238a84c790d60ef5392a88f1c1ef27dc6c53fbb6e`
- Source state: baseline commit plus the scoped release-preparation changes in
  this release commit.

## Automated and packaging evidence

| Gate | Result | Evidence |
| --- | --- | --- |
| Static analysis | PASS | `flutter analyze`: no issues |
| Focused privacy/no-AI tests | PASS | 24 passed |
| Full Flutter suite | PASS | 553 passed, 1 intentionally skipped |
| Signed archive | PASS | `1.0.0 (11)`, `app.letterwithin`, iOS 15.0 |
| Device targeting | PASS | `UIDeviceFamily = [1]`; iPhone only |
| Code signature | PASS | strict deep verification succeeded |
| App Store listing images | PASS locally | Six 1290 × 2796 JPEGs, no alpha, manifest hashes verified |
| No-AI runtime surface | PASS | dormant cloud preference and optional cloud-NLP adapter removed |

## Changes since TestFlight build 10

- Makes `No AI` a permanent product and technical constraint.
- Removes the dormant cloud-tools preference and cloud NLP adapter scaffolding.
- Keeps legacy onboarding JSON readable while omitting `cloud_tools` from new
  saves.
- Makes the privacy explanation explicitly state encrypted on-device storage
  and no transfer to AI services.
- Targets iPhone only for the first App Store release.
- Adds the final six-image App Store listing package, including Patterns and a
  populated clinician report.

## Required manual and external gates

Use synthetic records only. Do not place real health information in TestFlight
feedback, screenshots, recordings, or issue reports.

| Area | Required scenario | Status |
| --- | --- | --- |
| Fresh install and upgrade | Install build 11 cleanly and over build 10; verify local encrypted records and settings | Pending TestFlight upload and device run |
| Authentication | Sign in, relaunch, offline relaunch, sign out, and sign in again | Pending |
| Account deletion | Delete a synthetic server account and verify local-data behavior and wording | Pending — release blocker |
| Core logging | Record, edit, delete, and relaunch with synthetic period, symptom, observation, and check-in data | Pending |
| Care | Exercise all scenes, exits, check-back, interruption/re-entry, sound, haptics, and reduced motion on a physical iPhone | Pending — physical-device review |
| Reports | Verify dates, provenance, missingness, export, save, cancelled share, and retry | Pending |
| Backup | Verify encrypted backup/restore, wrong password, tamper, cancel, Merge, and Replace through native Files/share | Pending — release blocker |
| Privacy | Verify app-switcher cover, notification previews, encrypted/no-AI wording, and absence of health values in analytics | Pending |
| Purchases | Test monthly, yearly, lifetime, cancellation, failure, restore, lapse, and offline entitlement using sandbox accounts | Pending — explicit purchase approval required |
| Accessibility | VoiceOver order, 200% Dynamic Type, smallest supported iPhone width, reduced motion, and light/dark appearance | Pending — release blocker |
| Safety | Verify US and Canada resources and native call/text handoff without placing an emergency call | Pending |
| Listing | Upload six listing screenshots in manifest order and verify App Store processing | Pending — explicit upload approval required |
| Legal | Complete US/Canada privacy, cross-border, health-data, subscription/refund, and Quebec/French review | Pending — release blocker |

## Release boundary

- Do not upload build 11 or the listing screenshots without explicit approval.
- Do not add products for review, purchase, submit, deploy, push, or expand
  storefronts without explicit approval.
- Build 10 remains the latest TestFlight build until an authorized upload.
- Commit and upload were explicitly approved on 2026-09-24. Upload does not
  authorize adding products for review or submitting the app version.
