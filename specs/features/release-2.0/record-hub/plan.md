# Record Hub implementation plan

Date: 2026-10-09; Build17 recovery update: 2026-10-10. Batches 1–6 implementation and automated regression are complete on the Build17 baseline: 966 tests passed, one optional capture skipped, analyzer clean. Current native storage/capture evidence and independent release gates are tracked in `implementation-evidence-build17-2026-10-10.md` and `validation.md`. Logical batches are not permission to ship separate partial releases.

## Batch 0 — preparation and approval

- [x] Identify active native routes and compatibility gaps.
- [x] Prepare requirements, typed data/state contract, native map and validation criteria.
- [x] Recheck all four existing HTML suites and inline JavaScript syntax.
- [x] Establish dedicated preparation branch; preserve user changes.
- [x] Prepare constrained Codex + GPT visual brief and synthetic capture scenarios.
- [x] Owner approves strict same-day and historical active-value later-recall rules (P-01/P-02).
- [x] Owner approves requirements/validation package including P-03…P-06 engineering defaults (2026-10-09; hashes in implementation evidence).
- [x] Obtain permitted native rendered preview and review key journeys. Earlier small-phone 1×/2× captures identified layout issues that were corrected. The owner subsequently narrowed screenshot acceptance to a normal-size iPhone at default text; future control optimization covers the broader size matrix.
- [x] Owner supersedes Kimi design gate: “不需要让kimi设计了，codex+gpt完成即可”. No external upload is necessary.

Stop before production Dart if requirements/validation are unapproved. Product IA is already accepted; Codex + GPT can implement within it after contract approval without waiting for Kimi. Rendered/native review belongs to the vertical-slice and final acceptance gates. No external design provider or browser-refusal workaround.

## Batch 1 — shared data foundation

Dependencies: approved RH/data/validation contract. Files centered on existing health-record domain/repository, encrypted database/local store, degree score semantics, local backup, notes and additive typed repositories.

- Replace positional score decoding with explicit 0–5 mapping; retain old 1–5 values and available/unavailable IDs.
- Introduce unknown provenance and immutable write timing metadata under approved policy; preserve initial recordedAt and source identity.
- Persist stable symptom pins separately from Care pins, typed overall impact and standalone bleeding, date-bound notes and manual BBT.
- Define additive entities for context/regimen/actions/programme/plan; migrations may be delivered with their dependency batch, but export/delete/backup contracts must exist first.
- Extend encrypted backup/import validation and transactional rollback/reopen tests. Never edit generated Drift files by hand or use plaintext health preferences.
- Add deterministic repositories/controllers and source revision invalidation; avoid product rules in widgets.

Exit: RH-014/015/016/017/040 and storage/timing acceptance tests pass, old fixtures decode identically, blank stays blank and malformed/newer backups fail without partial writes. No release-ready claim.

## Batch 2 — first native vertical slice

Dependencies: batch 1; approved requirements and the fixed visual brief. Codex + GPT author presentation directly, preserving incumbent controls/tokens.

- Reconcile shell to four tabs plus global action, move You capabilities to existing Settings access, preserve immersive Care exits/bar behavior.
- Add independent Record session/route/controller with captured origin/return context, full calendar, local clock and guarded date changes.
- Wire Today Add a symptom/Record more/global + and Cycle nonbleeding dates into the same route.
- Reuse native symptom picker and degree UI; add zero, pins, inline impact/note/bleeding and accurate named deferred-section entries only where the corresponding editor is implemented.
- Child close/save stays dated Record; Done returns to retained Cycle/source. Keep Today-only Moment and More. Reopen app proves durable facts, not transient history date.
- Add semantics, error/loading/empty/Undo and midnight/time-zone tests; collect native screenshots.

Exit: one real path Today/+ /Cycle → calendar → symptom/impact/first spotting → durable save → Done → reopen, on iOS/Android. No fake implemented buttons or silent dead ends. Existing navigation/Care/settings/regressions pass.

## Batch 3 — full dated recording

Dependencies: batch 2 plus corresponding typed entities/migrations.

- Sleep/activity/appetite/context editors with typed optional fields and preserved visible catalogs.
- Manual BBT capture and per-method dated trend; no prediction/reminder effect.
- Medication/supplement/method managers: exact names, episode start/stop/change, eligible historical use and emergency events; preserve affected history explicitly.
- Single What I tried with versioned base catalog, local reuse/custom target and bundles.
- Complete dated log source edit/delete, collisions, unsaved recovery and privacy-default export exclusions.
- Make every named Record section work for dates before first period, not just flow dates.

