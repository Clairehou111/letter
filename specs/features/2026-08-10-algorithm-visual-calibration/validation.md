# Validation

- Routine capture offers exactly five present-symptom levels; the separate
  prospective diary still offers explicit absence.
- `[21, 45, 45]` now estimates day 21–48 instead of day 21–69.
- Gravity says `Estimated cycle gravity`, remains date-driven, and begins its
  curve from the central estimated pre-period start rather than the earliest
  edge of the uncertainty union.
- Spectrum takes the strongest record within each cycle/day, then the median
  across cycles. Tested three-cycle fixture: daily peaks `[5, 2, 4]`, typical
  `4`, range `2–5`.
- Spectrum renders an exact min–max whisker, five word labels, chronological
  trend points, cycle/day coverage, and a one-tap source sheet.
- Twin Matrix keeps within-cycle then across-cycle averaging, shows linked
  source evidence, and stacks its timing halves without horizontal scrolling
  at 320 and 390 logical pixels.
- iOS simulator package `app.letterwithin` was uninstalled, deleting the old
  prerelease database. No Android device or `adb` installation was present.
- Lovable/extra AI usage: zero.
- `flutter analyze`: pass with no issues.
- Focused algorithm, repository, responsive UI, source-drilldown, export, and
  updated representative golden tests: pass.
- Full suite: 515 pass, 1 skipped, and 1 unrelated pre-existing visual-baseline
  failure in `plans_sheet_test.dart` (2.99% pixel diff). The Plans surface was
  not changed as part of this work.
