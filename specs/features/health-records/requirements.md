# Confirmed health records

Status: current 2.0 feature contract, reconciled with the implemented local
record model. This supersedes the old health-record, NLP candidate, and
unified-record feature slices where they conflict.

## Capture and identity

HR-01. A person explicitly chooses a symptom from a versioned, reviewed local
catalog and chooses one of five labeled intensity anchors: Minimal, Mild,
Moderate, Severe, or Extreme. Absence is represented by no record, not an
automatically assigned zero. No default intensity is saved merely because a
symptom was selected. The current vocabulary is version 3; older stored codes
remain readable during migration.

HR-02. A confirmed rating stores stable ID, symptom code, experienced local
date, original recorded timestamp, updated timestamp, `same_day` or
`later_recall` provenance, explicit user confirmation, vocabulary version,
and any directly selected functional impacts. The impact domains are work or
school, home responsibilities, relationships, social activity, and sleep.
Neither impact nor intensity is inferred from text, Care gestures, mood state,
or time spent in the app.

HR-03. Creating the same confirmed symptom for the same experienced day
updates that day's rating and keeps the original recorded timestamp. A
separate repeated episode requires an explicit future data concept; duplicate
daily rows must not inflate Patterns or reports. Editing and permanent deletion
are available from a visible retrieval path and update all derived local
views. Record dates stay date-only across time-zone changes.

HR-04. Moment check-ins are timestamped, local observations that may appear in
Today's activity or the containing cycle story. They are distinct from
confirmed symptom ratings. A check-in does not create severity, functional
impact, a report fact, or a Comfort Window training day unless it meets the
specific [2.0 evidence rule](../release-2.0/requirements.md). Private Quick
notes, Care reflections, and Cycle Letters are separate authored records;
none is silently converted into another.

Today provides direct mood choices from the versioned catalog, including
Good, Calm, Steady, Energized, Low, Irritable, Anxious, and Physical, with
more states available in a picker. Selection saves one primary mood for the
local date. A later choice replaces the previous same-day primary mood;
save errors are retryable. Symptom details require their own explicit
capture and intensity choice. Today's activity exposes saved check-ins,
confirmed symptom ratings, notes, and factual Care records with a retrieval
path for each item. The old `+ Check in` → Add details/Undo interaction is
superseded by the current Today composition.

## Suggestions and safety

HR-05. Deterministic on-device phrase matching may show an editable candidate
with its source and evidence. It may recognize supported vocabulary, explicit
severity language, and negation, but never saves a candidate as a health
rating. The person accepts, edits, rejects, or leaves it unresolved. An
accepted record still requires an explicit intensity choice; emotional wording
or speech prosody cannot supply one. Unconfirmed Care or note content is never
silently converted into a candidate.

HR-06. `Suicidal thoughts` and `Self-harm` open the region-aware crisis route
instead of an ordinary five-level rating; the interrupted choice is not saved,
scored, analyzed, or exported. `Heart palpitations` opens the physical medical
route for new selections; older stored records remain readable. Safety routes
do not diagnose or replace emergency or clinician care.

HR-07. Routine symptom capture uses the five-level scale. It does not add a
second 0–10 pain score or pain-location field. That older proposal is retired
from this flow; a future dedicated pain diary would need separate clinical
purpose and review. No medication record or guidance is part of this contract.

HR-07A. User-authored text is optional beside structured fields. Text is
never required to save a confirmed rating. A future voice adapter must use an
approved on-device/OS speech path; cloud transcription and background
recording are excluded. Raw audio is not stored by default. A transcript is
shown for edit and saved only by explicit note action. Permission, recording,
cancel, failure, edit, and delete states need a text fallback when voice is
unavailable. Current voice capture is not a release claim until a reviewed
adapter and these states are verified. Neither text nor prosody supplies
severity, diagnosis, or functional impact.

## Local boundary

HR-08. Confirmed records and candidates remain in encrypted native local
storage; the web preview is memory-only. No health value, date, text,
candidate, or derived state enters account metadata, API requests, logs,
crash metadata, analytics, or an AI service. Repository errors keep the
person's input available for retry and do not print private values.

HR-09. Every recorded value in Patterns or a report must link back to a
confirmed source, date, and provenance. Missing days remain missing. `Same
day` and `Later recall` are distinguishable; a retrospectively entered value
cannot be presented as prospectively observed.
