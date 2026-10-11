# Today / Record V4 verification

Published base: Build17 `cf12e70791c14acb2735415b8c51b1ce6047fac2`. Branch: `feat/record-hub-build17-2026-10-10`. V4 follows the owner's Medication screenshot and request to optimize Medication, Supplement and Birth control; see [product composition](product-composition-v4.md). Superseded V2/V3 captures and failed attempts were removed from the active tree to prevent design agents from treating them as current; they remain recoverable from Git history.

## Final implementation

The shared manager presents compact product rows, one expanded period of use, and truthful daily status. Management moves into an adaptive action sheet. Additional use opens a focused editor with product/day, applicable details, original saved entry snapshots and an explicit Save additional entry. Other periods and archived sources remain accessible through collapsed history; dates, versions and exact source identities are preserved.

Create/edit forms put identity first, compact actual/effective dates second, and type/unit/route in themed catalog pickers. Exact dose/custom values and draft guards remain. Short editor/list content begins at the top rather than floating vertically in the middle. Expansion and touch feedback respect Reduce Motion.

Archive moves a period out of daily recording and prevents new entries; it retains actual dates, all saved uses and all detail versions. It is distinct from end-date correction and deletion. Archived periods without an end date say **No end date · Archived** rather than implying current ongoing use.

The displayed daily dose/name comes from the saved daily record's own version when one exists. A new additional entry uses the version applicable to its date. The UI distinguishes these real snapshots without rewriting them.

The shared temperature control retains exact typed precision and shows a concise hint when the wheels' hundredths differ from the exact input. The native-discovered synchronization fix remains covered by drag, accessibility, rapid-edit and blank-input regressions.

The complete [entry component audit](entry-component-audit.md) includes Today / Record primary and nested input routes. Shared degree and duration components retain each caller's labels, enum choices, zero/null and categorical/exact distinctions. Existing symptom/Moment immediate-save behavior and form Save boundaries are unchanged.

## Automated and source checks

- Full regression: **1041 passed, 1 optional test skipped, 0 failures**, process exit 0. [CLI result summary](v4/full-test-summary.json). The verbose reporter was removed after the result was summarized.
- Whole application `flutter analyze --no-pub`: **no issues**, 4.4 seconds.
- `git diff --check`: passed.
- Product scoped verification: **36 passed**, including existing editors, new real-Drift manager tests, domain and storage tests. Tests verify repeat/change daily-source identity, distinct additional entries, draft cancellation, stopped historical eligibility, actual end correction, archive and original version history, birth-control emergency semantics, and all three long-name managers at 320px / 2× text.

Frozen production fingerprint: `94d052fc6c892062e1c8e919bc357966bc4838572754cbebca8dead93cc4a6d3`. The snapshot contained 237 production Dart files and 17 changed/new presentation files against the integrated pre-pilot snapshot. The frozen audit recorded **protectedChanged: []**; generated hash inventories were removed from the active UI tree after summary. Earlier functional Record Hub integration changes are separate.

## Native / live status

V4 native verification passed on the isolated synthetic normal-size iPhone review device `7A533533-EA45-4735-AC28-10FA095A65FF`: process exit 0, **43/43** ordered captures at 402×874 logical pixels (1206×2622, DPR 3), default text scale. Schema 18, rendering exceptions 0. Child/product/period preview cancellation preserved source data; durable database reopen passed with 12 synthetic use periods and 9 use entries. Exact typed temperature 36.555 and its precision hint were verified. Ten representative frames remain in the [curated reference](../kimi-current-reference/README.md); the full batch is in Git history.

Two actual H.264 interaction recordings completed: Record 39.18 seconds and product manager 44.66 seconds. The bounded [V4 visual review](visual-review-v4.md) found no material blocker. The large recordings were removed from the active tree after review to avoid repeated model ingestion; Git history preserves them. Clip sampling did not establish frame rate or physical haptic quality. These V4 results precede the full-screen symptom and Today shortcut refinement.

The owner preview on `E45EAC1A-381E-44B0-AE71-684E3C693581` received V4 via its existing resident Flutter process: 9 libraries reloaded in 766 ms. Manager reassembly reloads saved sources read-only. No database reset, route replacement or forced Simulator clicks were performed. This reload duration does not measure motion performance.

No new JavaScript animation dependency, paid design provider, source/screenshot upload, bitmap generation, commit, merge, push or release was performed. The user-requested taste/Finesse/GSAP guidance was assessed for platform fit; appropriate design principles were implemented with existing Letter Within tokens and Flutter SDK components.
