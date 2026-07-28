# Encrypted Local Export And Import Validation

Status: in_progress

- Exported bytes contain no searchable plaintext health values.
- Wrong key and tampered packages fail closed.
- Cancelled or failed imports do not alter existing records.
- Replace and merge results match the preview exactly.
- Migrations preserve stable IDs, dates, provenance, and deletion semantics.
- No passphrase, package content, or health value enters logs or API calls.
- Native iOS and Android restore tests pass before release. (manual release gate pending)
