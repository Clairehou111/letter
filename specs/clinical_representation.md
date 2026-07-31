# Twin Matrix Clinical Representation

Status: approved product direction; clinical review pending
Date: 2026-07-31
Canonical clinical policy: `clinical-data-and-reporting.md`

## Purpose

The Twin Matrix is a compact, clinician-readable view of user-confirmed local
records. It supports a rapid review of timing, severity, functional impact,
coverage, and provenance without diagnosing PMS or PMDD.

## Eligibility

Eligible values:

- prospective diary ratings
- same-day user-confirmed symptom ratings
- later-recall ratings with visible provenance
- user-confirmed functional-impact ratings
- factual Care events without an inferred symptom score

Ineligible values:

- Care tap count, duration, pressure, or completion
- moment check-ins
- text or voice candidates that the user did not confirm
- app absence
- mirrored, projected, interpolated, or imputed values
- medication mentions or medication history

## Matrix

The horizontal axis may compare:

- days `-14` through `-1` before a subsequent observed period start
- observed cycle days `1` through `14` after an observed period start

The right side must use actual observations. If no observation exists, the
cell remains blank.

Rows may group reviewed symptom domains for scanability, but every displayed
value must retain traceability to its underlying symptom code, scale, date, and
provenance. Aggregation rules must be documented beside the report and must not
turn counts into severity.

## Header And Legend

The preview and export show:

- `Cyclical Symptom Summary`
- calendar date range
- cycles covered
- generated timestamp
- days with confirmed ratings
- missing days
- provenance legend

Until the clinical review gate is complete, do not use `DRSP`,
`DRSP-compatible`, `standard log`, or equivalent validated-instrument claims.

## Privacy

Raw drafts, private notes, clipboard contents, unresolved candidates, contacts,
and medication mentions are excluded by default. A user may explicitly select a
private-note excerpt only for the separate Cycle and Care Summary flow.

The report may say values were generated from local records. It must not claim
cryptographic authenticity, verification, or zero cloud transit unless the
specific export path can prove those properties.

## Output

The on-device preview and exported representation must match. Missingness and
provenance remain visible in both. The report contains no diagnosis, treatment
recommendation, causal conclusion, or invented clinical severity.
