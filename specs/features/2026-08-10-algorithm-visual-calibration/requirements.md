# Algorithm and visual calibration

Status: approved in conversation
Date: 2026-08-10

## Requirements

1. Routine symptom capture uses five present-symptom anchors: Minimal, Mild,
   Moderate, Severe, and Extreme. `Not at all` is not offered after a symptom
   has been selected.
2. The prospective daily diary keeps its separate 0–5 absent-to-severe scale.
3. This is a pre-release reset. Existing development health rows are not
   migrated; the installed development app database may be cleared.
4. Drift retains the technically required schema version, reset to version 1,
   with no historical upgrade path.
5. Next-period midpoint remains the rounded median of up to six recent eligible
   intervals. Range margins are asymmetric so variation on one side is not
   mirrored onto the other.
6. Gravity remains a cycle-timing prediction derived from the estimated
   pre-period window. Its user-facing legend is `Estimated cycle gravity`.
7. Spectrum shows a cycle-balanced typical level per relative day, variability,
   coverage, and an across-cycle trend. Tapping evidence opens visible source
   detail.
8. Twin Matrix keeps cycle-balanced aggregation, uses the five-level scale,
   exposes cell evidence, marks shared source records, and fits phone layouts
   without mandatory horizontal scrolling.
9. Missing observations remain missing and are never treated as zero.
10. No Lovable credits are used for this implementation.
