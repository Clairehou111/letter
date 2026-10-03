# Candidate v8: one Today frame plus Cycle recording proof

Status: **source provenance for the uploaded candidate-v9 set; not uploaded to ASC**.
The titled composition is under `../candidate-v9/`. This set retains the first seven core
positions from `artifacts/app-store/screenshot-order.md`, then follows the
owner-approved extension: a Cycle day editor at #8 and the immersive Care
scene at #9.

| # | Frame | What the app actually shows |
| --- | --- | --- |
| 1 | Care chooser | Current support paths. |
| 2 | Today | One top-of-page period and check-in frame. Existing marketing caption is unchanged in `manifest.json`. |
| 3 | Comfort Kit | Two past actions and a user-authored saved reflection. Basic Kit is free. |
| 4 | Privacy | Current in-app explainer, complete but text-dense. |
| 5 | What helped | Plus-depth outcome comparison with small `With Plus` badge. |
| 6 | Mood Patterns | Plus-depth chart and complete first insight with small `With Plus` badge. |
| 7 | Clinician report | Populated free on-screen matrix; current framing needs correction. |
| 8 | Cycle day editor | Selected medium flow, dark-red color, and saved moderate low-energy observation on one fictional date. The search field and edit/delete controls show how to continue recording. The next `Quick picks` heading enters at the natural scroll boundary; no control or sentence is cut. |
| 9 | Care scene | Current blue-rain scene with its action and exit. |

Frame 8 came from complete-app navigation on the 6.9-inch simulator:
`Cycle → Cycle 2 → 6/22/2026 flow day → day editor`. The debug-only full-app
fixture adds one flow/color record to a past day that already has a saved
symptom. The untouched native PNG is in `source/`; `final/` contains its
JPEG conversion. The final JPEGs are the retained app-only provenance used by
candidate-v9. Every health record shown is synthetic.

All nine `final/` files are 1320 × 2868 JPEGs without alpha. They have no
phone mockup or external caption. `manifest.json` lists the unchanged
marketing copy, navigation route, exact source, and output hash for each.

## Remaining visual gate

- Privacy (#4) is too dense at storefront thumbnail size. Prefer a concise
  real in-app state.
- Report (#7) has small, awkwardly wrapped labels and a card cut at the bottom.
  It needs a cleaner complete-app capture or appropriate product UI correction.
- Verify the final set against the selected release build. The synthetic
  fixture is the full application, but it is not the distributed Build 17.

Do not replace ASC screenshots without separate operation-specific
confirmation after the visual gate is resolved.
