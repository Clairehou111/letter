# Personal Patterns And Support-Action Matching Requirements

Status: proposed
Dependencies: health records, Care outcomes, Care Kit, and Cycle history

## Goal

Show cautious, user-auditable repetition across cycles and return previously
chosen support actions without making causal or treatment claims.

## Requirements

REQ-001: A pattern uses only user-confirmed symptom records, functional-impact
records, Care outcomes, period dates, and user-authored reflections.

REQ-002: The product shows a pattern only when at least two comparable records
exist and displays the count and covered dates. It never fills missing days.

REQ-003: Comparisons use observed calendar dates, cycle days, or the same Care
mode. The app does not claim a menstrual phase or hormone cause.

REQ-004: A returned action must be user-pinned or explicitly reported in prior
Care history. Matching is based on selected context, not a hidden distress
score.

REQ-005: Results use factual language such as `Better in 2 of 3 check-backs`.
They must show when the user marked an action `Worse` or `Same`.

REQ-006: Users can dismiss, unpin, edit, or delete the source record. Derived
patterns update immediately and never become independent health records.

REQ-007: Generic comfort content remains clearly separate from personal
history. No pattern is called a treatment, remedy, prevention, or guarantee.

## Non-Goals

- diagnosis or symptom prediction
- automatic cycle-phase or PMDD-window claims
- medication or contact features
- server-side personalization or analytics
