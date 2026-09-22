# Premium Companion Loop Plan

Status: premium loop and bounded payment slice implemented; external release gates pending
Depends on: `requirements.md`

## Delivery Principle

Build one narrow, truthful vertical slice before expanding entitlement or
billing. Reuse current repositories and core engines; do not duplicate or
reinterpret them.

## Batch 1: Evidence Composer

- [x] Add immutable domain models for preparation timing, observation evidence,
  Care-action evidence, future-self-note evidence, and the combined snapshot.
- [x] Compose them from `RepositoryPatternSource`, `PersonalPatternEngine`, the
  existing Care-memory repository, and `CyclePredictionEngine` output.
- [x] Require evidence from distinct completed cycles for recurrence.
- [x] Implement deterministic, explainable Care-action ordering.
- [x] Preserve provenance, missingness, and recorded-versus-estimated
  labels.
- [x] Do not persist a preparation object in this first batch.

## Batch 2: Read-Only Vertical Slice

- [x] Present one `Your next window` snapshot from real local data.
- [x] Model explicit insufficient-history, estimate-unavailable, irregular,
  no-Care-outcome, and no-future-note states.
- [x] Link the observation to supporting record dates and correction entry.
- [x] Route the action into the matching existing Care mode without changing
  its animation or safety behavior.
- [x] Keep the snapshot out of the removed Today activity-feed pattern.

## Batch 3: Lovable UX Plan And Flutter Port

- [x] Prepare one consolidated plan-mode prompt containing the product
  goal, operations, safety boundaries, free/Plus split, navigation constraints,
  and realistic example states.
- [x] Include mobile examples for zero, one, two, and three completed cycles;
  irregular timing; conflicting evidence; no helpful action; long text; and
  lapsed entitlement.
- [x] Ask Lovable to solve information hierarchy, progressive disclosure,
  correction, and low-capacity interaction—not to invent new health logic.
- [x] Approve the design before code generation to limit credit use.
- [x] Port the approved Flutter UI into production while retaining production
  repositories, controllers, navigation callbacks, validation, local storage,
  and safety behavior.
- [x] Make only the minor adjustments required for production data and Flutter
  accessibility.

Lovable generated the complete Flutter state set after one consolidated Plan
and one Build request. Production ports that hierarchy, copy, checkbox rows,
saved/stale/withdrawn states, contextual return card, and restore surface while
replacing fixture callbacks with encrypted local repositories.

## Batch 4: User Approval And Repair

- [x] Add persistent confirm, edit, dismiss, and restore behavior for proposed
  patterns.
- [x] Add a user-approved saved preparation plan only after the read-only slice
  tests well.
- [x] Let the user write and edit their own preparation; keep prior-cycle
  evidence separate from the saved summary.
- [x] Restore the preparation proposal immediately after withdrawal without a
  route refresh.
- [x] Ensure future evidence updates or withdraws previous summaries.
- [x] Preserve existing records when a derived interpretation is removed.

## Batch 5: Contextual Return

- [x] Surface a confirmed preparation in the appropriate in-app cycle context.
- [x] Offer the user-approved Care mode with one tap.
- [x] Show the relevant future-self note only in its intended context.
- [x] Keep `Not now` and direct Care access equally easy.
- [x] Add no new Care push notification in this batch.

## Batch 6: Free Preview And Plus Boundary

- [x] Let an eligible free user see one honest, specific pattern preview.
- [x] Explain Plus as continuing memory and preparation rather than a collection
  of locked screens.
- [x] Keep the plans surface outside Care and safety routes.
- [x] Validate the capability map with lapsed and offline-unknown states.
- [x] Gate Plus preparation and pattern continuity while preserving free records,
  Care, export, and local ownership.

## Batch 7: Product Validation

- [ ] Test comprehension, usefulness, fit, autonomy, trust, burden, and felt
  support with target users who have real multi-cycle data.
- [ ] Test a calm/clearer-day context and a low-capacity context separately.
- [ ] Confirm that users distinguish records, estimates, and interpretations.
- [ ] Observe whether users reuse a remembered Care action in a later cycle.
- [ ] Present the real Plus explanation after value and measure plan-selection
  intent without collecting health values.
- [x] Complete the bounded RevenueCat/domain/payment slice after the user
  explicitly superseded the earlier “no billing in this batch” timing decision.
- [ ] Validate real-user comprehension and willingness to pay with production-
  representative store configuration.

## External Release Gates (Payment Code Is Implemented)

- [ ] Add actual RevenueCat public Apple/Google keys.
- [ ] Configure `letter_monthly`, `letter_yearly`, and `letter_lifetime` in App
  Store Connect and Google Play.
- [x] Configure the `letter_plus` entitlement and `letter_default` current
  offering in the RevenueCat Test Store.
- [ ] Complete store agreements, sandbox accounts, and tax/banking setup.
- [ ] Validate native purchase, restore, pending, grace, expiry, cancellation,
  and offline behavior on iOS and Android.
