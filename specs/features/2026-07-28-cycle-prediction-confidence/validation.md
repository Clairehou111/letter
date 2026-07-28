# Cycle Prediction And Confidence Validation

Status: validated

## Automated Checks

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
6. Confirm a late period does not cause Letter to invent an unrecorded cycle.
7. Edit and delete history and confirm the estimate changes immediately.
8. Confirm no fertility or phase interpretation appears.

## Merge Gate

- [x] requirements are implemented without adding fertility scope
- [x] prediction remains derived local data
- [x] all values trace to recorded period starts
- [x] local changes are committed
- [ ] user explicitly requests merge
