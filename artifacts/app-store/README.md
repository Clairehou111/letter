# App Store screenshot set

Status: **the six-frame v1 set is uploaded but rejected by the owner; the
ten-frame v3 set was owner-approved on 2026-09-24 and is awaiting upload**

The files under `iphone-69/final/` are the six images currently visible in App
Store Connect. They must not be treated as approved launch masters. The owner
rejected the set because the first Care frame and Patterns frame were obsolete,
the report did not show enough data, and the strip read as coarse at storefront
scale.

The current replacement candidate is under `iphone-69/candidate-v3/`. It uses current
native Flutter UI and coherent synthetic records. No lifestyle photography,
generated interface, real health data, testimonial, or clinical outcome claim
is included.

## Message hierarchy

1. Care first: Letter Within helps in the moment, not only after data is logged.
2. Privacy second: readable health records are encrypted on the device, and the
   product does not use AI.
3. Product proof: Patterns makes evidence and missingness visible.
4. Practical proof: users can create a bounded report for a clinician.
5. Tracking breadth: period dates are one part of the record.
6. Continuity: an optional check-back helps the user remember what helped.

## Uploaded v1 order - rejected

| Order | File | Caption | Real app state |
| --- | --- | --- | --- |
| 1 | `iphone-69/final/01-cycle-care.jpg` | Cycle care for the days that feel heavier. | Care chooser with synthetic remembered-help evidence |
| 2 | `iphone-69/final/02-private-no-ai.jpg` | Encrypted on your device. No AI. | Current production privacy explainer, captured natively on iPhone 17 |
| 3 | `iphone-69/final/03-patterns.jpg` | See patterns across your cycles. | Twin pattern view showing observed and missing days |
| 4 | `iphone-69/final/04-clinician-report.jpg` | Create a report for your clinician. | Populated report with range, scope boundary, provenance legend, and cyclical symptom matrix |
| 5 | `iphone-69/final/05-track-more.jpg` | Track more than period dates. | Today view with cycle context and moment check-in |
| 6 | `iphone-69/final/06-remember-what-helped.jpg` | Remember what helped next time. | Optional post-Care check-back |

All uploaded v1 files are 1290 × 2796 JPEGs with no alpha channel. This is the
6.9-inch iPhone master set. App Store Connect may scale the highest-resolution
set for smaller iPhone display classes.

## Candidate v2 order - review before upload

| Order | File | Caption | Real app state |
| --- | --- | --- | --- |
| 1 | `iphone-69/candidate-v2/final/01-cycle-care.jpg` | Cycle care for the days that feel heavier. | Current Care chooser with all six supported paths visible |
| 2 | `iphone-69/candidate-v2/final/02-private-no-ai.jpg` | Encrypted on your device. No AI. | Current Backup & restore controls showing password-protected export, restore, and record-by-record preview before writing |
| 3 | `iphone-69/candidate-v2/final/03-cycle-patterns.jpg` | See patterns across your cycles. | Current Cycles & bleeding view with four realistic 28-30 day cycles |
| 4 | `iphone-69/candidate-v2/final/04-mood-patterns.jpg` | Understand the days that feel heavier. | Current Mood & patterns view with four cycles and 11 harder days |
| 5 | `iphone-69/candidate-v2/final/05-clinician-report.jpg` | Bring a clear record to your clinician. | Current report matrix with 43 confirmed synthetic records across four cycles |
| 6 | `iphone-69/candidate-v2/final/06-cycle-tracking.jpg` | Track more than period dates. | Current cycle view exposing flow, color, pain, and observations |
| 7 | `iphone-69/candidate-v2/final/07-care-heavy.jpg` | Support for the moment you are in. | Current low-energy Care scene with explicit Stay here and Leave for now controls |
| 8 | `iphone-69/candidate-v2/final/08-what-helped.jpg` | Remember what helped next time. | Current What helped view with four Care actions and recorded outcomes |

All candidate v2 files are 1290 × 2796 JPEGs with no alpha channel. The
machine-readable candidate record is
`iphone-69/candidate-v2/manifest.json`.

Candidate v2 remains preserved as the superseded eight-frame review pass. It
was not uploaded.

## Candidate v3 order - approved replacement set

