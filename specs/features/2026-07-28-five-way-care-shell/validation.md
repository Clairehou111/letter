# Five-Way Care Entrance And Finite Reward Shell Validation

Status: validated

## Automated Checks

- [x] Care is reachable from Today and primary navigation
- [x] all five entrances use exact approved labels
- [x] no entrance is inferred or preselected
- [x] each entrance opens its matching scene directly
- [x] first focal action changes visible scene state
- [x] each scene shows no more than one protective line
- [x] each scene ends in one real-world hand-off
- [x] hand-off returns to the Care gate
- [x] Not now returns to the Care gate
- [x] close returns to Today
- [x] emotional safety route interrupts the normal scene
- [x] physical medical-boundary route interrupts the normal scene
- [x] reduced-motion state remains understandable
- [x] no fake personal plan, contact, action, or outcome appears
- [x] no Care data is persisted or reported
- [x] primary controls meet the 44-pixel target
- [x] 320-pixel width at 200 percent text does not overflow
- [x] Care gate and transformed-scene goldens are reviewed
- [x] repository-wide validation passes: API 6 tests, Flutter 74 tests
- [x] Flutter web build passes

## Manual Product Review

1. Open Care from Today and from the bottom tab.
2. Confirm the right entrance can be identified without medical language.
3. Open each mode and confirm feedback follows the first action.
4. Confirm no interaction continues indefinitely or opens another mode.
5. Confirm close, Not now, emotional safety, and physical safety are obvious.
6. Confirm no screen claims treatment, diagnosis, or personal history.
7. Enable reduced motion and confirm the state transition remains legible.

## Merge Gate

- [x] Care is a real primary destination
- [x] every shell is finite and escapable
- [x] safety limitations are explicit
- [x] no mode-specific persistence was added early
- [x] local changes are committed
- [ ] user explicitly requests merge
