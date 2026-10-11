# Record Hub native integration inventory

Inspected: 2026-10-09. All paths below are relative to `product/letter/apps/mobile/`. Line numbers are discovery hints, not immutable APIs. This is read-only source evidence, not a native test result.

## Active routes — edit these, not abandoned prototypes

| Responsibility | Active source | Integration consequence |
| --- | --- | --- |
| App composition / local store | `lib/app/letter_app.dart:147`, `:437` | Inject new repositories through existing composition; retain encrypted shared store |
| Shell | `lib/experience/letter_experience_shell.dart:89`, `:620` | Actual native bar is Today / Cycle / Care / Patterns / You; approved four-plus-action is not implemented |
| Active Today | Shell `_buildToday :668` → `lib/experience/today/today_experience.dart:57` | Uses TodayExperienceVisual and RepositoryTodayVisualPort; do not implement only in `today_experience_rebuilt.dart` |
| Today visual / adapter | `lib/experience/today/today_experience_visual_baseline.dart`; `today_visual_port.dart:46`, `:66` | Preserve current steps/controls and route complete recording into shared Record |
| Cycle details/day editor | `lib/experience/cycle/cycle_experience.dart:309`, `:339`, `:406`, `:3164` | Current code pops detail before day editor; new route must retain selected-cycle return context |
| Cycle period/backfill | Same file `:282`, `:295`, `:1994`, `:2591` | Keep range editors / bleeding accordion; complete-day links go to Record |
| Native symptom picker | `lib/experience/records/observation_picker.dart:34` | Reuse vocabulary, search, groups, degree controls, impacts and safety; avoid second picker behavior |
| Separate symptom forms | `lib/features/health_records/presentation/health_record_form_screen.dart:12`; `health_records_screen.dart:15`, `:275` | Reconcile new entrances with incumbent archive and source-correction API |
| Patterns source correction | `lib/features/patterns/presentation/personal_patterns_route.dart:124` | Currently opens separate form; dated sources should open Record with focused source and exact return route |

## Reusable sources and concrete gaps

| Layer | Existing evidence | Preserve / extend |
| --- | --- | --- |
| Encryption | `features/health_data/data/local_health_store_factory_native.dart:25`, `:51`, `:72`, `:98` | SQLCipher and one transactional database; no health truth in plain preferences |
| Health model | `features/health_records/domain/health_record.dart:3`, `:7`, `:89`, `:117`, `:138`, `:166` | Vocabulary v3, stable IDs, original recordedAt; add score zero and unknown provenance without reordering storage semantics |
| Health repository | `features/health_records/data/drift_health_record_repository.dart:39`, `:76`, `:128`, `:217` | Existing stable upsert/update; positional score decoder and unknown-provenance rejection need versioned repair |
| Database | `features/cycle/data/letter_health_database.dart:82`, `:99`, `:184`, `:266` | Inspected schema 11, symptom/day unique key, legacy rebuild preservation; next migration chosen only after current branch inventory |
| Flow/period | `features/cycle/domain/period_repository.dart`; `data/drift_period_repository.dart`; database `:16` | Existing flow is period-bound; standalone first spotting/no-bleeding requires explicit data support |
| Moment | `features/check_in/domain/moment_check_in.dart`; `data/drift_moment_check_in_repository.dart` | 12 states; timestamped create/delete. Today `saveMood` currently creates then deletes older same-day rows; review source-correction and derived difficult-evidence lifecycle explicitly |
| Care | `features/care/domain/care_memory_repository.dart:36`; `data/drift_care_memory_repository.dart:35`, `:61` | Outcomes/reflections/Care-record pinning are not symptom pins or new outside-action bundles |
| Post-Care health receipt | `features/recovery_receipt/application/recovery_receipt_controller.dart:49` | Already writes shared symptoms; must remain shared and avoid duplicate action completion |
| Notes | `features/capture/domain/capture_models.dart:47`; `data/drift_capture_note_store.dart:8` | Current model has text/source/createdAt only; needs dated-source extension without merging distinct authored forms |
| Pattern source | `features/patterns/data/repository_pattern_source.dart:12`, `:31`, `:61`, `:69` | Transactional read/update/delete boundary should include new sources and invalidation |
| Preparation | `features/preparation/domain/`, `data/drift_preparation_repository.dart` | Inspect incumbent Kit/plan types before adding a parallel store |
| Diary | `features/diary/domain/diary_enrollment.dart:82`, `:130`, `:192`; `diary_repository.dart` | Existing diary has separate string keys and 0–5 anchors; only in-memory implementation found, not schema-11 persistent shared symptoms |

