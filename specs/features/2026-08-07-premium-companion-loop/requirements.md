# Premium Companion Loop Requirements

Status: premium loop and bounded payment slice implemented; external release configuration pending
Date: 2026-08-07
Research basis: `../../premium-companion-loop-evidence-and-plan.md`
Commercial decision: `../../pricing-and-entitlement-strategy.md`

## Goal

Connect Letter Within's existing cycle evidence, Care memory, future-self notes, and
prediction timing into one honest cycle-to-cycle loop:

> understand -> remember -> prepare -> return -> correct

The loop should reduce confusion and decision load without making self-care a
duty or pretending that Letter Within is a person, therapist, or diagnostic system.

## Product Hypothesis

> Letter Within Free helps me through this moment. Letter Within Plus helps the next
> difficult moment become more understandable and more prepared for.

People are not expected to pay for more tracking or more screens. The paid
outcome is trustworthy continuity built from their own records and choices.

## Free Contract

REQ-001: The following remain free regardless of entitlement state:

- period, bleeding, symptom, mood, energy, pain, and impact recording;
- record review, correction, deletion, and basic history;
- current Gravity Horizon, current Spectrum Log, and basic Twin Matrix;
- every acute Care activity and every safety route;
- privacy controls, app lock, local backup/restore, and raw export;
- access to readable local records after lapse or offline uncertainty.

REQ-002: No plan selector, locked card, checkout message, or upgrade prompt may
appear inside an active Care or safety flow.

## Evidence Eligibility And Honesty

REQ-003: Premium observations use existing local repositories and the existing
cycle prediction, Gravity Horizon, Spectrum Log, Personal Patterns, and Twin
Matrix semantics. This feature must not create a second estimate engine or
change existing eligibility/aggregation logic as a side effect.

REQ-004: A recurring cross-cycle observation requires eligible evidence from at
least two distinct completed cycles. Multiple records in one cycle do not by
themselves establish recurrence. Two-cycle output is labeled an early pattern;
three or more eligible cycles may receive stronger wording while still showing
missingness and uncertainty.

REQ-005: Every observation exposes:

- whether timing is recorded or estimated;
- the number of eligible records and distinct cycles;
- the dates or cycles that support it;
- missing or conflicting evidence;
- `Review`, `Not for me`, and correction paths.

REQ-006: Letter Within reports association and user-marked outcomes, not cause or
treatment efficacy. It may say `appeared in 2 of 3 recorded windows` or `you
marked this better twice`. It may not say `your hormones caused this`, `this
will work`, `you have PMS/PMDD`, or `this is your real self`.

REQ-007: Insufficient and conflicting data produce a useful honest state rather
than fabricated guidance. The user may continue recording and using all free
features without being asked to complete a daily duty.

## Remember

REQ-008: The loop reuses existing Care records, `better/same/worse` outcomes,
pinned actions, reflections, and future-self notes. It does not require a new
questionnaire to generate personalization.

REQ-009: Action ordering is deterministic and explainable. A user-pinned action
is treated as an explicit preference. Otherwise, actions with user-recorded
`better` outcomes rank before actions with only `same` or unknown outcomes;
ties use evidence count and then recency. Copy shows counts and does not call an
action `best` when the evidence cannot support a comparison.

REQ-010: A future-self note is shown only in the Care mode or context to which
the user attached it. User-authored wording is preserved and remains editable
and deletable.

## Prepare And Return

REQ-011: The first vertical slice is a derived, read-only `Your next window`
snapshot containing at most:

- existing estimated timing and uncertainty;
- one cautious repeated observation;
- one previous Care action and its exact outcome evidence;
- one relevant user-authored future-self note;
- one direct action into the matching existing Care mode;
- links to review supporting records.

REQ-012: The snapshot remains absent when timing or history is insufficient.
It must handle irregular cycles and wide estimate ranges without manufacturing
precision.

REQ-013: A later saved preparation plan requires explicit confirmation. It
includes an optional, editable user-authored preparation and may also include
one or more existing support items. A plan must contain the user's preparation
or at least one selected support item. Prior-cycle outcome evidence remains
read-only context and is not duplicated inside the saved plan. The user may
edit or withdraw the plan, or select `Not now` without penalty. Withdrawing a
plan restores the proposal immediately on the same detail page.

REQ-014: Returning support opens the existing Care activity. Core Care
animation, sound, haptics, safety behavior, and navigation remain unchanged
unless separately approved.

REQ-015: Preparation is an in-app surface. This feature adds no emotionally
loaded Care notification by default. The existing private Cycle Check-in policy
remains unchanged.

REQ-016: The feature must not recreate the removed Today activity feed. Final
entry placement and mobile presentation require Lovable design planning using
the operational states and example data in this specification.

## Correction And Repair

REQ-017: A user can confirm, edit, dismiss, or restore a proposed pattern. A
dismissed or corrected interpretation must not continue reappearing unchanged.

REQ-018: When new evidence conflicts with an earlier summary, Letter Within visibly
changes or withdraws the summary. It does not defend the old inference.

## Entitlement And Paywall

REQ-019: After enough real history exists, a free user may see one specific,
data-backed pattern preview. The preview must not be a generic blurred mock.

REQ-020: The Plus explanation may follow that preview outside Care. Plus
unlocks continuing cross-cycle memory, preparation, longitudinal comparison,
and clinician-ready organization.

REQ-021: Existing local records and already generated local material remain
readable after cancellation. Plus gates generation or refresh of advanced
analysis, not ownership of personal data.

REQ-022: The bounded payment slice uses RevenueCat with entitlement id
`letter_plus` and approved product ids `letter_monthly`, `letter_yearly`, and
`letter_lifetime`. The reference price hypothesis is `$6.99/month`,
`$29.99/year`, and `$79.99` one-time; configured store offerings provide the
localized labels shown to users. Purchase, restore, pending, cancellation,
failure, grace, lapsed, and offline-unknown states never grant unverified
access. Restore and store-provided subscription-management entry are available
when the provider supplies a management URL.

External release configuration remains pending: RevenueCat public keys, App
Store and Play products, the `letter_plus` entitlement and offering, store
agreements, sandbox accounts, and native purchase validation.

## Privacy And Safety

REQ-023: All loop inputs, derived outputs, corrections, and plans remain local
under the existing encrypted storage model.

REQ-024: Billing or product analytics contain no cycle dates, symptoms, notes,
Care modes, outcomes, patterns, or inferred windows.

REQ-025: Letter Within says what it can and cannot know. It does not impersonate a
human, imply that someone is monitoring the user, or position itself as a
replacement for clinical or crisis care.

## Accessibility And Cognitive Load

REQ-026: During a likely difficult window, the primary surface offers one
decision at a time, supports reduced motion and large text, and always allows
dismissal or direct Care entry.

REQ-027: No streak, score, overdue state, guilt language, celebratory pressure,
or requirement to complete a reflection is introduced.

## Non-Goals

- production RevenueCat/App Store/Play Store configuration and native purchase
  validation;
- a chatbot, generative AI therapist, or open-ended companion persona;
- changes to estimate, Gravity Horizon, Spectrum Log, or Twin Matrix logic;
- daily symptom requirements or notification campaigns;
- medication, treatment, fertility, or diagnostic recommendations;
- redesigning the established Care animations.
