# Racing Thoughts Convergence Flow Validation

Status: validated

## Automated Checks

- [x] the first screen shows scattered fragments and one calm center
- [x] one tap converges the scene immediately
- [x] reduced motion reaches the same centered state without spatial animation
- [x] convergence reveals only the approved protective line
- [x] naming, unnamed, and nothing-now paths are explicit
- [x] naming accepts 1 to 280 non-whitespace characters
- [x] naming has no recipient, task, send, share, or export affordance
- [x] set-down clears entered text before the next state
- [x] discard clears entered text before the hand-off
- [x] unnamed path makes no topic or meaning inference
- [x] nothing-now requires no text or reflection
- [x] no path claims that the thought is solved
- [x] no Care mode autoplays after completion
- [x] safety and exit remain available in every state
- [x] safety dismissal restores the same ephemeral state
- [x] reconstruction starts scattered with empty text
- [x] no thought is saved or resurfaced tomorrow
- [x] no Care event, symptom, severity, outcome, or interaction count is stored
- [x] no API, LLM, analytics, notification, background task, or clinical value
- [x] 320-pixel width at 200 percent text does not overflow
- [x] primary controls meet the 44-pixel target
- [x] Racing-flow visual baselines are reviewed
- [x] existing Angry, Heavy, space, and physical flows remain valid
- [x] repository-wide validation passes
- [x] Flutter Web build passes

## Evidence

- Two subagents implemented the isolated widget and widget tests with disjoint
  write scopes; the main agent reviewed and integrated both results.
- `flutter analyze`: no issues.
- `flutter test`: 131 tests passed.
- API validation: formatting, lint, type checks, contract checks, and 6 tests
  passed.
- Repository foundation and hygiene checks passed.
- Flutter Web production build passed.
- Golden baselines cover the 390-by-844 scattered and converged states.
- A real-font Chromium review covered the Care gate, scattered state, and
  converged state at 390 by 844; all screenshots were non-empty and controls
  were unobstructed.

## Manual Product Review

1. Enter `My mind won't stop` and tap once anywhere on the focal surface.
2. Confirm complexity drops immediately and no hold or breathing is required.
3. Name one synthetic thought, set it down, and confirm the text disappears.
4. Repeat and discard the text.
5. Use `I don't want to name it`.
6. Use `Nothing now` directly after convergence.
7. Open and dismiss safety from each state.
8. Leave and re-enter; confirm the scene and text reset.
9. Enable reduced motion and 200 percent text.
10. Confirm no screen promises to return the thought tomorrow.

## Merge Gate

- [x] one input creates visible order
- [x] all paths are finite and escapable
- [x] optional text is forgotten by design
- [x] safety limitations are explicit
- [x] no personal or clinical data is stored
- [x] local changes are committed
- [ ] user explicitly requests merge
