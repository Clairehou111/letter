# Need-Space Flow Integration Plan

Status: completed

1. Specification
   - [x] Confirm no contact access or message sending.
   - [x] Confirm the primary outcome is protected isolation.
   - [x] Split cocoon, boundary-card, and integration responsibilities.
   - [x] Review all three specifications with the user.
   - [x] Mark requirements and validation as approved.

2. Parallel Implementation
   - [x] Delegate `SafeCocoonStage` and its isolated tests.
   - [x] Delegate `NeedSpaceBoundaryCard` and its isolated tests.
   - [x] Implement the integration state machine on the main thread.
   - [x] Review and integrate both disjoint subagent results.

3. Care Integration
   - [x] Route `CareMode.space` to `NeedSpaceFlow`.
   - [x] Keep shared back, exit, and emotional safety behavior stable.
   - [x] Clear session-only text on every leave path.
   - [x] Update generic Care regression and visual baselines.

4. Validation
   - [x] Run isolated cocoon tests.
   - [x] Run isolated boundary-card tests.
   - [x] Run integrated state, privacy, safety, and callback tests.
   - [x] Inspect golden baselines.
   - [x] Run 320px, 200% text, and Reduced Motion checks.
   - [x] Run repository-wide validation and Flutter Web build.
   - [x] Perform a real-font browser review.

5. Handoff
   - [x] Update roadmap, README, canonical decisions, and evidence.
   - [x] Review the complete diff.
   - [x] Commit locally without push or merge.
