# Racing Thoughts Convergence Flow Requirements

Status: validated
Branch: `feature/racing-thoughts-convergence-flow`
Base branch: `feature/heavy-low-presence-flow`

## Context

The five-way Care shell currently represents racing thoughts with one generic
tap. The approved product direction calls for complexity to visibly decrease
until only one controllable point remains.

The user explicitly decided on 2026-07-28 that P0 does not save a thought until
tomorrow. This feature therefore has no Tomorrow Tray, reminder, local record,
or future resurfacing. Optional text exists only in the active widget session
and is cleared when set down, discarded, or left.

## Goal

Turn an `everything at once` screen into one calm point after a single input,
then let the user name at most one thought or choose to name nothing before
leaving the app.

## Requirements

REQ-001: Replace the generic racing shell with a dedicated
`Scattered -> Converged -> Optional one thought -> Set down -> Hand-off` flow.

REQ-002: The first screen must show multiple restrained fragments around one
calm center. One tap anywhere on the focal surface must converge all fragments
into that center.

REQ-003: A continuous hold, repeated tapping, swipe, breathing exercise, typing,
audio, or haptic input must not be required to converge the scene.

REQ-004: The first tap must create an immediate, obvious reduction in visual
complexity while navigation and safety controls remain stable.

REQ-005: Respect reduced motion. With animations disabled, switch directly from
scattered fragments to one centered point without spatial travel.

REQ-006: After convergence, show one bounded protective line:
`Your mind opened every tab at once. We only need one.`

REQ-007: Offer three explicit paths after convergence:
`Name one thought`, `I don't want to name it`, and `Nothing now`.

REQ-008: Naming is optional and accepts 1 to 280 non-whitespace characters.
Disable autocorrect and suggestions. There is no recipient, task metadata,
deadline, priority, send, share, or export action.

REQ-009: The naming screen must state directly that the text exists only on
this screen and will not come back tomorrow.

REQ-010: `Set it down for now` must clear the text controller before showing a
generic set-down state. The entered text must not remain visible in the next
state.

REQ-011: `Discard` must clear the text and reach the same finite hand-off
without representing the thought as completed or solved.

REQ-012: `I don't want to name it` must skip text entry and show a generic
acknowledgement without inferring the thought's topic or meaning.

REQ-013: `Nothing now` must reach the hand-off without input, reflection, or a
failure state.

REQ-014: The final hand-off must offer `Return to Care choices` and
`Leave Care`. It must not autoplay another Care mode.

REQ-015: Keep `I may not be safe`, back-to-Care, and leave-Care controls
available during scattered, converged, naming, set-down, and hand-off states.

REQ-016: The safety action must open the existing deterministic emotional
safety boundary and return to the same ephemeral state when dismissed.

REQ-017: Reconstructing or re-entering the flow starts at `Scattered` with an
empty text controller.

REQ-018: Do not persist text, a Care event, completion, symptom, severity,
outcome, or interaction count. Do not add a database table or repository.

REQ-019: Do not create an API request, LLM request, analytics event,
notification, background task, clinical report value, or
behavior-to-severity mapping.

REQ-020: Support 320 logical pixels at 200 percent text scaling and primary
controls of at least 44 logical pixels.

## State Model

```text
SCATTERED
  -> CONVERGED

CONVERGED
  -> NAMING
  -> SET_DOWN (unnamed)
  -> HAND_OFF (nothing now)

NAMING
  -> SET_DOWN (valid text, then text cleared)
  -> HAND_OFF (discard, then text cleared)

SET_DOWN
  -> HAND_OFF

ANY
  -> SAFETY
  -> previous ephemeral state or LEAVE_CARE

ANY
  -> CARE_GATE or LEAVE_CARE
```

## Approved Copy

- convergence: `Your mind opened every tab at once. We only need one.`
- unnamed set-down: `You do not have to name it for it to stop owning this minute.`
- named set-down: `It is set down for now. Letter will not bring it back tomorrow.`
- nothing-now hand-off: `Nothing else is required from this screen.`

## Non-Goals

- saving or resurfacing text tomorrow
- Tomorrow Tray, task list, reminders, deadlines, or priorities
- clearer-day reflection or future-self memory
- determining what the thought means
- treating anxiety, panic, ADHD, depression, or another condition
- breathing instruction, sound, haptics, or voice
- persistence, analytics, API, LLM, notification, or clinical data

## Product Decisions

- One tap is sufficient to create order; holding may never be mandatory.
- Naming one thought is an optional container, not journaling homework.
- `Nothing now` is a successful finite exit.
- P0 forgets the thought by design.
