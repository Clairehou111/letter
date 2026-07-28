# Production Workspace Foundation Requirements

Status: approved
Branch: `feature/production-workspace-foundation`

## Context

The Flutter UI fidelity spike is validated and Flutter has been approved for
Letter's production mobile application. The repository now needs a reproducible
foundation for separate mobile and API applications before product data,
onboarding, or cycle behavior is introduced.

The existing Flutter spike is useful evidence and reusable UI work, but the
workspace still contains generated defaults, has no API application or contract
pipeline, and cannot currently be validated on native iOS or Android tooling.

## Goal

Create a production-oriented monorepo foundation that a new contributor and CI
can set up, validate, and run deterministically while preserving Letter's
local-first health-data boundary.

## Approved Decisions

- Use `Letter` as the application display name and
  `com.letterhealth.letter` as the iOS bundle identifier and Android
  application ID.
- Retain the approved design tokens, reusable controls, and synthetic Today
  experience as the native visual baseline. It remains non-persistent and must
  not be represented as completed product functionality.
- Check the generated OpenAPI document and generated Dart API client into the
  repository. A deterministic command and CI check will fail when either is
  stale.
- Use GitHub Actions for the first clean-checkout CI workflow.
- Include the confirmed FastAPI, Pydantic v2, SQLAlchemy 2, and Alembic
  dependencies and application boundaries, but do not add a product database
  schema or require a Supabase connection in this feature.
- Use Flutter's supported platform defaults for minimum iOS and Android
  versions during foundation work. Treat final market-support floors as a later
  release decision.

## Scope

REQ-001: Establish a production monorepo layout with independently runnable
`apps/mobile` and `apps/api` applications, a generated contract under
`contracts/openapi`, and root-level contributor documentation and validation
entry points.

REQ-002: Pin or constrain the approved toolchains and lock all application
dependencies so a clean checkout uses Flutter stable with sound null safety and
Python 3.13 or newer through `uv`.

REQ-003: Promote the Flutter spike into a production mobile application with
Letter package metadata, production application identifiers, the approved
design-system baseline, and supported iOS and Android projects. Web remains a
development and visual-validation target only.

REQ-004: Establish a typed FastAPI application with explicit HTTP,
application, domain, and persistence boundaries; environment-based settings;
an unversioned non-sensitive liveness route; and versioned API routing ready for
future features.

REQ-005: Export the backend OpenAPI contract deterministically and generate the
mobile Dart client from that contract without handwritten duplication of API
request or response models.

REQ-006: Provide a minimal contract-backed API smoke path whose response
contains only operational status data, allowing the server, OpenAPI export, and
generated mobile client to be validated end to end without transmitting health
data.

REQ-007: Provide local and clean-checkout CI quality gates for formatting,
linting, strict type checking, automated tests, OpenAPI drift, generated-client
drift, and build smoke checks appropriate to each application.

REQ-008: Keep configuration and secrets out of source control, provide
non-secret example configuration where configuration exists, fail clearly on
invalid required configuration, and ensure application logs and test fixtures
contain no real or inferred health data.

REQ-009: Keep generated caches, local IDE state, build output, screenshots,
coverage, local environment files, and platform-local configuration out of
source control while retaining intentional lockfiles and generated API
artifacts.

REQ-010: Document setup, common commands, application boundaries, contract
generation, environment handling, test-data rules, and the fact that readable
health records must remain local by default.

REQ-011: Build and launch the accepted synthetic Flutter baseline on an iOS
simulator and an Android emulator, confirming native safe areas, typography,
touch behavior, and absence of clipping or overflow at representative phone
sizes.

REQ-012: Preserve narrow scope: the foundation must not introduce product
health persistence, server-side readable health records, authentication,
subscriptions, analytics, cloud LLM behavior, or deployable infrastructure.

## Non-Goals

- onboarding, cycle logging, prediction, or other Phase 1 behavior
- selection of the encrypted SQLite or state-management packages
- Supabase project creation, credentials, schemas, migrations containing
  product data, or hosted connectivity
- production authentication or authorization
- application flavors beyond configuration needed by local validation
- release signing, store submission, deployment, or hosting selection
- observability vendor selection
- redesigning or expanding the validated Flutter experience

## Current Environment Constraint

Flutter 3.44.8, Dart 3.12.2, Python 3.13.12, and `uv` 0.11.3 are available.
The Android SDK is absent. Xcode is incomplete and CocoaPods is absent.
Consequently, REQ-011 and the native build portions of validation cannot pass
until both native toolchains are installed and configured. Browser rendering
does not substitute for this native gate.

## Approved Validation Amendment

On 2026-07-28, the user explicitly deferred REQ-011 to release preparation so
that missing local SDKs do not block product iteration. This does not convert
browser validation into native validation. Native builds, launches, and
screenshots remain mandatory before release.
