# Release 2.0 App Store screenshot candidate

Status: **local review candidate; not uploaded to App Store Connect**. The eight
files in `final/` implement the core sequence in
`/Users/clairehou/pyProjects/pms-research-agent/marketing/launch-2.0/screenshot-order.md`:
Care → Today → Comfort Kit → Privacy → What helped → Mood Patterns → clinician
report → immersive Care. The plan marks its Cycle overview and immersive Care
positions as optional. Cycle overview is omitted because the current native
viewport cuts the `Edit dates` control; immersive Care is retained as frame 8.
The ten previously uploaded candidate-v4 images remain untouched.

All captures show production widgets reached through the complete `LetterApp`
navigation, using only fictional local data. The three new PNGs were captured
on the dedicated 6.9-inch iPhone simulator from the debug-only
`apps/mobile/tool/app_store_full_app_capture_main.dart` entrypoint, which
injects in-memory repositories into the complete application. They are not
captures from the distributed Build 17 binary. The remaining five frames use
candidate-v4's already reviewed complete-app native captures. `manifest.json`
records each route, source, caption, and output hash.

| Frame | Feature and visual check |
| --- | --- |
| 01 Care | All six Care paths, Everyday care, safety and daylight exit appear. Reused current blue/purple complete-app image. |
| 02 Today | Current period, moment check-in, Care entry, and remembered check-back are visible. Reused complete-app image. |
| 03 Comfort Kit | Real Care → Your comfort kit route. Two saved Care outcomes offer `Try this now`; a fictional user-authored future-self note is the paper item. The fixture also has Care/Cycle reflections and a kept Quick Note; the shelf intentionally shows only three ranked items. Basic Kit is free. |
| 04 Privacy | Real onboarding privacy explainer; the caption names encrypted local health records, and the screen explains account separation, no AI upload, user-started export, and control. The text remains dense at storefront thumbnail size; it is a truthful full view, not a cropped substitute. |
| 05 What helped | Two action outcome summaries and the complete conclusion are visible. Caption explicitly says `With Plus`, matching the Patterns entitlement boundary. |
| 06 Mood | Four fictional cycles with 19 harder days and the complete first insight sentence are visible. The first section heading has scrolled out of the native viewport, while the Patterns header and selected Mood tab remain visible. Caption explicitly says `With Plus`. |
| 07 Report | Real Settings → Clinician reports route, Last 3 months free on-screen report. The complete matrix shows 21 confirmed fictional records across five observed cycles, with entries in each category and an honest missing-data legend. The next `Blank in this range` card starts at the bottom edge of the native viewport. No PDF export claim is made. |
| 08 Care scene | Current blue-rain scene at completion shows check-back, stay, and exit controls. |

Frames 05 and 06 are Plus-depth Patterns, while Care, basic Kit, Today, and the
limited last-three-month on-screen report can be used without Plus. The
candidate contains no real health data. Before any ASC replacement, compare
the eight files visually with the final release build and obtain specific
confirmation for removing the current ten images and uploading these eight.
