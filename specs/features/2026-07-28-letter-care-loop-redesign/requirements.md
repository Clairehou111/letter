# Letter Care Loop Redesign Requirements

Status: approved
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

REQ-005: Let angry/overloaded users enter an immediate abstract ink-compression
ritual followed by a low-stimulation seal. Treat it as expressive interaction
and an impulse interruption, not evidence that aggression has been discharged.
Do not require repeated aggressive impact. Provide a one-tap completion route,
reduced motion, silence, and a stable urgent-safety route.

REQ-006: Let users write a private no-recipient draft and explicitly seal it
for a fixed 24-hour cooldown. During the cooldown Letter must prevent reading,
copying, sharing, and exporting inside the app, but allow deletion without
opening. Afterward, restore full user access and offer keep, delete, rewrite, or
future-self-note choices.

REQ-007: Return the user's own saved comfort actions and messages before
generic content during a similar future context.

REQ-008: Keep physical Care symptom-specific and medically bounded. Do not
provide medication logging, names, doses, intervals, reminders, or interaction
advice, and do not make analgesic claims for haptics.

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

REQ-017: Every acute scene must use a finite state-shift loop: validation,
immediate response, participatory visible change, a return to the present, and
an easy exit. The scene ends automatically at 90 seconds, while the user may
choose `Stay a moment` at any time to open the normal check-in directly.

REQ-018: Do not optimize Care for time spent, cards consumed, or repeated
distress entry. Exclude infinite feeds, streaks, coins, leaderboards, failure
states, and notifications that pull stable users back into distress content.

REQ-019: Match interaction energy to the state: energetic then quiet for rage,
near-zero effort for heavy/low, chaos-to-order for racing thoughts,
outside-to-closed for social overload, and low-stimulation plus practical
handoff for physical pain.

REQ-031: Selecting one of the five Care entrances must open its full-screen
motion scene immediately. Do not add a feeling picker or a `Touch`, `Words`,
or `Still & dim` route selector. Physical Care may ask one short context
question only because cramps/back pain, nausea/bloating, headache/migraine,
and general tension require materially different visual behavior.

REQ-032: Ask `Gone for now`, `Less intense`, `About the same`, or `More
intense` only as an ephemeral navigation check after the experience. Do not
store this as clinical severity or conflate it with the persisted
Better/Same/Worse result for a completed practical Care action.

REQ-033: Keep Back, Leave, and deterministic emotional/medical safety routing
reachable at every Care Break phase, including small screens, large text, and
reduced-motion use.

REQ-034: Do not ask the user to write during the immediate scene. Short,
app-authored supportive lines may surface only inside the motion at meaningful
turning points. Show one line at a time; bring it from blur into focus, hold it
briefly, then dissolve it back into the scene. It must never appear as a card,
feed, modal, or separate reading route.

REQ-035: Every motion scene must continuously respond to gesture position and
movement when the user participates, while also providing a one-tap or
automatic completion path. Do not use a tap counter, score, failure condition,
target, or repeated aggressive impact.

REQ-036: Do not expose `Still & dim` as a Care route. Reduced-motion settings
must automatically preserve the scene's meaning without spatial animation,
sound, haptics, typing, or a continuous hold. Headache/migraine must
automatically use a dim, motionless physical-Care presentation.

REQ-037: Optional Care sound is off by default and begins only after explicit
opt-in. It must be local, abstract, low-volume, and nonessential. Do not use
voices, heartbeats, reward jingles, notification-like tones, or user-derived
audio.

REQ-038: If the user reports `More intense`, stop additional novelty and offer
exit, safety, or a genuinely distinct practical protection. Do not tell the
user to repeat the same scene until it works.

REQ-039: Do not append a universal legacy practical flow. Heavy and racing
thoughts end after the shared state-shift. Anger, needing space, and physical
discomfort may offer distinct consequence-protection, boundary, or familiar-
comfort handoffs.

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
user rating, same-day user rating, later recall, or factual Care event. AI
candidates cannot appear until confirmed.

REQ-025: Apply the Letter metaphor in three layers: ritual for emotional
meaning, familiar utility controls for repeated tasks, and plain clinical
presentation for doctor-facing evidence.

REQ-026: Use moonlight as brand rhythm only. Do not map cycle phases or Care
states to astronomical moon phases as physiological fact or replace direct
health labels with mystical names.

REQ-027: Trigger Reply Rituals when a cooldown ends and the user chooses they
are ready. Do not assume cycle day 4 or 5 means the user is happy, rational, or
able to reflect.

REQ-028: Keep NLP keyword highlighting optional and user-confirmed. Raw Care
language may be worth revisiting but is not automatically the body's truth.

REQ-029: Present the Archive as scannable cycle folios with separate `Story`,
`Pattern`, and `Clinical` views. Narrative styling must not replace comparable
data or report provenance.

REQ-030: Defer physical subscriptions, supplements, and cycle-timed fulfillment
until the software loop has market evidence and separate regulatory, privacy,
fulfillment, and product-liability review.

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
