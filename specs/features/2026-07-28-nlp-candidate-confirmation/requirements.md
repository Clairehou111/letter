# NLP-First Candidate Confirmation Requirements

Status: in_progress
Dependencies: health-record foundation, Care Receipt, and text/voice capture

## Goal

Turn natural language into editable suggestions without allowing NLP or LLM
output to become a health record by itself.

## Requirements

REQ-001: Deterministic local rules handle known symptom vocabulary, negation,
dates, pain locations, and explicit severity phrases before any optional AI.

REQ-002: Each candidate stores its source, evidence span or source reference,
confidence as a displayable suggestion state, and unresolved/accepted/edited/
rejected status. Confidence is not clinical severity.

REQ-003: Candidates are shown in a review surface where the user can accept,
edit, reject, or leave each item unresolved. Only accepted or edited values
can enter the health-record repository.

REQ-004: Rules and LLMs may not assign severity from emotional intensity,
interaction behavior, writing length, or speech prosody. They may only suggest
that the user review a field.

REQ-005: LLM use is optional and requires cloud tools enabled, a minimized
payload preview, per-request approval, and an API contract that does not retain
or log the request body. Local rules remain the complete fallback.

REQ-006: Sealed angry drafts are excluded by default. Processing an excerpt
requires explicit user selection and preview.

REQ-007: NLP and LLM output cannot decide emotional or medical safety, diagnose,
state causality, fill missing days, or create medication records.

## Non-Goals

- mandatory LLM access
- hidden sentiment scores
- automatic report inclusion
- causal relationship or hormone interpretation