| Order | File | Caption | Real app state |
| --- | --- | --- | --- |
| 1 | `iphone-69/candidate-v3/final/01-cycle-care.jpg` | Cycle care for the days that feel heavier. | Current Care chooser with all supported paths visible |
| 2 | `iphone-69/candidate-v3/final/02-private-no-ai.jpg` | Encrypted on your device. No AI. | Backup & restore with password-protected export and record-by-record restore review |
| 3 | `iphone-69/candidate-v3/final/03-today-tracking.jpg` | Track more than period dates. | Populated Today showing flow, color, Care doorway, and three saved symptoms |
| 4 | `iphone-69/candidate-v3/final/04-cycle-days.jpg` | See every day in your cycle. | Five populated flow days with color observations |
| 5 | `iphone-69/candidate-v3/final/05-day-symptoms.jpg` | Edit symptoms on any day. | Day editor with saved flow, color, moderate pain, and the recorded symptom row |
| 6 | `iphone-69/candidate-v3/final/06-cycle-patterns.jpg` | See patterns across your cycles. | Four realistic completed cycles varying from 28 to 30 days |
| 7 | `iphone-69/candidate-v3/final/07-mood-patterns.jpg` | Understand the days that feel heavier. | Four cycles and 11 harder days with missingness kept honest |
| 8 | `iphone-69/candidate-v3/final/08-clinician-report.jpg` | Bring a clear record to your clinician. | Clinician matrix with 43 confirmed synthetic records across four cycles |
| 9 | `iphone-69/candidate-v3/final/09-care-heavy.jpg` | Care for the moment you are in. | Heavy scene with a useful in-scene action and permanent exit |
| 10 | `iphone-69/candidate-v3/final/10-what-helped.jpg` | Remember what helped next time. | Four Care actions with saved outcomes |

Candidate v3 uses the app's exact Experience System colors outside the native
UI: daylight is `#FBF7F3` / `#2A1626` / `#E4573D`; Care is the real
`#2E1A33` to `#170D1C` world with `#F7EEE6` type. There is no separate rose or
plum campaign canvas. Claude reviewed Heavy, Focus, Body, and Space through
OpenRouter and selected Heavy because it most directly supports the fixed
heavier-days promise.

All candidate v3 files are 1290 × 2796 JPEGs with no alpha channel. The
machine-readable record is `iphone-69/candidate-v3/manifest.json`.

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

- Uploaded v1 frames 1, 3, and 5 use native iPhone 17 captures from
  `apps/mobile/.ui-forge/letter-release-framework-visual-v2/screenshots/final-native-r2/`.
- Uploaded v1 frame 6 uses the native iPhone 17 pre-TestFlight evidence capture at
  `apps/mobile/.ui-forge/pre-testflight-visual-20260915/evidence/care-checkback-iphone17.png`.
- Uploaded v1 frames 2 and 4 were recaptured through `apps/mobile/tool/manual_qa_app.dart`
  on 2026-09-24. Frame 2 renders the production `PrivacyExplainerSheet`; frame
  4 renders `ReportsExperience` with fictional multi-cycle history. Their
  durable native sources are under `iphone-69/source/`.
- Uploaded v1 captions and framing are reproducibly composed by
  `tool/compose_app_store_screenshot.swift`.

- Candidate v2 uses fresh iPhone 17 Pro Max simulator captures from the current
  source tree, all dated against the same fictional September 2026 history.
- Candidate v2 synthetic history uses variable 28-30 day cycles, four Care
  actions, and 43 confirmed report records across four cycles.
- Candidate v2 framing is reproducibly composed by
  `tool/compose_app_store_screenshot_v2.swift`.
- Candidate v3 adds three populated tracker proofs, preserves all four Care
  options as source evidence, and uses the same compositor constrained to the
  app's actual daylight and Care color tokens.

The uploaded v1 machine-readable record is `manifest.json`.

## Release gate

Do not replace the uploaded screenshots, attach build 11, add any in-app
purchase for review, submit an app version, or change storefront availability
without explicit user approval. First launch remains United States and Canada
only.

The marketing website may reuse these masters and this message hierarchy. Its
redesign remains a separate comp-first task documented in
`/Users/clairehou/pyProjects/letter-cycle-companion/WEBSITE_REDESIGN_HANDOFF.md`.
