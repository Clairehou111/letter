# Angry And Overloaded Impulse Buffer Requirements

Status: validated
Branch: `feature/angry-impulse-buffer`
Base branch: `feature/five-way-care-shell`

## Context

The five-way Care shell proves that `I want to explode` is understandable and
that the acute loop can be finite. Its current one-tap transformation does not
yet provide the approved Shatter ritual, private unsent draft, or 24-hour
app-enforced cooldown.

This feature stores highly sensitive free text. It must reuse Letter's
encrypted local health database on native platforms and remain memory-only on
the Web preview.

## Goal

Give an angry or overloaded user an immediate finite interaction, sharply
reduce stimulation, and create time between a private impulse and an external
action without claiming that catharsis treats anger.

## Requirements

REQ-001: Replace the generic explode shell with a dedicated
`Shatter -> Quiet transition -> Private draft -> Review -> Seal` flow.

REQ-002: Show one large abstract crystal. Every tap must create immediate
visible local change on the object while navigation and safety controls remain
stable.

REQ-003: End Shatter after 20 seconds or 20 taps, whichever comes first.
Provide `Skip to quiet` throughout. Leaving the flow must always be possible.

REQ-004: Respect reduced motion. Cracks and completion state must remain
legible without shake, scale, sound, haptics, or spatial animation.

REQ-005: Do not claim that tapping discharged aggression, reduced anger, or
provided treatment. Describe the interaction as putting force somewhere that
cannot send, post, purchase, resign, or end a relationship.

REQ-006: After completion or skip, cut to a low-stimulation surface and stop
the energetic interaction. Do not autoplay another Care mode.

REQ-007: Keep `I may not be safe` visible during Shatter, the quiet transition,
drafting, review, and locked-envelope states.

REQ-008: Offer a private plain-text draft with no recipient, send, share,
export, or external-app action. Voice capture remains outside this feature.

REQ-009: Accept 1 to 4,000 non-whitespace characters. The user may explicitly
save an unsealed draft and leave, resume it later, or delete it.

REQ-010: Before sealing, show the exact consequence: Letter will hide the text
for 24 hours inside the app; the user can still act elsewhere; the unopened
envelope can always be deleted.

REQ-011: Sealing must store an absolute UTC `sealedAt` and `unlockAt` exactly
24 hours later. It must not require a background timer, server, notification,
or network access.

REQ-012: Describe the mechanism as an app-enforced cooldown. Do not claim it
is cryptographically unbreakable, resistant to device-clock changes, or able
to prevent action outside Letter.

REQ-013: While `now < unlockAt`, never render the draft text, place it in
semantics, expose copy/share/export controls, or reveal it in a notification.
Show only envelope state and remaining time.

REQ-014: A locked envelope can always be permanently deleted without opening.
Deletion requires explicit confirmation.

REQ-015: When `now >= unlockAt`, show a ready envelope without revealing its
content. Offer `Open privately`, `Keep sealed another 24 hours`, and
`Delete unopened`.

REQ-016: `Open privately` is the only action that renders unlocked content.
After opening, the user may edit and reseal the rewritten text for 24 hours or
permanently delete it.

REQ-017: Keeping or resealing starts a new 24-hour cooldown from the current
UTC time. Preserve the original creation timestamp.

REQ-018: Support one active impulse-buffer record. A locked or ready envelope
takes precedence over starting another Shatter flow. An unsealed draft may be
resumed or deleted.

REQ-019: Native persistence must add the impulse-buffer table to the existing
SQLite3MultipleCiphers database and reuse its secure-storage key. Do not create
a second health database or encryption key.

REQ-020: Add an explicit version-1 to version-2 database migration that
preserves existing period rows. Test the migration.

REQ-021: The Web preview must use an in-memory repository and must not persist
draft content in browser storage.

REQ-022: Repository and UI failures must be explicit and retryable. A failed
save, seal, reseal, or delete must not be represented as success.

REQ-023: Do not create a CareEvent, clinical symptom, severity, report value,
analytics event, API request, LLM request, or behavior-to-clinical mapping.

REQ-024: Support 320 logical pixels at 200 percent text scaling and primary
controls of at least 44 logical pixels.

## State Model

```text
NONE
  -> SHATTER (ephemeral)
  -> QUIET (ephemeral)
  -> DRAFT (persisted only after explicit save/review)
  -> LOCKED (sealed; now < unlockAt)
  -> READY (sealed; now >= unlockAt; content still hidden)
  -> OPENED (content visible in current private UI session)
  -> LOCKED (reseal)
  -> DELETED
```

## Data Model

`ImpulseDraftRecord`:

- `id`
- `content`
- `createdAt`
- `updatedAt`
- nullable `sealedAt`
- nullable `unlockAt`

`LOCKED` and `READY` are derived from `unlockAt` and the injected clock. The
database does not silently mutate a status when time passes.

## Non-Goals

- proving Shatter is therapeutic
- sound, haptics, pressure, Force Touch, or accelerometer input
- voice capture or transcription
- multiple simultaneous impulse drafts
- tamper-proof time locks or trusted server time
- notifications or background jobs
- send, share, email, social, resignation, purchase, or focus-mode integration
- converting text to a future-self note
- clearer-day interpretation, NLP extraction, or clinical confirmation
- Care analytics or adverse-response measurement infrastructure

## Product Decisions

- The defensible mechanism is interruption, lower stimulation, removal of send
  affordances, and explicit delay, not aggressive catharsis.
- A ready envelope never opens itself.
- The same encrypted health store owns cycle and impulse-buffer data.
- Future-self conversion waits for the dedicated clearer-day memory feature.
