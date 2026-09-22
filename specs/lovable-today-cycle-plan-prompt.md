Plan a complete production-quality redesign for Letter Within's Today and Cycle
journeys. Do not build code yet. This Plan-mode discussion owns the visual and
interaction design; after the plan is approved, you will generate the complete
Flutter presentation.

This corrects an earlier instruction: do NOT preserve the current Gravity
Horizon visualization exactly and do NOT merely wrap it in a card. Replace its
presentation with the richer paper-and-ink Gravity Horizon already represented
by these project files:

- `flutter/lib/widgets/gravity_horizon.dart`
- `flutter/lib/data/gravity_horizon_data.dart`
- `flutter/lib/screens/today_screen.dart`
- `flutter/lib/screens/cycle_screen.dart`
- `flutter/lib/theme/letter_theme.dart`
- `flutter/lib/widgets/state_switcher.dart`

The generated Flutter UI should become the new production presentation layer.
The developer state switcher and hardcoded fixtures are design-lab tools only;
they will not be copied into production.

## Product journeys

Primary navigation remains Today, Cycle, Care, Letters, You.

Today owns current date and cycle context, the complete Gravity Horizon, quick
check-in, today's chronological activity, confirmed symptom records, private
notes, and factual Care records. Tapping Gravity Horizon or Open Cycle opens the
Cycle tab.

Cycle owns period history, Start period today, End period today, Add past
period, edit dates, delete with confirmation, prediction explanation,
confidence, loading/retry, and validation feedback. Starting, editing, or
deleting a period refreshes Today and can add, change, or remove its estimate.
Do not design a placeholder Cycle page: design the real create/view/edit/delete
experience.

## Production data contract

The final UI receives presentation data derived locally from:

- `PeriodRecord(id, startDate: LocalDate, endDate: LocalDate?, createdAt,
  updatedAt)`
- `PeriodRepository.getAll/create/update/delete`
- `TodayCycleContext.fromRecords(...)`
- `CyclePredictionEngine.calculate(records)`
- `CyclePrediction(predictedMensesStart, predictedMensesEnd, midpoint,
  medianCycleDays, minimumCycleDays, maximumCycleDays, intervalCount,
  confidence, predictedLutealStart, predictedLutealEnd)`
- prediction timing: upcoming, current window, or later than estimate

Period validation includes no future dates, end not before start, no overlap,
only one open period, and explicit storage failure. Predictions are calculated
only from recorded period starts and are never persisted as health facts. Keep
local-date semantics. Do not invent a backend, API, database, or prediction
model.

## Gravity Horizon fixtures

Use these deterministic design states:

1. No history: today 2026-08-05, no periods. No cycle day, curve, or prediction
   should imply known information.
2. Insufficient: today 2026-08-05, period 2026-07-19 through 2026-07-23.
   Cycle day 18, latest start Jul 19, no prediction.
3. Prediction available: periods 2026-05-22 through 2026-05-27,
   2026-06-20 through 2026-06-24, and 2026-07-19 through 2026-07-23; today
   2026-08-05. Production result: 29/29-day intervals, midpoint 2026-08-17,
   estimated range 2026-08-13 through 2026-08-21, low confidence, cycle day 18.
4. Period in progress: completed periods 2026-06-20 through 2026-06-24 and
   2026-07-19 through 2026-07-23; open period begins 2026-08-16; today
   2026-08-18. Show recorded period day 3 as primary. A production estimate may
   still exist, but it must not outrank the active observed period.
5. Later than estimate: the three completed periods from state 3; today
   2026-08-23. The range remains Aug 13-21 and today is two days later. Do not
   imply a medical problem or convert the estimate into a recorded period.

Gravity Horizon must include observed period bands, a clearly different
hatched/dashed estimated range, today marker, dates, cycle day when available,
confidence, observed/estimated legend, evidence rows, accessible summary, and
the route to Cycle. Observed versus estimated cannot depend on color alone.

The graph describes dates and cycle timing only. It must never predict or claim
to measure mood, energy, symptoms, hormones, diagnosis, PMDD risk, or how the
person feels. Their check-in is the record of current experience.

Use modest factual language such as:

- "This illustration is calculated from the period dates you recorded. It is
  an estimate, not a body measurement."
- "Estimated premenstrual window. Your experience may be different."
- "Dates only. Your check-in is the record of how you actually feel."
- "Today is past the estimated range. Your experience may be different."

Do not use "your energy is falling", "gravity is heavier because of your
hormones", "PMDD danger window", "hormonal forecast", or cosmic-tide language.

## Required Cycle states

Design no-history, open-period, one-completed-period, insufficient prediction
history, prediction available, later-than-estimate, loading, storage failure
with retry, invalid dates, overlap, another-open-period conflict, editing, and
deletion confirmation. Show recorded dates as observed, estimates separately,
confidence/evidence, why history is insufficient, and why an estimate is not a
confirmed period.

## Acceptance

- Preserve the established Letter Within paper-and-ink/Newsreader design system.
- 390x844 primary layout and 320px narrow layout.
- 200% text scaling without clipping, fixed-height text, or overlap.
- Reduced-motion static chart mode.
- Minimum 44x44 targets and screen-reader chart summaries.
- No horizontal page scrolling; support long period history and localized text
  expansion.
- Keep Care activity internals and all pricing/entitlement work out of scope.

First return a decision-complete design plan: full Today hierarchy, full Cycle
hierarchy and sheets/dialogs, Gravity Horizon anatomy and five states,
interaction transitions, responsive rules, reusable components, and the exact
Flutter files you will replace or add during Build mode. Do not write code yet.
