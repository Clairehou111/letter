> **Superseded baseline:** this historical report describes the earlier Build8-based branch. Its test counts, screenshots, schema17 and warm-background acceptance do not validate the current Build17 implementation. See [current Build17 evidence](implementation-evidence-build17-2026-10-10.md). Historical approval text and hashes below are preserved.

# Record Hub implementation evidence — 2026-10-09

Branch: `feat/record-hub-2026-10-09`. No commit/merge/push/release authorization.

## Owner approval

Owner: “批准。新建branch, 当letterwithin组件和原型冲突时，使用letterwithin中的组件”. This approves requirements/data-contract/validation and P-03…P-06 following the explicit confirmation in this session. P-01/P-02 remain as previously approved. Codex + GPT implement; no external design/model routing. Existing Letter Within components take precedence over prototype presentation conflicts; approved product/date/source behavior still governs.

Approved document SHA-256 (captured before ledger updates):

- `requirements.md`: `41062682e93dc7f9ccec553049728c9735b707a13f62e0e7bdfbef2a127c1a98`
- `data-contract.md`: `351c43da1ce890092f6d65c2a13cc26c1d9bf340061104acd5443cb30274ee64`
- `validation.md`: `29a5338cb521d8c1db918b539aa299ef603eb1d57e73add1ce32e3b09cd9273a`
- `plan.md`: `fc7181168475b0d6a8304db803e44120254e7c73c95f19c4ebc3ddecfd2e375b`
- `visual-brief.md`: `89f8554ba515201f91e7ccef3fcfee64359ef7ecf7cdb01d23b1b4cb1c427895`

## Baseline

Root and nested product dirty trees inspected; no existing changes overwritten. Local binary diff/status snapshot: `/private/tmp/record-hub-baseline-kh7eqq7y`. Existing untracked files remain in place.

Final preservation check: eight unrelated dirty files' per-file binary diffs
match that baseline byte for byte (`preserved-dirty-work.json` in validation
artifacts). These include `.gitignore`, the iOS project, NLP candidate, existing
onboarding repository/profile/privacy sheet, its dirty golden and manual QA
entry. Onboarding flow has only the coordinated programme integration within
the approved feature scope; the initial changes were retained.

Focused Flutter baseline: 41 tests PASS, exit 0. Command from `apps/mobile`:

```sh
flutter test test/drift_health_record_repository_test.dart test/letter_health_database_schema_test.dart test/letter_health_database_migration_test.dart test/observation_catalog_test.dart test/today_visual_port_test.dart test/drift_local_backup_store_test.dart test/letter_report_experience_port_test.dart test/entitlement_domain_test.dart test/notification_privacy_navigation_test.dart test/privacy_shell_test.dart
```

This is repository/widget baseline evidence, not native SQLCipher/device, accessibility, clinical or release acceptance.

## Implementation

Implementation completed on the existing dirty branch; tested base HEAD is
`ddf47c982e2e100d39021da4bb9b56aa4403081e`. App version remains `1.0.0+8`
(development test build, not an approved 2.0 release). Native database schema is
17. A final source inventory/hash is stored with the validation artifacts.

`apps/mobile/validation/record-hub-2026-10-09/source-manifest.json` inventories
403 source/test/fixture/native-config files (including preserved initial dirty
work, excluding build outputs/databases/signing secrets). Aggregate SHA-256:
`b988a6b32f199ec778c1735c55b93bbfdcb57728e6cb5809783e048fcfd60010`.
Regression-only source/test/pubspec aggregate:
`2a5b95fa813c34e16f691b2a9a27bbf9e6be09d60796935ac380522b73d7b949`.
Production and headless-test sources have not changed since the 730-test pass;
the subsequent changes are confined to the native capture fixture's scope and
integrity guards.

- Four persistent destinations and a central Record action; independent dated
  session, full calendar, guarded drafts, exact origin return and midnight/resume
  handling. All 40 incumbent symptom IDs and explicit 0–5 degree semantics are
  preserved. No Moment entry is added to historical Record.
- Shared symptom/date identity, independent impact, bleeding, date-bound notes,
  sleep/appetite/activity/context, manual BBT, stable pins, product episodes/use,
  exact action bundles/check-back and optional date-versioned programme sources.
  Seventeen additive typed tables live in the same encrypted local store.
- Immutable original timestamps/provenance, actual-write local timing, historical
  active-value recall, unchanged-save no-op and conditional delete/Undo. Legacy
  undated/unknown sources remain unknown. Moment correction/deletion lives in a
  low-frequency Settings source archive; it cannot create a historical Moment.
- Period merge/range changes require explicit review and revalidation; independent
  bleeding and Cycle Letter sources survive range shrink/deletion/merge. An
  archive keeps detached letters reachable. Old imports/migrations never silently
  merge adjacent period sources.
