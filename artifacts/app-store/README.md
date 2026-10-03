# App Store assets

This folder contains the owner-approved iOS 1.0 App Store screenshot masters
and the source provenance needed to reproduce them. The uploaded set is
`iphone-69/candidate-v9/`; its nine titled JPEGs are in `final/` and its
manifest records the upload order, source routes, copy, and hashes.

## Current set

`iphone-69/candidate-v9/` was uploaded to App Store Connect on 2026-10-03
for the 6.9-inch English (U.S.) slot. The 6.5-inch slot inherits the set.
The order is:

1. Care chooser — Care for the moment you are in.
2. Today — Track more than period dates.
3. Comfort Kit — What helped before, kept close.
4. Privacy — Your health records stay encrypted here.
5. What helped — With Plus, compare what helped.
6. Mood Patterns — With Plus, notice harder-day patterns.
7. Clinician report — Bring a clear record to your clinician.
8. Cycle day editor — Keep the details that matter.
9. Immersive Care scene — A quiet moment to set it down.

Candidate-v9 uses the candidate-v8 full-app JPEGs as its source provenance.
Candidate-v8 remains the reviewable, app-only source set under
`iphone-69/candidate-v8/`; do not delete or replace those files without
updating the v9 manifest and the release evidence.

## Reproduction

The titled compositor is retained with the v9 set at
`iphone-69/candidate-v9/compose_titled_app_pages.swift`. The older reusable
compositors are retained under `tools/app-store/` for historical reproduction:

- `tools/app-store/compose_app_store_screenshot.swift`
- `tools/app-store/compose_app_store_screenshot_v2.swift`

These scripts only compose supplied native captures. They do not create app
screens, add device frames, or establish product behavior. All visible records
in the retained masters are synthetic.

## Claim boundaries

- The product's readable health records are encrypted in the local database.
  Account access and subscription entitlement remain operational cloud
  services, so storefront copy must not claim that nothing leaves the device.
- Letter Within does not use AI. Patterns and reports summarize saved
  observations deterministically and do not diagnose or promise an outcome.
- The clinician report summarizes user-recorded observations and is not a
  diagnosis.

Release status and remaining gates are recorded in
`validation/1.0/release-prep-2026-10-02/README.md` and
`validation/1.0/testflight-1.0.0-build-17/README.md`.
