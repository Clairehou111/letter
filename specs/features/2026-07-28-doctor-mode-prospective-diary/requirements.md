# Doctor Mode Prospective Diary Requirements

Status: proposed
Dependencies: health-record foundation, local export, and clinical review gate

## Goal

Offer an optional prospective daily diary for users preparing for a clinician
conversation, without pretending that retrospective Care use recreates one.

## Requirements

REQ-001: Doctor Mode clearly explains why daily records matter and is opt-in.
The core period tracker and Care experience remain usable without it.

REQ-002: The daily item set, labels, scoring, attribution, and licensing must
be approved before implementation. Until then the UI calls it `Prospective
daily symptom diary` and never uses `DRSP-compatible` language.

REQ-003: The diary collects explicit user ratings for each reviewed symptom and
functional-impact item. It never derives a rating from text, voice, Care mode,
app absence, or interaction behavior.

REQ-004: The assessment covers at least two consecutive cycles, uses a
user-chosen reminder time if reminders are enabled, and displays coverage
rather than a streak.

REQ-005: Missed days remain missing. The app never imputes, interpolates, or
backfills values from later recall without marking the provenance.

REQ-006: The user can pause, stop, extend, edit, or delete diary records. All
records remain in the encrypted local health store.

REQ-007: A clinical report uses only prospective diary values and factual
context, with a visible missingness and provenance legend. It makes no
diagnosis or treatment recommendation.

## Non-Goals

- reproducing a validated instrument before review
- diagnosis or PMDD confirmation
- mandatory notifications or streaks
- cloud storage or medication records
