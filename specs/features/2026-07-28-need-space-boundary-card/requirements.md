# Session-Only Boundary Card Requirements

Status: validated
Parent feature: `need-space-safe-cocoon`
Integration feature: `need-space-flow-integration`

## Context

`I need everyone away` should first create a quiet, protected feeling inside
Letter. Once the user is in that cocoon, Letter may optionally help them put a
truthful boundary into words.

The boundary card is not a messaging feature. Letter does not read contacts,
collect a recipient, send anything, open a share or message composer, or claim
that another person has received the boundary. The card only prepares
session-local text and, after a separate explicit action, copies that text to
the operating-system clipboard.

## Goal

Offer at most two calm, truthful boundary templates that the user can adapt to
one bounded period of quiet. Typing and copying remain optional, and the user
can finish the Care flow without using the card.

## Requirements

REQ-001: The boundary card must be an optional step after the protected cocoon.
The parent flow must also provide a direct completion path that requires no
typing, template selection, duration selection, or copying.

REQ-002: Offer no more than these two locally defined templates:

1. `I need some quiet time for the next {duration}. I will not be available to reply.`
2. `I am stepping away for {duration}. Please do not call or message me during that time.`

REQ-003: Templates must be static application copy. Do not use an LLM, API,
remote configuration, user history, diagnosis, symptom inference, or personal
data to create or rank them.

REQ-004: The user may select one of exactly three bounded durations:
`30 minutes`, `2 hours`, or `4 hours`. Do not offer an indefinite duration,
custom date, custom time, recurring schedule, countdown, reminder, or
background timer.

REQ-005: Selecting a template or duration may update the editable text only
inside the active Care session. It must not address a person or infer who the
boundary is for.

REQ-006: The user may edit the selected template as plain text. The field must
accept 1 to 280 non-whitespace characters and must not include a recipient,
contact picker, phone number, email address, relationship label, subject,
attachment, delivery status, or send destination.

REQ-007: The card must not invent or suggest a migraine, illness, diagnosis,
emergency, lack of safety, medical appointment, family event, work obligation,
or any other explanation the user did not provide.

REQ-008: The card must not describe the boundary as sent, delivered, scheduled,
shared, enforced, or seen. Letter cannot know whether another person receives
or follows it.

REQ-009: Copying must occur only after the user taps a clearly labelled
`Copy text` control. Do not automatically copy on template selection, duration
selection, editing, completion, navigation, or app lifecycle changes.

REQ-010: Immediately before or beside `Copy text`, explain:
`Copying puts this text on your device clipboard. It may remain there after you leave Letter.`

REQ-011: After a successful copy, show only a factual acknowledgement such as
`Copied to your device clipboard.` Do not imply sending or delivery.

REQ-012: Letter must not read the existing clipboard. It may only write the
currently visible boundary text after explicit user action. Do not attempt to
clear, monitor, or verify the OS clipboard after the user leaves.

REQ-013: Copying is optional. Provide a visible `Continue without copying`
path after valid text is prepared, and a visible `Discard` path that does not
require valid text.

REQ-014: Completing without copying and discarding are both successful,
non-judgmental outcomes. Neither path may be represented as a failure, missed
task, broken streak, or incomplete Care session.

REQ-015: Boundary-card text is current-session-only inside Letter. It must be
cleared on discard, leaving Care, leaving through the safety boundary, and
reconstruction or re-entry of the Care flow.

REQ-016: The component must not persist the selected template, selected
duration, edited text, copy result, completion, or interaction count. Do not
write them to preferences, files, a database, logs, analytics, crash metadata,
notifications, background tasks, or clinical records.

REQ-017: If the safety boundary is opened and then dismissed, the active
session text may remain so the user does not lose work during that interruption.
If the user leaves Care from the safety boundary, clear the session text before
navigation.

REQ-018: Reconstructing or re-entering the Care flow must start with no prior
user edits and no prior copy acknowledgement. A static default template may be
rendered only after a new in-session selection.

REQ-019: Back, discard, continue, leave-Care, and `I may not be safe` controls
must remain reachable without copying. The integration layer owns the shared
Care navigation and safety boundary.

REQ-020: Do not request contact, SMS, phone, email, notification, calendar,
Focus, Do Not Disturb, accessibility-service, or background permissions.

REQ-021: Do not open a system share sheet, message composer, email composer,
contact picker, deep link, or another application.

REQ-022: Respect Reduced Motion. Template, duration, edit, copy, and completion
states must remain understandable without transition or decorative animation.

REQ-023: Support a 320-logical-pixel viewport at 200 percent text scaling
without clipped text, overlapping controls, or unreachable actions.

REQ-024: All primary interactive targets must be at least 44 by 44 logical
pixels and expose clear screen-reader labels, selected states, and copy-status
announcements.

## State Model

```text
OPTIONAL_ENTRY
  -> TEMPLATE_SELECTED
  -> DURATION_SELECTED
  -> EDITING

TEMPLATE_SELECTED | DURATION_SELECTED | EDITING
  -> COPIED (explicit Copy text only)
  -> HAND_OFF (Continue without copying)
  -> HAND_OFF (Discard, after clearing text)

COPIED
  -> HAND_OFF

ANY
  -> SAFETY
  -> previous ephemeral state or LEAVE_CARE

ANY
  -> CLOSED_COCOON or LEAVE_CARE
```

Copying changes only the acknowledgement state inside Letter. It does not
transfer responsibility for the OS clipboard back to Letter.

## Component Contract

The isolated boundary-card component owns only its presentation and
session-local editing behavior. It must:

- accept a caller-owned `TextEditingController`
- accept callbacks for back and finish
- clear the controller before invoking finish from discard
- never dispose the caller-owned controller
- never own app navigation, safety-sheet routing, persistence, or external
  application actions

The integration layer must clear and dispose the controller at the end of the
Care session and before every leave-Care path.

## Approved Copy

- clipboard disclosure:
  `Copying puts this text on your device clipboard. It may remain there after you leave Letter.`
- copy action: `Copy text`
- copy acknowledgement: `Copied to your device clipboard.`
- private completion: `Continue without copying`
- discard action: `Discard`

## Non-Goals

- contact access, recipient collection, or saved people
- sending, sharing, scheduling, delivery, or read receipts
- opening a share sheet, composer, deep link, or another app
- actual phone isolation, notification silencing, Focus, or Do Not Disturb
- custom or unbounded durations, timers, reminders, or background work
- diagnosis, symptom capture, clinical reporting, or behavior-to-severity data
- LLM, API, analytics, logging, personalization, or persistence
- invented illness, migraine, emergency, safety, or availability explanations
- proving that another person respected the requested boundary

## Product Decisions

- Protected isolation is the primary experience; boundary words are optional.
- Two static truthful templates are enough for P0.
- A duration describes the requested boundary, not a timer Letter enforces.
- The OS clipboard is outside Letter's session-only privacy boundary.
- No typing or copying is required to complete Care.
