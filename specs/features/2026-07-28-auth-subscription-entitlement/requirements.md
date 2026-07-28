# Authentication And Subscription Entitlement Requirements

Status: proposed
Dependencies: local-first health storage and RevenueCat configuration

## Goal

Support account operations and paid entitlements without making an account or
server copy a prerequisite for local period tracking and Care.

## Requirements

REQ-001: A user can use local period, Care, and health-record features before
sign-in. Authentication is required only for an explicitly selected server
capability.

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

## Non-Goals

- health-data cloud sync
- contact access or direct messaging
- mandatory account creation
- storing report content on the server
