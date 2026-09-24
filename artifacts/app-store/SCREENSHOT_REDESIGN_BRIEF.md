# Letter Within storefront screenshot redesign brief

Status: candidate v3 was owner-approved on 2026-09-24 and is awaiting upload.
Candidate v2 is preserved but superseded.

## Why the uploaded set is being replaced

The six screenshots currently in App Store Connect are not approved launch
masters. The owner found the strip coarse and identified three concrete issues:

- The Care and Patterns frames used obsolete app states.
- The clinician report looked like an empty explanation rather than a useful
  report with data.
- The set did not communicate the product's capabilities quickly enough at
  storefront thumbnail size.

## Fixed launch story

Letter Within is a private period companion and tracker. The first two promises
are fixed and should stay first everywhere the product is introduced:

1. Cycle care for the days that feel heavier.
2. Encrypted on your device. No AI.

Patterns and a populated clinician report are required proof points. The product
must not be described as diagnostic, as cloud-only, or as AI-powered.

## Independent review

On 2026-09-24, OpenRouter Claude Sonnet 5 reviewed the current native screens,
the uploaded storefront strip, and the product positioning. Its first-pass
findings were:

- Use eight frames. Six is too thin for the two promises plus product proof;
  ten invites padding.
- Lead Care with the chooser because it proves breadth and control. Keep one
  immersive scene to prove depth.
- Do not ship the disabled check-back frame. Keep the aggregated What helped
  view instead.
- Patterns must show realistic variation rather than four perfect 28-day
  cycles.
- The report must lead with a dense populated matrix, not explanatory copy.
- Crop into evidence and increase UI scale. A headline must not overpower the
  product proof beneath it.

The owner then requested all three tracker proofs and explicitly noted that all
ten store slots were available. A second image review compared Heavy, Focus,
Body, and Space and selected Heavy. Candidate v3 therefore uses all ten slots
without duplicating a state. The final order keeps Care and privacy first
because the owner designated them as the top two launch messages.

## Candidate v3 order

1. Care chooser: breadth of support and leave-anytime control.
2. Privacy: current Backup & restore controls proving password-protected,
   user-controlled movement of local records.
3. Populated Today: flow, color, and three saved symptoms.
4. Cycle days: five populated days with flow and color.
5. Day symptom editor: saved flow, color, moderate pain, and a recorded
   symptom row.
6. Cycle patterns: four completed cycles with 28-30 day variation.
7. Mood patterns: 11 harder days across four cycles.
8. Clinician report: 43 confirmed records across four cycles.
9. Immersive Care: Heavy, selected by Claude from Heavy, Focus, Body, and
   Space because it aligns most directly with the fixed heavier-days promise.
10. What helped: four Care actions with saved outcomes.

Candidate JPEGs are in `iphone-69/candidate-v3/final/`. Their synthetic native
sources are in `iphone-69/candidate-v3/source/`, and hashes are recorded in
`iphone-69/candidate-v3/manifest.json`.

## Visual system

- Canvas size: 1290 x 2796, JPEG, no alpha.
- Editorial New York headline and small Letter Within kicker.
- Daylight frames extend the app's exact `#FBF7F3` canvas with `#2A1626` ink
  and `#E4573D` ember. Care frames extend the app's exact `#2E1A33` to
  `#170D1C` world with `#F7EEE6` type.
- No separate marketing-only rose or plum canvas surrounds native UI.
- Real native app UI only. No generated or recreated interface.
- Product UI fills most of the frame and is cropped around evidence.
- Current synthetic history uses May 23 through September 19, 2026.
- All dates, cycle lengths, Care outcomes, and report records are fictional.

The reusable compositor is `../../tool/compose_app_store_screenshot_v2.swift`
when this file is read from the repository root; the canonical repository path
is `tool/compose_app_store_screenshot_v2.swift`.

## Website handoff

Do not redesign or deploy the marketing website as part of screenshot approval.
When website work resumes, use the same ten-frame narrative as the content
spine, but do not reproduce the App Store strip as ten equal cards. The web
page should lead with Care, answer trust with encrypted Backup & restore proof,
then demonstrate Patterns, clinician reporting, tracking breadth, and remembered
Care outcomes. Use the candidate native sources as product imagery.

The existing website handoff remains at
`/Users/clairehou/pyProjects/letter-cycle-companion/WEBSITE_REDESIGN_HANDOFF.md`.
Before implementation, reconcile it against this brief. Do not deploy without
explicit approval.

## Approval state

The owner approved replacing the rejected six screenshots in App Store Connect
with candidate v3 on 2026-09-24. This approval covers screenshot replacement
only. Do not submit the app version, attach build 11, add an in-app purchase for
review, change storefronts, push, or deploy as part of this handoff.
