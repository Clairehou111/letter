# Care Check-Back And Personal Kit Requirements

Status: validated
Branch: `feature/phase2-personal-care-memory`
Approved together with the remaining Phase 2 scope on 2026-07-28.

## Goal

Let the user explicitly record whether one Care action left them `Better`,
`Same`, or `Worse`, and optionally keep that action in a private local Care Kit.

## Requirements

REQ-001: A completed Care hand-off may offer one optional check-back. The acute
flow remains complete even when the user skips it.

REQ-002: The check-back asks one question only: `How is this moment now?` with
exactly `Better`, `Same`, `Worse`, and `Skip`.

REQ-003: No Care record is persisted until the user selects Better, Same, or
Worse. Entry, taps, duration, text, and skipped check-backs are not records.

REQ-004: A persisted record contains only a generated ID, Care mode, stable
action ID and display label, user-selected outcome, occurrence time, and
created/updated timestamps.

REQ-005: After an outcome, offer `Keep in my Care Kit` as an explicit choice.
Never infer that an action worked or pin it automatically.

REQ-006: The Care Kit lists only user-pinned actions. It supports unpinning and
shows direct observed history, for example `Better in 2 of 3 check-backs`.

REQ-007: `Worse` must remain a valid, visible result and must not be reframed as
progress. The UI may offer the relevant safety boundary without diagnosing.

REQ-008: Records live in the encrypted local health database on native devices
and in memory in the Web preview. No health value enters logs, analytics,
crash metadata, API calls, or LLM calls.

REQ-009: Deleting a Care record removes it from counts and the archive. Unpinning
does not delete its check-back history.

REQ-010: Repository failures preserve the UI state and show a generic local
error without printing health values.

REQ-011: Support Reduced Motion, 320px at 200 percent text, screen readers, and
44px targets.

## Data Contract

```text
CareRecord {
  id, mode, actionId, actionLabel,
  outcome: better | same | worse,
  occurredAt, createdAt, updatedAt,
  pinned
}
```

## Non-Goals

- automatic effectiveness scores or behavior-derived outcomes
- reminders, notifications, background check-backs, streaks, or engagement
- free-text symptom logging, clinical severity, or report generation
- cloud sync, analytics, API, or LLM processing
