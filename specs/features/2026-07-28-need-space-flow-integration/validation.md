# Need-Space Flow Integration Validation

Status: validated

## Automated Checks

- [x] the Care gate opens the dedicated Need-space flow
- [x] one curtain action produces the protected cocoon state
- [x] tap and downward-gesture paths reach the same state
- [x] Reduced Motion reaches the same state without spatial travel
- [x] `Prepare words` opens the optional boundary card
- [x] `Nothing else right now` reaches the final hand-off directly
- [x] boundary-card back returns to the closed cocoon
- [x] finish, discard, and copy acknowledgement reach a finite hand-off
- [x] no completion path autoplays another Care mode
- [x] back, leave, and safety remain available throughout
- [x] safety dismissal restores the same ephemeral state
- [x] every Care-leave path clears boundary-card text
- [x] reconstruction starts open and contains no prior user text
- [x] no contact, recipient, send, share, or external-app affordance appears
- [x] no Focus or Do Not Disturb control or promise appears
- [x] no persistence, API, LLM, analytics, logs, notification, or clinical value
- [x] 320-pixel width at 200 percent text does not overflow
- [x] primary controls meet the 44-pixel target
- [x] cocoon, boundary-card, and integrated visual baselines are reviewed
- [x] existing Angry, Heavy, Racing, and physical flows remain valid
- [x] repository-wide validation passes
- [x] Flutter Web build passes

## Manual Product Review

1. Enter `I need everyone away`.
2. Close the curtain with the downward gesture.
3. Repeat with the tap alternative.
4. Confirm the scene feels quieter without claiming actual phone isolation.
5. Choose `Nothing else right now` and confirm no task is imposed.
6. Re-enter, prepare one synthetic boundary card, and edit it.
7. Copy it only through the explicit copy control.
8. Confirm no recipient, contact, send, share, or external app appears.
9. Discard and leave from every state; confirm text does not return.
10. Open and dismiss safety from cocoon and boundary-card states.
11. Repeat with Reduced Motion and at 320 pixels with 200 percent text.

## Parallel Merge Gate

- [x] all three specifications are approved
- [x] child component file ownership remains disjoint
- [x] public callback contracts are sufficient for integration
- [x] isolated child tests pass before integration
- [x] main agent reviews both child implementations

## Feature Merge Gate

- [x] one interaction creates visible protected isolation
- [x] no optional text or copy step is required
- [x] copied-text limitations are stated honestly
- [x] all session-only text is forgotten by Letter
- [x] safety and platform limitations are explicit
- [x] no personal or clinical data is stored
- [x] local changes are committed
- [ ] user explicitly requests merge

## Evidence

- Two subagents implemented the cocoon and boundary card in disjoint files;
  the main agent reviewed and integrated both.
- Focused Need-space and Care tests passed: 51 of 51.
- Full Flutter validation passed: analyze clean and 169 tests passing.
- Repository validation passed, including 6 API tests.
- Flutter Web built successfully.
- Four golden baselines and the real-font open and closed states were reviewed.
- Clipboard failure preserves the draft, reports failure locally, and emits no
  log or analytics event.
