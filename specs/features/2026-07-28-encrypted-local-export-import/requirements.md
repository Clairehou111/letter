# Encrypted Local Export And Import Requirements

Status: implemented (2026-08-04)
Dependencies: all local health repositories and encrypted native database

## Goal

Let users recover or move their local records without cloud synchronization or
placing readable health data on a server.

## Requirements

REQ-001: Export is an explicit user action from Privacy or You. The package is
encrypted before leaving the device and contains no readable health values in
the surrounding filename, logs, or share metadata.

REQ-002: Use a vetted authenticated-encryption and key-derivation library
(Argon2id + AES-256-GCM via the `cryptography` package). The key UX,
parameters, versioning, and recovery instructions are fixed; no custom
cryptography is allowed.

REQ-003: Import decrypts into a staging area, validates version and integrity,
shows per-record changes (which record, what action, and why) in addition to
aggregate counts, and requires explicit confirmation before any data is
modified.

REQ-004: Failed, wrong-key, corrupt, incompatible, cancelled, and partial
imports leave the existing local database unchanged.

REQ-005: The user can choose an explicit replace or merge policy only after a
preview. Merge resolves same-ID conflicts by keeping the record with the newer
`updatedAt` timestamp; equal timestamps favour the destination. Replace
overwrites entire collections. Both policies are deterministic and documented.

REQ-006: Web remains memory-only and does not offer a misleading persistent
health export path unless its repository explicitly supports it.

REQ-007: The server, API, analytics, and crash metadata never receive the
plaintext package or its passphrase.

REQ-008: Sealed impulse letters remain outside export and import. An import
does not replace or reveal a destination sealed letter; it can only be handled
through its existing Care flow.

REQ-009: The backup passphrase may be saved in platform secure storage (iOS
Keychain / Android Keystore) for reuse across sessions. Saving is optional
and the user can forget the stored passphrase at any time. The stored
passphrase is never included in the backup file or transmitted off-device.

REQ-010: Export saves a timestamped copy in a dedicated `letter/` subfolder
of the app documents directory and opens the OS share sheet. The share-sheet
filename matches the local copy filename.

REQ-011: In-app help is available from the backup screen and covers where
files are saved, the encryption envelope format, restore steps, and password
guidance.

## Non-Goals

- mandatory accounts or cloud sync
- server-side backup
- background export
- export of unsaved text or clipboard contents
- automatic cloud upload (user uploads manually via share sheet)
