# Letter Within Architecture

## Applications

- `apps/mobile`: iOS and Android client
- `apps/api`: FastAPI service for operational capabilities
- `contracts/openapi`: generated API contract and mobile-client input

## Data Boundary

Readable health data remains on the device:

- period dates and cycle history
- symptoms, severity, pain, mood, energy, notes, and transcripts
- Care plans, coping actions, outcomes, predictions, patterns, and reports

Phase 2 Care memory uses the same encrypted local database as period and
impulse records. A Care action is not stored on entry or interaction; the first
persisted Care record is created only when the user explicitly selects Better,
Same, or Worse. Clearer-day reflections and future-self notes are also
user-confirmed local records. The Web preview uses in-memory repositories.

The server may store:

- account and authentication data needed to operate the account
- subscription entitlement and consent receipts needed for account operations
- deletion requests

No AI reads, rewrites, summarizes, suggests from, or interprets health records.
Health records and free-text health content are never sent to an AI service.
Predictions, personal patterns, candidate matching, and reports are computed
deterministically on-device from local data. Supabase and RevenueCat are
operational account and entitlement services only; they do not process health
records or health-derived content.

## Recovery

P0 provides encrypted export and import. Mandatory cloud synchronization is out
of scope. Optional end-to-end encrypted backup may be added only after demand
is validated and a recovery-key design is approved.
