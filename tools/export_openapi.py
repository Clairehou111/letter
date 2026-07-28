#!/usr/bin/env python3
import argparse
import json
import sys
from pathlib import Path

REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
API_SOURCE = REPOSITORY_ROOT / "apps" / "api" / "src"
CONTRACT_PATH = REPOSITORY_ROOT / "contracts" / "openapi" / "letter-api.json"


def render_contract() -> str:
    sys.path.insert(0, str(API_SOURCE))
    from letter_api.bootstrap import create_app
    from letter_api.core.settings import Settings

    schema = create_app(Settings(environment="test")).openapi()
    return f"{json.dumps(schema, indent=2, sort_keys=True)}\n"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--check",
        action="store_true",
        help="Fail instead of writing when the committed contract is stale.",
    )
    args = parser.parse_args()
    rendered = render_contract()

    if args.check:
        if not CONTRACT_PATH.exists() or CONTRACT_PATH.read_text() != rendered:
            print(
                "OpenAPI contract is stale. Run tools/export_openapi.py.",
                file=sys.stderr,
            )
            return 1
        return 0

    CONTRACT_PATH.parent.mkdir(parents=True, exist_ok=True)
    CONTRACT_PATH.write_text(rendered, encoding="utf-8")
    print(f"Wrote {CONTRACT_PATH.relative_to(REPOSITORY_ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
