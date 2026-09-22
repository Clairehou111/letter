# Premium Companion Loop Validation

Status: premium loop and bounded payment automated validation complete; external
store/native and real-user validation pending

Automated baseline: `flutter analyze` clean and 611 Flutter tests passing on
2026-08-08. This is repository-level validation; configured store purchases,
real-user outcomes, accessibility review, and clinical review remain pending.

## Domain Matrix

- [x] no recorded period;
- [x] one incomplete or one completed cycle;
- [x] repeated records within one cycle only;
- [x] eligible evidence across two distinct completed cycles;
- [x] three or more cycles with consistent evidence;
- [x] conflicting evidence across cycles;
- [x] irregular cycles and a wide estimate;
- [x] unavailable estimate;
- [x] no Care history;
- [x] Care history with only `same`, only `worse`, mixed, and `better` outcomes;
- [x] pinned action with and without outcome evidence;
- [x] absent and wrong-context future-self notes;
- [x] current date before and after the estimated window;
- [x] edited and deleted source records mark saved material stale or withdrawn
  without rewriting its text;
- [x] dismissed proposal fingerprint does not reappear unchanged and a changed
  proposal remains reviewable;
- [x] lapsed and offline-unknown entitlement retains free access and data.
- [x] pending, active-intro, active-paid, grace, lapsed, offline-unknown, and
  unconfigured states are mapped without unverified premium access.
- [x] purchase cancellation leaves access unchanged and is not reported as a
  failure.

## Core-Logic Regression

- [x] existing cycle-estimate fixtures remain unchanged;
- [x] Gravity Horizon fixtures and geometry remain unchanged;
- [x] Spectrum Log eligibility and aggregation remain unchanged;
- [x] Twin Matrix aggregation, provenance, and missingness remain unchanged;
- [x] Care animation, sound, haptic, safety, and completion tests remain
  unchanged except for explicitly approved navigation entry points.

## Presentation And Accessibility

- [x] 390px and 320px mobile widths;
- [x] 200% text scale and long user-authored note;
- [ ] light/dark and reduced-motion behavior;
- [ ] screen-reader order distinguishes estimate, observation, and action;
- [x] every pushed confirmation, edit, detail, and restore state has an explicit
  way back;
- [ ] loading, empty, insufficient, unavailable, conflict, and error states;
- [x] no plan or upgrade prompt appears in active Care or safety flows.

## Honesty Review

Every user-facing statement is classified as one of:

- recorded fact;
- user-authored text;
- deterministic summary of records;
- estimate from the existing engine;
- cautious interpretation requiring review.

Reject copy that implies diagnosis, measured hormones, inevitability, treatment
effect, hidden knowledge, or human monitoring.

## Target-User Research

Recruit across ordinary PMS, severe PMS or diagnosed PMDD, irregular cycles,
and people who do not identify with pregnancy-centered or highly gendered
period products. Do not treat any one subgroup as representative of all users.

Evaluate:

- `Was this specific to your experience?`
- `What does Letter Within know, and what is it estimating?`
- `Did this reduce confusion or create more work?`
- `Did you feel believed without feeling diagnosed?`
- `Were you in control of what was remembered and surfaced?`
- `Would this have been useful when your capacity was lower?`
- `What would make you stop trusting it?`

Ask about a concrete recent episode rather than general liking. Compliments,
download intent, and mission agreement are not evidence of helpfulness.

## Willingness-To-Pay Validation

Only evaluate price after a participant sees a real pattern and preparation
outcome built from their own data.

Measure the sequence:

1. opens the Plus explanation;
2. accurately explains the paid outcome;
3. selects annual, monthly, one-time, or `Not now`;
4. reaches a noncharging checkout-intent boundary;
5. optionally identifies usefulness, trust, understanding, timing, or price as
   the reason for continuing or stopping.

Do not upload cycle dates, symptoms, notes, Care choices, outcomes, or inferred
windows as analytics dimensions.

## Release Gates Before Public Billing

Public store release remains blocked until:

- the complete loop works across at least two real cycles;
- users can distinguish evidence from estimation and interpretation;
- remembered support is reported as useful without creating duty or guilt;
- inaccurate summaries can be corrected and visibly repaired;
- the Plus outcome is understood before the plan selector;
- price is tested only with users who reached that outcome;
- RevenueCat products, entitlement, offering, keys, agreements, sandbox
  accounts, and native iOS/Android purchase flows are configured and verified.
