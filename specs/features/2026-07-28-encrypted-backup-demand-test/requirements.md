# Encrypted Backup Demand Test Requirements

Status: proposed; demand gate
Dependencies: encrypted local export/import and auth/entitlement

## Goal

Test whether users want encrypted recovery across devices before building a
cloud backup service.

## Requirements

REQ-001: The test explains that backup is optional, encrypted, and separate
from local storage. It does not imply that cloud sync already exists.

REQ-002: The test collects only a non-sensitive demand response, such as
interest level and preferred recovery method. It does not collect cycle dates,
symptoms, notes, drafts, reports, or reasons in free text.

REQ-003: The test is available only after users understand local export/import
and can complete the app without enabling backup.

REQ-004: No ciphertext upload or recovery-key generation is implemented in the
demand test. A positive result creates a product decision, not a backup record.

REQ-005: Advancement requires a written demand threshold, threat model,
recovery-key design, deletion model, legal/privacy review, and new approved
implementation spec.

## Non-Goals

- cloud synchronization
- automatic backup
- storing a recovery key on the server
- health-data analytics
