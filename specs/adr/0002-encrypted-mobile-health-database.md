# ADR 0002: Encrypted Mobile Health Database

Status: accepted

## Context

Period logging creates Letter's first structured readable health records.
`flutter_secure_storage` is suitable for small secrets but not relational
history. Letter needs transactions, migrations, deterministic queries, test
substitution, and encryption at rest on iOS and Android.

The older `sqlcipher_flutter_libs` package is end-of-life. Drift supports
custom native SQLite builds, and current `sqlite3` build hooks can bundle
SQLite3MultipleCiphers.

## Decision

Use Drift as the mobile data access layer and `sqlite3` with the
`sqlite3mc` build-hook source for native SQLite3MultipleCiphers.

- Generate a random database key on device.
- Store the key in platform secure storage.
- Configure the cipher and key before Drift reads or migrates schema.
- Verify cipher support when opening the database and fail closed if missing.
- Keep a repository interface above Drift.
- Use an in-memory repository for widget tests and web development previews.
- Do not use browser storage for readable health data.

## Consequences

- Native encryption behavior needs iOS and Android integration tests when the
  native validation gate is enabled.
- The SQLite3MultipleCiphers license and notices must be included in release
  compliance review.
- Losing both the secure-storage key and an encrypted export makes local data
  unrecoverable.
- Database migrations must be explicit and tested from the first schema.
- Web preview behavior is intentionally non-persistent and is not a production
  health-data architecture.
