# Cycle Letters Archive Requirements

Status: approved
Branch: `feature/phase2-personal-care-memory`
Approved together with the remaining Phase 2 scope on 2026-07-28.

## Goal

Turn the currently disabled Letters tab into a private, accessible archive of
completed cycles using only period records, Care check-backs, and reflections
the user actually created.

## Requirements

REQ-001: Enable the Letters navigation tab and open a dedicated archive screen.

REQ-002: A completed cycle begins on one recorded period start and ends the day
before the next recorded period start. The current incomplete cycle is shown
separately and never presented as complete.

REQ-003: Number completed Cycle Letters oldest to newest using only locally
available history. Never fabricate a long-running letter number.

REQ-004: Each archive item shows direct evidence: date range, recorded period
days, Care actions, Better/Same/Worse counts, and whether a reflection exists.
Missing data remains visibly absent.

REQ-005: Detail uses four plain sections: `Cycle timing`, `Care moments`,
`Reflections`, and `What is not recorded`. It does not generate a poetic story,
medical summary, diagnosis, phase claim, or treatment result.

REQ-006: The visual language may suggest bound letters or a shelf, but archive
items remain standard accessible controls with readable dates and labels.

REQ-007: Care records are assigned to cycles by their local calendar date.
Records outside known completed cycles appear under `Not assigned to a
completed cycle` and are not discarded.

REQ-008: Period editing stays in Cycle. Reflection editing/deletion uses the
reflection feature. Archive aggregation itself is read-only and updates from
repositories.

REQ-009: Empty, one-period, storage-error, and deleted-record states are
explicit. No sample records or fake trends appear.

REQ-010: Archive data remains local. Raw angry drafts, boundary-card text,
unsubmitted reflection text, and clipboard contents never appear.

REQ-011: Support Reduced Motion, 320px at 200 percent text, screen readers, and
44px targets.

## Non-Goals

- clinician report, PDF export, DRSP scoring, symptom heatmap, or diagnosis
- AI narrative, cloud sync, sharing, or analytics
- editing period records directly in the archive
- future Phase 3 symptom aggregation
