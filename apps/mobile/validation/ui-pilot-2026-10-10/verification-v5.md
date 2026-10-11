# Today / Record V5 verification

Published base: Build17 `cf12e70791c14acb2735415b8c51b1ce6047fac2`, branch `feat/record-hub-build17-2026-10-10`. This refinement follows the owner's full-screen Symptom editor and direct Today Bleeding/pinned shortcut requests. [Completed V4](verification-v4.md) remains separate evidence for the product managers and shared controls.

## Implementation and product truth

Today replaces the broad Body overview with a Quick records area. Bleeding is a direct named row. The user's actual pinned symptoms appear in their saved order as compact touch-responsive shortcuts, showing the real saved degree or Not recorded. Explicit zero remains Not present, with saved styling. When no pins have been saved, a small selection from the existing catalog's curated default picks is labeled Quick symptoms, never Pinned by you. Large text stacks the shortcuts so their names and statuses remain readable. Sleep and Private note remain named entries; All records retains access to the complete hub.

A named Today symptom opens the shared full-screen native editor. Closing returns to the retained Today route; editing from regular Record returns to its retained list and scroll. The original picker session owns all degree/save/removal callbacks and the source records. The page has a safe-area header, date, degree control, real acknowledgment/errors, original-source impact editing/removal and the Record owner's guarded Undo. Opening does not write. Pending saves block exit; unfinished failed changes require a discard decision. Reduce Motion uses an immediate route transition.

The Bleeding shortcut expands and brings the existing bleeding controls into view. Its existing source, repeated-selection, zero/null and period-review behavior is preserved. This batch adds presentation intent/callbacks only; no data model, repository contract or API change is intended.

## Validation status

Production was frozen at `22fe6548ffde6378e4e327b1ce6576c77b9f0dc3eff5ae154cab72021eab7722` (237 Dart files). Its audit recorded six changed presentation files since V4 and **protectedChanged: []** relative to the integrated pre-UI baseline. Generated per-file hash inventories were removed from the active UI tree after summary.

Full regression completed: **1055 passed, 1 optional skipped, 0 failures**, process exit 0 and JSON reporter success true. [Summary](v5/full-test-summary.json). The full-screen/Record/navigation scoped batch passed **67 tests**; Today scoped batch passed **25 tests**, with overlap between runs. Whole application analyzer passed with no issues in 4.3 seconds. After the full regression, the only production change removed an unnecessary non-null assertion from the catalog symptom mapping; behavior is identical. The summary preserves its tested fingerprint `a541b54affaaf4f8e22686e9e37d99622c92a7a85108bd6f310d076fa876e15d`. The verbose reporter was removed after summary. Diff checks passed.

Owner interrupted the implementation workflow to request a Kimi UI handoff. V5 native fixture/driver are prepared with nine states and the frozen fingerprint, but **have not been run**. V5 has no native screenshots, interaction recording or visual review. The owner's resident preview still shows V4; no V5 hot reload was performed. Completed V4 native evidence does not validate the new V5 surfaces. Continue from the [Kimi handoff](../../../../specs/features/release-2.0/record-hub/handoff-kimi-ui-2026-10-10.md).
