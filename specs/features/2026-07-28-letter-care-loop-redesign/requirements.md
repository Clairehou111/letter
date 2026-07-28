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

REQ-004: Provide four accessible Care entrances: angry or overloaded, heavy or
low, need space, and physical pain. Icons must have visible text labels.

REQ-005: Design anger support to reduce arousal and delay impulsive action.
Exclude aggressive catharsis as the therapeutic mechanism.

REQ-006: Let users save private drafts and choose a cooling-off time while
retaining the ability to access, edit, export, or delete their own content.

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

## Non-Goals

- implementing all Care modes in one feature
- a 3D shatter chamber or pain-melting visual
- an irreversible 24-hour content lock
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
