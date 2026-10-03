# Candidate v6: app-only screenshot review

Status: **superseded local review only; do not upload**. The owner requested
one Today storefront image, not the three Today scroll positions in this set.
These three native captures remain as validation evidence while a single-image
presentation is chosen. The ten
candidate-v4 screenshots remain live in ASC iOS 1.0. No replacement is
approved for this set.

`app-only/` holds native 1320 × 2868 full-app simulator captures. `final/`
holds the same frames as full-bleed JPEGs without an alpha channel, phone
mockup, external caption, or marketing canvas. Frames 7–8 have only a small
`With Plus` badge drawn over unused background above the Patterns heading;
`overlay_plus_badge.swift` reproduces that overlay from the untouched native
PNGs. The neutral simulator status bar remains part of the native screen. All
health records and notes are fictional. The complete `LetterApp` was launched
with a debug-only fixture; screens were reached through in-app navigation and
scrolling.

| # | Frame | Content and review |
| --- | --- | --- |
| 1 | Care | Current chooser and exit action complete. |
| 2 | Today: period | Period day 5, check-in, Care doorway and remembered help. |
| 3 | Comfort Kit | Two saved actions, recorded outcomes, and a user-authored saved reflection. Basic Kit is free. |
| 4 | Today: flow | Light bleeding, optional color, and three symptoms. |
| 5 | Today: notes | Saved Quick Note marked for Comfort Kit. This is a lower scroll position on the same Today page. |
| 6 | Privacy | Current in-app explainer. Accurate but text-dense at thumbnail size. |
| 7 | What helped | Complete Plus-depth comparison with owner-selected small `With Plus` badge. |
| 8 | Mood Patterns | Complete chart and insight with owner-selected small `With Plus` badge. |
| 9 | Report | Populated 21-record on-screen matrix; **needs recapture or UI correction** because category labels wrap awkwardly and the next card is cut by the viewport. This is the free on-screen report, not a PDF export. |
| 10 | Care scene | Current blue-rain scene with complete action and exit controls. |

The order starts Care → Today → Comfort Kit as recommended in
`marketing/launch-2.0/screenshot-order.md`. The owner's request to show the
Today period, flow, and note adds two further Today scroll positions. Those
three states do not fit in one native phone viewport. The last two Today
frames are deliberately separate screenshots of the same screen, not an
assembled fictional view.

Do not upload this directory as-is. Review the report frame and the dense
privacy frame. The owner chose the small badge for frames 7–8, and visual
inspection confirmed it does not cover native text or controls. Do not replace
candidate-v4 in ASC without operation-specific confirmation.
