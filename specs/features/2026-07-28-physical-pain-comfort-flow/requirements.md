# Physical-Pain Comfort Flow Requirements

Status: validated
Branch: `feature/phase2-personal-care-memory`
Approved together with the remaining Phase 2 scope on 2026-07-28.

## Goal

Give a person in physical discomfort one low-effort, symptom-appropriate
comfort interaction while keeping new, unusual, severe, changing, or
function-limiting symptoms on a direct medical route.

## Requirements

REQ-001: Replace the generic physical Care shell with a dedicated flow.

REQ-002: Start with five large choices: `Cramps or back pain`,
`Headache or migraine`, `Nausea or bloating`, `Breast, muscle, or joint
discomfort`, and `Completely drained`. Choosing the nearest option is optional.

REQ-003: Keep `This is new, unusual, or severe` fixed and available throughout.
It opens the existing deterministic physical safety boundary.

REQ-004: Each path produces useful feedback after one tap. Cramps/back pain
warms and softens a knot; headache immediately enters a dark, still state;
nausea/bloating settles a disturbed surface; breast/muscle/joint discomfort
loosens a thread; depletion closes visual noise.

REQ-005: Tracing or swiping may enrich an interaction but cannot be required.
Every path has a one-tap automatic-completion alternative.

REQ-006: After the transformation, offer only familiar, non-ingestible comfort
actions appropriate to the selected path, such as getting heat, dimming the
room, changing position, using familiar support, or resting.

REQ-007: Do not claim that animation, haptics, sound, heat, darkness, rest, or
another comfort action treats pain or is safe for every person.

REQ-008: Do not provide medication names, doses, intervals, interaction advice,
supplement advice, diagnosis, or a universal countdown.

REQ-009: Completing a comfort action may emit an in-memory completion callback
for the optional check-back feature. Merely entering, selecting a pain type, or
interacting with the scene creates no persisted record.

REQ-010: Back, leave Care, and medical safety remain available in every state.
No completion path autoplays another Care mode.

REQ-011: Headache mode has no sound, haptics, flashing, pulsing, or decorative
motion. All modes respect Reduced Motion.

REQ-012: Support 320 logical pixels at 200 percent text and controls of at least
44 logical pixels.

REQ-013: Create no symptom severity, pain rating, medication record, clinical
value, analytics event, log, API request, LLM request, notification, or timer.

## State Model

```text
CHOOSE_TYPE -> COMFORT_SCENE -> TRANSFORMED -> PRACTICAL_HANDOFF
ANY -> MEDICAL_BOUNDARY -> previous state | LEAVE_CARE
ANY -> CARE_GATE | LEAVE_CARE
```

## Non-Goals

- clinical pain or symptom logging
- medication or supplement guidance
- saved personalized actions before the user creates a Care record
- background timers, notifications, audio, or device setting control
- diagnosing dysmenorrhea, migraine, PMDD, or another condition
