# Local Onboarding And Privacy Choices Requirements

Status: validated for the original onboarding flow; its cloud-AI preference is superseded by the permanent no-AI product constraint
Branch: `feature/local-onboarding-privacy`

## Context

The first product experience must establish Letter Within's purpose and privacy model
without forcing a long questionnaire. Research defines the first-use sequence
as promise/privacy, period history, symptom goals, then Today, with useful
completion in under two minutes.

Period dates belong to the next roadmap feature. This feature implements the
promise, privacy choice, and goals, then hands off to the existing synthetic
Today experience.

## Goal

Give a first-time user a short, trustworthy, accessible onboarding flow whose
completion and non-diagnostic preferences persist securely on the device.

## Decisions

- Use three steps: product promise, privacy choice, and goals.
- Health-record processing is permanently on-device and deterministic. There
  is no cloud-AI preference or consent path.
- Supabase and RevenueCat provide operational account and entitlement services
  only; account operations do not transmit health records.
- Store onboarding completion and goal identifiers with platform secure
  storage.
- Keep a repository interface so widget tests never require platform channels.
- Allow goals to be skipped; uncertainty must not block access to Today.
- Provide a privacy center from the `You` tab where account/health-data
  boundaries can be read and onboarding data can be reset.

## Scope

REQ-001: Route a new installation to onboarding and a completed installation
to the main Letter Within experience without flashing the wrong screen.

REQ-002: Present a three-step flow with visible and semantic progress, Back and
Continue controls, and no dead end at supported phone widths or 200% text scale.

REQ-003: Explain Letter Within's product promise without pregnancy-first language,
diagnosis claims, or framing the cycle as an enemy.

REQ-004: Explain in plain language that readable health records stay on the
device and are never sent to an AI service or cloud health-processing service.

REQ-005: Do not offer a setting that enables cloud AI or health-record
processing. Supabase and RevenueCat are limited to operational account and
entitlement services.

REQ-006: Let the user choose zero or more goals from cycle understanding,
emotional changes, physical discomfort, energy and sleep, self-care
preparation, and appointment preparation.

REQ-007: Persist a versioned onboarding profile through an abstract repository
and a platform secure-storage implementation. Do not transmit it or log its
contents.

REQ-008: Handle storage load/save failures explicitly with retryable UI. Never
silently mark onboarding complete after a failed save.

REQ-009: Provide a `You` privacy center that explains the permanent local
health-data boundary and allows clearing onboarding data after confirmation.

REQ-010: Preserve the approved Today visual baseline and bottom-navigation
order while making `You` functional.

REQ-011: Keep the onboarding privacy promise concise—account data is separate
from health records, and readable health records remain on the device—and
provide a `See how privacy works` action that opens a readable,
non-interactive explanation. Closing the explanation must return to the same
onboarding step without changing any preference.

## Non-Goals

- period dates, cycle history, prediction, or confidence
- authentication, subscription, analytics, or server consent receipts
- AI calls, AI transcription/parsing, or cloud report generation
- notifications or trusted contacts
- health database selection
- legal privacy-policy acceptance

## Privacy Boundary

Goal identifiers can reveal health interests and therefore must not use plain
shared preferences. Production persistence uses platform secure storage.
Widget tests use synthetic in-memory data only. No onboarding value may appear
in logs, analytics, API requests, crash metadata, or screenshots based on a
real person.
