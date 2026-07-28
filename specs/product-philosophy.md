# Letter Product Philosophy

Status: redesign draft
Date: 2026-07-28

## Core Idea

Letter is a private period tracker built around a conversation across time:

- in a hard moment, Letter reduces decisions and holds what the user does not
  want to act on yet
- after the wave, Letter offers a small, optional check-back
- on a clearer day, Letter helps the user decide what the experience may have
  been asking for
- before a similar moment, Letter returns the user's own words and previously
  helpful actions

The product does not tell a user what their body "really means." It preserves
evidence, offers hypotheses, and lets the user author the interpretation.

Product promise:

> Your body writes in patterns. Letter helps you through hard moments,
> remembers what helped, and brings your own wisdom back when you need it.

## The Letter Loop

```text
NOTICE
  user records a period, symptom, thought, or need
    |
    v
CONTAIN
  reduce stimulation, delay impulsive action, offer familiar comfort
    |
    v
RECOVER
  one optional check-back: better, same, or worse
    |
    v
REFLECT
  when the user chooses: what felt true, what was needed, what helped
    |
    v
PREPARE
  save a message, action, boundary, or practical setup for next time
    |
    v
REMEMBER
  surface the user's own relevant plan in a similar future context
    +--------------------------------------------------------------> NOTICE
```

The natural retention unit is a cycle, not a daily streak.

## Two Product Contexts

### Hard Moment

The interface acts as a low-cognitive-load container:

- one-tap entry with accessible text labels
- one decision or action per screen
- optional dim theme, sound, haptics, and motion
- the user's own saved actions before generic suggestions
- a visible route for urgent emotional or medical safety
- no lesson, causal interpretation, or reflection homework

### Clearer Moment

The interface acts as a user-directed mirror:

- the user chooses whether and when to reopen a note
- the app distinguishes observation from interpretation
- need labels are optional prompts, not diagnoses
- AI or deterministic extraction produces editable suggestions only
- any suggested real-life action requires the user's approval
- the user can leave a short message for a future difficult day

Do not call these contexts `sane` and `insane`, or imply that every day outside
the follicular phase is a bad day.

## Five Care Entrances

Icons support the labels but never replace them:

1. `I want to explode`
2. `I feel heavy`
3. `My mind won't stop`
4. `I need everyone away`
5. `My body hurts`

The user names their state. Letter must not infer or declare it from a cycle
prediction.

See `care-experience-system.md` for the finite reward loop and detailed scenes.

### Angry Or Overloaded

The experience may begin with energy and attitude, but its product goal is to
interrupt an impulsive action and move toward lower stimulation.

#### Shatter Ritual

- show one large abstract crystal or glass surface
- let the user tap repeatedly for up to 20 seconds
- confine visual shaking to the interactive object; navigation and safety
  controls must remain stable
- use optional sound, haptics, and motion that respect system settings and the
  user's reduced-motion preference
- provide an immediate skip control and an always-visible urgent-safety route
- end with a deliberate cut to a quiet, dim surface

This is an expressive game and attention-interruption ritual, not a therapeutic
claim that aggression has been discharged. The product must measure whether
users feel calmer or more activated after it and remove or alter the interaction
if it commonly escalates distress.

#### 24-Hour Impulse Buffer

After the transition, Letter:

1. names the purpose directly: do not send, post, resign, purchase, or make a
   relationship decision from this screen state
2. offers a private text or voice draft with no send target
3. shows the exact consequence before sealing
4. seals the draft for a fixed 24 hours when the user confirms
5. prevents reading, copying, exporting, or sharing the sealed text inside
   Letter until the period ends
6. always permits deleting the sealed envelope without opening it

The draft is encrypted at rest with the rest of the local health store. Letter
must describe the feature as an app-enforced cooldown, not an unbreakable
cryptographic time lock or a guarantee that the user cannot act elsewhere.

When the period ends, Letter does not reveal the text in a notification. The
user can open it privately, keep it sealed, delete it, rewrite it as a calmer
message, or turn the underlying need into a note for the next cycle.

### Heavy Or Low

The goal is presence with minimal effort:

- tap once to start a quiet `stay with me` interval
- show one short user-approved or carefully bounded message at a time
- make holding, swiping, audio, and haptics optional
- show the urgent-safety route without forcing the user to read more

The product may say that a state has passed before when the user's history
supports it. It must not say that biology is the only explanation.

### Racing Or Overwhelmed

The goal is to turn simultaneous demands into one controllable point:

- visual complexity must decrease after the first interaction
- the user may park one thought for tomorrow without creating a task list
- breathing, holding, and typing remain optional
- the flow ends with one next action or permission to do nothing now

