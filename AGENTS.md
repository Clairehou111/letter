# Letter Repository Instructions

## Mission

Build Letter as a private, local-first period and PMS/PMDD companion for North
American users. Product behavior must remain supportive, evidence-aware, and
useful during both emotional and physical symptom episodes.

## Sources Of Truth

- Product intent: `specs/mission.md`
- Delivery order: `specs/roadmap.md`
- Technology decisions: `specs/tech-stack.md`
- System boundaries: `specs/architecture.md`
- Permanent decisions: `specs/adr/`
- Feature scope and acceptance: `specs/features/<feature>/`

Do not duplicate canonical decisions across instruction files. Application-level
`AGENTS.md` files add local rules and must defer to these specifications.

## Spec-Driven Workflow

1. Read `specs/roadmap.md` and identify the next proposed feature.
2. Confirm the feature priority and unresolved product decisions with the user.
3. Create a dedicated branch.
4. Create `requirements.md`, `plan.md`, and `validation.md`.
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

