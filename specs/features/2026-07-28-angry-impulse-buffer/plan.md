# Angry And Overloaded Impulse Buffer Plan

Status: completed

1. Specification
   - [x] Confirm the full feature boundary with the user.
   - [x] Define Shatter, draft, seal, unlock, and deletion behavior.
   - [x] Define security claims, clock limits, and non-goals.
   - [x] Create the stacked feature branch and specification.

2. Local Data
   - [x] Add the impulse-buffer domain model and repository contract.
   - [x] Add deterministic state and remaining-time rules.
   - [x] Add in-memory and Drift repository implementations.
   - [x] Share one encrypted health database across period and impulse data.
   - [x] Add and test the version-2 database migration.

3. Angry Care Experience
   - [x] Add the finite 20-second or 20-tap Shatter scene.
   - [x] Add skip, reduced-motion, exit, and safety behavior.
   - [x] Add the low-stimulation transition and private draft editor.
   - [x] Add explicit save, resume, review, and seal behavior.
   - [x] Add locked-envelope countdown and unopened deletion.
   - [x] Add ready-envelope open, reseal, and delete options.
   - [x] Add explicit retry states for repository failures.

4. Validation
   - [x] Test the complete repository state model and failure mapping.
   - [x] Test Shatter tap, timer, skip, and reduced-motion completion.
   - [x] Test content validation and review consequence.
   - [x] Test locked content is absent from rendering and semantics.
   - [x] Test unlock, private open, rewrite, reseal, and deletion.
   - [x] Test app restart reconstruction from local records.
   - [x] Test narrow-screen, large-text, and primary touch targets.
   - [x] Add and inspect visual baselines.
   - [x] Run repository-wide validation and Web build.

5. Handoff
   - [x] Update roadmap, README, and validation evidence.
   - [x] Review the complete diff.
   - [x] Commit locally without push or merge.
