#!/usr/bin/env python3
import sys
from pathlib import Path

REPOSITORY_ROOT = Path(__file__).resolve().parents[1]


def require(path: str) -> Path:
    resolved = REPOSITORY_ROOT / path
    if not resolved.exists():
        raise AssertionError(f"Required foundation path is missing: {path}")
    return resolved


def main() -> int:
    for path in (
        "apps/mobile/lib/main.dart",
        "apps/api/src/letter_api/main.py",
        "contracts/openapi/letter-api.json",
        "tools/export_openapi.py",
        "tools/generate_dart_client.py",
        "README.md",
    ):
        require(path)

    android_build = require("apps/mobile/android/app/build.gradle.kts").read_text(
        encoding="utf-8"
    )
    android_manifest = require(
        "apps/mobile/android/app/src/main/AndroidManifest.xml"
    ).read_text(encoding="utf-8")
    ios_project = require("apps/mobile/ios/Runner.xcodeproj/project.pbxproj").read_text(
        encoding="utf-8"
    )
    ios_plist = require("apps/mobile/ios/Runner/Info.plist").read_text(encoding="utf-8")

    assert 'applicationId = "com.letterhealth.letter"' in android_build
    assert 'namespace = "com.letterhealth.letter"' in android_build
    assert 'android:label="Letter"' in android_manifest
    assert "com.letterhealth.letter;" in ios_project
    assert "<string>Letter</string>" in ios_plist

    combined = "\n".join((android_build, android_manifest, ios_project, ios_plist))
    for stale_value in (
        "com.example",
        "com.letterhealth.letter_mobile",
        "com.letterhealth.letterMobile",
        "Letter Mobile",
    ):
        assert stale_value not in combined, f"Stale mobile metadata: {stale_value}"

    print("Foundation structure and mobile metadata check passed.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AssertionError as error:
        print(error, file=sys.stderr)
        raise SystemExit(1) from error
