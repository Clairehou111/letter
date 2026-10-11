# Record Hub — Flutter development entry

Date: 2026-10-09; implementation update: 2026-10-10  
Status: implemented and validated on `feat/record-hub-build17-2026-10-10`, based on the published Build17 commit `cf12e70791c14acb2735415b8c51b1ce6047fac2`. Earlier Build8-based implementation and screenshots are superseded and do not validate this branch. Current evidence is recorded in [Build17 implementation evidence](implementation-evidence-build17-2026-10-10.md). Release approval is not recorded.

## Read this first

**Latest owner direction, 2026-10-10:** “现在我要让kimi来做UI优化，你写一个handoff”. Kimi may now take over UI optimization; this supersedes the earlier author/provider-routing prohibition below. Read the [current Kimi handoff](handoff-kimi-ui-2026-10-10.md) for the actual Build17 worktree, uncommitted implementation, owner feedback, protected contracts and V5 verification gaps. This handoff request does not itself upload any source or screenshots to an external service.

**Checkpoint authorization:** the owner subsequently requested “先 commit&push remote 当前分支”. The current implementation, specifications, tests, synthetic evidence and Kimi handoff may be committed and pushed to `feat/record-hub-build17-2026-10-10`. Earlier no-commit/no-push notes describe previous phases; this does not authorize merging or releasing.

This is a scoped successor beneath the current release directory, not a claim that Record Hub belongs to the approved 2.0 binary. The 2.1/2.2 allocation in the research scope identifies dependencies; it does not authorize separate shipping or silently change the current release. The owner approved development, a new branch and precedence of existing Letter Within components over conflicting prototype presentation.

Read in order:

1. [Requirements](requirements.md): approved product decisions and the amendments needed to incumbent contracts.
2. [Data and state contract](data-contract.md): dates, identity, provenance, zero, migrations and privacy.
3. [Native integration inventory](native-map.md): the active code paths, not old experimental screens.
4. [Implementation plan](plan.md): dependency-ordered batches and stop conditions.
5. [Acceptance and evidence](validation.md): native acceptance matrix and actual HTML results.
6. [Visual handoff](visual-brief.md): fixed IA and Codex + GPT presentation/visual acceptance boundaries.
7. [Today / Record UI pilot and owner revisions](ui-pilot-2026-10-10.md): Build17 styling, reference-motion iteration, all entry-form consistency, and removal of duplicate archive/preparation entrances. [Completed V4 verification](../../../../apps/mobile/validation/ui-pilot-2026-10-10/verification-v4.md) covers the shared product-page redesign. [V5 verification](../../../../apps/mobile/validation/ui-pilot-2026-10-10/verification-v5.md) records the subsequent full-screen symptoms and direct Today shortcuts.

Open the [current HTML prototype](../../../../../../prototypes/record-hub-html/index.html) and its [evidence/instructions](../../../../../../prototypes/record-hub-html/README.md). These resolve to the shared `/Users/clairehou/pyProjects/pms-research-agent` workspace, not only this nested product repository.

## What is settled

Four destinations Today / Cycle / Care / Patterns plus a global `+ Record` action. Today is always actual today. All complete-record entrances use an independent dated Record workspace; every occurred date is recordable, not just bleeding dates. Moment stays only on Today, with all twelve feelings in its focused chooser; Today also provides named Record shortcuts. Record changes date with a calendar and contains the existing Letter Within symptom vocabulary and degree controls. Pinned/catalog/programme records share source identity. Explicit zero is not missing.

## Approval ledger

| Gate | State | Evidence / next action |
| --- | --- | --- |
| Product IA and latest prototype | Owner accepted direction | Conversation: “sure. seems good”, followed by “ok …完成…开发flutter前的工作” |
| Development scope | Owner approved | New branch and native implementation; existing Letter Within components take precedence over conflicting prototype presentation |
| Native requirements/data/validation package | Owner approved 2026-10-09 | Requirements/data/validation and P-03…P-06 approved in current session; hashes and exact instruction in [implementation evidence](implementation-evidence-2026-10-09.md) |
| HTML logical checks | Passed | 155 overlapping synthetic assertions, rechecked 2026-10-09; `validation.md` |
| Rendered prototype / large text | Not verified | Prior local-file access was rejected; do not bypass that refusal |
| Design/implementation agent | Owner changed direction | Latest instruction: “不需要让kimi设计了，codex+gpt完成即可”; Kimi and DeepSeek-only routing are superseded for this iteration |
| External design uploads | Not needed or authorized | No Kimi call, upload manifest approval or external design service is required |
| Native migration/widget/export regression | Passed on Build17 | 966 passed / one optional capture skipped; analyzer clean; current results in Build17 evidence |
| Native visual scope | Owner changed 2026-10-10 | Live normal-size simulator review; subsequently authorized representative synthetic screenshots/interaction recording for independent GPT UI review |
| Native encrypted storage | Passed on iOS and Android | Two tests per platform: schema18 encrypted reopen/restore and Build17 schema12 migration; synthetic fixtures only |
| Clinical / physical device / purchase / actual delivery gates | Open | Automated tests and simulator captures do not complete independent release acceptance |

Do not turn this ledger into approval by editing a status word. Record the owner’s explicit approval and the relevant document hashes when it arrives. Do not restart the superseded Kimi workflow or silently use a paid design provider.

## Development boundary

Repository AGENTS were read, the dirty tree was preserved and package/validation approval was recorded before production changes. P-01/P-02 timing is explicitly approved. Codex + GPT own implementation under the latest owner override; Kimi/DeepSeek requirements in older handoffs or agent instructions do not block this iteration. Rendered/native visual and accessibility review remain acceptance work, not an external-design prerequisite.

No commit, merge, push, release, external source upload or real-user-data fixture is authorized by this package.
