# Gravity Horizon Requirements

Status: approved for implementation

## Purpose

Gravity Horizon gives a brief, honest answer to: where does today sit relative
to recorded period dates and the range estimated from them?

## Data Semantics

- The horizontal axis is calendar time, anchored by recorded period starts.
- Recorded dates are solid; estimated dates are dashed or hatched.
- The vertical direction is an ordinal emotional/energy gravity metaphor:
  higher is lighter; the shallow valley is potentially heavier.
- The estimated premenstrual window uses that shallow valley. Its horizontal
  position and width come from
  `CyclePrediction.predictedLutealStart` and `predictedLutealEnd`.
- Valley depth is not a numeric score and must not be presented as a
  measurement of actual mood, symptoms, energy, hormones, fertility, or
  ovulation.
- The complete emotional/energy curve is estimated. Recorded period dates are
  shown on a solid teal rail beneath the plot using the same horizontal date
  mapping; they have no gravity Y-value. Check-ins remain authoritative for
  how the person feels.
- The estimated next-period range comes from `predictedMensesStart` and
  `predictedMensesEnd` and is shown as a pale-blue hatched vertical date band
  aligned to the curve, recorded rail, and Today marker.
- Today is a distinct vertical marker.
- `cycle_prediction.dart` remains unchanged.

## Today Surface

- The Today page header shows the calendar date only. Gravity Horizon is the
  single owner of cycle day, period day, and no-history cycle context.
- Keep the card brief: current period/cycle day, one estimate summary, and one
  confidence/evidence line at most.
- During an open period, prioritize recorded period day and recorded bleeding
  duration; do not show a redundant future estimate as the primary message.
- Tap the chart or action to open Cycle for detail and editing.
- Do not list last period, range width, cycle-length distribution, confidence,
  and status as a long evidence table on Today.

## Safety And Language

- Use "estimated premenstrual window" in user-facing copy.
- Explain that the valley represents a time when emotional or energy changes
  may feel heavier, while making clear that it does not measure or decide how
  the person feels.
- Later-than-range language is a date comparison, not a diagnosis or pregnancy
  conclusion.
- With insufficient history, show only what is observed and explain that more
  recorded periods are needed for an estimate.

## State Coverage

- no period history
- one recorded period / insufficient intervals
- regular short, typical, and long cycles
- irregular cycles with a wider estimate
- inside the estimated premenstrual window
- inside the estimated next-period range
- later than the estimated range
- open period in progress
- narrow screen and 200 percent text

## Lovable Boundary

Lovable owns the focused visual composition and interaction treatment for the
compact card. Production period repositories, domain records, prediction
engine, navigation, accessibility semantics, and validation remain in Letter Within.
