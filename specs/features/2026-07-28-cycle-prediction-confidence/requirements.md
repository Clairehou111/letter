# Cycle Prediction And Confidence Requirements

Status: validated
Branch: `feature/cycle-prediction-confidence`
Base branch: `feature/period-logging-history`

## Context

Period history is now the local source of truth. Letter Within needs to turn that
history into a useful next-period estimate without presenting false precision
or expanding into fertility and phase claims.

This is a stacked feature branch because period logging is locally validated
but intentionally not merged without the user's explicit request.

## Goal

Show a transparent next-period date range and confidence explanation after
enough observed cycle history exists.

## 1.0 Today/Cycle presentation amendment (2026-10-01)

The formal prediction in REQ-002 and the Algorithm below still requires two
usable start-to-start intervals. Today and Cycle also offer a **visual-only
early estimate** after one usable interval (two recorded starts). It uses the
observed interval as its median and an inclusive range seven calendar days on
either side of the midpoint. Label it as early and based on one observed
interval. It must not feed insights, reports, preparation, reminders, or other
health decisions. With zero intervals, show the factual current day and an
honest forming state, without an estimate.

For both estimate kinds, calculate separate left and right margins: each is
the greater of its sample minimum and the corresponding deviation from the
median. This may make a variable-history range asymmetric. Preserve the
original range before, during, and after its dates; identify the current
window and a later-than-estimate state without rolling the dates forward.
The Today card and Cycle ring/estimate line must agree on current day, range,
timing, and the reason an estimate is limited. A variable-history estimate
must say recorded cycles vary, rather than implying the person has little
history. Date labels must disambiguate a range that crosses years.
After a history edit, Cycle must render its ring and estimate from the same
freshly loaded record revision while the enclosing shell refreshes.

## Requirements

REQ-001: Calculate predictions locally from user-recorded period start dates.
Do not use the API, cloud tools, analytics, population averages, or LLM output.

REQ-002: Require at least two complete start-to-next-start cycle intervals.
This normally requires three recorded period starts. Do not show a prediction
from only one interval in the formal prediction. See the 1.0 amendment for the
separately labeled Today/Cycle early estimate.

REQ-003: Predict a date range, never a single promised date.

REQ-004: Use at most the six most recent observed cycle intervals so the
estimate can adapt while remaining based on multiple cycles.

REQ-005: Use the median observed cycle length as the center estimate. Expand
the range according to both sample count and observed variation.

REQ-006: Apply a minimum uncertainty margin of four days on either side with
two intervals, three days with three intervals, and two days with four or more
intervals. A wider observed spread must widen the affected side of the range
further. The visual-only one-interval estimate uses seven days on each side.

REQ-007: Label confidence as `Low`, `Medium`, or `Higher`, not as certain or
clinically validated.

REQ-008: Keep confidence `Low` when only two intervals exist or when observed
cycle-length spread exceeds seven days. Use `Medium` for developing history.
Use `Higher` only with at least four intervals and a spread of four days or
less.

REQ-009: When history varies by more than seven days, say that recorded cycles
vary and that the estimate is wider. Do not diagnose an irregular cycle.

REQ-010: Show how many recent intervals were used and the observed cycle-length
range. The user must be able to understand why the estimate is broad or narrow.

REQ-011: If history is insufficient, show progress toward two complete
intervals rather than a fabricated estimate.

REQ-012: Anchor the next estimate to the most recent recorded period start,
including a currently open period once the minimum prior history exists.

REQ-013: If today's date is inside the predicted range, identify that the
estimate window is current. If today is later than the range, say the recorded
period is later than this estimate; do not silently roll the estimate forward.

REQ-014: Recalculate immediately after period create, edit, or delete
operations. Do not persist derived prediction values as separate health
records.

REQ-015: Preserve local date semantics. Prediction dates must not move when a
time zone changes.

REQ-016: Keep the estimate operable and readable at 320 logical pixels and 200
percent text scaling.

REQ-017: Keep prediction language direct and clinically modest. It is an
estimate based on the user's history, not contraception, diagnosis, or proof
of a biological phase.

## Algorithm

1. Sort recorded period starts from oldest to newest.
2. Keep the seven most recent starts, producing at most six intervals.
3. Calculate start-to-start day differences.
4. Require at least two differences.
5. Use the rounded median difference as the center cycle length.
6. Set the left margin to the larger of the sample-count minimum and median
   minus the shortest used interval. Set the right margin to the larger of the
   sample-count minimum and the longest used interval minus the median.
7. Add the center length to the latest start for the midpoint.
8. Subtract the left margin and add the right margin for the displayed range.

These are conservative product heuristics, not a clinical prediction model.

## Non-Goals

- ovulation, fertile-window, conception, or pregnancy estimates
- menstrual, follicular, ovulation, or luteal phase labels
- PMS/PMDD danger-window prediction
- diagnosis of irregular cycles, amenorrhea, or pregnancy
- population-average defaults
- symptom prediction
- notifications
- background jobs
- persisted prediction tables or server APIs

## Product Decisions

- A complete cycle interval is measured between two recorded period starts; a
  period end date does not define cycle length.
- A currently open period can be the latest prediction anchor because its start
  is observed, but it does not remove the two-interval minimum.
- Unusual history is retained and visibly widens confidence rather than being
  silently discarded as an outlier.
- The next roadmap feature may use this estimate as context, but must not
  reinterpret it as a fertile or clinical window.
