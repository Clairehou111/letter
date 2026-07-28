# Letter API

FastAPI service for Letter's operational capabilities.

```bash
uv sync --locked
uv run fastapi dev src/letter_api/main.py
uv run ruff format --check .
uv run ruff check .
uv run pyright
uv run pytest
```

The foundation exposes only liveness and service-status routes. It contains no
health schemas or product database tables. Request and response bodies, query
values, and headers must not be written to application logs.
