# Heavy And Low Presence Flow Validation

Status: validated

## Automated Checks

- [x] first tap changes the dim light immediately
- [x] first tap reveals only the first approved protective line
- [x] the sequence contains no more than three lines
- [x] each line advances only after explicit input
- [x] the user can stop before reading all lines
- [x] presence starts only after explicit selection
- [x] presence requires no continuing gesture or input
- [x] presence completes at exactly two minutes
- [x] safety and background time do not consume the presence interval
- [x] End early reaches the same practical hand-off
- [x] no Care mode autoplays after completion
- [x] safety and exit remain available in every state
- [x] reduced motion preserves lit, timer, and completion state
- [x] reconstruction starts from a fresh dim state
- [x] no personal Care Kit, contact, history, or future-self copy appears
- [x] no Care event, symptom, severity, or outcome is persisted
- [x] no API, LLM, analytics, notification, or background task is created
- [x] 320-pixel width at 200 percent text does not overflow
- [x] primary controls meet the 44-pixel target
- [x] Heavy-flow visual baselines are reviewed
- [x] existing Angry, racing, space, and physical flows remain valid
- [x] repository-wide validation passes: API 6 tests, Flutter 115 tests
- [x] Flutter Web build passes

## Evidence

- `python3 tools/validate.py`: passed
- API tests: 6 passed
- Flutter tests: 115 passed
- `flutter analyze`: no issues
- `flutter build web`: passed, including the Wasm dry run
- 390x844 Chromium review: dim, awake, and presence states rendered with real
  fonts without blank output, overlap, unstable controls, or hidden safety
- reviewed goldens: `heavy_dim_390x844.png` and
  `heavy_presence_390x844.png`
- implementation and isolated widget tests were delegated to two subagents
  with disjoint write scopes, then reviewed and integrated on the main branch

## Manual Product Review

1. Enter `I feel heavy` and confirm the first screen asks for only one tap.
2. Tap once and confirm the response is obvious without energetic page motion.
3. Advance the copy and confirm there is no infinite feed or lesson.
4. Stop after the first line and confirm a practical hand-off is available.
5. Start two-minute presence and confirm no hold or repeated input is needed.
6. End early, then complete a separate interval naturally.
7. Open safety from dim, awake, presence, and hand-off states.
8. Enable reduced motion and confirm all state remains legible.
9. Re-enter the mode and confirm it starts fresh without personal claims.

## Merge Gate

- [x] almost-zero effort produces a visible response
- [x] the interaction is finite and escapable
- [x] presence is optional and does not claim treatment
- [x] safety limitations are explicit
- [x] no personal or clinical data is fabricated or stored
- [x] local changes are committed
- [ ] user explicitly requests merge
