# Cycle Flow And Clearer History Requirements

Status: approved in product review

## Context

Letter Within already records period boundaries and calculates next-period estimates
from recorded starts. The period tracker needs more day-to-day utility without
weakening the existing estimate engine or adding calendar-only fertility
claims.

## Goal

Let a user privately record the observed flow for each day inside a recorded
period and understand bleeding duration and completed cycle length at a glance.

## Requirements

REQ-001: Keep `cycle_prediction.dart` behavior unchanged.

REQ-002: Support four user-selected flow values: spotting, light, medium, and
heavy.

REQ-003: Store flow against a date-only local calendar day and its recorded
period. A flow selection must never create, start, extend, or end a period.

REQ-004: Allow flow only on days inside the recorded period interval. For an
open period, allow days from its start through today.

REQ-005: Let the user replace or clear a previously selected flow value.

REQ-006: Preserve valid flow entries when period dates are edited and remove
entries that fall outside the corrected interval.

REQ-007: Delete a period's flow entries when that period is deleted.

REQ-008: Keep flow data in the same encrypted local database and include it in
encrypted local backup without sending it to APIs, analytics, logs, or crash
metadata.

REQ-009: Show bleeding duration and completed cycle length as separate labels.
Completed cycle length is start-to-next-start and is unavailable for the newest
record until a later period exists.

REQ-010: Keep recent history limited to three completed periods and retain the
expandable all-period archive and edit/delete navigation.

REQ-011: Surface the existing past-estimated-range state as "Later than
estimated range" without calling the period clinically late or implying
pregnancy.

REQ-012: Keep all primary controls at least 44 logical pixels and operable at
320 logical pixels wide with 200 percent text scaling.

## Non-Goals

- changing next-period estimate inputs, thresholds, ranges, or confidence
- predicting ovulation, fertile days, pregnancy, or clinical cycle phases
- inferring a period start from spotting or flow
- server synchronization
- pricing or entitlement changes
- notification scheduling in this slice

