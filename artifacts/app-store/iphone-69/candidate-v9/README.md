# Candidate v9: titled App Store review set

Status: **uploaded to ASC iOS 1.0 on 2026-10-03**. With specific owner
confirmation, candidate-v4's ten dark screenshots were deleted and the nine
candidate-v9 screenshots uploaded. The 6.9-inch slot showed all nine in the
order below after reloading the iOS 1.0 version page; the 6.5-inch slot
inherits that set. Candidate-v9 consists of nine titled
1320 × 2868 JPEGs in `final/`, in this order:

1. Care chooser — Care for the moment you are in.
2. Today — Track more than period dates.
3. Comfort Kit — What helped before, kept close.
4. Privacy — Your health records stay encrypted here.
5. What helped — With Plus, compare what helped.
6. Mood Patterns — With Plus, notice harder-day patterns.
7. Clinician report — Bring a clear record to your clinician.
8. Cycle day editor — Keep the details that matter.
9. Immersive Care scene — A quiet moment to set it down.

The first seven follow the core order in
`marketing/launch-2.0/screenshot-order.md`. The owner approved adding Cycle
recording proof after the report, with immersive Care last. There is one Today
frame. All marketing headlines are unchanged from the v8 manifest.

`compose_titled_app_pages.swift` adds a title band and fits each complete
native app screenshot beneath it. It draws no phone frame and preserves the
whole native view without changing its displayed controls or content. The two Plus-only Patterns screenshots
retain the small owner-selected `With Plus` badges inside the app image. All
visible records are fictional. `manifest.json` records routes, sources, copy,
and hashes; v8 retains the full-app capture provenance.

## Visual review

All nine were inspected at full image scale after composition. Titles fit in
the band; no app action is covered. Privacy has a complete `Done` control but
remains text-heavy. The report has a full matrix and check-in explanation,
but some category labels wrap awkwardly and the next `Blank in this range`
card enters at the bottom. These are known marketing-quality limitations of
the current native view and were disclosed in the owner's replacement
confirmation. ASC processed a nine-file upload in completion order, so the
images were reordered in Media Manager to the manifest's 01–09 sequence.
The order persisted on the version page after reload. No build, Review Notes,
review reply, or submission was changed in this operation.
