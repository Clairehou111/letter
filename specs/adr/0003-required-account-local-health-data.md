# ADR 0003: Required account, local health data

Status: accepted; reconciled for the 2.0 target on 2026-10-03.

## Context

Account identity is needed for operational subscription restoration and
deletion. Requiring an account must not turn readable health history into
server data or make returning users depend on a live connection. Optional
analytics needs its own consent and identity boundary.

## Decision

- Require one successful Supabase Auth sign-in before a new user enters the
  full product. Sign in with Apple is the primary iOS route. An email/password
  route supports the dedicated App Review account and configured fallback.
- Keep period, symptom, mood, note, Care, Pattern, and report material in the
  encrypted local database. Signing in elsewhere restores account and
  entitlement state, not local health history.
- Use the authenticated operational identity for account and entitlement
  services only. Optional PostHog analytics is off by default and uses a
  separate random analytics identifier, never the Supabase user ID. Its exact
  event boundary is in [architecture](../architecture.md) and the
  [2.0 requirements](../features/release-2.0/requirements.md).
- Returning users can use existing local records and acute Care offline.
  Operations requiring the server wait for reauthentication.
- Account deletion and local health deletion are separate explicit actions.
  Explain the difference before either action.

## Consequences

First full entry needs a network connection. Authentication failures must not
erase or hide an existing user's local records. Encrypted local backup/import,
not sign-in, is the recovery path for health history. Public copy must describe
account, purchase, analytics consent, and health storage accurately.
