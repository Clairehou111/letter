# Doctor Mode Prospective Diary Validation

Status: future capability; no production validation claim

The current in-memory domain tests do not satisfy this validation plan. Run the
checks below only after encrypted persistence, production UI wiring, and the
prospective report exist.

- A user can understand the difference between ordinary logging, later recall,
  and prospective diary entry.
- No missing day is silently filled.
- Coverage is not presented as a streak or success score.
- The report shows prospective values, missingness, and source dates.
- At least two consecutive synthetic cycles produce correct local data.
- Clinicians can identify timing, severity, impact, and missingness quickly.
- The exact instrument and any DRSP claims remain blocked until written review.
