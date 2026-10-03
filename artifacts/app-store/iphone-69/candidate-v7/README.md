# Candidate v7: one Today frame, Release 2.0 order

Status: **superseded local review draft; do not upload**. The owner approved
adding a later Cycle day editor frame; see `../candidate-v8/`. The ten approved
candidate-v4 screenshots remain live in ASC iOS 1.0. This eight-frame set uses
the recommended sequence in `marketing/launch-2.0/screenshot-order.md`:

1. Care chooser
2. Today, top of page only
3. Comfort Kit
4. Privacy
5. What helped — With Plus
6. Mood Patterns — With Plus
7. Clinician report
8. Immersive Care scene

The plan's Cycle overview is optional and omitted because the available native
view cuts the `Edit dates` control. Only one Today image belongs in this set.
The separate flow, symptoms, and Quick Note captures remain untouched in
`candidate-v6/` as internal validation evidence. The existing Today marketing
caption, **“Track more than period dates.”**, is retained in `manifest.json`
as requested; these app-only JPEGs have no external caption or phone mockup.

Each file is a 1320 × 2868 JPEG without alpha. All visible health records are
fictional. The sources are real navigation and scroll states in the complete
`LetterApp`, launched with an in-memory capture fixture. Frames 5–6 retain the
small owner-selected `With Plus` badges. `manifest.json` records exact source
files and hashes.

## Visual gate before upload

- Privacy (#4) is complete but text-dense; only its heading and section titles
  remain easy to read at storefront thumbnail size. Prefer a shorter true
  privacy view before replacing ASC images.
- Report (#7) has small, awkwardly wrapped category labels and a new card
  visibly cut at the bottom. It needs a cleaner complete-app recapture or an
  appropriate product UI correction before upload.
- Compare the final selected images with the release build. These fixture
  captures are not screenshots of the distributed Build 17 binary.

No screenshot was deleted from another candidate, and no ASC operation was
performed for this draft. Removing or uploading ASC screenshots requires a
separate operation-specific confirmation.
