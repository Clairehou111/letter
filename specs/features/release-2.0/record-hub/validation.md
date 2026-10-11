# Record Hub acceptance and evidence

Date: 2026-10-09; Build17 recovery update: 2026-10-10. Implementation regression: 966 passed, one optional capture skipped; analyzer clean. Native encrypted storage and rendered synthetic captures were run; the durable result summary is in [Build17 implementation evidence](implementation-evidence-build17-2026-10-10.md). Generated logs and inventories were removed from the active tree after verification and remain in Git history. A planned assertion is not evidence. Requirements approval and release approval are distinct.

## Evidence already available

Read-only recheck against current standalone HTML, isolated jsdom storage, no network/native production data:

| Suite | Result | Meaning |
| --- | --- | --- |
| `prototypes/record-hub-html/check.cjs` | 48/48, exit 0 | Incumbent interaction scenarios |
| `iteration-check.cjs` | 50/50, exit 0 | Added evidence/Care/privacy acceptance |
| `goal-audit.cjs` | 11/11, 0 HTML gaps, exit 0 | Bounded product-goal probes |
| `daily-record-check.cjs` | 46/46, exit 0 | Dated-workspace/navigation/catalog/calendar cases |
| One inline script via `new vm.Script` | PASS | JavaScript syntax only |

Total 155 intentionally overlapping synthetic assertions. The prototype is clock-fixed to 2026-10-08. Test names that still say “Today date navigation” use the global Record/calendar helper and explicitly assert Today never changes to history. No rendered layout, physical-device, clinical or native persistence/migration result is implied.

Commands from workspace root, with an existing jsdom installation:

```sh
env NODE_PATH=/private/tmp/record-hub-cycle-qa.OAgkIB/node_modules node prototypes/record-hub-html/check.cjs
env NODE_PATH=/private/tmp/record-hub-cycle-qa.OAgkIB/node_modules node prototypes/record-hub-html/iteration-check.cjs
env NODE_PATH=/private/tmp/record-hub-cycle-qa.OAgkIB/node_modules node prototypes/record-hub-html/goal-audit.cjs
env NODE_PATH=/private/tmp/record-hub-cycle-qa.OAgkIB/node_modules node prototypes/record-hub-html/daily-record-check.cjs
```

That temporary dependency path is not a repository dependency or guarantee for a later session. If missing, use an existing permitted jsdom installation or request installation approval; do not rewrite tests to remove dependencies or bypass a permission refusal.

## Native acceptance criteria

Each case requires synthetic fixtures and appropriate unit/repository/widget/integration/manual evidence, not every case as a screenshot.

