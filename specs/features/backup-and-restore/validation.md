# Backup and restore acceptance

Status: implementation and automated coverage exist; final physical-device
release check is open.

| Case | Required result |
| --- | --- |
| Export | Versioned encrypted envelope, neutral filename, saved local path, OS destination sheet, optional secure passphrase storage. |
| Import preview | Version/integrity checked before staging; each add/keep/replace/remove decision and reason visible before commit. |
| Merge | Later `updatedAt` wins; equal timestamps keep destination; unique IDs on either side stay. |
| Replace | Entire supported collections match the preview after explicit confirmation. |
| Failure | Wrong password, tamper, unsupported version, cancellation, storage failure, and interrupted commit leave the original store intact. |
| Boundaries | Sealed drafts excluded; no health content or password in cloud, analytics, logs, filename, or crash metadata. |

Focused implementation checks are in `apps/mobile/test/` for local backup
service, import planner, and Drift store. Record final device, build, file
round trip, and reviewer under [`validation/2.0/`](../../../validation/2.0/).