- Free factual programme summaries and method-separated BBT trends; no new
  diagnostic, fertility, dose or causal model. Versioned Comfort Window replay
  uses explicit zeros and current same-day sources, with canonical evidence and
  unchanged numerical support/reliability thresholds. The current cycle cannot
  train its own forecast.
- Durable user-confirmed preparation snapshots and source-change labels; default
  off Comfort Window reminder, explicit opt-in, 0/1/2-day timing, 09:00 local
  scheduling and cancellation/reconciliation. The old default-enabled scheduler
  is no longer invoked by production wiring.
- Exact source/range/category preview drives free raw CSV and recent factual
  Visit PDF; long/custom factual and Clinical PDF generation checks actual Plus
  file capability. Preview and already-generated files remain accessible after
  lapse. Reference prices are reconciled without replacing store-localized
  offers. Sensitive categories/text remain opt-in and unsupported sources fail
  closed. Backup/restore validates the full graph and rejects partial writes.

Presentation uses the active Letter Within components under the owner's explicit
precedence instruction. Earlier Quiet Dusk-only brief text is superseded where
it conflicts. Three relevant golden changes were reviewed; the pre-existing
dirty onboarding golden was preserved.

## Final automated verification — 2026-10-10

Commands run independently from `apps/mobile`:

```sh
flutter test --no-pub > validation/record-hub-2026-10-09/flutter-test.log 2>&1
flutter analyze --no-pub > validation/record-hub-2026-10-09/analyze.log 2>&1
```

Full suite: **730 passed, one skipped, zero failures**, exit 0. The skip is the
incumbent optional animation-capture test, enabled only when an output path is
supplied (`test/care_audit/care_animation_capture_test.dart`); it is not a skipped
Record Hub acceptance test. Whole analyzer: **No issues found**, exit 0. Product
`git diff --check`: exit 0. Native capture fixture scope was subsequently narrowed
by a test-only define and strengthened native integrity checks. Final whole
analyzer rerun after all native runs: **No issues found**, exit 0 (5.5 seconds).
The final source inventory accompanies the captures.

Toolchain: Flutter 3.44.8 stable, framework `058e0af2c2`, engine
`0cd610717b` / `13ffd72b2f9a5ca4db2a74ea52d5353ec2e8f939`, Dart 3.12.2.

Focused tests and full-suite regression cover:

| Area | Representative source evidence |
| --- | --- |
| Session/calendar/navigation | `record_session_test.dart`, `record_calendar_test.dart`, `record_hub_navigation_test.dart`, `record_hub_screen_test.dart` |
| Shared zero/timing/persistence | `record_hub_zero_compatibility_test.dart`, `record_hub_symptom_persistence_test.dart`, `drift_record_hub_repository_test.dart`, `health_records_domain_test.dart` |
| Context/interventions | `record_context_editor_test.dart`, `record_interventions_test.dart`, `drift_record_interventions_repository_test.dart`, `record_interventions_editor_test.dart` |
| Programme/facts | `record_programme_repository_test.dart`, `record_programme_facts_test.dart`, `record_programme_screen_test.dart`, `record_programme_navigation_test.dart` |
| Period preservation/confirmation | `period_preservation_confirmation_test.dart`, `period_repository_contract_test.dart`, `record_hub_bleeding_bridge_test.dart`, `today_cycle_period_coherence_test.dart`, `cycle_experience_history_test.dart` |
| Moment originals/correction/date | `moment_timing_persistence_test.dart`, `moment_correction_persistence_test.dart`, `moment_pattern_date_test.dart`, `moment_source_history_review_test.dart`, `record_report_moment_correction_test.dart` |
| Care completion/check-back | `care_action_recording_test.dart`, `care_memory_repository_test.dart`, `recovery_receipt_controller_test.dart` |
| CW/reliability/races/plan | `comfort_window_record_hub_test.dart`, `comfort_window_review_test.dart`, `record_preparation_review_test.dart`, `notification_privacy_navigation_test.dart` |
| Exact export/access/handoff | `record_report_export_test.dart`, `record_reports_experience_test.dart`, `record_native_file_handoff_test.dart`, `entitlement_domain_test.dart` |
| Full graph/migration/rollback | `record_hub_backup_test.dart`, `letter_health_database_migration_test.dart`, `drift_local_backup_store_test.dart` |

Earlier full regression had six failures. They were resolved with explicit
period-confirmation fixtures, a shared injected Care clock, scoped programme
scrolling, an actual wide Today closed-period branch fix and a Cycle archive
scroll adjustment. The failing log is retained as
`flutter-test-before-final-regressions.log`; the final whole suite above passed.
Tests were not disabled to obtain a pass.

## Native evidence and screenshot scope

All native fixtures use isolated fictional sources, their own temporary
SQLCipher database/key and actual native repository/save/reopen paths. They do
not open, copy or export the user's production database. No health values are
logged. The test key is synthetic, not a production credential.

