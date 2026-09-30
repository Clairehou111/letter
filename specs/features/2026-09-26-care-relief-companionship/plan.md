# Care Relief and Companionship Plan

Status: implementation integrated; SP6/LV3 redraw review and final physical-
device validation pending

This plan records the owner-approved implementation now present on
`release/2.0`. It replaces the earlier staging-only checklist so a later agent
does not regenerate approved Care work or remove the dynamic companion.

## 0. Approved Source and Visual Direction

- [x] Preserve the approved UI Forge apply manifest and staged-to-product path
  map as provenance for the Care implementation.
- [x] Apply the approved warm editorial illustration direction for `My body
  needs care` and `Everyday care`.
- [x] Keep the existing approved illustrations; do not redesign or regenerate
  them in a new conversation.
- [x] Use Settings, local-preference migration, and minimal Care assembly wiring
  for the device-local companion name.
- [ ] Replace SP6/LV3 locator assets through the original illustration
  conversation if the current art does not pass anatomical review, then inspect
  the replacements before overwriting product assets.

## 1. My Body Needs Care

- [x] Open with a body feeling/practice chooser instead of a continuous image.
- [x] Provide self-paced warmth, supported rest, lower-back release,
  knees-to-chest rest, slow hip/pelvic movement, massage, and safety guidance.
- [x] Keep every practice open until the person deliberately leaves or chooses
  the existing completion action; no practice auto-completes.
- [x] Keep `Explore acupressure` visible with SP6 and LV3 selection, safety
  screening, locator diagrams, zoom, restrained claims, and direct safety
  access.
- [x] Show the named-companion elapsed line without persisting duration or
  using it as a completion or efficacy measure.
- [x] Preserve body step IDs, build signature, shared exit, safety, and
  persistence semantics.
- [ ] Obtain documented qualified clinical review of the final SP6/LV3 art,
  location text, self-pressure guidance, and safety copy before release.
  An evidence-based AI pre-review has been completed and its noncontroversial
  clarity changes applied; it does not satisfy this qualified-human gate.

## 2. Everyday Care and Companion Motion

- [x] Open to the ritual list rather than auto-selecting a practice.
- [x] Include deliberate rest, warmth, warm drink, shower, massage,
  lower-back release, knees-to-chest rest, and slow hip/pelvic movement.
- [x] Keep essential action guidance readable without a forced Next step.
- [x] Keep every ritual user-ended; motion never completes, persists, or exits
  a ritual.
- [x] Preserve the dynamic cat as realistic companionship. Under full motion,
  it occasionally walks to a new position and then sits, stretches, or sleeps
  in place. Hidden/background states and Reduced Motion schedule no movement.
- [x] Keep headache/light-sensitivity guidance dim and still.
- [x] Keep illustrations free of electronic devices and avoid efficacy claims.

## 3. Companion Preference

- [x] Store the optional cat name only in existing device-local privacy
  preferences.
- [x] Edit or clear the name only from the `Care companion` Settings card.
  Care does not interrupt a difficult moment with a naming prompt.
- [x] Write changes only after the explicit Settings action, trim whitespace,
  preserve Unicode, reject blank input, and enforce a 24-visible-character
  limit.
- [x] Keep the name out of health records, Care completion payloads,
  analytics, reports, exports, and network requests.

## 4. Validation and Release Gate

- [x] Validate list-first Everyday care, body-feeling-first physical care,
  practice navigation, manual completion, safety access, elapsed time, Settings
  naming, and reduced/static motion behavior in the iPhone Simulator.
- [x] Run formatting, analyzer, focused tests, full Flutter regression, and
  diff checks after integration.
- [x] Preserve the approved product assets and record intentional code-level
  divergences from the original apply manifest.
- [ ] Validate replacement SP6/LV3 assets at phone size and enlarged zoom,
  then complete qualified clinical review.
- [ ] Complete final physical-device checks for Dynamic Type, VoiceOver,
  Reduce Motion, daylight legibility, safe areas, and touch targets when a
  device is available.

## Integration Constraints

- Work only in the designated `release/2.0` worktree and preserve unrelated
  uncommitted changes.
- Do not merge, push, deploy, submit to stores, or alter production store
  configuration without a separate explicit instruction.
- Do not replace the approved Care implementation wholesale. Resolve later
  integration conflicts field by field, with the current product Care files as
  the Care-side authority.
- Do not add package dependencies for illustrations. Approved raster assets
  live under `apps/mobile/assets/images/care/editorial/`.
