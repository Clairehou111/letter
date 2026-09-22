# Cycle Flow And Clearer History Validation

Status: focused automated validation passed

## Automated Checks

- [x] spotting, light, medium, and heavy round-trip through in-memory storage
- [x] flow values round-trip through Drift storage
- [x] flow cannot be saved outside a period interval or in the future
- [x] editing dates removes only newly out-of-range flow values
- [x] deleting a period removes its flow values
- [x] old databases migrate without changing existing period records
- [x] encrypted backup round-trips flow and accepts older backups without it
- [x] history distinguishes bleeding duration from completed cycle length
- [x] newest history row explains when completed cycle length is unavailable
- [x] later-than-range wording remains non-clinical
- [x] narrow width and 200 percent text do not overflow
- [x] `cycle_prediction.dart` has no production diff from the approved engine
- [x] Flutter analyzer passes
- [x] focused Flutter tests pass

Additional exceptional-cycle regression coverage is maintained in
`test/cycle_domain_test.dart`, `test/cycle_screen_test.dart`,
`test/period_flow_repository_test.dart`, and
`test/care_memory_repository_test.dart` for one-day bleeding, prolonged open
periods, adjacent starts, stable identity after older-history insertion, date
editing and flow cleanup, schema migration, and date-owned Care records.

The period-delete dialog still needs a future presentation change to mention
that an attached cycle reflection will also be deleted. That warning is not
claimed as validated by this local-only batch.

## Manual Review

1. Start a period today and record today's flow.
2. Change and clear today's flow.
3. Add a completed past period and record flow for several days.
4. Correct its boundaries and confirm out-of-range flow disappears.
5. Confirm recent and archived rows show bleeding days and, where available,
   start-to-next-start cycle length separately.
6. Confirm all editor, archive back, edit, and confirmed-delete paths return to
   a usable Cycle screen.
