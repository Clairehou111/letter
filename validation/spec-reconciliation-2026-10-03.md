# Feature-spec reconciliation — 2026-10-03

The prior checkout had 40 dated directories under `specs/features/` and
additional loose specs. This audit records where their still-applicable
requirements went. The original text is available in Git before commit
`9d259cf`; copying it unchanged would restore retired navigation, cloud-AI,
App Lock, old prices, and earlier release gates. Current contracts are indexed
in [`specs/features/README.md`](../specs/features/README.md).

| Historical directories (date prefix omitted) | Current disposition |
| --- | --- |
| `flutter-ui-fidelity`, `production-workspace-foundation`, `letter-care-loop-redesign`, `lovable-utility-surfaces`, `algorithm-visual-calibration` | Architecture and experience rules in `specs/architecture.md`, `specs/experience.md`; prototype and tool-process instructions retired. |
| `period-logging-history`, `cycle-prediction-confidence`, `today-cycle-context`, `cycle-flow-history`, `gravity-horizon` | Detailed editing, identity, day observation, estimate, and presentation rules in `specs/features/period-and-cycle/`. |
| `health-record-foundation`, `text-voice-capture`, `nlp-candidate-confirmation`, `unified-record-and-navigation` | Confirmed-record, candidate, check-in, safety-signal, and capture rules in `specs/features/health-records/`; five-tab navigation and cloud LLM path retired. |
| `five-way-care-shell`, `angry-impulse-buffer`, `heavy-low-presence-flow`, `racing-thoughts-convergence-flow`, `need-space-safe-cocoon`, `need-space-boundary-card`, `need-space-flow-integration`, `physical-pain-comfort-flow` | Current guided scenes and Care boundary in `specs/features/care-and-memory/`; proposed Body/Everyday extensions in `release-2.0/care-relief.md`. Old Shatter, draft seal, timer, thought text, curtain, and boundary-card flows are retired because current scenes no longer implement them. |
| `care-checkback-personal-kit`, `care-recovery-receipt`, `clearer-day-reflection`, `cycle-letters-archive` | Check-back, receipt, Kit, authored note, and cycle-story ownership in `specs/features/care-and-memory/`. |
| `archive-story-pattern-views`, `personal-patterns-support-matching`, `cycle-care-summary-export` | Evidence, missingness, story, report, PDF/CSV, and current Free/Plus scope in `specs/features/patterns-and-reports/`. |
| `encrypted-local-export-import` | Current encrypted local backup and staged restore contract in `specs/features/backup-and-restore/`. |
| `auth-subscription-entitlement`, `paid-split-and-paywall`, `privacy-safe-operational-analytics`, `premium-companion-loop` | Account, consent, purchase, preview, and Plus rules in `specs/features/account-and-access/`, `specs/entitlements.md`, and `release-2.0/`. Older prices and Supabase ID analytics use retired. |
| `local-onboarding-privacy`, `safety-boundary-content` | Current onboarding/no-AI and region-aware safety rules in `specs/features/onboarding-and-safety/`. |
| `privacy-cycle-checkin` | Screen Cover/privacy rules in account and experience contracts. The old default-enabled Cycle Check-in remains in code but is **not accepted as the 2.0 Comfort Window reminder**; see period validation. App Lock retired. |
| `doctor-mode-prospective-diary` | Deferred future constraints in `specs/features/patterns-and-reports/requirements.md`; no 2.0 or validated-instrument claim. |
| `encrypted-backup-demand-test` | Historical demand-test proposal only; cloud health backup remains outside 2.0. Local encrypted backup has a current contract. |
| `release-acceptance-gates` | Current gates in `specs/features/release-2.0/validation.md` and dated records under `validation/`. |

## Verified behavior and open gaps

- Focused period and estimate tests passed **65** cases. Current prediction
  accepts 15–90-day quality intervals, treats 21–45 as a review band, filters
  relative outliers, and requires two filtered intervals for the formal
  estimate. A one-interval estimate is labeled early and cannot feed insights.
- The UI saves period drafts without an adjacent-merge confirmation. Both
  repositories merge directly adjacent periods; flow moves to the survivor,
  while an absorbed period's reflection can lose its cycle association. This
  conflicts with the current period contract and blocks its acceptance.
- Focused Cycle Check-in, navigation, and privacy tests passed **14** cases.
  The existing preference defaults on and schedules a neutral 10:00 local
  notification after the formal estimated range. It is not the 2.0 default-off,
  09:00 Comfort Window reminder; no separate scheduler was found in this
  checkout. The current 2.0 reminder gate remains open.
- The current Care experience animation-port test passed **9** cases,
  including final-step completion, interruption recovery, safety routing,
  and Heavy scene mounting. Source inspection confirms the five current
  guided scenes in `care_experience.dart`; historical Shatter and text-draft
  interactions are not current scene behavior.
- Legacy documentation that proposed a routine 0–10 pain scale, optional
  cloud-AI processing, App Lock, and five-tab navigation is superseded by the
  current feature and release contracts.

This is a documentation and focused-test reconciliation, not a full physical
device, StoreKit, clinical, or 2.0 release validation.
