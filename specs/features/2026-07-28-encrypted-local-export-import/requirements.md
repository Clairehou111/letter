# Encrypted Local Export And Import Requirements

Status: proposed
Dependencies: all local health repositories and encrypted native database

## Goal

Let users recover or move their local records without cloud synchronization or
placing readable health data on a server.

## Requirements

REQ-001: Export is an explicit user action from Privacy or You. The package is
encrypted before leaving the device and contains no readable health values in
the surrounding filename, logs, or share metadata.

REQ-002: Use a vetted authenticated-encryption and key-derivation library. The
key UX, parameters, versioning, and recovery instructions must be reviewed
before implementation; no custom cryptography is allowed.

REQ-003: Import decrypts into a staging area, validates version and integrity,
shows record counts and the destination effect, and requires confirmation.

REQ-004: Failed, wrong-key, corrupt, incompatible, cancelled, and partial
imports leave the existing local database unchanged.

REQ-005: The user can choose an explicit replace or merge policy only after a
preview. Stable IDs and conflict rules are deterministic and documented.

REQ-006: Web remains memory-only and does not offer a misleading persistent
health export path unless its repository explicitly supports it.

REQ-007: The server, API, analytics, and crash metadata never receive the
plaintext package or its passphrase.

## Non-Goals

- mandatory accounts or cloud sync
- server-side backup
- background export
- export of unsaved text or clipboard contents
