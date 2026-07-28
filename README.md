# Letter

Letter is a private, local-first period and PMS/PMDD companion. This repository
contains independently runnable mobile and API applications.

## Structure

```text
apps/
  mobile/              Flutter application for iOS and Android
  api/                 FastAPI operational service
contracts/openapi/     Generated API contract
tools/                 Contract generation and repository validation
specs/                 Product roadmap, architecture, and feature specifications
```

Readable health records remain on the device. The API foundation contains only
non-sensitive operational routes and must not receive synthetic Today-screen
state.

The current product direction is defined in
[`specs/product-philosophy.md`](specs/product-philosophy.md). Letter combines
period tracking with a cross-cycle Care loop: contain a hard moment, check back
later, let the user author what it meant, and return their own helpful actions
and words next time.

## Mobile

```bash
cd apps/mobile
flutter pub get
flutter analyze
flutter test
flutter run
```

Web is available for visual development only. iOS and Android are the product
targets.

## API

```bash
cd apps/api
uv sync --locked
uv run fastapi dev src/letter_api/main.py
uv run pytest
```

The local service exposes:

- `GET /health`: process liveness
- `GET /v1/status`: contract smoke path
- `GET /docs`: local OpenAPI documentation

No Supabase connection or secret is required for the foundation.

## Contract

From the repository root:

```bash
uv run --project apps/api python tools/export_openapi.py
python3 tools/generate_dart_client.py
```

Use `--check` with either command to fail when committed generated output is
stale.

## Validation

```bash
python3 tools/validate.py
```

Native simulator and emulator checks require complete Xcode, CocoaPods, and
Android SDK installations.
