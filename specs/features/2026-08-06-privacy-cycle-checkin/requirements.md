# Privacy and Cycle Check-in requirements

Status: approved 2026-08-06

## Scope

- Cover health content in the app switcher whenever Letter Within becomes inactive.
- Offer an optional app lock using the device's authentication UI.
- Provide one local Cycle Check-in notification, enabled by default.
- Keep notification wording neutral by default and never use “late”.
- Keep all preference, prediction, and scheduling work on device.

## Cycle Check-in behavior

- Use the existing `CyclePredictionEngine` without changing its estimation logic.
- When a prediction exists, schedule one check-in for the local calendar day after
  `predictedMensesEnd`.
- Use one stable notification identity so a recalculation replaces the previous
  pending check-in.
- Cancel or recalculate after period creation, editing, deletion, import, or reset.
- Do not schedule when permission is denied, the feature is disabled, or no
  prediction exists.
- A notification tap must pass through the app lock before opening Cycle.
- Notification payloads and displayed text must contain no dates, symptoms, notes,
  period status, or other health data.

## Explicit exclusions

- Decoy mode, cover PINs, shake gestures, and double-back gestures.
- Care follow-ups, PMS warnings, emotion-based prompts, streaks, and engagement
  notifications.
- Cloud scheduling or analytics.
- Pricing and entitlement changes.

