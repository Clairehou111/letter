# Heavy And Low Presence Flow Requirements

Status: validated
Branch: `feature/heavy-low-presence-flow`
Base branch: `feature/angry-impulse-buffer`

## Context

The five-way Care shell proves that `I feel heavy` is understandable, but its
current one-tap transformation is only a placeholder. A user who is crying,
empty, slowed down, or unable to concentrate should not need to read a lesson,
hold a control, complete breathing instructions, or make several choices before
the interface responds.

The user approved this scope by asking to start after the proposed boundary:
one-tap light, optional two-minute presence, no more than three low-burden
messages, persistent exit and safety controls, and no fabricated personal Care
Kit, contact, future-self note, or clinical record.

## Goal

Let one small input create a clear, calm response, then offer optional presence
and one practical hand-off without promising recovery or maximizing time in the
app.

## Requirements

REQ-001: Replace the generic heavy shell with a dedicated
`Dim light -> Awake light -> Optional presence -> Practical hand-off` flow.

REQ-002: The first screen must contain one dim focal light in an otherwise quiet
scene. One tap wakes it immediately. A continuous hold, swipe, typing, audio, or
reading is not required.

REQ-003: Waking the light must create an obvious visual state change and reveal
one short protective line. The control frame, navigation, and safety action must
remain stable.

REQ-004: Do not claim that the light changes mood, treats depression, regulates
the nervous system, or proves the user is improving.

REQ-005: After the light wakes, offer no more than three bounded protective
lines, one at a time. The user advances explicitly and may stop after any line.
Do not use an infinite feed or autoplay into another Care mode.

REQ-006: Generic copy must avoid arguing, teaching, forced gratitude, biological
causality, guaranteed recovery, and deadlines for feeling better.

REQ-007: Offer `Stay with me for 2 minutes` as an optional finite presence
interval. Starting it must be explicit and must not be required to finish the
flow.

REQ-008: During presence, no input is required. Show elapsed or remaining time,
allow `End early`, and complete at exactly two minutes using an injected
monotonic elapsed-duration source in tests.

REQ-009: The two-minute interval must remain local and foreground-only. Do not
schedule notifications, background work, alarms, or server timers.

REQ-010: After presence completes or ends early, show one practical hand-off:
`Put the phone down for a moment`. The user may return to the Care choices or
leave Care immediately.

REQ-011: Keep `I may not be safe` visible during dim, awake, message, presence,
and hand-off states. It must open the existing deterministic emotional safety
boundary and interrupt the normal flow.

REQ-012: Keep back-to-Care and leave-Care controls available throughout. Do not
hide exit behind completion.

REQ-013: Respect reduced motion. Use a stable lit state instead of pulsing or
spatial animation when animations are disabled. All state information must
remain available in text and semantics.

REQ-014: Support 320 logical pixels at 200 percent text scaling and primary
controls of at least 44 logical pixels.

REQ-015: Do not show or imply a saved Care Kit, trusted person, previous
outcome, clearer-self note, personalized quote, or cycle-aware recommendation.

REQ-016: Do not persist a Care event, mood, symptom, severity, timer result, or
completion state. Reconstruction starts a fresh dim-light scene.

REQ-017: Do not create analytics, API, LLM, clinical report, or
behavior-to-severity data.

REQ-018: Do not add sound, haptics, voice, medication guidance, breathing
protocols, crisis diagnosis, or external device-control integration.

## State Model

```text
DIM
  -> AWAKE
  -> MESSAGE_2
  -> MESSAGE_3
  -> HAND_OFF

AWAKE | MESSAGE_2 | MESSAGE_3
  -> PRESENCE (0:00 to 2:00)
  -> HAND_OFF (complete or end early)

ANY
  -> SAFETY
  -> previous state or LEAVE_CARE

ANY
  -> CARE_GATE or LEAVE_CARE
```

The message sequence is finite and ephemeral. Returning to this mode creates a
new `DIM` state.

## Approved Generic Copy

1. `You do not have to become okay all at once.`
2. `Nothing needs to be solved from this minute.`
3. `One small input was enough. You can stop here.`

These lines are bounded fallback copy, not personalized memory.

## Non-Goals

- diagnosing depression, suicidality, PMDD, or another condition
- proving that the state will pass or assigning a biological cause
- saved Care Kit actions or named contacts
- clearer-day notes or cross-cycle memory
- check-back, effectiveness rating, or symptom logging
- clinical reporting or severity inference
- sound, haptics, voice, or background timers
- system brightness, focus mode, messaging, or other external integration
- native persistence or schema changes

## Product Decisions

- The reward is that almost no effort creates a visible response.
- Presence is offered, never required.
- The app does not earn success from keeping the user for two minutes.
- Generic support stays finite until user-authored memory has its own feature.