Exit: all in-scope non-Moment types save/edit/delete/reload correctly for today and historical dates. Context never becomes a symptom/prediction input. No invented recent records or inferred episode starts.

## Batch 4 — optional recording evidence and Prepare

Dependencies: shared entities and approved clinical/interpretation boundaries; do not copy HTML algorithms as clinical implementation.

- Persistent single programme from onboarding/Patterns, fixed native IDs+impact, optional Today continuation; date-versioned config/pause/resume/end history.
- Shared core/pin/catalog source updates, same-day vs recalled/unknown coverage and missing-date entries into Record.
- Free provisional/two-cycle facts through incumbent Spectrum/Twin source/adapters; keep literal completeness, elapsed cycles and CW support separate.
- Versioned Comfort Window classifier amendment and deterministic legacy replay; preserve existing voting/reliability/reminder gates, not current-cycle training.
- Gated Prepare → ordinary Care or real user-confirmed plan/Kit, durable snapshot/dismissal/history correction behavior.
- Native default-off reminder scheduling/permission/cancellation only after source eligibility; reconcile old scheduler before release.

Exit: zero/partial/persistent/recalled/unknown/paused/ended synthetic histories produce traceable factual output, never diagnoses or fake coverage. Clinical review is required before shipping affected interpretation/copy, not an automatic test PASS.

## Batch 5 — Care event/check-back/learning integration

Dependencies: action-event sources and approved incumbent Care boundary.

- Exactly-one automatic completion event; abandon/early exit creates none, retries idempotent.
- Manual outside-app history stays manual; no belated scheduled push.
- Preserve deep check-back/safety/reflections, add Mixed/Couldn’t try and optional target/unexpected fields with guarded drafts.
- Factual exact-target/exact-action-set grouping, bundles/unchecked counts; legacy unspecified target remains separate.
- Keep saved plan references and existing Kit behavior distinct; source changes do not rewrite the user’s authored memory.

Exit: completion, interrupted safety return, all outcomes, bundle attribution and unknown-target regressions pass without changing native gesture/audio/haptic runtime.

## Batch 6 — reports, privacy and whole-release acceptance

Dependencies: every included entity declared, access amendments approved and clinical wording reviewed where relevant.

- Reconcile requirements/entitlements/paywall/store/public copy for approved free/Plus factual/file boundaries; test preview/lapse/offline/purchases.
- Extend incumbent PDF/CSV pipeline with exact range/category/note previews, fail-closed unknown entities and explicit local saved path; no form snapshots in exports.
- Native backup/restore/delete coverage for all new entities, migration failure and rollback, encrypted reopen on iOS/Android.
- Real notification permission/delivery/cancellation, regional call/text handoff, report share/save-path and accessibility/device verification.
- Full analyzer/test/golden/integration regression, clinical review, physical-device acceptance and exact build evidence.
- Codex + GPT whole-system visual/interaction review with native screenshots and owner acceptance; no Kimi audit/apply prerequisite.

Exit: `validation.md` gates have dated build/device/reviewer evidence; original 2.0 trust defects are reconciled. Ask before commit/merge/push/release; none is authorized by this plan.

## Engineering and agent boundaries

Read the current AGENTS and skills before implementation. Product architecture/privacy/safety and final integration remain with the primary agent; use bounded delegated inventories/tests as allowed. The owner’s latest explicit instruction assigns this iteration to Codex + GPT and supersedes mobile AGENTS’ DeepSeek-only architecture/tests and Kimi-only presentation routing, as well as UI Forge’s external-author requirement. Do not wait for those services, impersonate their outputs or upload sources. This is a scoped override, not an edit to global agent instructions.

Preserve feature-first domain/data/presentation separation and established state management. Do not add Riverpod/BLoC/Provider merely because an instruction has a placeholder. The owner's later instruction, “当letterwithin组件和原型冲突时，使用letterwithin中的组件”, supersedes this package's earlier sole Quiet Dusk appearance instruction wherever it conflicts with the active Letter Within implementation. Reuse the incumbent warm-paper/ember theme, typography and native semantic controls; preserve platform adaptation. This changes presentation precedence, not source, date or clinical rules.

Candidate new file responsibilities, not mandated names: `features/record_hub/{domain,application,presentation}` for session/navigation; existing health repositories for shared symptoms; new typed context/regimen/action repositories wired into `LocalHealthStore`. The native map identifies active integration seams. Review planned file ownership/diffs before parallel implementation and never overlap dirty onboarding/privacy files without a narrow coordinated plan.
