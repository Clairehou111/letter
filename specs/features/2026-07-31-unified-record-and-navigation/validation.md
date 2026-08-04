# Unified Record And Navigation Validation

Status: validated; native device review deferred

- `+ Check in` opens state choices directly and one state tap persists locally.
- Saved check-ins survive screen reconstruction, show timestamps, can be undone,
  and never enter symptom patterns or reports.
- Today's activity retrieves check-ins, confirmed symptoms, notes, and Care
  records with explicit source labels.
- Same-day same-symptom entry updates rather than duplicates; original creation
  time is preserved.
- Health history is grouped by experienced day and cycle context.
- Today has no standalone symptom-creation promotion; quick check-in Add
  details remains the fast multi-symptom path.
- Symptom selection opens a focused intensity surface, does not preselect an
  intensity, supports multiple symptoms, and keeps chosen ratings editable.
- Vocabulary version 2 exposes the reviewed plain-language distinctions while
  existing version 1 records remain readable.
- Suicidal thoughts and self-harm open the crisis boundary immediately and are
  not persisted as routine symptom ratings.
- Heart palpitations route to the physical medical boundary and are not
  offered as a routine new-record tile; existing records remain readable.
- Each cycle exposes one editable cycle reflection; repeated Care actions are
  grouped and older per-Care reflections remain nested under their source.
- Gravity Horizon copy distinguishes estimate from experience.
- Spectrum Log uses confirmed observations and exposes coverage/missingness.
- Twin Matrix contains no mirrored data, medication log, cryptographic
  authenticity claim, or DRSP-compatible language.
- `dart format`, `flutter analyze`, and the complete Flutter test suite pass.
- Today, Letters Patterns, and report preview render without overflow at
  320x700 and 390x844 representative viewports.

## Validation Evidence — 2026-07-31

- [x] `dart format`, `flutter analyze`, and the complete Flutter suite pass
      (463 tests, including cycle-reflection migration, backup, hierarchy, and
      large-text coverage).
- [x] The Flutter web build completes.
- [x] Widget tests cover Today and symptom capture at 320x700 with 200 percent
      text; Today also matches its approved 390x844 golden baseline.
- [ ] Native iOS and Android device review before release.
