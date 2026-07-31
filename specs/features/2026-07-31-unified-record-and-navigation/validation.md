# Unified Record And Navigation Validation

Status: in_progress

- `+ Check in` opens state choices directly and one state tap persists locally.
- Saved check-ins survive screen reconstruction, show timestamps, can be undone,
  and never enter symptom patterns or reports.
- Today's activity retrieves check-ins, confirmed symptoms, notes, and Care
  records with explicit source labels.
- Same-day same-symptom entry updates rather than duplicates; original creation
  time is preserved.
- Health history is grouped by experienced day and cycle context.
- Every Care reflection appears with its source Care moment.
- Gravity Horizon copy distinguishes estimate from experience.
- Spectrum Log uses confirmed observations and exposes coverage/missingness.
- Twin Matrix contains no mirrored data, medication log, cryptographic
  authenticity claim, or DRSP-compatible language.
- `dart format`, `flutter analyze`, and the complete Flutter test suite pass.
- Today, Letters Patterns, and report preview render without overflow at
  320x700 and 390x844 representative viewports.
