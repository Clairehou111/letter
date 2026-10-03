# Letter Within

Letter Within is a private period and cycle companion for difficult days. The
app combines local tracking, optional Care experiences, source-linked Patterns,
and factual records a person can choose to share. It is not a diagnostic or
emergency service. Health history is encrypted on the device; account and
purchase services are separate. No AI interprets health records.

**Release state:** Letter Within 1.0 Build 17 was submitted for iPhone App
Store review on 2026-10-03 with manual release selected. Approval and public
availability are not recorded here. [Release 2.0](specs/features/release-2.0/) is the
next target, with [acceptance gates](specs/features/release-2.0/validation.md) still
open. The detailed 1.0 handoff is in
[validation/1.0](validation/1.0/app-store-handoff.md).

## Repository map

| Path | Purpose |
| --- | --- |
| [`apps/mobile/`](apps/mobile/) | Flutter iOS/Android app; iPhone is the first public distribution target. |
| [`apps/api/`](apps/api/) | FastAPI operational service for account and related non-health functions. |
| [`contracts/openapi/`](contracts/openapi/) | Generated API contract for the mobile client. |
| [`specs/`](specs/) | Current product, system, and 2.0 release contracts. |
| [`validation/`](validation/) | Dated 1.0 submission and 2.0 verification evidence. |
| [`artifacts/app-store/`](artifacts/app-store/) | Current App Store screenshot set and its provenance. |
| [`tools/`](tools/) | Contract, validation, hygiene, and App Store asset tooling. |

The dated feature plans were reconciled into the current
[feature contracts](specs/features/README.md); Git history retains the
originals. Start with the [spec index](specs/README.md).

This README is the repository entry point. [PRODUCT.md](PRODUCT.md) is the
product and brand brief; [specs/product.md](specs/product.md) is the current
release product contract. The [spec index](specs/README.md) explains how the
other contracts fit together.

## Work locally

The unconfigured mobile debug build uses local development adapters. A
release-like build needs ignored local configuration for Supabase, RevenueCat,
and optional consented PostHog; see the [mobile guide](apps/mobile/README.md).
Use synthetic data for tests, demonstrations, and screenshots.

```bash
cd apps/mobile
flutter pub get
flutter analyze
flutter test
flutter run
```

The API can be run and tested separately:

```bash
cd apps/api
uv sync --locked
uv run fastapi dev src/letter_api/main.py
uv run pytest
```

From the repository root, `python3 tools/validate.py` runs the combined
foundation checks. Native builds and device checks require the corresponding
Apple or Android toolchains. Release evidence and any open manual gates belong
in [`validation/`](validation/README.md).
