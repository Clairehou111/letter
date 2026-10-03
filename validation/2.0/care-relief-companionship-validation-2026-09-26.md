# Care Relief and Companionship Validation

Status: automated and Simulator coverage substantially complete; replacement
SP6/LV3 locator art is installed and visually verified; qualified clinical
review and physical-device checks remain open

## Scope and Preservation

- [x] Work is on `release/2.0` in the designated worktree and existing
  unrelated changes are preserved.
- [x] The implementation is limited to the approved Care redesign, companion
  preference, assets, and necessary assembly/accessibility wiring.
- [x] Existing explicit completion, exit, safety, and persistence contracts are
  preserved.
- [x] The only new persisted Care value is the device-local companion name.
  Reports, Patterns, health records, analytics, exports, and completion payloads
  do not receive it.

## My Body Needs Care

- [x] Entry is body-feeling/practice first; no practice starts automatically.
- [x] Heat, gentle movement, massage, supported rest, and acupressure are
  optional and self-paced.
- [x] Essential positions and actions are visible in reading order without a
  required Next tap.
- [x] Rest and practices remain open without an automatic completion or exit.
- [x] Medical/safety support is reachable from the chooser and active practice
  paths.
- [x] `Explore acupressure` is a visible chooser entry; it is not silently
  hidden while art review is pending.
- [x] SP6 includes pregnancy/could-be-pregnant/unsure screening and shared skin,
  swelling, clot, bleeding-disorder, and blood-thinner cautions.
- [x] SP6 and LV3 provide point code/name, plain anatomical landmarks, gentle
  non-painful guidance, zoomable diagrams, and non-efficacy framing.
- [x] Replacement locator art shows visually credible SP6
  and LV3 locations at both phone size and enlarged zoom.
- [ ] A qualified reviewer documents approval of final point locations,
  self-pressure guidance, and safety copy before release.
- [x] Evidence-based AI pre-review checked the final candidate art and copy
  against WHO/VA/CDC/NCCIH guidance. Standard point names, approximate-measure
  wording, and explicit clot/emergency actions were applied. This is not a
  substitute for the qualified review above; anatomy and pregnancy guidance
  remain open release gates.

## Everyday Care and Cat Companion

- [x] Everyday care opens to its list and never auto-selects a ritual.
- [x] Rest, warmth, warm drink, shower, massage, lower-back release,
  knees-to-chest, and slow hip/pelvic movement remain user-ended.
- [x] Every key illustrated state includes an action-specific companion without
  obscuring the body, prop placement, copy, or controls.
- [x] Under full motion, the cat moves at calm irregular intervals: walking may
  change position, while sitting, stretching, and sleeping remain anchored.
- [x] Hidden/background states and Reduced Motion do not schedule companion
  movement; headache/light-sensitivity guidance remains dim and still.
- [x] Companion movement never advances, completes, persists, scores, or times
  the practice.
- [x] The elapsed companion line starts on practice entry, stops on exit, never
  persists, and is not presented as an efficacy measure.

## Companion Name

- [x] Settings shows the saved name and writes changes only after `Save name`.
- [x] Care does not show a first-use naming interruption.
- [x] Blank input does not write; surrounding whitespace is trimmed; Unicode
  is preserved; the visible limit is 24 characters.
- [x] The unnamed fallback reads naturally as `your cat`.
- [x] Existing privacy-preference payloads migrate without losing settings.

## Accessibility, Safety, and Quality

- [x] Essential controls use at least 44 logical-pixel targets and illustrations
  have screen-reader descriptions.
- [x] Paper surfaces use dark status-bar content and audited text contrast.
- [x] Reduced Motion retains the same instructions and controls.
- [x] No practice promises relief, treatment, diagnosis, hormone regulation,
  blood-flow change, or another medical outcome.
- [x] No Care practice is automatically selected or personalized from mood,
  symptoms, period, or other health records.
- [x] Re-run the focused Care/widget test after restoring the visible
  acupressure entry.
- [ ] Verify Dynamic Type, VoiceOver, Reduce Motion, daylight legibility, safe
  areas, and touch targets on a physical iPhone when available.

## Engineering and Visual Evidence

- [x] Approved editorial assets live under
  `apps/mobile/assets/images/care/editorial/` and require no new package
  dependency.
- [x] The approved Care manifest and staged-to-product map remain available for
  provenance; intentional post-apply fixes are recorded separately.
- [x] Formatting, analyzer, focused acupressure journey, full Flutter
  regression, and iPhone Simulator build passed after the entry restoration.
- [x] After the locator replacement, focused chooser → SP6/LV3 → safety →
  locator → zoom → back navigation passed, and iPhone 17 locator/zoom screenshots
  showed no clipping. Repeat any affected checks if clinical review requires an
  image or copy change.
