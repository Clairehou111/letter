# Encrypted Local Export And Import Validation

Status: validated (native release gate deferred)

- [x] Exported bytes contain no searchable plaintext health values.
- [x] Wrong key and tampered packages fail closed.
- [x] Cancelled or failed imports do not alter existing records.
- [x] Replace and merge results match the preview exactly.
- [x] Migrations preserve stable IDs, dates, provenance, and deletion semantics.
- [x] No passphrase, package content, or health value enters logs or API calls.
- [ ] Native iOS and Android restore tests pass before release. (manual release gate pending)