| ID | Contract | Required native assertion |
| --- | --- | --- |
| V-01 | RH-001/002 | Four destination states; + does not select a fifth tab; You/settings/account/privacy/purchases reachable; active Care bar hidden and safe exit preserved |
| V-02 | RH-003/005 | Fresh + from every visible tab uses actual today; old historical session cannot seed next +; Done restores origin |
| V-03 | RH-004/006 | Any occurred day before first period/premenstrual/nonbleeding can access complete record; future writes rejected at domain and picker |
| V-04 | RH-005/006 | Child save/close and Choose today keep Record; Cycle day/Fill-in/Patterns source return to exact retained detail/list, no historical Today |
| V-05 | RH-006 | Calendar month/year, 2000 leap vs 1900, cross-year cycle bounds, future disabled, saved markers, cancel and one-tap selection; semantic keyboard/screen-reader behavior |
| V-06 | RH-010/013 | Moment/More only Today; existing Moment sources preserved; Mood-category severity remains full catalog; all 40 available IDs/quick picks/aliases/groups match incumbent |
| V-07 | RH-011/034 | Positive Moment creates no zeros/non-hard day; difficult signal is derived, no duplicate Hard-day row; source edits/deletes recompute under explicit version |
| V-08 | RH-012/020 | 2–4 stable pins persist/reorder; remove does not delete history; no auto phase/recent replacement; visible named complete sections and honest empty states |
| V-09 | RH-014 | Zero round-trip; old 1–5 decode unchanged; missing remains missing; selected degree withdrawal/Undo preserve source ID/date/timing; score graphics never index −1 |
| V-10 | RH-014/015/030 | Pin/catalog/core/receipt share symptom/date identity across concurrent writes and reopen; independent impact never inferred and optional domains not copied from symptom impacts |
| V-11 | RH-016/043 | First spotting/explicit no bleeding without period; color/clots progressive; period start/end validation, adjacent-merge confirmation, all flow and letters retained |
| V-12 | RH-017/005 | Durable save precedes success receipt; failed write leaves recoverable state; date/exit guard note/forms; safety round-trip restores fields/date/focus; Undo never overwrites newer edit |
| V-13 | RH-017/040 | Historical note remains on its day, never latest-any-date Today leak; undated legacy notes readable without guessed date; Quick note/Care reflection/Cycle Letter stay distinct |
| V-14 | RH-021/024 | Context typed optional fields, categorical vs exact duration distinction including 30+; custom choice requires meaningful custom text; no bucket midpoint or inferred causal score |
| V-15 | RH-022 | Entered BBT unit/value/method/time/flags persist, distinct method series; no prediction/reminder change; no imported source claimed |
| V-16 | RH-023 | Episode alone≠Taken; historical stopped episode eligible use; actual start requested; overlap/change/stop/cascade policy explicit; emergency method events privacy defaults off |
| V-17 | RH-024/025 | Manual reuse template creates nothing until Save; completion token gives exactly one Care event, retry safe; abandon gives none; historical manual source never schedules retroactive push |
| V-18 | RH-025/026 | Five outcomes, skip/no outcome, target severity optional, adverse safety/draft recovery; bundles one outcome and unspecified targets isolated; all outcomes/unchecked counts visible |
| V-19 | RH-030/031 | Onboarding/Patterns one persisted programme; stable core IDs shared; config changes dated/versioned; pins independent; no duplicated diary rating store |
| V-20 | RH-031/032 | Missing/partial zero/unknown/recall/pause/end remain distinct; approved P-02: changing an old same-day value retains original source ID/recordedAt/original provenance, updates active provenance to later_recall and removes that value from prospective completeness; history viewing and unchanged save are no-ops |
| V-21 | RH-033/034 | Elapsed/literal complete/CW eligible distinguished; free partial/persistent/zero facts accessible without 9/3 CW gate; typical/peak/distribution and source provenance visible |
| V-22 | RH-033/034/035 | Versioned amended CW + legacy replay; completed cycles only, existing thresholds, no current-cycle training; change/delete/Undo/restore invalidates sources and reminders deterministically |
| V-23 | RH-035 | Prepare interval/reliability gates, ordinary Care without plan/Kit, durable snapshots/references, stored dismissal and explicit notification opt-in |
| V-24 | RH-040/041 | Zero health payloads in analytics/logs/crash; category consent default off; unknown entity/form snapshot excluded; exact preview equals actual serialized selected fields |
| V-25 | RH-042/043 | Free/Plus/preview/lapse/offline matrix includes raw CSV/recent factual PDF/long custom clinical exports; exact range, actual local saved path/share and retained generated files |
| V-26 | RH-040/043 | Encrypted device reopen; old schema/backup lossless upgrade; zero/unknown/new entity backup round-trip; unsupported newer version/injected failure reject atomically; local deletion complete |
| V-27 | RH-002/005 | Approved P-01: previous-date writes at 00:01, 03:59 and 04:00 local are all later_recall (no grace), current-date write same_day; injected midnight/resume refresh, captured Record date, DST/zone stability and newly future write blocking |
| V-28 | RH-043/044 | Offline regional safety, severe/adverse priority, manual call/text handoff and return; no automatic dial/diagnosis/fertility/dose recommendation; conditional import not exposed |
| V-29 | RH-001…044 | Small/large iOS/Android and large text: no clipped calendar/form/nav/action, ≥44px targets, readable labels, focus recovery, contrast, Reduce Motion and screen readers |
| V-30 | RH-001…044 | Full incumbent Care/period/pattern/report/account/onboarding/privacy regression; no unrelated dirty work overwritten or release gate silently marked complete |

V-01…30 cover every RH requirement; final native evidence must reference case IDs and source/spec commit hashes. Clinical interpretation claims are independently reviewed, not satisfied by a widget test.

## Execution ledger — 2026-10-10

The full suite covers the repository/widget portions below. These entries name
actual automated evidence; they do not declare every manual clause of each case
passed. Fixture files below are relative to `apps/mobile/test` unless stated
otherwise. Native schema is 17; development version is `1.0.0+8`, on branch
`feat/record-hub-2026-10-09` over base HEAD
`ddf47c982e2e100d39021da4bb9b56aa4403081e` plus the preserved dirty tree.

