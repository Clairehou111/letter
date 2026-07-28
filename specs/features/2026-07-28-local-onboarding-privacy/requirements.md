# Local Onboarding And Privacy Choices Requirements

Status: approved
Branch: `feature/local-onboarding-privacy`

## Context

The first product experience must establish Letter's purpose and privacy model
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
- Default cloud tools to `off`. The alternative is `ask each time`, which is a
  preference and never consent for a particular cloud request.
- Every future cloud operation still requires a purpose-specific payload
  preview and confirmation.
- Store onboarding completion, cloud preference, and goal identifiers with
  platform secure storage.
- Keep a repository interface so widget tests never require platform channels.
- Allow goals to be skipped; uncertainty must not block access to Today.
- Provide a privacy center from the `You` tab where the cloud preference can be
  changed and onboarding data can be reset.

## Scope

REQ-001: Route a new installation to onboarding and a completed installation
to the main Letter experience without flashing the wrong screen.

REQ-002: Present a three-step flow with visible and semantic progress, Back and
Continue controls, and no dead end at supported phone widths or 200% text scale.

REQ-003: Explain Letter's product promise without pregnancy-first language,
diagnosis claims, or framing the cycle as an enemy.

REQ-004: Explain in plain language that readable health records stay on the
device by default and that nothing is sent to cloud AI without a later,
purpose-specific preview and approval.

REQ-005: Let the user choose `Cloud tools off` or `Ask me each time`, with off
selected by default and neither option granting upload consent.

REQ-006: Let the user choose zero or more goals from cycle understanding,
emotional changes, physical discomfort, energy and sleep, self-care
preparation, and appointment preparation.

REQ-007: Persist a versioned onboarding profile through an abstract repository
and a platform secure-storage implementation. Do not transmit it or log its
contents.

REQ-008: Handle storage load/save failures explicitly with retryable UI. Never
silently mark onboarding complete after a failed save.

REQ-009: Provide a `You` privacy center that shows the current privacy mode,
allows changing it, and allows clearing onboarding data after confirmation.

REQ-010: Preserve the approved Today visual baseline and bottom-navigation
order while making `You` functional.

## Non-Goals

- period dates, cycle history, prediction, or confidence
- authentication, subscription, analytics, or server consent receipts
- cloud AI calls, transcription, parsing, or report generation
- notifications or trusted contacts
- health database selection
- legal privacy-policy acceptance

## Privacy Boundary

Goal identifiers can reveal health interests and therefore must not use plain
shared preferences. Production persistence uses platform secure storage.
Widget tests use synthetic in-memory data only. No onboarding value may appear
in logs, analytics, API requests, crash metadata, or screenshots based on a
real person.
