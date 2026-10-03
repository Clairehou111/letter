# System architecture

Status: Release 2.0 target, grounded in the existing Flutter and FastAPI
applications. See the [ADRs](adr/) for durable storage decisions.

## Applications and boundaries

| Area | Responsibility |
| --- | --- |
| `apps/mobile` | Flutter iOS/Android app; owns encrypted health records, deterministic computation, Care, and reports. |
| `apps/api` and Supabase functions | Operational account, entitlement, consent, and deletion functions. No readable health history. |
| `contracts/openapi` | Generated API contract; the Dart client is generated from this contract. |
| Web preview | In-memory development and visual QA only; no browser persistence of readable health records. |

Native health storage uses Drift with SQLite3MultipleCiphers. A random local
database key is held in platform secure storage; database open fails closed
without verified cipher support. Native migrations and encrypted export/import
must preserve user records. There is no automatic cloud health sync. A sign-in
on another device restores account and entitlement state, not local history.
Legacy onboarding profiles that contain the retired `cloud_tools` field still
decode; new saves omit it. The app offers no AI or cloud health-processing
preference.

Period dates, symptoms, mood, notes, Care content, outcomes, forecasts,
Patterns, and report material remain on-device. They do not enter Supabase,
RevenueCat, PostHog, API requests, logs, crash metadata, or account metadata.
Only explicitly selected report/export files leave the app through the user's
chosen local share destination.

## Identity, purchase and analytics

The first full entry requires a successful Supabase sign-in. Returning users
can reach their existing local records and acute Care when offline; server
operations wait for reauthentication. Sign in with Apple is the primary iOS
route. The dedicated App Review account uses a supported email/password route;
do not publish its credentials. Account deletion and local health deletion are
separate explicit actions.

RevenueCat associates an authenticated operational account with `letter_plus`.
Store-provided product and localized price metadata is authoritative. Loss of
network or store access must not delete local data or erase a still-valid
locally known entitlement without reconciliation.

PostHog is optional and off by default. Consent is explicit and revocable.
Disable autocapture, replay, and person profiles. Use an analytics-only random
identifier, not a Supabase user ID. Immediate events are limited to non-health
settings, paywall, and purchase flows. Any delayed Care usage aggregate follows
the exact payload boundary in [2.0 requirements](features/release-2.0/requirements.md).
The public privacy policy and App Store declaration must match a configured
analytics build before it is submitted.

## Technology and validation

The mobile app uses Flutter/Dart; the operational API uses Python, FastAPI,
Pydantic, SQLAlchemy, and Supabase PostgreSQL. OpenAPI generation and the Dart
client are checked in CI. Do not add a health-data server, AI provider,
mandatory sync, or new infrastructure without an approved specification and
privacy review. Runtime release configurations and signing secrets remain
Git-ignored.
