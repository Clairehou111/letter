# Release Acceptance Gates Requirements

Status: proposed; release gate

## Goal

Define evidence required before Letter can be called a native, privacy-safe,
clinically legible release.

## Gates

REQ-001: iOS and Android open the encrypted Drift database, run migrations,
preserve records, and fail closed when cipher support or the key is unavailable.

REQ-002: Encrypted export/import is manually exercised on both platforms with
wrong-key, tampered, cancelled, and restore scenarios.

REQ-003: Target users can enter Care within ten seconds, leave without
reflection, understand the Better/Same/Worse boundary, and report whether each
scene calms, changes, or increases activation.

REQ-004: Users can distinguish candidate symptoms from confirmed values and
same-day ratings from later recall.

REQ-005: Clinicians or qualified reviewers can identify report dates,
provenance, severity, functional impact, missingness, and limits without a
diagnostic promise.

REQ-006: Accessibility, reduced motion, 320px width, 200 percent text,
screen-reader labels, privacy copy, deletion, billing, and store metadata pass
their release checklists.

REQ-007: No release claim uses DRSP wording, diagnostic equivalence, treatment
effectiveness, medication advice, contact access, or cloud health storage
without a separately approved decision.

## Non-Goals

- replacing feature-level automated tests
- treating browser validation as native validation
- using analytics as evidence of clinical benefit
