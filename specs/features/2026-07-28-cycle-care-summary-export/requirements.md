# Cycle And Care Summary Export Requirements

Status: proposed
Dependencies: Cycle Letters archive, confirmed health records, Care outcomes,
and encrypted local export/import

## Goal

Give normal Letter users a truthful, clinician-readable summary of their local
history without calling it a diagnosis or a validated clinical instrument.

## Requirements

REQ-001: The report covers a user-selected date range and shows period dates,
cycle day when available, and prediction ranges separately from observations.

REQ-002: It includes only user-confirmed symptoms, severity, pain ratings,
functional impact, Care events, Care outcomes, and user-selected notes.

REQ-003: Every report value shows provenance: prospective, same-day, later
recall, or factual Care event. Missingness and unrated Care remain visible.

REQ-004: Raw angry drafts, unsaved text, clipboard contents, unresolved NLP
 candidates, medication data, contacts, and inferred causal statements are
 excluded by default and cannot be silently included.

REQ-005: The user previews the complete report before creating a local PDF or
CSV. Export is explicit and may use the operating system share surface.

REQ-006: The report uses direct clinical headings, tables, legends, dates, and
plain language. Letter styling may be restrained but cannot obscure evidence.

REQ-007: The report states that it is a user-recorded summary and does not
diagnose PMS, PMDD, pain conditions, or another disorder.

## Non-Goals

- DRSP or DRSP-compatible claims
- automated diagnosis or clinician conclusions
- cloud report generation
- medication history or treatment-effect claims