**Owner update, 2026-10-10:** “不需要大小屏ios截图，只需要正常屏幕的就行。因为接下来我们会对控件进行优化。”
The requested handoff therefore uses a normal-size iPhone at default text.
Additional large/small iOS and large-text screenshot runs are not required.
Existing supplemental captures are retained and labelled separately; they are
not presented as normal-size acceptance. Android encrypted-storage proof is
independent of that screenshot reduction.

| Run | Result / evidence |
| --- | --- |
| iPhone SE native storage, final schema 17 | PASS, `ios-storage-final.log`; encrypted file signature, full typed graph, exact IDs/timestamps/provenance after reopen and restore |
| Earlier SE visual, schema 16 | 14 captures/renderer pass, archived `screenshots/ios-se-iteration-2-schema16/`; manual review found large-text masthead/navigation word wrapping, subsequently fixed; not final visual acceptance |
| Supplemental SE visual, schema 17 | PASS, 14 captures, archived `screenshots/ios-se-iteration-3-schema17/`; already running when screenshot scope was narrowed |
| Requested normal iPhone/default text | **PASS**, seven actual native PNGs individually reviewed by the primary agent, renderer exceptions 0; `screenshots/ios-normal-17-pro/`, `ios-normal-visual.log`. iPhone 17 Pro, iOS 26.5 (23F77), 1206×2622 physical / 402×874 logical, DPR 3, text scale 1, no display override |
| Android native storage, schema 17 | **PASS**, `android-storage-final.log`; Pixel_9 / sdk_gphone16k_arm64, Android 17 / API 37, build CP31.260623.009 dev-keys, physical 1080×2424 at 420 dpi unchanged. Extra Android screenshots skipped under the bounded handoff scope |

Exact device IDs, command strings and results:
[`native-run-manifest.json`](../../../../apps/mobile/validation/record-hub-2026-10-09/native-run-manifest.json).
Both storage fixtures assert encrypted file signature, all seventeen new entity
types, exact source metadata across reopen and atomic backup restore. iOS
storage used the SE simulator on iOS 26.5 (23F77); this is storage evidence rather
than a requested small-screen visual matrix.

Requested normal screenshots:
[`screenshots/ios-normal-17-pro/README.md`](../../../../apps/mobile/validation/record-hub-2026-10-09/screenshots/ios-normal-17-pro/README.md).
Reviewed Today, Record today, calendar, historical nonbleeding Record, explicit
zero and independent impact, inherited-date Sleep editor, and optional programme
with honest missing/elapsed/literal coverage. Ordinary scrolling hides content
outside the viewport; no clipped action/label or layout overlap was observed in
these seven captures. This is the owner's narrowed visual handoff, not full
physical accessibility acceptance.

Initial screenshot artifacts written inside app temporary storage were removed
by native-test cleanup; those missing files were not claimed as captured proof.
The host screenshot driver now preserves PNGs on the workstation. An initial
storage fixture selected a nonexistent Care target; the corrected fixture uses
the actual catalog target and passes. The failed log remains
`ios-storage-fixture-target-failure.log`.

Reviewer: primary Codex agent. Source assertions, screenshot observations and
physical/manual acceptance are separate evidence types.

The first normal-device run's widget assertions passed but all seven PNGs were
the identical launch screen. Manual visual FAIL is preserved at
`screenshots/ios-normal-17-pro-splash-failure/`. The next bounded probe's first
frame timed out (`ios-normal-first-frame-failure.log`). The failure was isolated
to a system account prompt
on the existing simulator. No account action was taken. A diagnostic containing
account information was immediately discarded rather than included in synthetic
evidence. The replacement uses one dedicated normal-size simulator with empty
account state. Native capture now requires a rasterized first frame and distinct
Today/Record/calendar PNG payloads; passing widget assertions alone cannot pass
the capture fixture. The dedicated normal simulator passed both integrity checks;
all seven final payloads differ, and their SHA-256 values are in its manifest.

## Independent release gates and known limits

- Physical-device VoiceOver/TalkBack, actual keyboard/focus recovery, Reduce
  Motion, regional emergency call/text handoff and actual OS notification
  permission/delivery remain manual release gates. Automated safety routes and
  scheduling/cancellation do not prove those external actions.
- Real StoreKit purchase/restore/offline release configuration and App Store
  declarations/metadata require independent release verification. Reference
  prices and capability fixtures do not claim a real purchase.
- Qualified clinical review remains required for affected interpretation/Care
  copy, including incumbent SP6/LV3 guidance. No diagnosis or clinical
  qualification is claimed by synthetic tests.
- Incumbent PDF font coverage cannot render every Unicode character. Unsupported
  selected glyphs produce an explicit generation failure; free UTF-8 CSV
  preserves the text. Native platform share/save-path and retained real files
  still require manual release-configuration verification.
- Broader device/control optimization is deferred by the owner. This iteration
  does not claim the full V-29 physical accessibility matrix or all V-01…V-30
  release gates complete.

No commit, merge, push, release or external design upload was performed.
