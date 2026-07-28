# Letter Architecture

## Applications

- `apps/mobile`: iOS and Android client
- `apps/api`: FastAPI service for operational capabilities
- `contracts/openapi`: generated API contract and mobile-client input

## Data Boundary

Readable health data remains on the device:

- period dates and cycle history
- symptoms, severity, pain, mood, energy, notes, and transcripts
- Care plans, coping actions, outcomes, predictions, patterns, and reports

The server may store:

- account or pseudonymous user ID
- subscription entitlement
- consent receipts
- configuration/content versions
- non-sensitive operational events
- deletion requests

Cloud LLM processing is a transient, consented exception. The mobile app builds
a minimized payload, the user previews and approves it, and the API must not
retain or log the request body.

## Recovery

P0 provides encrypted export and import. Mandatory cloud synchronization is out
of scope. Optional end-to-end encrypted backup may be added only after demand
is validated and a recovery-key design is approved.

