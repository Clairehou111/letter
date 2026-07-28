# Archive Story And Pattern Views Requirements

Status: proposed
Dependencies: Cycle Letters archive, confirmed health records, reflections,
and personal patterns

## Goal

Evolve the Phase 2 archive into a scannable cycle record with distinct personal,
pattern, and clinical views without hiding evidence in a story.

## Requirements

REQ-001: Each completed cycle provides `Story`, `Pattern`, and `Clinical`
views. The current incomplete cycle remains clearly separate.

REQ-002: Story contains only user-authored reflections, approved future-self
notes, and factual Care memories. Letter must not invent a narrative voice.

REQ-003: Pattern contains confirmed symptom counts, observed Care outcomes,
action history, and confidence or missingness context. It does not diagnose.

REQ-004: Clinical contains confirmed ratings, provenance, functional impact,
and factual Care events in plain tables. Export controls are deferred to the
Cycle and Care Summary feature.

REQ-005: Archive cards show date range, observed period dates, coverage, and
incomplete data. Search and filtering must not expose hidden or deleted data.

REQ-006: Raw sealed drafts, unsaved text, clipboard contents, inferred
symptoms, and generated medical conclusions never appear.

REQ-007: All views update from local repositories and preserve 320px,
large-text, screen-reader, and reduced-motion behavior.

## Non-Goals

- poetic AI narrative
- PDF/CSV export
- diagnosis or phase claims
- cloud sync, sharing, medication history, or analytics