No persistent symptom-pin, independent overall-impact, full context, regimen/method, manual BBT or manual action-bundle repository was found in the inspected native health layers. This is a bounded inventory conclusion; recheck before creating new repositories, not proof that no experimental file exists anywhere.

## Must-fix compatibility risks

1. `drift_health_record_repository.dart:133`: `.values[row.severity - 1]` breaks zero and can shift old values if an enum is inserted. Decode by stored score.
2. `experience/degree/degree_graphics.dart:680`: ramp index `severity.score - 1` becomes −1 for zero; zero needs distinct graphics/semantics. `experience/theme/experience_foundation.dart:100` documents a five-degree ramp.
3. `features/local_backup/data/drift_local_backup_store.dart:672`: validator rejects severity<1 and uses enum length as max. Update import/export versioning, not only form controls.
4. Health provenance only accepts same_day/later_recall. Unknown legacy timing needs a controlled decoder/migration path; no guessed same-day values.
5. `cycle_experience.dart:1341` and `health_record_form_screen.dart:49` derive provenance from viewing/editor date. Opening history must be read-only; only actual changes classify active value.
6. `today_visual_port.dart:143` reads `notes.firstOrNull?.text`, the newest note across all dates. Do not display an historical Record note on Today.
7. `health_record_form_screen.dart:117` permits clock+1 day, contrary to occurred-day Record policy. Older Cycle pickers also impose shallow year bounds; make common date validation coherent.
8. Diary keys such as `depressedMood`, `lowInterest`, `sleepChange`, `physicalSymptoms` are not interchangeable with native symptom IDs. Broad aggregates cannot be silently mapped to one symptom.
9. `features/cycle/domain/local_date.dart` supports date/epochDay and leap-day arithmetic; shell today uses a clock callback while Cycle receives a time snapshot. Resume handler currently addresses screen cover, not explicit midnight refresh.
10. Current native five-destination index/controller and You route must be reconciled without losing Settings/account/privacy/purchases. Replacing the visible bar alone is insufficient.

## Existing tests to extend

These files are baseline candidates, not proof that the iteration passes:

- `test/drift_health_record_repository_test.dart`: stable symptom/day upsert, timestamps, delete.
- `test/letter_health_database_schema_test.dart`: unique symptom/day, foreign keys/cascades.
- `test/letter_health_database_migration_test.dart`: v7/v10/v11 preservation and legacy recovery.
- `test/drift_moment_check_in_repository_test.dart`, `test/drift_care_memory_repository_test.dart`, `test/recovery_receipt_controller_test.dart`.
- `test/today_visual_port_test.dart`, `test/today_visual_baseline_test.dart`: shared Today/Cycle facts and incumbent controls.
- `test/cycle_experience_history_test.dart`, `test/cycle_period_reachability_test.dart`: date conversion, day editing, historical reachability, merge/delete paths.
- `test/observation_catalog_test.dart`: stable definitions, safety metadata, available catalog.
- `test/diary_domain_test.dart`, `test/diary_two_cycle_validation_test.dart`: zero/missing/recall/pause/end semantics, currently in-memory synthetic evidence.
- `test/drift_local_backup_store_test.dart`, `test/local_backup_service_test.dart`, `test/patterns/repository_pattern_source_test.dart`.
- `integration_test/native_storage_acceptance_test.dart`: native key reopen, encrypted persistence, schema10 migration. Extend and rerun on native targets; browser/in-memory success cannot substitute.

Before coding, inspect report/entitlement/notification/You-route tests under the current tree and record a baseline. Never delete or skip a failing test just to match the new design.

## Dirty-tree handoff

Nested product branch created for preparation: `docs/record-hub-preflight-2026-10-09`, from `docs/current-specs-in-product`. No commit was created. Existing modifications remain in `.gitignore`, iOS project configuration, NLP, onboarding/privacy flows and their tests/golden, and `tool/manual_qa_app.dart`; `.agents/` is untracked. These are not this preparation’s changes.

Root repository separately has an existing README modification and untracked corpus/prototypes/research/scripts/ui-forge-kimi. Do not reset, clean, stage wholesale or overwrite those changes. Re-run `git status` in both repositories in the new session. The only product files created by this preparation are under `specs/features/release-2.0/record-hub/` and the small spec-index link.
