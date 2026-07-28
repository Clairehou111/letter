#!/usr/bin/env python3
import subprocess
import sys
from pathlib import Path

REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
FORBIDDEN_PARTS = {
    ".dart_tool",
    ".env",
    ".idea",
    ".pytest_cache",
    ".ruff_cache",
    ".venv",
    "__pycache__",
    "artifacts",
    "build",
    "coverage",
}
FORBIDDEN_NAMES = {
    "local.properties",
}
FORBIDDEN_SUFFIXES = {
    ".iml",
    ".pyc",
}


def tracked_files() -> list[Path]:
    result = subprocess.run(
        ["git", "ls-files", "-z"],
        cwd=REPOSITORY_ROOT,
        check=True,
        capture_output=True,
    )
    return [Path(item.decode()) for item in result.stdout.split(b"\0") if item]


def main() -> int:
    violations: list[Path] = []
    for path in tracked_files():
        if (
            FORBIDDEN_PARTS.intersection(path.parts)
            or path.name in FORBIDDEN_NAMES
            or path.suffix in FORBIDDEN_SUFFIXES
        ):
            violations.append(path)

    if violations:
        print("Generated or local-only files are tracked:", file=sys.stderr)
        for path in violations:
            print(f"- {path}", file=sys.stderr)
        return 1

    print("Repository hygiene check passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
