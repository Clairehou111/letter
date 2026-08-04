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

REQ-004A: Add details opens a focused, repeatable two-step interaction:
choose one symptom, confirm its explicit intensity, then add another symptom or
continue to shared date, provenance, pain, and impact context. Choosing a
symptom must not silently assign a default intensity.

REQ-004B: Today has no separate promoted entrance for creating a symptom
record. Confirmed symptom details are created from quick check-in or a
user-chosen Care recovery receipt, while saved symptom activity remains
retrievable and editable.

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

REQ-010A: Confirmed symptom capture uses vocabulary version 2 derived from the
reviewed complaint corpus. It distinguishes commonly expressed experiences
that the original vocabulary conflated, including crying, hopelessness,
anhedonia, mood swings, rage, panic attacks, brain fog, fatigue, distinct sleep
changes, distinct pain locations, appetite and digestive changes, hot flashes,
and palpitations. Existing stored codes remain readable.

REQ-010B: `Suicidal thoughts` and `Self-harm` are first-class safety signals,
not ordinary symptoms on the six-point severity scale. Selecting either
immediately opens the region-aware crisis boundary. Letter does not infer,
score, save, analyze, or export that selection from this interruption.
`Heart palpitations` is a physical safety signal rather than a routine Care
interaction or new six-point rating; selecting it opens the physical medical
boundary. Existing historical palpitation records remain readable.

## Letters

REQ-011: Letters provides canonical `Cycles`, `Patterns`, and `Reports`
destinations. A cycle has at most one new editable cycle reflection. Cycle
Story presents that reflection first, then groups repeated Care actions with
expandable factual event detail. Reflections saved under the earlier per-Care
model remain readable as nested Care notes under their originating actions.

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
- treating a crisis signal as a routine reportable symptom rating
