# Period and cycle acceptance

Status: focused tests pass; final 2.0 device validation, adjacent-merge
correction, and reminder reconciliation are open.

| Case | Required result |
| --- | --- |
| Date editing | Create open/closed; end, reopen, backfill, edit, delete; future/end-before-start/overlap/second-open failures preserve draft and show reason. |
| Identity | Editing dates keeps period ID and reflection; deleting warns about and removes the reflection; independently dated symptom and Care records survive. |
| Flow and color | Four flow values; color requires flow; replacing/clearing works; date correction removes only out-of-range days; delete removes owned flow. |
| Unusual history | One-day period, prolonged open period, adjacent start, short/long/variable intervals, older-history insertion, and passed forecast preserve recorded truth. |
| Estimate | Two-interval formal threshold, one-interval orientation-only state, six-interval cap, quality/outlier exclusions, range margins, confidence thresholds, edit/delete recomputation. |
| Storage and UI | Native encrypted persistence and migration, web memory-only behavior, loading/error/retry, 320px/200% text, screen reader, and 44px targets. |

On 2026-10-03 the focused `flutter test` run for `cycle_prediction_test.dart`,
`core_cycle_prediction_test.dart`, `period_repository_contract_test.dart`, and
`period_flow_repository_test.dart` passed 65 tests. These tests currently
encode the automatic merge; they do not establish PC-03 acceptance.

**Open defect:** `cycle_experience.dart` submits directly to `create`/`update`;
`period_validation.dart` and both repositories merge adjacent ranges without
confirmation. The earliest existing period generally keeps its ID and absorbed
flow is reassigned. Drift can detach a reflection attached to an absorbed
period, leaving its authored text without cycle ownership. Add confirmation
and safe reflection handling, then replace the old automatic-merge tests with
the accepted behavior and run a native migration/device check.

**Resolved contract choice:** the formal engine uses inclusive 15–90-day
quality bounds, a 21–45-day review band, and relative outlier filtering.
Stable 19-day and 60-day histories are covered by current tests. One usable
interval only produces a limited orientation estimate; formal insights need
two filtered intervals.

**Open reminder mismatch:** on 2026-10-03, `cycle_check_in_scheduler_test.dart`,
`notification_privacy_navigation_test.dart`, and `privacy_analytics_test.dart`
passed 14 tests. They cover a legacy Cycle Check-in that defaults enabled
and schedules a neutral local notification at 10:00 the day after the formal
period estimate's upper bound, subject to OS permission. This is separate
from the 2.0 Comfort Window reminder, which defaults off, needs explicit
opt-in and Clearer evidence, supports 0/1/2-day lead, and defaults to 09:00.
No separate Comfort Window scheduler was found in this checkout. Reconcile
the product decision, implementation, tests, and privacy copy before release.
