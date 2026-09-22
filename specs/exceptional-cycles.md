# Exceptional Cycles

Date: 2026-08-07

Status: Approved product and data rules. The first implementation batch changes
cycle-history interpretation and presentation, but does not change the estimate
engine's mathematics.

## Implementation coverage

The bounded local implementation is covered by focused repository and widget
tests for one-day bleeding, prolonged open periods, adjacent starts, short and
long intervals, edited period identity and flow cleanup, older-history
insertion, schema migration, and independence of date-owned Care records.
When a cycle reflection is attached, period deletion explicitly warns that the
reflection will also be deleted while dated symptom and Care records remain.

## 1. Purpose

Letter Within must preserve what the user recorded without silently turning missing,
unusual, or ambiguous data into a biological claim. Exceptional records remain
part of local history even when they are not eligible for an estimate.

The governing model is:

```text
Recorded history     Always retained
Interpretation       Ordinary, uncertain, or context-affected
Estimate eligibility Included, excluded with a reason, or insufficient history
```

"Recorded" must never imply "typical", and "excluded from estimates" must never
imply that the record is false.

## 2. Definitions

- **Period**: the bleeding date range explicitly recorded by the user.
- **Cycle interval**: the number of days from one recorded period start to the
  next recorded period start.
- **Current cycle**: the interval beginning at the latest recorded period start;
  it has no complete length until a later start is recorded.
- **Short bleeding**: a period containing only one or two recorded bleeding days.
  This is different from a short cycle interval.
- **Short interval**: a start-to-start interval shorter than 21 days under the
  current estimate engine's eligibility rule.
- **Long interval**: a start-to-start interval longer than 45 days under the
  current estimate engine's eligibility rule. It may be a genuinely long cycle,
  a missing period record, or another context the app cannot infer.
- **Adjacent bleeding**: a proposed new period start fewer than 10 days after the
  previous period start.

These thresholds describe Letter Within's current product rules. They are not diagnoses
and must not be labeled "normal", "abnormal", or "pathological" in product copy or
code comments.

## 3. Non-negotiable data rules

1. Period dates, flow, symptoms, Care events, and reflections remain local-first.
2. Symptoms and Care events are owned by their actual timestamps. Editing,
   inserting, or deleting a period does not rewrite or delete them.
3. Bleeding flow is owned by a stable period ID plus a calendar date.
4. A cycle reflection is owned by the stable ID of its starting period, not by an
   editable start date or a displayed sequence number.
5. Displayed dates, cycle numbers, and list positions are presentation only and
   must never be persistent identity.
6. No exceptional record is silently deleted, extended, merged, or changed into
   another kind of record.

## 4. Current estimate engine boundary

This implementation batch does not change:

- the median calculation;
- the use of at most six recent intervals;
- the two-interval minimum;
- the existing 21–45-day eligibility bounds;
- relative outlier filtering;
- confidence levels or range widening;
- Gravity Horizon geometry or semantics;
- the PMS/luteal-window calculation;
- Spectrum Log or Twin Matrix aggregation.

The UI may explain why an interval did not participate in an estimate. A future
change to support consistently short cycles or different eligibility bounds
requires a separately approved engine revision and regression fixtures.

Reference fixture that must remain unchanged:

```text
Recorded starts: Mar 2, May 10, Jun 13, Jul 14, 2026
Raw intervals: 69, 34, 31 days
Eligible intervals: 34, 31 days
Rounded median: 33 days
Prediction midpoint: Aug 16, 2026
Prediction range: Aug 12–20, 2026
Confidence: Low
```

## 5. Presentation rules

### 5.1 Cycle identity

Do not display `Letter No. N`. Inserting an older period changes chronological
ordinals and makes the same cycle appear to become a different letter.

Use stable, date-first labels:

```text
Current cycle
Jul 14–Today · Cycle day 25

Jun 13–Jul 13 · 31-day cycle
Bleeding Jun 13–17 · 5 days
```

### 5.2 Recent and complete history

- Pin the current cycle separately.
- Show the three most recent completed cycle intervals.
- `View all recorded periods` remains the single period archive entry.
- The archive contains completed bleeding periods only, newest first and grouped
  by year.
- Archive editing uses compact Flow, Edit dates, and Delete controls with
  44-by-44 touch targets; compact cycle cards may group Edit and Delete in an
  overflow menu.

### 5.3 Provenance

Do not use repeated `Recorded` and `Derived` badges on compact cards. In details,
use natural language only where it resolves ambiguity:

- `33 days, calculated between two recorded period starts.`
- `Jul 14–18 · 5 bleeding days you recorded.`

## 6. Exceptional-case behavior

