# Letter Care Loop Redesign Requirements

Status: specifying
Branch: `feature/letter-care-loop-redesign`

## Context

The source discussion in `first-aid&letter phylosyphy.md` proposes a stronger
dual-context product: contain distress during hard moments, then help the user
reflect and prepare on clearer days. It also includes unsafe or unsupported
mechanisms that cannot become product requirements without revision.

This feature is a product-system redesign. It updates the mission, philosophy,
information architecture, roadmap, and implementation boundaries. Individual
Care screens and persistence are delivered as subsequent roadmap features.

## Goal

Define a coherent, safe Letter loop that is emotionally distinctive, remains a
real period tracker, and becomes more personally useful across cycles.

## Requirements

REQ-001: Keep cycle tracking and prediction as the foundation. The redesign
must not turn Letter into a generic emotional-wellness app.

REQ-002: Define the core loop as `Notice -> Contain -> Recover -> Reflect ->
Prepare -> Remember`.

REQ-003: Separate hard-moment support from clearer-day reflection. Do not ask
the user to analyze, learn, or solve life decisions during an acute wave.

REQ-004: Provide five accessible Care entrances: `I want to explode`, `I feel
heavy`, `My mind won't stop`, `I need everyone away`, and `My body hurts`.
Icons must have visible text labels.

REQ-005: Let angry/overloaded users enter an optional 20-second Shatter ritual
followed by an immediate low-stimulation transition. Treat it as expressive
interaction and an impulse interruption, not evidence that aggression has been
discharged. Provide skip, reduced-motion, sensory controls, and a stable
urgent-safety route.

REQ-006: Let users write a private no-recipient draft and explicitly seal it
for a fixed 24-hour cooldown. During the cooldown Letter must prevent reading,
copying, sharing, and exporting inside the app, but allow deletion without
opening. Afterward, restore full user access and offer keep, delete, rewrite, or
future-self-note choices.

REQ-007: Return the user's own saved comfort actions and messages before
generic content during a similar future context.

REQ-008: Keep physical Care symptom-specific and medically bounded. Do not
invent medication doses, universal dose intervals, onset times, or analgesic
claims for haptics.

REQ-009: Ask only a lightweight `better`, `same`, or `worse` check-back after a
Care action, with `not now` always available.

REQ-010: Make reflection opt-in and user-authored. Need labels and NLP/LLM
output are editable hypotheses, not psychological conclusions.

REQ-011: Support private drafts, notes from clearer days, and editable cycle
letters as distinct artifacts with distinct privacy behavior.

REQ-012: Use Letter, archive, envelope, and moon imagery as restrained brand
language, never as medical causality or a claim about Chinese tradition,
astrology, witchcraft, or youth preservation.

REQ-013: Keep safety and medical red-flag routing deterministic. Generative AI
must not decide whether a user is safe.

REQ-014: Make dark mode, motion, sound, haptics, continuous hold, and audio
optional. Care must remain operable without any one sensory channel.

REQ-015: Preserve the local-first architecture. Raw journals, cycle records,
Care history, and personal letters stay on device by default.

REQ-016: Update onboarding language and goals only after the redesigned core
journey is accepted; do not discard the validated persistence and privacy work.

REQ-017: Every acute scene must use a finite reward loop: immediate response,
visible transformation, one protective line, one personal or practical
hand-off, and an easy exit within 20 to 90 seconds.

REQ-018: Do not optimize Care for time spent, cards consumed, or repeated
distress entry. Exclude infinite feeds, streaks, coins, leaderboards, failure
states, and notifications that pull stable users back into distress content.

REQ-019: Match interaction energy to the state: energetic then quiet for rage,
near-zero effort for heavy/low, chaos-to-order for racing thoughts,
outside-to-closed for social overload, and low-stimulation plus practical
handoff for physical pain.

REQ-020: Keep observed Care events, unconfirmed symptom candidates, and
user-confirmed clinical ratings as separate data layers. Never map interaction
frequency, pressure, duration, app absence, or Care-mode use directly to a
clinical severity score.

REQ-021: Offer an optional recovery receipt that lets the user confirm symptom,
six-point severity, functional impact, and other signals after an acute event.
Mark ratings entered later as recall rather than prospective data.

REQ-022: Provide two report tiers: a provenance-safe Cycle and Care Summary for
normal use and a Prospective Clinical Diary for an optional two-cycle Doctor
Mode.

REQ-023: Do not use `DRSP`, `DRSP-compatible`, or diagnostic-equivalence claims
until the exact instrument, licensing, wording, scoring, daily completion, and
clinical review requirements are satisfied.

REQ-024: Every report value must identify whether it came from a prospective
user rating, same-day user rating, later recall, factual Care event, or
user-entered medication event. AI candidates cannot appear until confirmed.

## Non-Goals

- implementing all Care modes in one feature
- claiming the Shatter ritual reduces anger through catharsis
- claiming the 24-hour cooldown is cryptographically unbreakable or prevents
  action outside Letter
- hiding or deleting a sealed draft without the user's explicit action
- automatically controlling device focus mode or other apps
- a universal painkiller countdown
- automatic mapping from people or work keywords to an unmet need
- claiming a lunar phase explains a symptom
- replacing prospective symptom tracking with narrative interpretation
- validating willingness to pay from internal product opinion

## Product Decision Gate

Before UI implementation begins, the redesign must answer:

- what Letter does in the first ten seconds of a hard moment
- what is stored during Care and when it can reappear
- what the user, deterministic rules, and optional AI each decide
- how the product handles anger without escalating arousal
- how medical and urgent-safety exits remain visible
- why a user returns across a second and third cycle
