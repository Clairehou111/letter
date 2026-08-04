# Letter Core UI

Status: approved
Date: 2026-07-31

## Purpose

Letter uses three signature views to move from current context to personal
pattern to clinician-readable evidence:

1. `Gravity Horizon` on Today
2. `Spectrum Log` in Letters > Patterns
3. `Twin Matrix` in Letters > Reports

They are views over the same local timeline, not independent stores. Each view
must distinguish observed data, predicted context, and missing data.

## Gravity Horizon

### Job

Answer:

> Where is today within my recorded and estimated cycle context?

The Horizon is the first-viewport visual signature on Today. It shows:

- observed period timing
- the current cycle day when available
- the predicted next-period range and confidence
- a clearly labeled today marker

It may use a thin horizon or tidal curve as restrained ritual language. It must
not claim to measure hormones, energy, mood, symptom severity, or a medical
danger window.

### Copy Boundary

Allowed:

> Estimated premenstrual window. Your experience may be different.

Not allowed:

> Your energy is falling.

> Gravity is heavier because of your hormones.

> You are entering a PMDD danger window.

The user's check-in, not the prediction, is the source of their current state.

### States

- no period history
- insufficient history for prediction
- prediction available with confidence and range
- period in progress
- later than the current estimate

Tapping the Horizon opens Cycle. Reduced motion uses a static curve and marker.

## Quick Check-In

The header action is `+ Check in`. It opens one state-selection surface without
an intermediate menu.

One state tap saves a timestamped `MomentCheckIn` immediately:

- Good
- Steady
- Energized
- Low
- Irritable
- Physical

The completion surface shows the save time, `Add details`, and `Undo`. Adding
details opens confirmed symptom recording but does not change the original
check-in into a clinical rating.

Confirmed symptom recording is a focused repeatable interaction:

1. choose one plain-language symptom
2. confirm one of the six visible intensity anchors
3. add another symptom or continue to shared context

The symptom directory is grouped into Physical, Mood, Energy, and Sleep. A
chosen symptom becomes a compact editable summary rather than expanding a
long inline form beneath the directory. No intensity is preselected.

`Suicidal thoughts` and `Self-harm` are visually separated safety actions in
the Mood directory. Either action interrupts symptom capture with the
region-aware crisis boundary and creates no routine symptom record.

Moment check-ins:

- are visible in Today's activity and the containing cycle Story
- may repeat during a day and retain timestamps
- are excluded from clinical severity, symptom patterns, and reports
- never imply diagnosis or phase causation

## Today's Activity

Today presents one chronological, editable view of:

- moment check-ins
- confirmed symptom ratings
- private notes
- factual Care moments and outcomes

Period controls remain contextual to the cycle surface. Private notes and
saved confirmed symptom details remain directly accessible from activity.
Today does not promote a separate symptom-creation entrance alongside quick
check-in.

Today is a current-state activity view, not an audit log. Creating a record makes
it visible; editing updates that record and may show an `Edited today` marker;
deleting removes it from the activity view and is confirmed with transient
feedback. Deleted health content is not retained as a persistent activity item.
If a future audit or revision history is needed, it must be a separate,
explicitly user-facing local history with its own export policy.

## Cycle Care And Reflection

Cycle Letters group repeated Care actions instead of rendering an unbounded
event list. Each group shows usage and Better/Same/Worse totals first; its
dates, individual outcomes, and preserved older Care notes are expandable.

Each cycle has at most one editable cycle reflection. New reflection entrances
must not be repeated on individual Care events. The archive Story hierarchy is:

1. the user-authored cycle reflection
2. grouped factual Care overview
3. expandable event details and preserved older Care notes

Individual Care events remain available in Clinical records.

## Spectrum Log

### Job

Answer:

> When have my confirmed symptoms tended to appear across completed cycles?

The Spectrum Log is the primary visual in Letters > Patterns. It uses only
user-confirmed symptom ratings anchored to a subsequent observed period start.
It must not use moment check-ins, inferred symptoms, Care interaction behavior,
or predicted future values.

The visual may use a continuous color spectrum instead of a conventional line
chart, but it must also expose:

- day labels
- symptom filters
- cycles and observations covered
- missingness
- source-record access

The user-facing name is `Spectrum Log`, not `Hormonal Spectrum`, because Letter
does not measure hormone levels. Empty and insufficient-history states remain
plain and do not fabricate a spectrum.

## Twin Matrix

### Job

Answer:

> What confirmed evidence is available for review or a clinician conversation?

The Twin Matrix belongs to Letters > Reports and the Cycle and Care Summary
preview. It is a restrained clinical grid, not a ritual visualization.

It may show:

- observed days before a subsequent period
- observed menstrual or follicular cycle days
- confirmed symptom ratings
- confirmed functional-impact ratings
- provenance and missingness

It must never mirror, interpolate, impute, or project one side of the matrix
from the other. Unobserved cells remain blank.

Until clinical wording, scoring, attribution, and licensing are approved, the
matrix must not use `DRSP`, `DRSP-compatible`, or diagnostic-equivalence copy.
Medication history remains outside Letter's current scope.

## Shared Accessibility

All three views provide equivalent text semantics, preserve 320 logical-pixel
layouts at large text sizes, respect reduced motion, and avoid relying on color
alone. Decorative rendering cannot hide confidence, coverage, missingness,
dates, or provenance.
