# Need-Space Safe Cocoon Requirements

Status: approved
Parent feature: `need-space-flow-integration`

## Purpose

Safe Cocoon is the immediate sensory response after a user enters Care through
`I need everyone away.` Its job is to make the Letter screen feel quieter,
more enclosed, and less socially demanding without asking the user to explain,
learn, regulate, or complete an exercise.

The experience is a temporary visual container, not a claim that Letter has
isolated the user from people or changed the phone.

## Confirmed Product Facts

- The product is the Letter Flutter mobile app.
- The Care entrance label is `I need everyone away.`
- The primary user need is an immediate isolated, protected, and safe feeling.
- Letter does not access contacts or send messages.
- Letter must not claim that it blocks people, calls, messages, notifications,
  or activity in other apps.
- The experience must remain finite, low stimulation, usable with one thumb,
  and easy to leave.
- Emotional safety access, Reduced Motion, 320 logical pixels at 200 percent
  text scaling, and 44 logical-pixel touch targets are required.

## Approved Experience

### 1. Open

The first frame presents one quiet, dominant action: `Close the curtain`.
Curtain edges visually frame an open center so the result of the action is
understandable before it is used.

A short downward pull and a single tap on the same control must both be
supported. Holding, precision dragging, or reaching across the screen must
never be required.

The screen must disclose the platform boundary without turning it into the
headline:

`Letter can quiet this screen. It cannot silence calls or other apps.`

### 2. Closing

After one activation, the curtain closes once and resolves into the cocoon.
The transition must be restrained, non-looping, and no longer than 400
milliseconds.

There is no progress score, streak, repeated pull, vibration requirement,
sound requirement, reward burst, or prompt to perform the action again.

With Reduced Motion enabled, the open frame changes directly to the closed
cocoon through an immediate state change or brief opacity transition. Curtain
travel, parallax, scale, and simulated depth are removed.

### 3. Cocoon

The closed state reduces visual detail and presents no form, lesson, breathing
instruction, countdown, or decision that must be made immediately.

Primary copy:

`The door is closed. You are allowed to be unavailable.`

Supporting copy:

`Nothing is required here.`

The cocoon may use a static textile, paper, or layered-curtain treatment
consistent with Letter's visual system. It must not resemble a locked door,
cage, sealed container, restraint, surveillance screen, or emergency service.

The cocoon does not end automatically. Remaining on a static screen is allowed,
but the product must not measure, praise, extend, or reward time spent there.

It offers exactly two stage exits:

- `Prepare words`
- `Nothing else right now`

Both are optional in the sense that the persistent Care back, leave, and safety
controls remain usable without choosing either. `Prepare words` delegates to
the separate session-only boundary card. `Nothing else right now` delegates to
the parent flow's finite hand-off.

## State Model

```text
OPEN
  -> COCOON

COCOON
  -> PREPARE_WORDS_CALLBACK
  -> NOTHING_NOW_CALLBACK

ANY
  -> parent-owned CARE_CHOICES
  -> parent-owned LEAVE_CARE
  -> parent-owned EMOTIONAL_SAFETY_BOUNDARY
```

`CLOSING` is a visual transition, not a state that can trap navigation or
safety controls. Interrupted or disabled animation must resolve deterministically
to `COCOON`.

## Functional Requirements

REQ-001: Opening Safe Cocoon from `I need everyone away.` must present the
`OPEN` state without another questionnaire or setup step.

REQ-002: One tap or one short downward gesture on `Close the curtain` must
reach `COCOON`. The gesture must never be the only path.

REQ-003: The primary curtain control and all navigation and safety controls
must be reachable and operable with one thumb.

REQ-004: The curtain transition must run once, remain restrained, and never
block back, leave, or emotional safety actions.

REQ-005: Reduced Motion must remove spatial curtain travel and reach the same
`COCOON` state and content.

REQ-006: `COCOON` must be a low-stimulation, static resting state with no
required input, countdown, breathing task, lesson, score, streak, or repeated
interaction.

REQ-007: `COCOON` must provide `Prepare words` and
`Nothing else right now`. It must also keep parent-owned back, leave, and
safety controls available without requiring either stage action.

REQ-008: `I may not be safe` must remain available in every state and open the
existing deterministic emotional safety boundary. Dismissing that boundary
must return to the same Safe Cocoon state.

REQ-009: Copy must distinguish the visual cocoon from device-level isolation.
It must not state or imply that Letter has blocked contacts, calls, messages,
notifications, people, networks, or other apps.

REQ-010: The component must not request contacts, recipients, permissions,
message content, health details, reasons, or free text.

REQ-011: Completing or leaving Safe Cocoon must not create a persisted record,
clinical symptom, severity score, effectiveness result, analytics event, or
background task.

REQ-012: Re-entering the component must start at `OPEN`; no prior cocoon state,
duration, or interaction count is restored.

REQ-013: The layout must work at 320 logical pixels with text scaled to 200
percent without clipping, overlap, inaccessible controls, or horizontal
scrolling.

REQ-014: Every interactive target must be at least 44 by 44 logical pixels and
must expose an understandable accessibility label and role.

REQ-015: Color must not be the only state signal. Copy, semantics, focus order,
and contrast must communicate `OPEN`, `COCOON`, and `HAND_OFF`.

REQ-016: Both stage exits must invoke one parent callback exactly once. The
component must not loop back into `OPEN` or `COCOON` as a reward or engagement
prompt.

## Component Boundary

Safe Cocoon owns only:

- the open curtain frame
- one curtain-closing interaction
- the closed low-stimulation cocoon
- the two stage-exit controls
- component-level accessibility and Reduced Motion behavior

The public widget must accept:

- parent-owned `isClosed`
- `onClose`
- `onPrepareWords`
- `onNothingNow`

It must not own navigation, the shared safety sheet, persistence, or the
boundary card. The parent owns `isClosed`, so returning from the boundary card
cannot reopen the curtain accidentally.

## Future And Non-Goals

These items are outside Safe Cocoon and are not facts about the implemented
product:

- boundary-message drafting, copying, sharing, or sending
- contact access, recipient selection, or communication history
- controlling Focus, Do Not Disturb, notifications, calls, messages, or apps
- timers, countdowns, reminders, scheduled resurfacing, or background work
- breathing exercises, meditation lessons, grounding homework, or coaching
- soundscapes, ASMR, required audio, or required haptics
- streaks, rewards, achievements, daily goals, or engagement loops
- journaling, symptom entry, severity inference, diagnosis, or treatment
- storing cocoon use, duration, completion, outcomes, or clinical data
- API, LLM, analytics, notification, or account work
- the parent Need-space flow, Care routing, and final cross-feature integration

## Approved Decisions

- The platform-boundary, primary, and supporting copy are approved.
- The downward pull plus tap alternative is approved.
- Select the final curtain material and color treatment during implementation
  visual review.
