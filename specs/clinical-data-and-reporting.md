# Letter Clinical Data And Reporting

Status: design draft
Date: 2026-07-28

## Goal

Letter should make difficult moments easy to express and still produce a report
that a clinician can understand. It must do this without turning interaction
behavior into invented symptom severity.

The product has two reporting promises:

1. `Cycle & Care Summary` organizes normal Letter use with transparent data
   provenance.
2. `Prospective Clinical Diary` organizes user-completed daily ratings for
   users actively preparing for a clinical conversation.

Only the second can claim alignment with a validated daily symptom instrument,
and only after wording, scoring, licensing, and implementation are reviewed.

## Non-Negotiable Measurement Rule

A patient-reported outcome comes directly from the patient without another
person or system interpreting the response.

Therefore Letter must not map:

- tap count to anger severity
- tap speed, pressure, or acceleration to a DRSP score
- time spent touching a pain scene to pain severity
- using a medication log to `severe` or `disabling`
- copying a boundary message to severe social withdrawal
- not reopening Letter to any symptom or impairment score
- haptic use to clinical improvement

These behaviors vary with device hardware, motor ability, game style,
accessibility settings, opportunity, and product familiarity. They are not
validated clinical measures.

## Three Data Layers

### Layer 1: Observed Care Event

The app may record factual product events locally:

- Care mode selected
- event timestamp and associated cycle day
- scene started, skipped, or completed
- draft sealed
- personal action selected
- medication event entered by the user
- later `better`, `same`, or `worse` response

This layer answers `what happened in Letter`, not `how clinically severe the
symptom was`.

### Layer 2: Symptom Candidate

Deterministic rules or optional AI may propose fields from the user's choices,
text, or voice:

```text
selected Shatter
  -> candidate: anger or irritability

"I could not finish work"
  -> candidate: work impairment

"I cried and felt completely hopeless"
  -> candidates: tearfulness, depressed mood, hopelessness
```

Candidates:

- remain visibly marked as suggestions
- retain an evidence link to the user's selected mode or text span
- are not exported as confirmed symptoms
- never receive an inferred severity score
- can be accepted, edited, rejected, or left unresolved

### Layer 3: User-Confirmed Clinical Rating

Only the user can confirm:

- which symptom was present
- symptom severity
- functional impact
- whether a medication or action was used
- perceived outcome

This layer is eligible for the clinical report. Every rating stores when it was
experienced, when it was entered, and whether it was prospective or recalled
later.

## Acute Care Capture

Care must not interrupt the acute scene with a symptom form.

Example:

```text
20:42  user selected I want to explode
20:42  Shatter started
20:43  user entered the quiet transition
20:47  user sealed a private draft
```

Letter may store this as an unrated Care event. It must not silently add:

```text
anger = 6
social impairment = severe
PMDD event = true
```

If the user never confirms clinical fields, the report may say:

> One anger/overload Care session was opened on cycle day 26. Symptom severity
> was not rated.

## Recovery Receipt

At a user-chosen later time, Letter presents a short reconciliation flow. This
is the bridge between expressive Care and structured data.

### Screen 1: Confirm The Signal

> Yesterday you opened Shatter. What was strongest, if you want to record it?

Candidate chips:

- angry or irritable
- overwhelmed
- anxious or tense
- mood swings
- something else
- I do not remember

The selected Care mode may suggest the first chip, but it is never already
confirmed.

### Screen 2: Confirm Severity

> At its strongest, how intense was it?

Use the six explicit anchors:

1. not at all
2. minimal
3. mild
4. moderate
5. severe
6. extreme

The UI may look like ink wells or marks on a letter, but labels and numbers
must remain visible. Decorative interaction cannot obscure the scale.

For a specific pain event, Letter may additionally collect a conventional
user-entered 0-10 pain rating. This remains separate from a daily premenstrual
symptom scale.

### Screen 3: Confirm Functional Impact

> What did it interfere with?

- work or school
- home responsibilities
- relationships
- social activities
- sleep
- nothing I want to record

The user then rates selected impact directly. An AI suggestion based on text
must still be confirmed.

### Screen 4: Reconcile Other Signals

The proposed `circle words in a letter` interaction is useful here when it is
transparent:

> Letter noticed possible signals in what you recorded. Circle only what was
> actually present.

Possible chips include:

- low energy
- concentration difficulty
- appetite or craving change
- sleep change
- breast tenderness
- bloating
- headache
- cramps

The app must not write a synthetic first-person sentence and ask the user to
approve it as if they originally said it.

The receipt is optional and can be completed in under 30 seconds for one
primary event. A later rating is marked `retrospective`, not `prospective`.

## Doctor Mode

There is no honest way to recreate a validated prospective daily diary from
tap behavior or end-of-cycle memory.

