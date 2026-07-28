# Production Workspace Foundation Plan

Status: validated with native release gate deferred

1. Specification And Decisions
   - [x] Read repository instructions and all existing specifications.
   - [x] Record Flutter approval in the canonical technology decision.
   - [x] Create the dedicated feature branch and proposed specification.
   - [x] Obtain approval for requirements, proposed decisions, and validation.

2. Repository And Toolchain Baseline
   - [x] Establish root documentation, validation entry points, and repository
         hygiene.
   - [x] Pin or constrain toolchains and lock dependencies.
   - [x] Normalize production mobile metadata without expanding product scope.

3. API Foundation
   - [x] Scaffold the layered FastAPI application and typed configuration.
   - [x] Add the non-sensitive liveness and API smoke paths.
   - [x] Configure Ruff, strict Pyright, pytest, SQLAlchemy, and Alembic
         foundations.

4. Contract And Mobile Boundary
   - [x] Export a deterministic OpenAPI contract.
   - [x] Generate and integrate the Dart API client.
   - [x] Add drift checks for the contract and generated client.

5. Automation And Documentation
   - [x] Add clean-checkout CI for mobile, API, contract, and build checks.
   - [x] Document setup, configuration, boundaries, and common workflows.
   - [x] Verify secret, artifact, and synthetic-test-data hygiene.

6. Validation
   - [x] Run all locally available API, mobile, contract, and repository
         automated checks.
   - [ ] Build and launch on an iOS simulator (deferred to release preparation).
   - [ ] Build and launch on an Android emulator (deferred to release preparation).
   - [ ] Capture and review native screenshots (deferred to release preparation).
   - [x] Record results, limitations, and the user-approved native-gate deferral.