### 6.1 One-day or short bleeding

- Accept the period exactly as recorded.
- Do not extend it to an average or predicted duration.
- Do not exclude a cycle merely because bleeding was short.
- Show the factual duration: `1 bleeding day`.

### 6.2 Prolonged open bleeding

- Never auto-close an open period.
- After more than seven recorded/open days, show a gentle `Still bleeding?`
  check with `End today` and `Keep open` actions.
- This check is not a diagnosis and must not erase any days.

### 6.3 Adjacent period starts

- Existing overlapping ranges remain invalid.
- When a proposed new start is fewer than 10 days after the previous start, ask
  for explicit confirmation before storing it as a separate period.
- Offer a path to edit/continue the previous period instead.
- Standalone spotting is not introduced in this batch; it remains a documented
  follow-up because spotting should not require creating a period.

### 6.4 Short interval

- Preserve and display the interval.
- Label it `Short interval · not used in estimates`.
- Do not label it invalid or pathological.
- A future engine may support a repeatedly confirmed short personal pattern, but
  this batch does not.

### 6.5 Long interval or skipped record

- Preserve both recorded periods.
- Display `Long interval · may contain missing records`.
- Keep the existing `Add past period` action available as the corrective path.
- Never invent a missing period.
- Never claim the interval was a biologically complete cycle.
- A genuinely long interval can remain in history while the current estimate
  engine excludes it.

### 6.6 Variable intervals

- Preserve genuine variability.
- Use the existing low-confidence estimate state when eligible intervals vary.
- Do not hide several variable cycles merely to make the prediction look stable.

### 6.7 Past the estimated window

- Say `Past the estimated window` or `No period recorded yet`.
- Do not infer pregnancy, amenorrhea, or another medical condition.
- Do not project a chain of additional future cycles from a missed estimate.

### 6.8 Insufficient history

- Keep the current requirement of three recorded starts/two usable intervals.
- Explain progress without showing a precise estimate prematurely.

## 7. Reflection lifecycle

- Store `startingPeriodId` on each cycle reflection.
- Migrate existing reflections by matching the legacy `cycleStartDay` to a period
  with the same recorded start.
- Editing the anchored period's dates keeps the reflection attached.
- Adding older history does not renumber or move the reflection.
- Adding a missed period does not silently rewrite reflection text.
- If the anchored period is deleted, confirmation must state that its cycle
  reflection will also be deleted. Symptoms and Care events remain.
- Do not introduce an unassigned-reflection interface in the MVP.

## 8. Deferred exceptional contexts

These require separate product and data-model work:

- standalone spotting outside a period;
- pregnancy;
- postpartum state;
- lactation;
- hormonal contraception;
- perimenopause or menopause context;
- user-controlled inclusion of consistently short cycles;
- longitudinal cycle-deviation notifications;
- clinician-facing interpretation of exceptional patterns.

When a future cycle factor is active, the preferred behavior is to keep factual
records while pausing interpretations that assume ordinary ovulation or PMS timing.

## 9. Evidence from established trackers

- Apple retains logged history, supports pregnancy/lactation/contraception cycle
  factors, asks whether a period ended, and detects patterns such as irregular or
  infrequent cycles, prolonged periods, and persistent spotting:
  <https://support.apple.com/en-us/120356>
- Clue retains atypical cycles while allowing them to be hidden from calculations:
  <https://support.helloclue.com/hc/en-us/articles/215935083-What-if-an-atypical-cycle-is-making-my-Clue-predictions-inaccurate>
- Clue requires 10 days between bleeding starts before automatically treating the
  second as a new period:
  <https://support.helloclue.com/hc/en-us/articles/28104706329885-Clue-didn-t-recognize-my-second-bleeding-as-a-period-why>
- Flo shows a delay after its prediction window and suppresses some predictions
  when cycle conditions make them unreliable:
  <https://help.flo.health/hc/en-us/articles/360015106672-Why-can-t-I-see-ovulation-predictions>
- ACOG describes cycle and bleeding ranges as reasons for clinical review; Letter Within
  uses those references for gentle safety language, not data rejection:
  <https://www.acog.org/womens-health/faqs/abnormal-uterine-bleeding>

## 10. Required regression coverage

- one-day completed period;
- open period beyond seven days;
- adjacent proposed start under 10 days;
- short interval under 21 days;
- long interval over 45 days;
- missing historical insertion without ordinal identity changes;
- period start-date edit preserving flow and cycle reflection;
- anchored-period deletion warning and reflection deletion;
- symptoms and Care unchanged after period edits/deletion;
- current-cycle plus three-completed-cycle list behavior;
- exact unchanged estimate fixture in Section 4.
