# Production Workspace Foundation Validation

Status: validated with native release gate deferred

## Automated Requirement Coverage

| Requirement | Validation |
| --- | --- |
| REQ-001 | Root structure test or check confirms both apps, contract output, documentation, and independent application entry points |
| REQ-002 | Clean dependency sync uses committed locks; toolchain versions satisfy the documented constraints |
| REQ-003 | Mobile metadata tests or inspections confirm Letter naming and identifiers; Flutter formatting, analysis, and tests pass |
| REQ-004 | API tests exercise application creation, typed settings, liveness, versioned routing, and layer import boundaries |
| REQ-005 | OpenAPI export and Dart generation are reproducible; drift checks pass from a clean tree |
| REQ-006 | API smoke test matches the contract and generated Dart client compiles against it |
| REQ-007 | Local aggregate checks and clean-checkout CI run the same required quality gates |
| REQ-008 | Configuration tests reject invalid required values; ignore/secret checks pass; captured logs contain no request bodies or health values |
| REQ-009 | Repository hygiene check rejects generated caches, local configuration, build output, screenshots, and coverage |
| REQ-010 | Documentation check confirms setup, commands, boundaries, contract flow, environment handling, and synthetic-data guidance |
| REQ-011 | Native build smoke checks pass; manual simulator/emulator launch and screenshot review pass |
| REQ-012 | Dependency, route, and repository review confirms excluded product and infrastructure scope was not introduced |

## Required Commands

The implementation may add a root aggregate command, but it must run these
underlying checks without weakening them.

API:

- `uv sync --locked`
- `uv run ruff format --check .`
- `uv run ruff check .`
- `uv run pyright`
- `uv run pytest`

Mobile:

- `dart format --output=none --set-exit-if-changed lib test`
- `flutter analyze`
- `flutter test`
- `flutter build apk --debug`
- `flutter build ios --simulator --no-codesign`

Contract:

- export OpenAPI and fail if the committed contract changes
- regenerate the Dart client and fail if committed generated sources change
- analyze and test the mobile application after generation

Repository and CI:

- run the aggregate validation from a clean checkout
- confirm the working tree remains unchanged after generation and tests,
  excluding ignored build output
- confirm CI contains no production credentials and needs no Supabase access

## API Behavior And Privacy Checks

- Liveness and smoke responses contain only fixed operational fields.
- The OpenAPI document exposes no health-data schemas in this feature.
- Invalid configuration fails with an actionable message that contains no
  secret value.
- Captured request logs contain method, route template, status, and timing only;
  they contain no headers, query values, request bodies, or response bodies.
- All tests, examples, generated contract examples, and screenshots use
  synthetic operational or health context.
- No mobile code transmits the synthetic Today-screen state.

## Native Manual Validation

After installing the native toolchains:

1. Launch the app on an iOS simulator at approximately 390x844 logical points.
2. Launch the app on an Android emulator at approximately 412x915 logical
   pixels.
3. On each platform, verify:
   - Letter name and application identity
   - successful cold launch without a red error screen or crash
   - native safe-area and keyboard/inset behavior
   - bundled typography and design tokens
   - primary controls and modal sheet touch behavior
   - no clipping, overflow, unintended layout movement, or blank region
   - no network transmission when interacting with synthetic Today state
4. Capture one Today screenshot and one open Care-sheet screenshot per
   platform using only synthetic content.

A web screenshot, widget test, or desktop build does not satisfy this native
validation.

## Clean-Checkout CI Gate

The CI workflow must:

- install pinned or constrained Flutter and Python toolchains
- restore dependencies only from committed manifests and locks
- run API formatting, linting, strict typing, and tests
- run mobile formatting, analysis, and tests
- verify OpenAPI and generated-client drift
- smoke-build Android and iOS without signing
- use no production secret, Supabase project, deployment credential, or real
  health fixture

## Acceptance Gate

The feature is ready for validation status when:

- every automated check passes locally and in clean-checkout CI
- OpenAPI and Dart client regeneration produce no diff
- repository and log review find no secret or health-data leakage
- all limitations are recorded honestly

Native builds, launch reviews, and screenshots remain a release-preparation
gate under the user-approved 2026-07-28 amendment.

The feature must not be merged, pushed, or deployed without separate explicit
user instruction.

## Known Pre-Implementation Blocker

Native validation is presently unavailable because the Android SDK is absent
and the Xcode installation is incomplete. CocoaPods is also absent. The
foundation may be implemented after this specification is approved, but it
cannot satisfy its acceptance gate until both native toolchains are available.

## Implementation Validation Result

Status: automated foundation passed; native acceptance gate pending

Validated on 2026-07-27:

- Flutter 3.44.8 and Dart 3.12.2
- Python 3.13 constraint with a universal `uv.lock`; local validation used
  available CPython 3.14.6 within the supported range
- `uv sync --locked`: passed
- Ruff format and lint across API and repository tools: passed
- strict Pyright across API source, migrations, and tools: passed
- API tests: 6 passed without warnings
- deterministic OpenAPI export and drift check: passed
- generated Dart client drift and compile test: passed
- foundation metadata and repository hygiene checks: passed
- Dart formatting and Flutter analysis: passed
- Flutter tests: 7 passed
- Flutter release web build: passed as a development smoke build

Implemented boundaries:

- `/health` and `/v1/status` expose operational status only.
- The OpenAPI document contains no cycle, symptom, period-date, or health-record
  schema.
- Access logging records method, route template, status, and duration without
  query values, headers, or bodies.
- The generated mobile client is tested against a synthetic operational
  response and is not called by the Today experience.
- SQLAlchemy and Alembic boundaries contain no product or health table.

Pending:

- Android build, emulator launch, and screenshots: Android SDK unavailable.
- iOS build, simulator launch, and screenshots: full Xcode and CocoaPods
  unavailable.
- Clean-checkout GitHub Actions execution requires a local commit and push,
  neither of which was requested.

Browser rendering remains development evidence only and does not satisfy the
deferred native release gate.
