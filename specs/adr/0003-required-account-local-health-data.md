# ADR 0003: Required Account With Local Health Data

Status: accepted

## Context

Letter Within needs one stable identity for approved operational analytics,
subscription entitlement, purchase restoration, consent receipts, support, and
future optional account services. Allowing unregistered use and later account
conversion adds anonymous-user linking, duplicate-account resolution, and
ambiguous attribution. That complexity is not justified for the first release.

Requiring an account must not turn readable period, symptom, Letter Within, or Care
records into server data or make returning users depend on a live connection.

## Decision

Require one successful Supabase Auth sign-in before a new user enters the full
product.

- Do not create a pre-registration anonymous Supabase account.
- Use Sign in with Apple as the primary iOS path and email magic link as the
  fallback.
- Use the Supabase user ID for approved operational analytics, consent receipts,
  and entitlement association only.
- Keep readable health records in the encrypted local database; never store
  them in account metadata or operational analytics.
- After the first successful sign-in, local records, Letters, and Care continue
  to work offline. An expired session gates only server operations that need
  re-authentication.
- Account deletion and local-health-data deletion remain separate, explicit
  actions with a clear explanation of what each removes.

## Consequences

- The first full-product entry requires a network connection and introduces
  measurable onboarding friction.
- Letter Within avoids anonymous-to-registered identity conversion and account-merge
  behavior for new users.
- Signing in on another device restores account and entitlement state, not
  local health records; encrypted backup/import remains the recovery path.
- Auth or network failure must not lock a returning user out of local records or
  an already-available Care flow.
- Product copy must say that account data and health records are separate, not
  that Letter Within has no account.

## Implementation status

As of 2026-08-08, the mobile auth slice implements the approved state model,
Apple and email magic-link entry points, the `LetterApp` gate, prior-sign-in
offline/expired access, explicit sign-out, and server-side account-deletion
boundary. Auth service, screen, and LetterApp gate tests cover the
provider-independent behavior and pass in the current Flutter suite.

The decision is not yet a release-complete account system. The production build
must enable the authentication gate and verify the deployed Supabase Auth
providers, redirect configuration, email magic-link flow, and
`delete-account` function. Native iOS and Android session restoration remain
release validation work. None of these gates permit uploading readable period,
symptom, Letter Within, or Care data.
