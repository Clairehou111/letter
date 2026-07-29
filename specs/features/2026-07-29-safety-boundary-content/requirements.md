# Safety Boundary Content Requirements

Status: validated
Branch: `feature/safety-boundary-content`
Base branch: `feature/phase2-personal-care-memory`

## Context

The five-way Care shell ships an honest dead end: the emotional safety sheet
says only that locale-aware crisis routing is not configured, and the physical
sheet gives a generic medical-attention statement without red-flag guidance
(`2026-07-28-five-way-care-shell` REQ-010/011).

The product philosophy requires safety and red-flag routing to be
**deterministic and locale-aware** (`specs/product-philosophy.md`, Evidence And
Safety). The clinical anchor rules require 988 and 911 for the U.S. and
localized crisis routing before any other-country launch
(`corpus/manual_gold/insights/20260726_batch_004_clinical_anchor_rules.md`).
This is a launch blocker for the paid MVP.

## Goal

Give every Care safety route real, deterministic, region-appropriate content:
verified crisis contacts for the launch markets (US and Canada), an honest
fallback everywhere else, and medical red-flag guidance that routes to care
without diagnosing.

## Requirements

REQ-001: Replace the unconfigured emotional safety content with configured
crisis content selected deterministically from the device region:

- `US`: 988 Suicide & Crisis Lifeline — call or text 988. 911 for immediate
  danger.
- `CA`: 9-8-8 Suicide Crisis Helpline — call or text 9-8-8. 911 for immediate
  danger.
- Any other or unknown region: an honest fallback directing the user to local
  emergency services, the nearest emergency department, or a trusted person.
  Never invent or guess another country's crisis numbers.

REQ-002: Crisis content must state plainly that Letter cannot provide
emergency help, and must encourage reaching out now. It must not diagnose,
moralize, shame, argue, minimize, or promise that the feeling will resolve on
any timeline.

REQ-003: Each displayed phone number must be tappable (`tel:`) and must also
remain fully visible as text so the number is never hidden behind a control
failure. If the dialer cannot open, the visible number remains the fallback.

REQ-004: Replace the physical medical-boundary content with two-tier red-flag
guidance:

- Urgent: fainting, chest pain or palpitations, severe or sudden pain, heavy
  bleeding with weakness or dizziness, or any symptom that feels like an
  emergency — seek urgent medical care now.
- Non-urgent: new, unusual, changing, severe, or function-limiting symptoms —
  book a medical assessment; what was noticed can be recorded and shown to a
  clinician.

REQ-005: Medical content must not diagnose, name conditions as the cause,
recommend starting/stopping medication or supplements, give dosing, or claim
Letter can assess the symptom.

REQ-006: Region selection must be pure and deterministic: a domain function
mapping a region/locale code to content, with no network, no LLM, no random
source, and no device-permission dependency. US and CA matching must be
explicit; everything else falls back.

REQ-007: The safety route must remain available and identical in every Care
scene state, and opening it must still stop the normal interaction. Leaving
the sheet (return to scene or leave Care) must require no explanation.

REQ-008: Nothing about safety-route use may be persisted, counted, scored,
included in history, reports, analytics, logs, or crash metadata. Opening a
safety sheet creates no Care event and no symptom candidate.

REQ-009: All safety content must remain usable at 320 logical pixels with
200 percent text scaling, with controls of at least 44 logical pixels, full
screen-reader semantics, and no dependence on animation, sound, or haptics.

REQ-010: All copy must be English at launch. A localization note must record
that any non-US/CA launch requires reviewed localized crisis content first.

## Non-Goals

- detection of crisis language from user text (deterministic routing exists
  only where the user explicitly opens the safety route)
- contacting a trusted person on the user's behalf
- crisis resources for countries outside the US and Canada
- emergency chat, calling on the user's behalf, or location sharing
- clinical triage questions or risk scoring
- notifications or follow-up after a safety route is shown

## Product Decisions

- Tap-to-call is included because a user in crisis must not have to memorize
  and manually dial; the visible number is the failure fallback.
- Canada is included because the launch market is North America (US & CA).
- The fallback for other regions is deliberately honest rather than a best
  guess; wrong crisis numbers are worse than none.
- Copy is short and declarative: the user on this screen needs a door, not an
  essay.
