# Period Logging And History Validation

Status: validated for shared logic and web preview; native gate deferred

## Automated Checks

- [x] local-date conversion remains stable across time zones
- [x] valid open and closed intervals can be created
- [x] future dates are rejected
- [x] end-before-start is rejected
- [x] overlapping intervals are rejected
- [x] a second open interval is rejected
- [x] edits preserve identifiers and creation timestamps
- [x] records are returned newest first
- [x] deletion removes the selected record
- [x] Cycle shows loading without flashing an empty history
- [x] empty history can start today or add a past period
- [x] current period can be ended
- [x] history can be edited and deleted
- [x] save failures leave entered values recoverable
- [x] navigation reaches Cycle and returns to Today
- [x] primary controls meet the 44-pixel touch target
- [x] 320-pixel width at 200 percent text does not overflow
- [x] Cycle screen matches the reviewed visual baseline
- [x] Flutter analyzer passes
- [x] Flutter test suite passes: 32 tests
- [x] Flutter web build passes with in-memory storage only

## Native Checks

- [ ] iOS database opens only with SQLite3MultipleCiphers available
- [ ] Android database opens only with SQLite3MultipleCiphers available
- [ ] reopening with the secure key preserves records
- [ ] opening without the correct key cannot read records
- [ ] database file contains no searchable period values

Native checks remain deferred until the previously deferred native toolchain
gate is enabled. This feature cannot be marked fully native-validated without
them.

The Drift repository is covered against an in-memory SQLite executor. That
proves schema and CRUD behavior, not native encryption-at-rest behavior.

## Manual Product Review

1. Start a period from an empty Cycle page.
2. End the current period.
3. Add a non-overlapping past period.
4. Edit that period.
5. Attempt an overlap and confirm the error explains how to recover.
6. Delete a period and confirm that only the intended record disappears.
7. Restart the native app and confirm records remain.
8. Confirm spotting is not implied or offered as a period start.
9. Confirm no prediction appears before the prediction feature exists.

## Merge Gate

- [x] requirements are implemented without silently broadening scope
- [x] no readable health value leaves the device
- [x] no browser persistence is introduced
- [x] native encryption limitations are explicit
- [x] local changes are committed
- [ ] user explicitly requests merge
