# Release roadmap

This roadmap records delivery state, not a claim that target features have
shipped. See [validation](../validation/README.md) for dated evidence.

| Release | State | Scope |
| --- | --- | --- |
| 1.0 | Build 17 submitted for iPhone App Store review on 2026-10-03; manual release selected | Submitted product and App Store evidence are under `validation/1.0/` and `artifacts/app-store/`. Review approval and public availability are not recorded here. |
| 2.0 | Target; release gates open | Four-destination navigation, Comfort Window and Kit, revised Free/Plus report boundary, Quiet Dusk, Care relief and companionship, and consented operational analytics. [Requirements](features/release-2.0/requirements.md) and [plan](features/release-2.0/plan.md). |

## Next 2.0 work

1. Reconcile implemented behavior with the 2.0 requirements on physical iPhone
   and small/large supported layouts.
2. Add explicit confirmation before adjacent-period merging and preserve
   every attached cycle reflection; see the
   [period contract](features/period-and-cycle/validation.md).
3. Reconcile the legacy Cycle Check-in scheduler with the default-off,
   evidence-gated 2.0 Comfort Window reminder.
4. Complete qualified clinical review of SP6/LV3 locator art, instructions,
   and safety copy; correct and re-review any finding.
5. Verify real StoreKit purchase and restore, consent and privacy disclosures,
   notification opt-in, report exports, and account/deletion paths in the
   release configuration.
6. Run accessibility, safety, migration, and regression checks; record exact
   results in [2.0 validation](features/release-2.0/validation.md).
7. Submit only after those gates and final store assets are approved.

Android remains an engineering target; public availability is not promised by
this roadmap. Doctor Mode, cloud health backup, fertility and ovulation
prediction, and clinical diagnosis are outside this 2.0 release.