| Cases | Recorded evidence | Remaining boundary |
| --- | --- | --- |
| V-01…04 | `record_hub_navigation_test.dart`, `record_session_test.dart`, `record_hub_screen_test.dart`; real shell/Record native journey fixture | Physical route/focus review is separate |
| V-05 | `record_calendar_test.dart`; native month picker/future-disabled/saved marker captures | Physical keyboard/screen-reader traversal |
| V-06…10 | `record_hub_zero_compatibility_test.dart`, `record_hub_symptom_persistence_test.dart`, `record_hub_facts_test.dart`, `drift_record_hub_repository_test.dart`; native explicit-zero/source reopen | No historical Moment creation; device assertions cover a representative source, not every catalog item |
| V-11 | `period_preservation_confirmation_test.dart`, `record_hub_bleeding_bridge_test.dart`, `period_repository_contract_test.dart`, `cycle_experience_history_test.dart`, migration tests | Final release-binary/device reconciliation |
| V-12…13 | `record_hub_screen_test.dart`, context/editor fixtures, source/export tests; conditional Undo and failure/draft guards | Physical safety/focus return with OS handoff |
| V-14…16 | `record_context_editor_test.dart`, `drift_record_hub_repository_test.dart`, `record_interventions_test.dart`, `drift_record_interventions_repository_test.dart`, `record_interventions_editor_test.dart` | Final manual full-editor review; no prediction/dose claim |
| V-17…18 | `care_action_recording_test.dart`, `care_memory_repository_test.dart`, `record_interventions_test.dart` | Physical audio/haptic/gesture and interrupted safety runtime |
| V-19…21 | Programme repository/facts/screen/navigation tests; actual optional programme native capture | Qualified clinical interpretation review; factual counts are not qualification |
| V-22…23 | `comfort_window_record_hub_test.dart`, `comfort_window_review_test.dart`, `record_preparation_review_test.dart`, notification/privacy tests | Actual OS permission, timed delivery/cancellation and clinical copy review |
| V-24…25 | `record_report_export_test.dart`, `record_reports_experience_test.dart`, `record_report_moment_correction_test.dart`, `record_native_file_handoff_test.dart`, access tests; actual generated PDF/CSV in tests | Native platform share/save paths, retained files and real StoreKit release behavior |
| V-26 | `record_hub_backup_test.dart`, migration/backup tests; `integration_test/record_hub_storage_acceptance_test.dart` native SQLCipher reopen/full graph restore PASS on iOS 26.5 and Android 17 / API 37 | Final release configuration still independent |
| V-27 | Session, symptom/Moment timing, `moment_pattern_date_test.dart`, privacy scheduler/resume tests; captured Record date in native journey | Real device zone/DST and resume behavior |
| V-28 | Existing safety/native route and adverse draft fixtures run in full suite | Actual regional call/text handoff and physical return; no automatic call |
| V-29 | Earlier SE 1×/2× captures and automated compact/large-text tests; seven normal iPhone 17 Pro / 402×874 / default-text native screenshots individually reviewed PASS under owner's revised scope | Further control optimization and physical accessibility review deferred; no full device matrix PASS claim |
| V-30 | Whole analyzer clean, 730 passed / one optional capture skipped; reviewed three relevant goldens, dirty baseline preserved | Final binary, clinical, physical-device and store release acceptance |

The optional skip is the pre-existing `care_animation_capture_test.dart`, which
requires an explicit output path; no Record Hub test was skipped. Earlier failed
regression/capture attempts are preserved and explained in implementation
evidence. Source inventory hashes and exact native device manifests accompany
the final artifacts.

Owner screenshot scope update: “不需要大小屏ios截图，只需要正常屏幕的就行。因为接下来我们会对控件进行优化。”
Normal-size iPhone/default-text screenshots satisfy this iteration's requested
visual handoff. Extra small/large iOS, large-text and compact Android screenshot
runs are not required; already-produced supplemental evidence remains labelled.

## Synthetic scenario pack

Reuse explicit prototype scenarios as behavior references, not production seeded history:

1. Quick: no programme, first spotting, one Moment/pin, missing other fields.
2. Guided: selected core+impact, overlapping pin/catalog updates to same source.
3. Recalled/unknown: history view unchanged; changed past active value recalled; incomplete prospective coverage.
4. Paused/ended: dated pause and unresolved legacy pause; sources retained after ending.
5. Zero/persistent/partial: two-cycle factual views distinguish complete zero, persistent symptoms and missing fields, without diagnosis/false difference.
6. Clearer/Prepare/Care: synthetic reliable window, ordinary Care/plan lifecycle, exact-target bundles and private export selections.
7. Migration/failure: old score/notes/flow/reflections, failed commit, duplicate upsert, newer backup and storage-unavailable state.
8. Date boundary: leap/century/cross-year, local midnight, DST/zone change and date becoming future.

## Native execution and evidence format

From `product/letter/apps/mobile`, run baseline focused tests before changes, then focused tests per batch, followed by `flutter analyze` and `flutter test` at integration. Add widget/semantics and approved representative goldens; do not wholesale regenerate them to hide differences. Native SQLCipher integration tests require supported iOS/Android device/emulator and actual storage assertions.

Device sizes and exact test commands should be resolved from current repo/device availability before capture, not fabricated here. Minimum visual states are defined in `visual-brief.md`. Browser screenshots do not count as native simulator/physical-device acceptance.

Record each gate: date, tested commit/dirty diff hash, build number, OS/device/viewport/text scale, exact command/scenario, expected/actual result, screenshot/log artifact path, reviewer, unresolved defect and next action. Health examples in artifacts must be synthetic; diagnostics must not contain real health values.

## Open independent gates

- Native domain/schema/widget implementation and whole automated regression have passed; simulator encrypted-storage/capture evidence is linked above. These results do not close the independent release gates.
- Rendered HTML mobile/large text/keyboard accessibility remains unverified; prior rejected local-file access was not bypassed.
- External Kimi design/upload/system/apply gates are cancelled by the latest owner instruction; no Kimi request or upload occurred. Codex + GPT rendered/native visual acceptance still requires actual evidence.
- Clinical language/engine qualification, physical-device screen-reader/safety, actual notifications, account/purchases and PDF/share/save-path require evidence before affected release.
- Existing release-2.0 period-merge/reflection and legacy reminder implementation defects are corrected on this branch with automated source-preservation/confirmation and scheduler evidence. Final binary/device/actual notification release checks remain open; this package does not declare the release complete.