For users seeking PMDD evaluation, Letter offers a temporary Doctor Mode:

- explain why daily ratings matter
- collect daily self-ratings across at least two consecutive cycles
- use a user-chosen reminder time
- display progress by cycle coverage, not a behavioral streak
- allow missed days without filling or imputing values
- show missingness in the report
- stop automatically after the selected assessment period unless extended

The original DRSP contains 21 symptom items grouped around 11 symptom domains
and 3 functional-impairment items, each rated daily from 1 to 6. Reproducing
the exact instrument in a commercial app requires confirmation of wording,
scoring, attribution, and permission from the rights holder.

Until that is resolved, Letter must call its own flow:

> Prospective daily symptom diary

It must not call an altered, shortened, inferred, or partially completed flow
`DRSP`, `DRSP-compatible`, or diagnostically equivalent.

## Data Model

### CareEvent

```text
id
occurred_at
cycle_id
cycle_day
selected_mode
scene_status
selected_action_ids
sealed_draft_id?
```

### SymptomCandidate

```text
id
care_event_id?
symptom_code
source: mode | text | voice | rule | llm
evidence_reference
status: unresolved | accepted | edited | rejected
```

### SymptomRating

```text
id
symptom_date
recorded_at
symptom_code
score
scale_id
provenance: same_day | later_recall | doctor_mode
confirmed_by_user: true
care_event_id?
```

### FunctionalImpactRating

```text
id
symptom_date
recorded_at
domain
score
provenance
confirmed_by_user: true
```

### MedicationEvent

```text
id
user_entered_name
user_entered_amount?
taken_at
schedule_source?
notes?
```

Medication use does not imply severity, necessity, effectiveness, or correct
dosing.

### CareOutcome

```text
id
care_event_id
action_id
recorded_at
response: better | same | worse
confirmed_by_user: true
```

## Report A: Cycle And Care Summary

This is available from normal Letter use.

### Data Quality Header

- cycles covered
- calendar date range
- days with user-confirmed ratings
- later-recall ratings
- unrated Care events
- missing data
- generated date

### Cycle Timeline

- user-entered period dates
- cycle day
- prediction ranges shown separately from observed dates

### Confirmed Symptom Summary

- only user-confirmed symptoms and severity
- source marker for same-day versus later recall
- no imputed values

### Functional Impact

- work or school
- home
- relationships
- social activity
- sleep

### Care And Medication History

Use factual language:

> User reported taking ibuprofen at 14:10.

> User selected heat and later reported `better`.

Do not write:

> Medication was required for severe pain.

> Heat effectively treated the symptom.

### Optional Notes

Raw drafts are excluded by default. The user may select specific excerpts for
the report and preview every included sentence.

## Report B: Prospective Clinical Diary

This report is available only from Doctor Mode.

- daily item-by-item ratings
- six-point scale legend
- cycle and calendar timing
- late-luteal and follicular views
- functional-impairment ratings
- completion and missingness
- medication events shown as self-reported context
- no automatic diagnosis

The report can help a clinician evaluate timing, severity, impairment, and
whether other conditions should be considered. It cannot promise a diagnosis
in ten seconds.

## Provenance Legend

Every reportable value has one visible source:

- `P` prospective user rating
- `S` same-day user rating
- `R` later user recall
- `E` factual Care event without a symptom score
- `M` user-entered medication event

AI-generated candidates have no report code because they are not exported
until the user confirms them.

## LLM Boundary

LLM may:

- extract candidate symptoms from user-selected text
- identify a possible functional-impact phrase
- organize user-confirmed records
- draft neutral narrative from selected structured data

LLM must not:

- assign severity from language intensity or interaction behavior
- fill missing days
- infer a medication was medically necessary
- infer treatment effectiveness
- diagnose PMS or PMDD
- convert an unresolved candidate into a report fact

## Validation

Before claiming clinical utility:

- obtain review from an OB-GYN or clinician experienced with premenstrual
  disorders
- verify any DRSP licensing and exact-use requirements
- test whether users understand candidate versus confirmed data
- test whether clinicians can see data provenance and missingness quickly
- compare generated reports against the underlying local records
- ensure every report statement is traceable to a user-confirmed value

Sources:

- DRSP reliability and validity:
  https://pubmed.ncbi.nlm.nih.gov/16172836/
- ACOG Clinical Practice Guideline No. 7:
  https://www.acog.org/clinical/clinical-guidance/clinical-practice-guideline/articles/2023/12/management-of-premenstrual-disorders
- FDA patient-reported outcome definition:
  https://www.fda.gov/regulatory-information/search-fda-guidance-documents/submitting-patient-reported-outcome-data-cancer-clinical-trials
- IAPMD DRSP overview:
  https://www.iapmd.org/drsp
