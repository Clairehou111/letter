# Letter API Instructions

Follow the repository `AGENTS.md` and the active feature specification.

## Stack

- Python 3.13 or newer
- FastAPI and Pydantic v2
- SQLAlchemy 2 and Alembic
- PostgreSQL through Supabase
- `uv` for environments and dependency locking
- Ruff for formatting and linting
- Pyright in strict mode
- pytest for tests

## Architecture

- Keep HTTP transport, application services, domain rules, and persistence
  separate.
- Validate all external input at the boundary.
- Publish an OpenAPI contract and generate the Dart API client from it.
- Verify Supabase JWTs using published signing keys.
- Make webhook handling signature-verified, idempotent, and replay-safe.
- Do not add queues, caches, or background infrastructure without a measured
  requirement.

## Privacy And Logging

- The API must not persist readable health records in P0.
- Never log request bodies for LLM, report, journal, symptom, or voice routes.
- Operational analytics must not contain health values or inferred health
  state.
- Use synthetic test data only.

## Validation

- Run Ruff, strict Pyright, and pytest.
- Test authorization failures, deletion, retries, idempotency, and log
  redaction for every applicable feature.

