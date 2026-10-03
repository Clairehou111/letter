# Data, estimates, and reports

Status: Release 2.0 target. The exact Comfort Window rules and report ranges
are in [2.0 requirements](features/release-2.0/requirements.md).

## Records and provenance

Period dates, bleeding flow, symptoms, mood, impact, notes, Care events,
outcomes, reflections, and report selections are local records. The person
can inspect, correct, and delete them. A period's stable ID owns its dated
flow and cycle reflection; symptoms and Care events belong to their own
timestamps. Editing a period must not silently rewrite or delete those
independent records. A period deletion warns when its reflection will go too.
Short, long, variable, adjacent, or incomplete history remains visible even
when an interval is excluded from an estimate. No missing period or symptom is
invented.

The period estimate uses the median of at most six recent eligible
start-to-start intervals, requires at least two, and uses the current 21–45
day eligibility and relative-outlier rules. It is an estimate of recorded
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

Free access includes a limited factual on-screen view of the most recent
three months. Plus can select longer, custom, or all-record ranges and
generate a factual Visit Summary PDF, a raw source-record CSV, or a Clinical
Pattern Report PDF. A preview never grants file generation. Every file uses
the selected range shown before generation; show the local saved path after a
successful save. Previously generated files and local records survive an
entitlement lapse.

Reports distinguish observed dates from estimates, confirmed values from
unconfirmed suggestions, and missing days from zeros. Include provenance and
coverage when interpretation is shown. Notes enter a report only when the
person selects them. Do not infer a clinical score from Care actions, diagnose
PMDD, claim relief or efficacy, or label a modified diary as DRSP. A future
prospective clinical diary requires separate clinical, licensing, and release
approval; it is not a 2.0 promise.
