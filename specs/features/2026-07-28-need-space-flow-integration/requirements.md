# Need-Space Flow Integration Requirements

Status: approved
Branch: `feature/need-space-safe-cocoon`
Base branch: `feature/racing-thoughts-convergence-flow`

## Context

`I need everyone away` currently opens the generic Care response shell. The
user wants this mode to create an immediate sense of protected isolation.
Letter must provide that emotional container without claiming that it silences
notifications, blocks callers, changes system Focus settings, controls another
app, or prevents another person from reaching the user.

This work is split into three specifications so implementation can proceed with
disjoint write scopes:

1. `need-space-safe-cocoon`: the curtain and protected low-stimulation scene
2. `need-space-boundary-card`: optional truthful words that may be copied
3. `need-space-flow-integration`: orchestration, Care routing, shared safety,
   regression coverage, and final hand-off

## Goal

Replace the generic mode with one coherent finite flow:

```text
EXPOSED
  -> CLOSE THE CURTAIN
  -> PROTECTED COCOON
  -> QUIET HAND-OFF
     or OPTIONAL BOUNDARY CARD
  -> QUIET HAND-OFF
```

The first interaction should make the screen quieter and more enclosed.
Nothing after that is mandatory.

## Product Decisions

- Letter creates a symbolic private boundary inside the app, not actual phone
  isolation.
- Closing the curtain is the only required interaction before the protected
  state.
- A tap control must provide the same result as the downward curtain gesture.
- Preparing or copying boundary words is optional.
- Letter does not read contacts, collect a recipient, send a message, or open a
  system share or message composer.
- P0 does not integrate with system Focus or Do Not Disturb settings.
- P0 stores no Care event, duration, free text, copy event, symptom, severity,
  or inferred outcome.
- Boundary-card text exists only during the current widget session.
- `I may not be safe`, back-to-Care, and leave-Care remain available.

## Integration Requirements

REQ-001: Route `CareMode.space` to a dedicated `NeedSpaceFlow` instead of the
generic `CareModeScene`.

REQ-002: The dedicated flow must use the existing Care emotional safety
boundary without adding dynamic or diagnostic safety advice.

REQ-003: The dedicated flow must keep stable back, leave, and safety controls
through cocoon, boundary-card, copy acknowledgement, and hand-off states.

REQ-004: The cocoon stage must expose two optional next steps after closure:
`Prepare words` and `Nothing else right now`.

REQ-005: `Prepare words` opens the session-only boundary card. It must not ask
for a recipient or leave the app.

REQ-006: `Nothing else right now` reaches a quiet final hand-off without
typing, copying, a timer, or another Care mode.

REQ-007: Finishing or discarding the boundary card reaches the same final
hand-off. Copying may show a factual acknowledgement but must not be described
as sending, delivery, communication, or completed boundary-setting.

REQ-008: The final hand-off must offer `Return to Care choices` and
`Leave Care`. It must not autoplay another Care mode.

REQ-009: Back from the boundary card returns to the already closed cocoon.
Back-to-Care or leave-Care clears all session-only boundary text.

REQ-010: Dismissing the safety boundary returns to the same ephemeral state.
Leaving through the safety boundary clears session-only boundary text.

REQ-011: Reconstructing or re-entering the dedicated flow starts with an open
curtain and default boundary-card text generated only from static local copy.

REQ-012: Do not create persistence, API or LLM requests, analytics, logs,
notifications, background work, system-setting changes, contact access, share
actions, or clinical values.

REQ-013: Support Reduced Motion, 320 logical pixels at 200 percent text, screen
reader semantics, and primary controls of at least 44 logical pixels.

REQ-014: Keep the interaction finite and escapable. Do not use streaks,
rewards, engagement counters, forced countdowns, guilt, or a completion score.

## Parallel Component Contracts

### Safe Cocoon

The isolated cocoon implementation owns:

- `apps/mobile/lib/features/care/presentation/safe_cocoon_stage.dart`
- `apps/mobile/test/safe_cocoon_stage_test.dart`
- its own golden files

It must expose a public widget with callbacks for:

- `onClose`
- `onPrepareWords`
- `onNothingNow`

The integration layer owns and passes an `isClosed` value so returning from the
boundary card cannot reopen the curtain accidentally.

It must not own app navigation, the safety sheet, persistence, or the boundary
card.

### Boundary Card

The isolated boundary-card implementation owns:

- `apps/mobile/lib/features/care/presentation/need_space_boundary_card.dart`
- `apps/mobile/test/need_space_boundary_card_test.dart`
- its own golden files

It must expose a public widget with callbacks for:

- `onBack`
- `onFinish`

It must accept a caller-owned `TextEditingController`. The integration layer
clears and disposes that controller; the child must not dispose it. This makes
every Care-leave path independently testable. The implementation may use
Flutter's clipboard API only after an explicit user tap.

### Integration

The main agent owns:

- `apps/mobile/lib/features/care/presentation/need_space_flow.dart`
- `apps/mobile/lib/features/care/presentation/care_screen.dart`
- `apps/mobile/test/need_space_flow_test.dart`
- `apps/mobile/test/care_screen_test.dart`
- canonical and feature documentation

The main agent reviews both child implementations before integration and owns
all cross-feature validation.

## Non-Goals

- actual isolation from people, calls, notifications, or other apps
- contact selection or contact permission
- sending, sharing, or opening another app
- system Focus or Do Not Disturb control
- saved people, messages, templates, durations, or Care Kit actions
- countdowns, notification reminders, or background timers
- clearer-day check-back, effectiveness tracking, or future-self memory
- behavior-to-symptom or behavior-to-severity mapping
- diagnosis, treatment, or emergency response
