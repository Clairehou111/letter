# Lovable utility surfaces

## Goal

Port the approved Lovable presentation for Letter Within's utility family into the
production Flutter app while retaining all existing local-first behavior.

## Scope

- Make You a brief utility index rather than one long settings form.
- Move app lock, the always-on app-switcher cover explanation, Cycle Check-in,
  and optional cloud-tool consent into a pushed Privacy and protection page.
- Redesign encrypted full-data backup and staged merge/replace restore without
  changing encryption, credential storage, file, import, or commit behavior.
- Redesign Cycle and Care Summary setup/preview under its existing Reports
  entry point without changing Twin Matrix, range, note opt-in, PDF, CSV, or
  sharing logic.
- Preserve selected starting goals and Clear onboarding choices behavior.
- Keep pricing and entitlement UI out of this slice.

## Locked behavior

- App lock is on/off only. The app-switcher cover is always on.
- Cycle Check-in is on/off only and uses the existing scheduler and status.
- Cloud tools remain Off or Ask each time and never imply synchronization.
- Backup creation saves locally and opens sharing as one existing operation.
- Restore policy is selected before file picking; import remains staged and
  recoverable until commit.
- Clear onboarding choices does not delete health or cycle records.
- Summary stays at Letters → Reports → report detail; it is not duplicated in
  You.
- Share results use only the statuses supported by existing adapters.

## Navigation and accessibility

- Every pushed, loading, error, preview, and completion screen has a usable
  Back or Done path.
- One primary action per screen; destructive styling is reserved for actual
  removal/reset choices.
- Support 320 logical pixels, 200% text, reduced motion, and 44-pixel targets.
- Growing preview content uses progressive disclosure instead of expanding a
  root screen indefinitely.

## Out of scope

- Pricing, subscriptions, entitlement, accounts, cloud backup/sync, analytics.
- Changes to Care, Today, Cycle, Gravity Horizon, Spectrum Log, Letters, or the
  Reports hierarchy.
- Changes to prediction, encryption, import, clinical, or export semantics.
