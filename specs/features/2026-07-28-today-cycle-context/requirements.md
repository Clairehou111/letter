# Today Cycle Context And Logging Entry Requirements

Status: validated
Branch: `feature/today-cycle-context`
Base branch: `feature/cycle-prediction-confidence`

## Context

The existing Today screen is a visual prototype. It hard-codes cycle day 24,
a luteal phase, a softer-day interpretation, a personalized Care plan, a note
from the user, and a recent entry that do not exist in local storage. Its Log
button also has no action.

Period history and transparent prediction are now real. Today must use those
records and stop presenting synthetic personalization as user data.

## Goal

Make Today an honest, useful daily entry point based on the user's actual local
cycle record while keeping full symptom persistence in its later dedicated
feature.

## Requirements

REQ-001: Load period history from the same local repository used by Cycle.
Show an explicit loading state and do not flash synthetic or empty context.

REQ-002: Show today's real local calendar date.

REQ-003: If a period is open, show the inclusive period day and its recorded
start date.

REQ-004: If no period is open but history exists, show the inclusive cycle day
calculated from the latest recorded period start.

REQ-005: If a supported prediction exists, show its date range and whether it
is upcoming, current, or later than estimated. Use the same prediction engine
as Cycle.

REQ-006: If prediction history is insufficient, say that the cycle record is
still taking shape. Do not substitute a population-average cycle.

REQ-007: If no period history exists, provide a direct route to Cycle to start
or backfill a period.

REQ-008: Do not show a menstrual phase, luteal phase, ovulation, fertile
window, PMDD danger window, or mood/energy inference.

REQ-009: Remove all synthetic user artifacts: fake recent entries, fake Care
plans, fake named contacts, fake remedies, and fake notes from a calmer self.

REQ-010: Keep a generic Care entrance without claiming that a personal plan is
ready. The existing Care content remains a prototype shell for later Care
features.

REQ-011: Keep balanced quick-state choices for good, steady, energized, low,
irritable, and physical states.

REQ-012: Make the header Log control open the quick-state entry instead of
being a no-op.

REQ-013: State and severity choices in this feature are session-only UI input.
Do not call them saved, add them to Recent, or include them in reports.

REQ-014: State detail UI must explicitly say that it is not yet saved to the
health record. Its completion action must use neutral `Done` language.

REQ-015: Do not add a symptom database, daily-record table, analytics event,
API request, LLM request, notification, or background task.

REQ-016: Rebuild Today from repository data whenever the user navigates back
from Cycle, so recent period changes are reflected.

REQ-017: Replace the prototype's fake status bar with SafeArea-aware app
layout.

REQ-018: Keep primary controls at least 44 logical pixels and preserve
operation at 320 logical pixels with 200 percent text scaling.

REQ-019: Keep actual health context direct and familiar. Letter styling must
not obscure date, cycle day, period state, or prediction provenance.

## Context Rules

- No records: no cycle day and no estimate.
- Latest record open: period day = today minus latest start plus one.
- Latest record closed: cycle day = today minus latest start plus one.
- Prediction is always delegated to `CyclePredictionEngine`.
- Today does not persist derived context.

## Non-Goals

- persisted symptoms, severity, pain, mood, energy, or notes
- personalized Care plans or future-self notes
- phase or fertility calculations
- cycle-day notifications
- widgets or lock-screen surfaces
- doctor-report data
- Today redesign for the five finished Care modes

## Product Decisions

- It is better to show less information than to imply that prototype content
  came from the user.
- Quick-state controls remain to validate low-effort interaction, but they are
  not health records until the dedicated logging feature defines storage,
  provenance, editing, and deletion.
- The Today hero reports observed or derived context only. It does not tell the
  user what their body or mood must be doing.
