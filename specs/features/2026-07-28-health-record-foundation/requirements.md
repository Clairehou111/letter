# Confirmed Health Record Foundation Requirements

Status: validated
Dependencies: Phase 1 local repositories and Phase 2 encrypted Care memory

Superseded in part by
`../2026-07-31-unified-record-and-navigation/requirements.md`, which adds
same-day update semantics, day grouping, and explicit episode separation.

## Goal

Make direct, user-confirmed symptom records durable, editable, local, and
traceable without interrupting an acute Care scene.

## Requirements

REQ-001: Today can record one or more user-selected symptoms from a reviewed,
versioned vocabulary covering physical symptoms, mood, energy, and sleep.

REQ-002: Each selected symptom has an explicit severity using visible six-point
anchors: not at all, minimal, mild, moderate, severe, and extreme.

REQ-003: A pain entry may additionally use a separate explicit 0-10 pain scale
and one or more user-selected locations. Pain scores must not be converted to
the six-point symptom scale.

REQ-004: The user may record functional impact directly for work or school,
home responsibilities, relationships, social activity, and sleep. The UI must
show that this is user-reported impact, not an inferred impairment score.

REQ-005: Every saved value stores the experienced date, recorded timestamp,
source provenance, and user confirmation. Initial sources are `same_day` and
`later_recall`; no missing value is imputed.

REQ-006: Users can edit and permanently delete their records. Deletion updates
Cycle Letters and all derived local views.

REQ-007: Records use the encrypted native local database and an in-memory Web
repository. No symptom value, date, note, or inferred state enters logs,
analytics, API calls, or cloud tools.

REQ-008: The foundation provides repository and domain contracts for later
Care Receipt, text, voice, NLP, patterns, and reports. It does not implement
those input channels in this feature.

## Non-Goals

- medication history or medication guidance
- diagnosis, cycle-phase claims, or symptom prediction
- automatic severity from Care behavior, text, or voice
- reminders, cloud sync, or Doctor Mode
