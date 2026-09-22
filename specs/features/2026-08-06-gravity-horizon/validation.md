# Gravity Horizon Validation

Status: passed

## Automated Checks

- [x] no history and one-period states contain no invented estimate
- [x] x positions are monotonic calendar-date positions
- [x] valley boundaries equal the estimated premenstrual window boundaries
- [x] next-period band equals the engine's estimated menses range
- [x] next-period range is a hatched date band aligned to the shared x-axis
- [x] short, typical, long, and irregular histories remain drawable
- [x] open period prioritizes recorded period/bleeding duration
- [x] Today header does not duplicate cycle day or the no-history message
- [x] emotional/energy curve remains estimated while recorded period dates use
  a separate solid teal rail on the same x-axis
- [x] current-range and later-than-range states use non-clinical language
- [x] chart and action navigate to Cycle
- [x] accessible summary distinguishes observed from estimated information
- [x] 320-pixel width at 200 percent text has no overflow
- [x] Today golden passes at 390 by 844
- [x] `cycle_prediction.dart` has no production diff
- [x] Flutter analyzer and focused tests pass

## Manual Review

1. [x] Confirm that the chart communicates lighter-to-heavier estimated
   emotional/energy gravity without implying a measured personal value.
2. [x] Confirm the Today card is understandable without reading a data table.
3. [x] Confirm Cycle remains the place for detailed dates, history, and editing.
