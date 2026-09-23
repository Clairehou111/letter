# Deterministic Candidate Confirmation Requirements

Status: in_progress; former optional-LLM path superseded by the permanent no-AI product constraint
Dependencies: health-record foundation, Care Receipt, and text/voice capture

## Goal

Use deterministic on-device rules to match known phrases and user selections to
editable candidates. No AI reads, rewrites, summarizes, suggests from, or
interprets health records. Candidate matches never become health records by
themselves.

## Requirements

REQ-001: Deterministic local rules handle explicitly supported symptom phrases,
negation, dates, pain locations, and explicit severity phrases. There is no AI
or cloud-processing path.

REQ-002: Each candidate stores its source, evidence span or source reference,
confidence as a displayable suggestion state, and unresolved/accepted/edited/
rejected status. Confidence is not clinical severity.

REQ-003: Candidates are shown in a review surface where the user can accept,
edit, reject, or leave each item unresolved. Only accepted or edited values
can enter the health-record repository.

REQ-004: Rules may not assign severity from emotional intensity, interaction
behavior, writing length, or speech prosody. They may only surface a candidate
for user review.

REQ-005: Candidate matching runs on-device and deterministically. Health records,
notes, transcripts, and excerpts are not sent to AI services or cloud
processing.

REQ-006: Sealed angry drafts are excluded by default. Processing an excerpt
requires explicit user selection and preview.

REQ-007: Candidate rules cannot decide emotional or medical safety, diagnose,
state causality, fill missing days, or create medication records.

## Non-Goals

- AI/LLM processing or any network service for candidate matching
- hidden sentiment scores
- automatic report inclusion
- causal relationship or hormone interpretation
