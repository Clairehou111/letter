# Today Cycle Context And Logging Entry Plan

Status: completed

1. Specification
   - [x] Confirm the narrow Today scope with the user.
   - [x] Inventory synthetic prototype content and no-op controls.
   - [x] Define real context and session-only entry boundaries.
   - [x] Create the stacked feature branch and specification.

2. Context Domain
   - [x] Add an immutable Today cycle-context model.
   - [x] Derive open-period, between-period, no-history, and prediction states.
   - [x] Test cycle-day and prediction delegation rules.

3. Today Experience
   - [x] Load local period history with loading and retry states.
   - [x] Replace the synthetic hero with real context.
   - [x] Remove fake plan, note, recent entry, phase, and status bar.
   - [x] Make Log and quick-state controls functional and honest.
   - [x] Keep a generic Care entrance.

4. Validation
   - [x] Test no-history, open-period, between-period, and prediction states.
   - [x] Test navigation to Cycle from no history.
   - [x] Test Log opens state entry.
   - [x] Test state choices are not described as saved.
   - [x] Test narrow-screen and large-text behavior.
   - [x] Update and inspect the Today golden.
   - [x] Run formatting, analyzer, all tests, and web build.

5. Handoff
   - [x] Update roadmap, README, and validation evidence.
   - [x] Review the complete diff.
   - [x] Commit locally without push or merge.
