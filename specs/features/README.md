# Current feature contracts

These documents contain the detailed behavior that the 2.0 release contract
depends on. Read the [product rules](../product.md),
[architecture](../architecture.md), and [2.0 requirements](release-2.0/requirements.md)
with them. The 2.0 contract governs release scope, pricing, and visual direction;
the feature contracts govern record editing, provenance, and recovery. A known
code/spec difference is an open validation item, not a silently accepted change.

| Feature | Detailed contract |
| --- | --- |
| Shared data, estimate, and report rules | [data-and-reports.md](data-and-reports.md) |
| Periods, cycle history and estimates | [period-and-cycle](period-and-cycle/requirements.md) |
| Confirmed health records | [health-records](health-records/requirements.md) |
| Care and personal memory | [care-and-memory](care-and-memory/requirements.md) |
| Patterns and clinician records | [patterns-and-reports](patterns-and-reports/requirements.md) |
| Encrypted local recovery | [backup-and-restore](backup-and-restore/requirements.md) |
| Account, privacy and Plus | [account-and-access](account-and-access/requirements.md) |
| Onboarding and safety routes | [onboarding-and-safety](onboarding-and-safety/requirements.md) |
| Release 2.0 additions and gates | [release-2.0](release-2.0/requirements.md) |

The 2026 dated feature plans were removed from the working tree after their
current rules were reconciled here. Git history retains the original plans
and test records. Dated release execution evidence lives in
[`validation/`](../../validation/README.md).
