# Letter Within Repository Instructions

## Mission

Build Letter Within as a private, local-first period and PMS/PMDD companion for North
American users. Product behavior must remain supportive, evidence-aware, and
useful during both emotional and physical symptom episodes.

## Sources Of Truth

- Product intent: `specs/product.md`
- Delivery order: `specs/roadmap.md`
- System and technology boundaries: `specs/architecture.md`
- Experience, data, and access: `specs/experience.md`,
  `specs/data-and-reports.md`, `specs/entitlements.md`
- Permanent decisions: `specs/adr/`
- Current release scope and acceptance: `specs/features/release-2.0/`
- Dated release evidence: `validation/`

Do not duplicate canonical decisions across instruction files. Application-level
`AGENTS.md` files add local rules and must defer to these specifications.

## Spec-Driven Workflow

1. Read `specs/README.md` and `specs/roadmap.md`; identify the current release
   contract or proposed change.
2. Confirm unresolved product decisions with the user.
3. Create a dedicated branch.
4. Update the release requirements, plan, and validation criteria, or create a
   scoped proposal beneath the current release directory.
5. Do not implement until requirements and validation criteria are approved.
6. Complete plan task groups in order and keep their status current.
7. Run all specified automated and manual validation.
8. Record limitations honestly and ask before merging locally.

Never push, deploy, or merge without explicit user instruction.

## Repository Rules

- Keep mobile and API code as separate deployable applications.
- Generate the mobile API client from the backend OpenAPI contract.
- Keep health records local by default.
- Never place health values, cycle dates, notes, report contents, or inferred
  health state in analytics, logs, crash metadata, or test fixtures based on
  real people.
- Use synthetic examples in tests and screenshots.
- Prefer narrow changes over unrelated refactors.

## Delegation Policy

- Use `gpt-5.6-luna` subagents for bounded, inexpensive work whenever the
  task can proceed independently: repository inventories, synthetic fixture
  preparation, prompt drafts, generated-code comparisons, isolated tests,
  analyzer/test runs, and visual-diff classification.
- Keep product decisions, privacy and safety judgments, cross-feature
  architecture, Lovable design direction, integration review, and final
  acceptance with the primary agent.
- Give implementation subagents disjoint file ownership and review their
  changes before integration. Do not duplicate delegated work locally.
