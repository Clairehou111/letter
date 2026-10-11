# Record Hub on published Build17

Date: 2026-10-10. Implementation validation passed; no release claim.

## Source and correction

Owner instruction: everything must be based on Build17. The prior branch used an older Build8 checkout and is superseded. Existing component priority refers to the published Build17 components, including Quiet Dusk.

- Base: `cf12e70791c14acb2735415b8c51b1ce6047fac2`, published TestFlight 1.0.0 (17) source, including safe-area and iOS-on-Mac sharing fixes.
- Branch: `feat/record-hub-build17-2026-10-10`.
- Worktree: `/Users/clairehou/pyProjects/pms-research-agent/.worktrees/record-hub-build17`.
- Original dirty branch and initial user edits remain preserved in `product/letter`; recovery copy is `.record-hub-build17-recovery-2026-10-10`.
- No commit, push, merge, archive upload or release performed.

## Preserved Build17 behavior

Quiet Dusk tokens and native typography; existing Comfort Kit note opt-in and item overrides; persisted Comfort reminder consent, lead day, hour/minute and durable Not now; store-backed paid entitlement and isolated account state; no-card Preview restrictions; native SQLCipher key validation; bounded iOS-on-Mac share; spreadsheet formula protection; clinical calculation remains separately versioned legacy clinical logic.

Record Hub’s explicit-zero engine feeds the existing Kit and reminder components through an evidence-preserving projection. No fallback to legacy classifications occurs when this engine has insufficient evidence. Old cycle notification slot is cancelled, while old tap payload routing remains. Only explicit reminder opt-in can request permission.

## Storage compatibility

Schema18 preserves Build17 schema12 tables and values, and incorporates the dated Record Hub graph. Note backup v3 reads both historical v2 shapes; privacy v5 reads both v4 shapes. No legacy experienced date is inferred from creation time.

## Validation

Full regression: **966 passed, one optional capture skipped, zero failures**, exit0. Full Flutter analyzer clean; `git diff --check` clean. Final source inventory and test log are in `apps/mobile/validation/record-hub-build17-2026-10-10/`. The kept-note correction and all-note archive retain Build17 note read/edit/delete and Kit access; 16 focused archive/store/Record checks passed. Only two goldens changed for the added explicit-zero degree and scale copy. Existing 1–5 colors, core theme, platform files/assets, Auth, Plus and purchase implementations remain based on the published Build17.

Owner subsequently authorized representative synthetic screenshots for a **separate GPT UI/interaction expert review**, and requested immediate tap feedback and period range selection. Those review images are design evidence, not a release visual approval, and are captured on a separate normal-size simulator so the live review remains available. The historical 730-test result and schema17 screenshots are excluded from acceptance. Owner cancelled dark-page screenshots and requested direct simulator review; no new screenshots were taken. The normal iPhone17Pro simulator is launched from this worktree using `tool/record_hub_build17_preview.dart`: the actual LetterApp and encrypted native store, local development services, starts at Today without account/onboarding setup. Physical assistive-technology checks, real purchases, actual delivery and independent clinical review remain release gates.

Native encrypted storage: iOS E45 and Android emulator5554 each passed 2 tests: all-source encrypted reopen/atomic backup restore, and encrypted Build17 schema12 to18 migration preserving Kit and reminder values. Logs: `apps/mobile/validation/record-hub-build17-2026-10-10/{ios-storage,android-storage}.log`.
