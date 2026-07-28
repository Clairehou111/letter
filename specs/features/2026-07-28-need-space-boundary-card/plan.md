# Session-Only Boundary Card Plan

Status: completed

1. Specification Approval
   - [x] Review the two static template texts.
   - [x] Review the `30 minutes`, `2 hours`, and `4 hours` duration set.
   - [x] Confirm clipboard disclosure and session-only clearing behavior.
   - [x] Confirm the component contract with the Need-space integration spec.
   - [x] Mark requirements and validation as approved.

2. Isolated Component
   - [x] Add the boundary-card presentation component.
   - [x] Accept a caller-owned text controller and navigation callbacks.
   - [x] Add static template and bounded-duration selection.
   - [x] Add optional plain-text editing with the 280-character limit.
   - [x] Add discard and continue-without-copying paths.

3. Clipboard Boundary
   - [x] Add the explicit clipboard disclosure beside the copy action.
   - [x] Write only the visible text after an explicit `Copy text` tap.
   - [x] Add a factual copied acknowledgement.
   - [x] Verify that no existing clipboard content is read.
   - [x] Verify that no share, send, composer, or external-app action exists.

4. Session Privacy And Safety
   - [x] Clear text on discard and every Care-leave path.
   - [x] Clear text and copy acknowledgement on reconstruction or re-entry.
   - [x] Preserve the active ephemeral state only when safety is dismissed.
   - [x] Keep safety, back, leave, and no-copy completion reachable.
   - [x] Verify no persistence, analytics, logs, API, LLM, or clinical output.

5. Accessibility And Validation
   - [x] Add isolated widget tests for all state transitions.
   - [x] Test 320 logical pixels at 200 percent text scaling.
   - [x] Test Reduced Motion behavior.
   - [x] Test screen-reader labels, selected states, and announcements.
   - [x] Test all primary targets at 44 by 44 logical pixels or larger.
   - [x] Add and inspect boundary-card visual baselines.

6. Integration Handoff
   - [x] Run isolated tests before integration.
   - [x] Hand the component contract to the Need-space integration owner.
   - [x] Verify the parent flow can complete without opening the card.
   - [x] Review the integrated clearing behavior.
   - [x] Commit locally without push or merge.
