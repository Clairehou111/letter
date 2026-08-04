# Encrypted Local Export And Import Plan

Status: implemented (2026-08-04)

1. [x] Approve the archive format, key UX, crypto library, and recovery wording.
2. [x] Implement versioned client-side encryption (Argon2id + AES-256-GCM) and integrity verification.
3. [x] Implement export preview, system hand-off via share sheet, timestamped local copy in `letter/` subfolder, import staging, and conflict UI with per-record change detail.
4. [x] Add on-device passphrase storage (iOS Keychain / Android Keystore) with opt-in save, reuse on export/import, and forget capability.
5. [x] Add in-app help dialog and user-facing `help.md` documentation covering export locations, encryption envelope, restore steps, merge rules, password management, and troubleshooting.
6. [x] Add failure recovery and migration tests without real health fixtures.
7. [ ] Validate native key handling and manual restore on both target platforms. (deferred to release gates)
