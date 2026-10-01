# Cycle Prediction And Confidence Validation

Status: validated

## Automated Checks

The checks below describe the original formal prediction. The 1.0 Today/Cycle
visual-only amendment is tracked in
`validation/today-cycle-audit-2026-10-01/` and must additionally verify the
two-start early range, asymmetric margins, timing, cross-year labels, and
matching Today/Cycle semantics on small and large-text iPhone simulators.

## 1.0 Today/Cycle release audit (2026-10-01)

- [x] Independently calculated synthetic dates cover zero/one/two starts,
  regular and variable cycles, ongoing and ended-today bleeding, forecast
  timing, leap day and year rollover, future dates, and historical edits.
- [x] Today and Cycle agree on current day and inclusive estimate range. The
  Cycle ring places today in the expected observed or estimated segment and
  names each segment's day bounds in its accessibility description.
- [x] A one-interval estimate is labeled early and remains visual-only;
  variable history is described as variable rather than limited history.
- [x] At 320 logical pixels and 200% text, both destinations keep their facts
  readable without overflow; iPhone 17 Pro Max and SE 3 Simulator captures
  were visually reviewed, including larger system text on SE 3.
- [x] `flutter analyze --no-pub` found no issues; final full `flutter test
  --no-pub -r expanded` passed 671 tests with one pre-existing skip.

The screenshot files, expanded test log, independent arithmetic sheet, and
temporary synthetic-data entrypoint remain local verification artifacts and
are intentionally excluded from the release commit.

- [x] fewer than two complete intervals produces no prediction
- [x] exactly two intervals produces a Low-confidence range
- [x] the most recent six intervals are used
- [x] the rounded median is deterministic for odd and even samples
- [x] minimum uncertainty margins are enforced
- [x] observed variation widens the range
- [x] spread above seven days keeps confidence Low
- [x] at least four stable intervals can produce Higher confidence
- [x] an open current period can anchor the estimate
- [x] dates remain local calendar values
- [x] inside-window and later-than-estimate states are correct
- [x] insufficient-history progress is visible
- [x] evidence states interval count and observed length range
- [x] deleting history can remove an unsupported prediction
- [x] no fertility, phase, danger-window, or diagnosis language appears
- [x] 320-pixel width at 200 percent text does not overflow
- [x] updated Cycle golden is reviewed
- [x] Flutter analyzer passes
- [x] complete Flutter test suite passes: 44 tests
- [x] Flutter web build passes

## Manual Product Review

1. Confirm no estimate appears with only one complete interval.
2. Confirm a range appears after the second interval is recorded.
3. Confirm confidence never reads as certainty.
4. Confirm broad history produces a visibly broad estimate.
5. Confirm the evidence line explains interval count and cycle-length range.
6. Confirm a late period does not cause Letter Within to invent an unrecorded cycle.
7. Edit and delete history and confirm the estimate changes immediately.
8. Confirm no fertility or phase interpretation appears.

## Merge Gate

- [x] requirements are implemented without adding fertility scope
- [x] prediction remains derived local data
- [x] all values trace to recorded period starts
- [x] local changes are committed
- [ ] user explicitly requests merge
