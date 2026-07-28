# Five-Way Care Entrance And Finite Reward Shell Requirements

Status: approved
Branch: `feature/five-way-care-shell`
Base branch: `feature/today-cycle-context`

## Context

Care currently exists as a four-choice prototype bottom sheet inside Today.
It uses generic actions and implies that saved people and personal plans may
already exist. The approved Care system instead defines five experiential
entrances and a finite interaction grammar.

The dedicated angry, heavy, racing-thoughts, need-space, and physical-pain
features remain separate roadmap items. This feature establishes their shared
navigation, interaction contract, and honest placeholder boundary.

## Goal

Make Care a real primary destination where a distressed user can identify the
closest current state, receive immediate visible feedback, reach one bounded
hand-off, and leave without entering an infinite or misleading flow.

## Requirements

REQ-001: Make Care the fourth working primary navigation destination. Today's
`Open Care` action and the bottom Care tab must open the same destination.

REQ-002: Present exactly five visible, text-labeled entrances:
`I want to explode`, `I feel heavy`, `My mind won't stop`,
`I need everyone away`, and `My body hurts`.

REQ-003: Do not infer, preselect, rank, or automatically open a Care mode from
cycle day, prediction, Today state, or other behavior.

REQ-004: Selecting an entrance must immediately open its finite scene without
an additional confirmation screen.

REQ-005: Every scene must implement the shared shell:
`Name -> Respond -> Transform -> Protect -> Hand off -> Exit`.

REQ-006: The first focal action must produce immediate visible feedback. The
interaction must remain understandable with sound and haptics unavailable.

REQ-007: Each scene may show at most one protective line in this shell. It must
validate or create space without teaching, diagnosing, promising recovery, or
claiming a therapeutic mechanism.

REQ-008: Each scene must end with one mode-specific real-world hand-off and a
`Not now` exit. Completing either action returns to the Care gate instead of
autoplaying another mode.

REQ-009: Keep an explicit close control available before and after the focal
interaction. No scene may require completion.

REQ-010: Keep a visible `I may not be safe` route on emotional Care scenes. It
must stop the normal interaction and state honestly that locale-aware crisis
routing is not configured in this shell.

REQ-011: Physical Care must instead keep a visible
`This is new, unusual, or severe` route. It must stop the normal interaction
and direct the user away from the Care scene toward medical assessment without
diagnosing or giving medication advice.

REQ-012: Respect reduced-motion. Meaning may not depend on movement, sound,
haptics, repeated tapping, holding, swiping, pressure, or device sensors.

REQ-013: Use stable dimensions and controls of at least 44 logical pixels.
Support 320 logical pixels at 200 percent text scaling without overlap.

REQ-014: Do not show a streak, score, timer presented as active when it is not,
coin, feed, failure state, engagement reward, or distress intensity.

REQ-015: Do not persist Care selection, interaction count, state, outcome,
clinical candidate, draft, boundary message, pain, medication, or analytics.

REQ-016: Do not map interaction behavior to clinical severity or include it in
history or reports.

REQ-017: Do not imply that a personal Care Kit, trusted person, saved action,
future-self note, or prior outcome exists.

REQ-018: Keep the five mode-specific implementations outside this feature:
Shatter and 24-hour sealing, timed presence, Tomorrow Tray, editable boundary
messages, physical symptom routing, check-backs, and personal memory.

## Shell Copy

| Entrance | Focal action | Protective line | Hand-off |
| --- | --- | --- | --- |
| I want to explode | `Put the force here` | `Nothing has to leave this screen.` | `Pause the decision for now` |
| I feel heavy | `Wake one light` | `Nothing needs to be solved from this minute.` | `Put the phone down for a moment` |
| My mind won't stop | `Bring it to one point` | `The rest can wait outside this minute.` | `Choose one thing, or nothing now` |
| I need everyone away | `Close the curtain` | `You are allowed to be unavailable.` | `Take a quiet boundary now` |
| My body hurts | `Make the screen quieter` | `Comfort first. You do not need to explain it.` | `Get one familiar comfort` |

## Non-Goals

- completed therapeutic or medical Care modes
- haptics, sound, voice, sensors, or native integrations
- a working 20-second Shatter sequence
- 24-hour draft storage or sealing
- countdowns or background timers
- message composition, sharing, or focus-mode control
- clinical triage, emergency-number lookup, or diagnosis
- Care persistence, reports, personalization, or analytics

## Product Decisions

- Care is a primary app destination, not a hidden Today modal.
- This shell validates entrance comprehension and finite interaction structure.
- Honest absence is preferable to showing fabricated personal support.
- The shell's transformation demonstrates agency, not treatment efficacy.
