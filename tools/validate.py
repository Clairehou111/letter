#!/usr/bin/env python3
import os
import subprocess
from pathlib import Path

REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
API_ROOT = REPOSITORY_ROOT / "apps" / "api"
MOBILE_ROOT = REPOSITORY_ROOT / "apps" / "mobile"


def run(command: list[str], cwd: Path) -> None:
    print(f"\n$ {' '.join(command)}", flush=True)
    subprocess.run(command, cwd=cwd, check=True, env=os.environ.copy())


def main() -> int:
    os.environ.setdefault("UV_CACHE_DIR", str(REPOSITORY_ROOT / ".cache" / "uv"))

    run(["uv", "sync", "--locked"], API_ROOT)
    run(["uv", "run", "ruff", "format", "--check", ".", "../../tools"], API_ROOT)
    run(["uv", "run", "ruff", "check", ".", "../../tools"], API_ROOT)
    run(["uv", "run", "pyright", "src", "migrations", "../../tools"], API_ROOT)
    run(["uv", "run", "pytest"], API_ROOT)
    run(
        ["uv", "run", "python", "../../tools/export_openapi.py", "--check"],
        API_ROOT,
    )
    run(["python3", "tools/generate_dart_client.py", "--check"], REPOSITORY_ROOT)
    run(["python3", "tools/check_foundation.py"], REPOSITORY_ROOT)
    run(["python3", "tools/check_repository_hygiene.py"], REPOSITORY_ROOT)
    run(
        [
            "dart",
            "format",
            "--output=none",
            "--set-exit-if-changed",
            "lib",
            "test",
        ],
        MOBILE_ROOT,
    )
    run(["flutter", "analyze"], MOBILE_ROOT)
    run(["flutter", "test"], MOBILE_ROOT)
    print("\nFoundation validation passed.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except subprocess.CalledProcessError as error:
        raise SystemExit(error.returncode) from error