### Need Everyone Away

The goal is a truthful, low-effort boundary:

- offer user-edited messages for a partner, friend, or work context
- never invent a migraine, illness, or safety claim
- let the user choose the duration and recipient
- prepare messages on a clearer day where possible

Letter cannot promise to disconnect the phone or control other apps. Platform
focus-mode integrations require separate feasibility work.

### Physical Pain

The goal is practical comfort with an explicit medical boundary:

- identify pain type and severity
- ask whether it is familiar or new, unusual, or severe
- return the user's saved comfort action and location-specific note
- allow a later effect check-back
- record a medication only as user-entered history

Letter must not invent dose timing, tell a user when another dose is safe, or
claim haptics treat pain. Medication reminders may only reproduce a schedule
the user explicitly saved from a product label or clinician instruction, with
clear editing and source context.

## Letters Across Time

Letter has three distinct artifacts:

### A Private Draft

Words written during a hard moment. Before sealing, the user can edit or delete
them. After explicitly starting the 24-hour protocol, Letter hides and disables
copy/share/export of the content until the timer ends, while still allowing the
unopened envelope to be deleted. After the timer, the user may revisit, edit,
export, keep, or delete it.

### A Note From Clearer Me

A short user-authored message or action for a future difficult moment. It is
surfaced by user-approved cycle timing and symptom similarity, not by a claim
that the app understands the user's subconscious.

### A Cycle Letter

An editable cycle summary containing:

- period timing
- positive, neutral, and difficult symptoms
- functional impact
- support actions tried
- user-reported outcomes
- user-authored reflections

Poetic narrative is optional. Pattern counts, confidence, safety information,
and doctor exports stay direct and clinically legible.

## Reflection Without Overclaiming

Premenstrual symptoms can amplify distress around real situations, coexist
with another condition, or be misattributed. Letter therefore asks:

> Looking back, did this point to something you want to remember?

Optional need prompts:

- boundaries
- connection
- autonomy
- rest or physical capacity
- something else
- not sure

Use `may`, `might`, and `you decide`. Never state that PMS reveals an objective
truth, that a relationship or job is the cause, or that a specific hormone
created a thought.

## Brand And Cultural Boundary

`Letter` and `monthly correspondence` are the primary metaphors. Moon phases,
envelopes, stamps, and archival details may provide restrained visual language.

They are not health measurements or medical explanations. The product must
not claim:

- a symptom state corresponds medically to a moon phase
- traditional Chinese medicine proves the recommendation
- witchcraft, astrology, or Chinese culture makes the product effective
- menstruation inherently preserves youth

The North American appeal of any cultural framing is a market hypothesis that
requires concept testing with target users.

## Evidence And Safety

- Prospective cycle and symptom records help reduce recall bias and distinguish
  recurring premenstrual patterns from symptoms occurring throughout a cycle.
- The energetic Shatter ritual is not treated as a therapeutic mechanism.
  Letter's defensible intervention is the immediate downshift, removal of send
  affordances, explicit delay, and later user-directed review.
- Different over-the-counter pain medicines and products have different label
  intervals and warnings, so there is no universal four-hour timer.
- Safety and red-flag routing remains deterministic and locale-aware.
- The product does not diagnose PMS/PMDD, prescribe, or replace clinical care.

Clinical anchors:

- ACOG Clinical Practice Guideline No. 7:
  https://www.acog.org/clinical/clinical-guidance/clinical-practice-guideline/articles/2023/12/management-of-premenstrual-disorders
- Anger arousal meta-analysis:
  https://pubmed.ncbi.nlm.nih.gov/38518585/
- U.S. DailyMed ibuprofen menstrual-pain label:
  https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=ae1625f4-ef32-4d4f-bf54-c44085843e41
- U.S. DailyMed naproxen menstrual-pain label:
  https://dailymed.nlm.nih.gov/dailymed/lookup.cfm?setid=2b4135b3-389c-46e2-ae86-7674c2ab9a32

## Experience Architecture

Primary navigation:

1. `Cycle`
2. `Letters`
3. `Today`
4. `Care`
5. `You`

`Today` remains the central home anchor. `Care` remains one tap away. `Letters`
contains cycle letters, patterns, and report entry; it does not disguise
medical evidence behind poetic copy.

## P0 Value

Letter earns payment through compounding personal usefulness:

> period tracking + low-effort logging + in-the-moment Care + the user's own
> remembered remedies and messages + cautious patterns + doctor-ready evidence

Static reassurance, generic remedy lists, decorative moon mythology, and
haptic interactions alone are not a paid moat.
