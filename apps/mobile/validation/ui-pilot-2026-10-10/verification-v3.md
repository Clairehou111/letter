# Today / Record V3 verification

Base: published Build17 `cf12e70791c14acb2735415b8c51b1ce6047fac2`. Branch: `feat/record-hub-build17-2026-10-10`.

## Implemented scope

The owner requested an audit of every Today / Record entry subpage. [entry-component-audit.md](entry-component-audit.md) records production routes, nested forms, managers, catalogs, confirmation dialogs, and compatibility-only Today fallback forms.

- Symptom severity, daily impact, sleep quality, cravings, activity/event intensity, and check-back target severity share `RecordOptionScale`, preserving their own values and labels.
- Sleep, activity, and What I tried share `RecordDurationPicker`, preserving categorical buckets versus exact minutes.
- Temperature supports manual whole/hundredths wheels and exact typed input. Selection edits a draft; Save remains the write boundary. Unit changes clear the draft reading rather than reinterpret it.
- Product forms retain precise dose text, typed units/routes, episode dates and version/use identities, with consistent themed controls.
- Record uses a layered, interruptible workspace transition and symptom expansion from the actual tapped origin. Notes show truthful Saving / Saved / Try again at the action.
- The duplicate Cycle letter archive and My preparation plan entrances are removed. Original reflections remain accessible within Cycle history; existing Comfort Kit and legacy persistence remain intact.

The V2 usability report is historical. The owner's rejection of its motion and visual quality is authoritative; it does not approve V3.

## Source and automated checks

The frozen snapshot includes 237 production Dart files; 17 changed/new presentation files relative to the integrated UI-pilot baseline. Domain, data, application and generated API sources are unchanged by this presentation iteration (`protectedChanged: []` in [V3 api-preservation.json](v3/api-preservation.json)). Earlier functional Record Hub integration changes remain in the working tree and are distinct from this comparison.

Final V3 production snapshot fingerprint: `79a3afd21d53ce81ef2cc17d157964b9b17f1e687923ff4eabe3889c418a4892`. It includes the native-discovered temperature synchronization fix. [The immutable V3 snapshot](v3/source-after.json) is preserved separately from later owner-requested product-manager refinements.

- Final full regression: **1030 passed, 1 optional test skipped, 0 failures**, [full-tests-v3.log](v3/full-tests-v3.log).
- Whole application `flutter analyze --no-pub`: no issues.
- `git diff --check`: passed.
- Focused coverage includes rapid workspace reversal, retained hidden drafts, active accessibility traversal, Reduce Motion, zero versus missing, exact temperature precision, source/version preservation, cancel/discard, and original reflections surviving period correction/merge/delete.

## Native and live preview status

The first actual V3 native attempt captured 20 of 28 states but **failed** the strict temperature precision assertion: typing `36.555` after wheel use displayed `36.56`. Programmatic wheel synchronization triggered selection callbacks. Its partial manifest is retained in [attempt-1](v3/attempt-1/screenshots/manifest.json) and does not verify reopen or cancellation. The fix ignores wheel notifications matching already synchronized positions, preserving exact input and genuine wheel/accessibility changes; a regression covers rapid typing, blank synchronization and returning to an earlier emitted value. The historical V2 log and screenshots are not counted as V3 evidence.

The corrected V3 rerun completed with **28/28 native states**, strict `36.555` preservation, encrypted database reopen, child-preview cancellation and period-preview cancellation verified, measured schema **18**, and **0 render exceptions**. [Actual native manifest](v3/screenshots/manifest.json), captured on the isolated synthetic review device `7A533533-EA45-4735-AC28-10FA095A65FF`; every PNG is 1206×2622 pixels / 402×874 logical pixels at default text scale.

[The actual Record interaction recording](v3/screenshots/ios-record-pane-interactions.mov) is 39.258 seconds, H.264, 1206×2622 pixels. The requested 90 ms Stage sample captured an intermediate opacity of 0.828; the requested 160 ms sample was already settled. These requested sampling intervals are not guaranteed physical elapsed frames or performance measurements.

The owner's normal-size iPhone simulator `E45EAC1A-381E-44B0-AE71-684E3C693581` received V3 via the existing resident preview process: initial hot reload updated 16 of 3265 libraries in 840 ms; the temperature fix then updated 6 libraries in 824 ms. The database was not replaced or reset. These are development reload durations, not measures of animation performance.

No measured physical haptics or animation frame-rate claim is made. Owner visual acceptance remains theirs to judge in the live preview.

## Subsequent owner steering

After this verification, the owner supplied a live Medication manager screenshot and requested further optimization of Medication, Supplement and Birth control, including ambiguous additional-use/end/archive buttons and the presentation of multiple periods of use. That separate refinement is in progress; the successful V3 fixture did not cover or approve the subsequent redesign.
