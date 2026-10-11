# Data, estimates, and reports

Status: Release 2.0 target. The exact Comfort Window rules and report ranges
are in [2.0 requirements](release-2.0/requirements.md).

## Records and provenance

Period dates, bleeding flow, symptoms, mood, impact, notes, Care events,
outcomes, reflections, and report selections are local records. The person
can inspect, correct, and delete them. A period's stable ID owns its dated
flow and cycle reflection; symptoms and typed facts preserve their own
experienced dates and frozen write-time evidence. Editing a period must not silently rewrite or delete those
independent records. A period deletion warns when its reflection will go too.
Short, long, variable, adjacent, or incomplete history remains visible even
when an interval is excluded from an estimate. No missing period or symptom is
invented.

The formal period estimate uses the median of at most six recent eligible
start-to-start intervals, requires at least two, and uses 15–90-day quality
bounds plus relative-outlier filtering. The 21–45-day band is a review cue,
not automatic exclusion. A one-interval orientation estimate is labeled
limited and cannot feed health insights. It is an estimate of recorded
period timing, not fertility, ovulation, phase, or diagnosis. Low confidence,
insufficient history, and a passed estimated range are stated plainly.

A confirmed symptom or mood check-in can be evidence for a Comfort Window.
Flow, Care use, and note-only days cannot train it. The current cycle never
trains its own forecast. Each derived result retains algorithm version,
source cycle IDs, coverage, support, lift, confidence, and projected range.
Edits recompute the result and any pending reminder. A candidate from local
text matching becomes reportable only after explicit user confirmation.
Care gestures never imply severity, impact, or treatment response.

## Reporting boundary

RH-042 supersedes the earlier paid-export split. Any range can be previewed
for free. Raw source-record CSV is free for every range, including All records.
A factual Visit Summary PDF covering the recent three calendar months is
free. Longer or custom Visit Summary PDFs and Clinical Pattern Report PDFs
require paid Plus access at file generation. A no-card Plus preview does not
grant those paid PDF capabilities. Every file uses the selected range and
fields shown before generation; show the local saved path after a successful
save. Previously generated files and local records survive an entitlement
lapse. Factual programme records, manual BBT and factual Care memory have no
feature upsell.

Known categories and fields are declared explicitly; newly introduced health
categories remain excluded until their consent and serialization are defined.
Medication, supplements, birth-control methods, emergency contraception,
manual BBT, significant context events, notes/reflections and unexpected
observations default off. Notes and reflections additionally require
individual source selection. Date filtering uses the frozen experienced date.
Undated legacy text is excluded by default and, if explicitly selected, is
labeled `Date unknown`; save timestamps never supply an experience date.
CSV preserves original/current timing, save/update timestamps, available zone
evidence, original units and duration categories without guessed midpoints.
Product episode, dated version and actual use rows remain distinct. Archived
episodes preserve historical use; a schedule never implies a taken dose.
The Clinical PDF keeps its existing narrower period/symptom/Moment/Care/note
contract and algorithms; additional typed facts belong in the factual Visit
Summary or raw CSV. Drafts, audio and programme form snapshots are excluded.

Reports distinguish observed dates from estimates, confirmed values from
unconfirmed suggestions, and missing days from zeros. Include provenance and
coverage when interpretation is shown. Notes enter a report only when the
person selects them. Do not infer a clinical score from Care actions, diagnose
PMDD, claim relief or efficacy, or label a modified diary as DRSP. A future
prospective clinical diary requires separate clinical, licensing, and release
approval; it is not a 2.0 promise.
