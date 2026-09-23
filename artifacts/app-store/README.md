# App Store screenshot set

Status: **final local masters, not uploaded**

These six images are the approved launch story for Letter Within, a private
period companion and tracker. They use real Flutter UI and synthetic records.
No lifestyle photography, generated interface, real health data, testimonial,
or clinical outcome claim is included.

## Message hierarchy

1. Care first: Letter Within helps in the moment, not only after data is logged.
2. Privacy second: readable health records are encrypted on the device, and the
   product does not use AI.
3. Product proof: Patterns makes evidence and missingness visible.
4. Practical proof: users can create a bounded report for a clinician.
5. Tracking breadth: period dates are one part of the record.
6. Continuity: an optional check-back helps the user remember what helped.

## Upload order

| Order | File | Caption | Real app state |
| --- | --- | --- | --- |
| 1 | `iphone-69/final/01-cycle-care.jpg` | Cycle care for the days that feel heavier. | Care chooser with synthetic remembered-help evidence |
| 2 | `iphone-69/final/02-private-no-ai.jpg` | Encrypted on your device. No AI. | Current production privacy explainer, captured natively on iPhone 17 |
| 3 | `iphone-69/final/03-patterns.jpg` | See patterns across your cycles. | Twin pattern view showing observed and missing days |
| 4 | `iphone-69/final/04-clinician-report.jpg` | Create a report for your clinician. | Populated report with range, scope boundary, provenance legend, and cyclical symptom matrix |
| 5 | `iphone-69/final/05-track-more.jpg` | Track more than period dates. | Today view with cycle context and moment check-in |
| 6 | `iphone-69/final/06-remember-what-helped.jpg` | Remember what helped next time. | Optional post-Care check-back |

All final files are 1290 × 2796 JPEGs with no alpha channel. This is the
6.9-inch iPhone master set. App Store Connect may scale the highest-resolution
set for smaller iPhone display classes.

## Claim boundaries

- “Encrypted on your device” applies to readable health records stored in the
  local SQLCipher database. Account access and subscription entitlement are
  operational cloud functions, so do not shorten this to “nothing leaves your
  device” or “100% local.”
- “No AI” is a permanent product constraint. Patterns, estimates, candidate
  matching, and reports are deterministic and run on-device.
- Patterns describe saved observations and must keep missing data visible. They
  do not diagnose, identify causes, or promise an outcome.
- Reports summarize user-recorded observations. They are not a diagnosis and
  are shared only when the user exports them.
- Every visible record is synthetic. The remembered-help line is product UI
  derived from fictional local history, not a customer quote.

## Provenance

- Frames 1, 3, and 5 use native iPhone 17 captures from
  `apps/mobile/.ui-forge/letter-release-framework-visual-v2/screenshots/final-native-r2/`.
- Frame 6 uses the native iPhone 17 pre-TestFlight evidence capture at
  `apps/mobile/.ui-forge/pre-testflight-visual-20260915/evidence/care-checkback-iphone17.png`.
- Frames 2 and 4 were recaptured through `apps/mobile/tool/manual_qa_app.dart`
  on 2026-09-24. Frame 2 renders the production `PrivacyExplainerSheet`; frame
  4 renders `ReportsExperience` with fictional multi-cycle history. Their
  durable native sources are under `iphone-69/source/`.
- Captions and framing are reproducibly composed by
  `tool/compose_app_store_screenshot.swift`.

The matching machine-readable record is `manifest.json`.

## Release gate

Do not upload this set, attach build 11, add any in-app purchase for review,
submit an app version, or change storefront availability without explicit user
approval. First launch remains United States and Canada only.

The marketing website may reuse these masters and this message hierarchy. Its
redesign remains a separate comp-first task documented in
`/Users/clairehou/pyProjects/letter-cycle-companion/WEBSITE_REDESIGN_HANDOFF.md`.
