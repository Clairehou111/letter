# Text And On-Device Voice Capture Requirements

Status: in_progress
Dependencies: confirmed health-record foundation

## Goal

Let users describe a symptom in ordinary language without forcing a checklist,
while keeping capture local and confirmation explicit.

## Requirements

REQ-001: Direct logging accepts optional user-authored text alongside
structured fields. Text is never required to save a structured record.

REQ-002: Voice capture uses the operating system or an approved on-device
speech-to-text path. Cloud transcription is out of scope for this feature.

REQ-003: Raw audio is not stored by default. A transcript is shown for review
and is stored only when the user explicitly saves it as a note.

REQ-004: Transcripts and notes remain local and are excluded from analytics,
logs, API requests, and reports unless the user explicitly selects an excerpt
for a later report.

REQ-005: The UI provides clear microphone permission, recording, cancel,
transcription, edit, and delete states. If voice is unavailable, text remains
fully usable.

REQ-006: Capture does not infer symptoms, severity, safety, diagnosis, or
functional impact. Candidate extraction belongs to the separate NLP feature.

REQ-007: Text and transcript limits prevent unbounded local records and remain
usable with accessibility text scaling.

## Non-Goals

- cloud speech services
- automatic clinical extraction
- raw audio archive
- background recording or always-on listening
- medication or contact features
