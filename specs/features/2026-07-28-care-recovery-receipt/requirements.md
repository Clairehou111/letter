# Care-Linked Recovery Receipt Requirements

Status: proposed
Dependencies: confirmed health-record foundation and Phase 2 Care records

## Goal

Connect an explicitly saved Care moment to structured health data later, while
keeping the acute interaction free of forms and interpretation.

## Requirements

REQ-001: A receipt can begin only from a user-persisted Care record. Skipped
check-backs and unsaved Care sessions cannot generate a receipt.

REQ-002: The entry point is user-selected from Letters, Care history, or the
completed hand-off. No automatic notification assumes that the user is ready.

REQ-003: The receipt asks, in order, which signal was present, its explicit
severity, what it interfered with, and which optional physical signals were
also present. The user may skip every step.

REQ-004: The Care mode may preselect a visible candidate, but the candidate is
never confirmed until the user accepts or edits it. The app must allow
`something else` and `I do not remember`.

REQ-005: One primary event can be completed in under 30 seconds. The user can
leave and return without silently saving partial answers.

REQ-006: A rating entered on the same local calendar day is `same_day`; a later
entry is `later_recall`. The report must preserve this distinction.

REQ-007: The receipt stores only confirmed values in the health-record
repository. It never maps tap count, duration, haptics, draft language, or
Care-mode selection to severity.

REQ-008: No LLM or cloud request is needed. Raw sealed drafts are excluded
unless the user explicitly selects an excerpt in a later feature.

## Non-Goals

- acute symptom forms
- automatic reminders or cycle-day assumptions
- medication records or advice
- diagnostic scoring or DRSP claims
