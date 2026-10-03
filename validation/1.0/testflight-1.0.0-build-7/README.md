# TestFlight Validation — 1.0.0 (7)

Status: in progress

Date opened: 2026-09-21

## Current TestFlight State

- Build `1.0.0 (7)` is validated and available to the `Internal Testers`
  group.
- Current observed metrics: 2 testers invited, 2 installs, 33 sessions, no
  crashes, and no feedback for build 7.
- The two crash-feedback records in App Store Connect belong to build 1 on
  macOS, not build 7.
- `What to Test` is blank in App Store Connect.
- Bundle ID: `app.letterwithin`; minimum iOS: 15.0; device family: iPhone and
  iPad.

Use synthetic records only. Do not put real cycle dates, symptoms, notes,
screenshots, or other health information into TestFlight feedback.

## Pass Criteria

Every required row below has an owner, device/OS, date, and evidence. A pass is
not inferred from an automated test or from the absence of crash reports.

| Area | Required TestFlight scenario | Expected result | Status / evidence |
| --- | --- | --- | --- |
| Install | Delete the app, install build 7 from TestFlight, and launch | Clean startup; onboarding and authentication appear; no stale local health records | Pending |
| Upgrade | Install build 7 over the previous internal build with synthetic records | Encrypted records and settings remain readable; migration completes without reset | Pending |
| Authentication | Sign in, kill/relaunch, launch offline after prior authentication, sign out, then sign in again | Account gate is truthful; prior-auth offline launch follows policy; local records are not deleted by sign-out | Pending |
| Account deletion | Delete the server account using synthetic data, then relaunch | Server account is removed; local-health-data behavior and retention wording match the release policy | Pending — release blocker |
| Core logging | Record/edit/delete a synthetic period, symptom, observation, and check-in | Saved values and provenance remain correct after relaunch | Pending |
| Care | Enter Care quickly, exercise each scene, exit without reflection, and complete one check-back | Exit is always available; no pressure or diagnostic/treatment claim; receipt is understandable | Pending |
| Reports | Generate a synthetic report, inspect dates/provenance/missingness, save, cancel share, and retry | Report remains clinically legible; cancellation is safe; no hidden cloud upload | Pending |
| Backup | Create an encrypted backup; cancel save/share; restore valid, wrong-password, and tampered files; exercise Merge and Replace | Failure/cancel leaves data unchanged; valid restore is rollback-safe and understandable | Pending — native Files/share coverage required |
| Privacy | Background/app-switcher the app on sensitive screens; review analytics consent and notification previews | Privacy cover hides content; health values never appear in analytics or notifications | Pending |
| Plus catalog | Open Plus before answering personal questions and after synthetic use | Monthly, yearly, and lifetime appear with localized prices and renewal/payment wording | Pending |
| Monthly purchase | With a dedicated sandbox tester/account, purchase monthly, relaunch, restore, then observe renewal/lapse behavior | `letter_plus` activates; only Plus unlocks; lapse never removes local records | Pending |
| Yearly purchase | With a separate sandbox tester/account, purchase yearly, relaunch, and restore | Correct product activates `letter_plus`; annual billing is shown truthfully | Pending |
| Lifetime purchase | With a separate sandbox tester/account, purchase lifetime, relaunch, and restore | Non-consumable activates `letter_plus`; restore works after reinstall | Pending |
| Cancellation/failure | Cancel a purchase and retry with network unavailable | No charge/access claim; prior state remains truthful; free functions remain usable | Pending |
| Offline entitlement | Launch offline while active, then after an expired/lapsed test subscription | Existing local data and free Care/tracking/export stay available; Plus state is honest | Pending |
| Subscription management | Open Restore Purchases and Manage Subscription | Correct Apple destination opens; no dead end or misleading status | Pending |
| Accessibility | VoiceOver reading order, 200% Dynamic Type, reduced motion, dark/light mode, and smallest supported width | Controls remain labeled and reachable; no clipping/overflow; motion fallback is equivalent | Pending — release blocker |
| Safety | Exercise US and Canada safety routes and native call/text handoff without placing a real emergency call | Correct regional resources and graceful fallback; no unsupported clinical promise | Pending — native handoff coverage required |
| iPad | Repeat startup, navigation, Care, report, backup, and Plus smoke tests on iPad | Layout remains usable and privacy behavior matches iPhone | Pending |

## Evidence Template

For each run, record:

- tester initials (not a personal email or Apple ID);
- device model and OS version;
- build number;
- scenario and synthetic fixture used;
- expected and actual result;
- pass/fail/blocker;
- screenshot or screen recording only when it contains no personal or health
  information;
- related issue and retest build, if applicable.

## Proposed `What to Test` Copy

Do not publish this copy without explicit approval.

> Please use synthetic data only. Test fresh install and upgrade, sign-in and
> offline relaunch, cycle logging, Care entry/exit, report export, encrypted
> backup/restore, and the app-switcher privacy cover. In Plus, verify monthly,
> yearly, and lifetime prices, then exercise purchase and Restore Purchases with
> test accounts. Also check VoiceOver, larger text, reduced motion, dark mode,
> and iPad layout. Report the build, device/OS, steps, expected result, and
> actual result; do not include real health information in feedback.

## Release Boundary

- Do not use real health data during beta validation.
- Do not add external testers or submit for Beta App Review without explicit
  approval.
- Do not click App Store Connect `Add for Review`, submit the app/products, make
  a real purchase, or expand beyond the United States and Canada without
  explicit approval.
- Canadian privacy, cross-border processing, health-data wording,
  subscription/refund disclosure, and Quebec/French review remain release
  gates.
