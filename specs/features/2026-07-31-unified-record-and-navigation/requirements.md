# Unified Record And Navigation Requirements

Status: approved
Date: 2026-07-31

## Goal

Make every apparent recording action fast, persistent, visible, and traceable
while giving Today, Cycle, Care, Letters, and the three signature views one
consistent ownership model.

## Navigation

REQ-001: Primary navigation order is `Today`, `Cycle`, `Care`, `Letters`, and
`You`. Today is the initial destination and Care is the central destination.

REQ-002: Today owns current context, quick check-in, and Today's activity.
Cycle owns period history and date context. Care owns acute support. Letters
owns cycle stories, cross-cycle patterns, and reports.

## Check-In And Activity

REQ-003: The header action is `+ Check in` and opens the state selector directly
without an intermediate action menu.

REQ-004: Selecting Good, Steady, Energized, Low, Irritable, or Physical saves a
timestamped local moment check-in immediately and offers Add details and Undo.

REQ-005: Moment check-ins appear in Today's activity and the containing cycle
Story. They are excluded from clinical severity, symptom patterns, and reports.

REQ-006: Today's activity also exposes confirmed symptom ratings, private notes,
and factual Care records. Every saved item has a visible retrieval path.

## Health Record Integrity

REQ-007: Confirmed symptom history is grouped by experienced day and containing
cycle in user-facing views.

REQ-008: Creating the same confirmed symptom for the same experienced day
updates the existing daily rating instead of creating an accidental duplicate.
The original recorded timestamp is retained and the updated timestamp changes.

REQ-009: A repeated timestamped episode is a separate explicit concept and is
never inferred from duplicate daily rows. Episode counts do not become clinical
severity.

REQ-010: Pattern counts use distinct confirmed daily symptom ratings and cannot
be inflated by accidental duplicates.

## Letters

REQ-011: Letters provides canonical `Cycles`, `Patterns`, and `Reports`
destinations. Cycle Story places each reflection with its originating Care
moment and exposes every reflection in that cycle.

REQ-012: Spectrum Log is the primary Patterns visualization and uses only
confirmed records anchored to observed cycles. It exposes coverage and
missingness and is not labeled hormonal.

REQ-013: Twin Matrix is available from Reports and the summary preview. It uses
only actual confirmed observations, shows missing cells, and does not use
DRSP-compatible or medication language.

## Gravity Horizon

REQ-014: Gravity Horizon remains a first-viewport Today signature and visualizes
cycle timing, prediction range, confidence, and today. It does not predict the
user's energy, mood, symptoms, or diagnosis.

## Privacy And Accessibility

REQ-015: All new records remain in the encrypted native local store and
in-memory Web store. No health value, state, date, or free text enters analytics
or logs.

REQ-016: All affected surfaces support 320 logical pixels, large text, screen
readers, reduced motion, empty states, storage failures, and 44-pixel targets.

## Non-Goals

- hormone measurement or phase-based state inference
- diagnosis, DRSP equivalence, or medication history
- cloud synchronization
- automatic conversion of check-ins or Care behavior into symptom severity
