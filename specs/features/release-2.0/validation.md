# Release 2.0 acceptance

Status: **open**. Detailed historical test evidence is in
[`validation/2.0/`](../../../validation/2.0/). A dated validation record is
evidence for its tested commit and environment, not automatic release approval.

| Gate | Required result | Current state |
| --- | --- | --- |
| Product contract | Four tabs, local deterministic Window/Kit, correct Free/Plus/report behavior, safety and deletion paths | Automated and simulator work recorded; final binary reconciliation open |
| Period editing | Explicit confirmation before adjacent merge; all absorbed flow and reflections preserved | Record Hub branch implements explicit immutable review/confirmation with stale-write rejection and retained bleeding/letter sources; repository/widget regression passed. Final release-binary/device reconciliation remains open |
| Reminders | Default-off, explicitly opted-in Comfort Window with Clearer evidence, timing choice and 09:00 default | Record Hub branch replaces the production legacy scheduler with default-off `ComfortWindowScheduler`, settings/opt-in/lead selection and deterministic cancellation; automated race/gate tests passed. Actual OS permission/delivery and release-configuration review remain open |
| Care clinical review | Qualified review and any correction/re-review of SP6 and LV3 location, guidance, and safety copy | Open; blocks affected point release |
| Native usability/accessibility | Physical iPhone, supported small/large layouts, Dynamic Type, contrast, screen reader, Reduced Motion, Care exit and safety | Final physical-device pass open |
| Purchases | StoreKit purchase, restore, preview, lapse, and offline reconciliation on release configuration | Real purchase/restore proof open |
| Privacy and analytics | Opt-in/off, payload boundary, deletion, public privacy policy and App Store declaration match build | Final declaration and configuration review open |
| Reports/data | Confirmed-only provenance, selected ranges, PDF/CSV output, migration, local backup/restore | Final release-configuration pass open |
| Store submission | Exact tested binary, localized prices, screenshots, review notes, and release control | Not submitted as 2.0 |

Do not call 2.0 released or gate complete until its evidence is recorded here
and the linked dated record identifies the tested build, reviewer, and result.

2026-10-10 branch evidence:
[`record-hub/implementation-evidence-2026-10-09.md`](record-hub/implementation-evidence-2026-10-09.md).
This updates obsolete implementation-defect descriptions; it does not mark the
release gates complete. The owner narrowed this iteration's screenshot scope
to a normal-size iPhone at default text, leaving broader control optimization
and physical accessibility review for subsequent work.
