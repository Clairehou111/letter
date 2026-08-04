# Encrypted Local Export And Import Validation

Status: validated (2026-08-04; native release gate deferred)

- [x] Exported bytes contain no searchable plaintext health values.
- [x] Wrong key and tampered packages fail closed (integrity check).
- [x] Cancelled or failed imports do not alter existing records.
- [x] Replace and merge results match the preview exactly, including per-record change entries.
- [x] Merge correctly keeps the newer record by `updatedAt` timestamp; equal timestamps favour destination.
- [x] Per-record preview labels are derived from structured fields only — no free-text notes or impulse content leaked.
- [x] Migrations preserve stable IDs, dates, provenance, and deletion semantics.
- [x] No passphrase, package content, or health value enters logs or API calls.
- [x] Passphrase can be stored, reused, and forgotten via platform secure storage.
- [x] Export produces a timestamped filename and saves a local copy in the `letter/` subfolder.
- [x] In-app help dialog and `help.md` document the full export/import/merge workflow.
- [ ] Native iOS and Android restore tests pass before release. (manual release gate pending)
