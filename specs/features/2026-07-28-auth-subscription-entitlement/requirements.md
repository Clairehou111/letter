# Authentication And Subscription Entitlement Requirements

Status: implemented bounded mobile/auth-entitlement contract; provider and
native release validation pending
Dependencies: local-first health storage and RevenueCat configuration

## Goal

Require one initial Supabase sign-in for a stable user identity, account
operations, and paid entitlements while keeping readable health records local
and keeping the signed-in app usable offline.

## Requirements

REQ-001: A new user signs in before entering the full product. Sign in with
Apple is the primary iOS path and email magic link is the fallback. Letter Within does
not create a pre-registration anonymous Supabase account.

REQ-002: The API stores only account or pseudonymous user ID, consent receipts,
subscription entitlement, configuration versions, deletion requests, and
approved non-sensitive operational data.

REQ-003: No readable cycle date, symptom, note, transcript, Care text, report,
or inferred health state is uploaded for authentication or billing.

REQ-004: RevenueCat is the source for Apple and Google purchase state. The app
handles pending, restored, expired, cancelled, grace, and offline states
without deleting local records.

REQ-005: Losing entitlement never removes access to read, export, or delete
local health data. Premium gates must be explicit and reversible.

REQ-006: Account deletion explains what is deleted on the server and what
remains on the device. Local data requires a separate explicit deletion action.

REQ-007: Billing and auth failures do not block local Care safety routes or
period tracking.

REQ-008: After the first successful sign-in, a missing network connection or
expired server session does not block local period history, health records,
Letters, or Care. Server operations can request re-authentication separately.

REQ-009: Supabase user ID is the stable account key for approved operational
analytics, consent receipts, and entitlement association. It must never be
used as a reason to upload readable health records.

## Non-Goals

- health-data cloud sync
- contact access or direct messaging
- anonymous-to-registered account conversion or identity merging
- storing report content on the server
