# Release 2.0 Implementation Plan

Status: implementation substantially complete; report-entitlement correction,
SP6/LV3 final review, regression revalidation, and physical-device validation
pending

1. Establish `release/2.0`, baseline analyzer/tests, and approved specifications.
2. Add immutable Comfort Window evidence/result models and a pure deterministic
   engine that consumes existing cycle prediction and pattern source records.
3. Add encrypted local persistence for reminder preferences, Comfort Kit item
   state, Quick-note Kit opt-in, and generated report access; migrate existing
   preparation data without losing user content.
4. Wire recomputation, forecast lifecycle, notifications, Kit eligibility and
   ranking, Quick note history, and revised prices. Preserve the Release 1
   report boundary: only the limited recent on-screen factual view is free;
   longer/custom ranges and every generated Visit Summary, CSV, or Clinical
   Pattern Report file require paid Plus. A no-card preview may demonstrate
   in-app interpretation but cannot generate report/export files.
5. Replace account-linked analytics identity and implement consent-gated local
   Care buckets with payload-contract tests.
6. Move You content to Settings, expose reports from Patterns, and keep four
   main destinations.
7. Capture fresh iOS runtime evidence, obtain exact UI Forge upload approval,
   generate and approve a replacement Quiet Dusk Experience System, stage
   Kimi-authored visual replacements for the complete app and Care manifest,
   validate, obtain apply approval, and apply. Preserve the verified four-tab
   shell structure while discarding its staged light-theme direction.
8. Correct stale report specifications, copy, ports, and tests together; restore
   the visible SP6/LV3 chooser entry; then rerun focused, migration, full-suite,
   accessibility, reduced-motion, native screenshot, and privacy-boundary
   validation. Do not merge or deploy.
