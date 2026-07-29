# Period Logging And History Requirements

Status: validated
Branch: `feature/period-logging-history`

## Context

Letter must first work as a trustworthy period tracker. This feature creates
the first readable health records in the product, so it also resolves the
previously deferred encrypted local database decision.

The feature records observed bleeding intervals only. Prediction, symptom
logging, spotting, flow intensity, fertile-window estimates, and clinical
interpretation remain separate features.

## Goal

Let a user start and end a period, add a past period, and correct or delete
history without an account or network connection.

## Requirements

REQ-001: Make the `Cycle` tab a working first-class destination.

REQ-002: Let the user start a period on today or add a past period with an
explicit start date and optional end date.

REQ-003: Let the user end the current open period using today or another valid
past date.

REQ-004: Let the user edit the start and end dates of an existing period.

REQ-005: Let the user delete an existing period only after a clear
confirmation. Deletion must remove the local record rather than hide it.

REQ-006: Store period boundaries as date-only local calendar values. Traveling
across time zones must not move a recorded day.

REQ-007: Reject future dates, an end before its start, overlapping intervals,
and more than one open period. Show a specific recoverable error.

REQ-008: Do not impose an arbitrary maximum period length. Unusual data should
remain editable and available for later clinical context.

REQ-009: Do not treat spotting as a period start. Spotting is outside this
feature and must not be silently inferred from period records.

REQ-010: Keep period records on device. Production iOS and Android storage must
use an encrypted SQLite database whose key is generated on device and kept in
platform secure storage.

REQ-011: Do not send period dates to the API, analytics, logs, crash messages,
or cloud tools.

REQ-012: Web builds are development previews only. They may use an
in-memory repository but must not persist readable health records in browser
storage.

REQ-013: Separate the domain repository contract from the database
implementation so tests and development previews can use an in-memory
repository.

REQ-014: Show explicit loading, empty, populated, save-error, and retry states.
Do not flash an empty history while secure local storage is opening.

REQ-015: Use familiar date and edit controls inside Letter's modern
correspondence visual language. Metaphor must not obscure the actual dates or
actions.

REQ-016: Keep all primary touch targets at least 44 logical pixels and keep the
flow operable at 320 logical pixels wide with 200 percent text scaling.

REQ-017: Do not calculate cycle predictions in this feature. The saved
intervals become the source data for the next roadmap feature.

REQ-018: Preserve deterministic ordering, newest start date first, and stable
record identifiers across edits.

## Data Model

Each period record contains:

- stable local identifier
- start local date
- optional inclusive end local date
- created timestamp
- updated timestamp

Timestamps support local record management only. They are not period dates and
must not be exposed as clinical observations.

## Non-Goals

- cycle length, next-period, or fertile-window prediction
- spotting or flow-intensity logging
- symptoms, medication, mood, pain, energy, or notes
- account synchronization or backup
- report export
- server APIs
- migration from the discarded TypeScript prototype

## Product Decisions

- An open interval means the user has recorded a start but not an end.
- One open interval is allowed.
- A new interval cannot overlap an existing open or closed interval.
- Date validation uses the user's current local calendar day at action time.
- Web preview data resets when the app process/page is reset.
- Native encryption availability must fail closed; Letter must not silently
  open an unencrypted health database.
