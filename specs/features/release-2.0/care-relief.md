# Care Relief and Companionship Requirements

Status: approved 2.0 target; implementation evidence exists, locator-art and
clinical review remain release checks
Date: 2026-09-26

## Goal

Make `My body needs care` useful during physical discomfort through clear,
self-paced embodied comfort practices. Make both target experiences feel
accompanied, with an expressive cat present throughout their illustrated care
scenes.
The experience is for North American users and presents familiar wellness
language without dismissing or exoticizing Traditional Chinese Medicine.

This specification is a narrow exception to Release 2.0 REQ-021: interaction,
sub-scene order, pacing, illustration, motion, and the companion-name
preference may change only as required by `My body needs care`, `Everyday
care`, and the Settings surface that edits that preference. Minimal Care
assembly wiring may pass the preference into the two scenes. All other shared
Care contracts and every other Care scene remain authoritative and unchanged.

## Requirements

REQ-001: Product behavior remains limited to the two named Care experiences
and the companion-name preference in Settings. The smallest required Care
assembly and local-preference wiring may change to pass that name between
these surfaces. Do not change Reports, Patterns, navigation structure, shared
Care foundations, other Care scenes, health records, analytics, or unrelated
data behavior.

REQ-002: `My body needs care` may reorganize into a chooser of useful, optional
comfort practices. The person chooses a practice and advances at their own
pace without being required to tap a button after each illustrative beat;
they may return to the practice chooser or leave. The scene never advances or
ends on a timer. Its rest landing remains open until the person deliberately
exits or chooses its existing completion action.

REQ-003: Body-care sub-scenes may be reorganized around the action being
shown. Each action illustration must make the body's position, hand or prop
placement, movement direction, and a comfortable stopping point understandable
without relying on imagery alone. Body and point locator art prioritizes clear
anatomical contours, landmarks, markers, and leader lines over painterly
abstraction.

REQ-004: Acupressure guidance includes at minimum SP6 (Sanyinjiao) and LV3
(Taichong), as requested. PC6 (Neiguan) and ST36 (Zusanli) may be included only
after the content review in REQ-012 approves their location description and
safety framing. Every included point has a limb/body locator illustration,
point code and name, plain-language anatomical landmarks, and gentle,
non-painful self-guidance. A decorative dot without location landmarks does
not satisfy this requirement.

REQ-005: Heat therapy, restorative stretching, massage, and rest may be offered
as optional comfort rituals. They do not replace or obscure the existing
medical safety route. No practice requires a user to report pain severity or
complete a fixed duration.

REQ-006: Every illustrated comfort practice in both target experiences,
including tea, heat, shower, stretching, massage, and rest, includes the cat
as an active visual companion in its key states. Under full motion, the cat may
occasionally walk, relocate, sit, stretch, or sleep to resemble a real nearby
companion. Relocation happens only while walking; sitting, stretching, and
sleeping remain anchored. The movement is intermittent rather than constant,
never obscures anatomy or controls, stops when the app backgrounds or the page
is left, and becomes static for Reduced Motion. Its presence is comforting and
never presented as medical authority or as a source of health advice.

REQ-007: The cat's visual language takes inspiration from the brushwork,
gesture, and character of cat paintings attributed to the Xuande Emperor
(Zhu Zhanji). Before using a specific reproduction, record the identified
artwork, source, provenance, and rights basis. Otherwise create a distinct
original digital illustration that references those visual qualities without
copying a reproduction.

REQ-008: Everyday rituals include Ginger-Turmeric tea / Golden Milk and
Rose-Chamomile tea, warm showers, heat, massage, gentle movement, and deliberate
rest. Each is optional, described in familiar North American wellness language,
and visually demonstrates the actual preparation or action. Do not instruct
users to avoid ice water or imply a required cycle lifestyle.

REQ-009: Copy does not promise that acupressure, tea, heat, massage, movement,
or illustration will relieve, prevent, diagnose, or treat a condition or
regulate hormones, blood flow, inflammation, or the nervous system. Avoid
medical efficacy claims. Practices are framed as comfort options; stop if an
action feels painful or uncomfortable.

REQ-010: Suggestions are user-selected within the scene. No suggestion is
automatically triggered, ranked, or personalized from period, symptom, mood,
or other health records.

REQ-011: Preserve existing route, safety access, exit, shared completion
callback, explicit completion semantics, and persistence behavior. Add no
health data, analytics, notifications, network requests, or package
dependencies. The approved on-screen elapsed companion clock is transient,
never persisted, and never used as health evidence, completion, or analytics.
Preserve all existing toolkit ritual IDs and their completion payload identity.
New tea variants remain within the existing `warm-drink` action identity.
Preserve body step IDs and the `CareBodyScene.build(...)` public contract.

REQ-012: SP6 and LV3 remain visible product entries. Before release, their
rendered locator art, point locations, self-pressure instructions, and safety
copy receive a documented review by a qualified clinician with relevant
women's-health and/or acupuncture/acupressure experience. Any inaccurate art is
redrawn in the original illustration workflow and re-reviewed. An unresolved
clinical finding blocks release of the affected point; it does not authorize
silently hiding the approved entry, weakening its warning, or changing health
data and navigation contracts.

REQ-013: The visual direction is premium, warm, tactile, and legible for North
American wellness audiences. Avoid generic medical diagrams, exoticized TCM
motifs, infantilizing cat behavior, stock-card repetition, and decorative
motion that competes with the instruction. The cat is charming and artful while
the movement demonstrations remain anatomically credible.

REQ-014: Preserve accessibility: new and target-owned interactive controls
have 44 logical-pixel minimum targets; illustrations have screen-reader
descriptions; text remains readable at supported Dynamic Type sizes; contrast
is sufficient; and Reduced Motion retains equivalent information. No action
depends on color or motion alone. Scoped shared-foundation corrections are
allowed when required to fix a verified accessibility, safety, lifecycle, or
platform-navigation defect; they must not redesign unrelated Care scenes.

REQ-015: The cat accompanies illustrated comfort practices in both `My body
needs care` and `Everyday care`. It appears alongside the instructional figure
without obscuring body position, hand/prop placement, point landmarks, copy,
or controls. Under full motion it changes state at calm, irregular intervals,
walks only while changing position, and then settles in place. Headache/light-
sensitivity guidance uses a quiet static companion. Reduced Motion, static
fallbacks, hidden tabs, and backgrounded app states do not schedule movement.
The cat never advances, completes, times, or evaluates a practice.

REQ-016: Leaving an unfinished Everyday care ritual returns to the chooser and
records nothing, as today. Do not add persisted or in-memory ritual recovery.
The existing memory-evidence gate, proposal visibility, dismissal, and
reappearance behavior remain unchanged. A visual busy state during the
existing asynchronous completion handoff is allowed only if the completion
callback still fires at most once and retains its existing payload.

REQ-017: Use the approved editorial illustrations under
`apps/mobile/assets/images/care/editorial/` and retain their provenance. Do
not add a package dependency for artwork. Any replacement SP6/LV3 locator
must pass the qualified review in REQ-012 before release.

REQ-018: Do not require a separate button tap for every small action or
illustration beat. Essential guidance remains freely readable in a consolidated
scene or static storyboard. The cat may perform the intermittent companion
motion described in REQ-006 and REQ-015, including a safe warmth-side-table
gesture, but animation never auto-completes, persists, or leaves the ritual.
Reduced Motion presents equivalent static information and a settled companion
pose.

REQ-019: Body positions and care actions are presented as a small static
storyboard in normal reading or scroll order. All essential panels are visible
without tapping Next or revealing optional chips. Each panel shows one clear
pose, hand or prop placement, any relevant movement direction, and a
comfortable stopping point. The cat remains beside the practice and changes
pose between panels. `My body needs care` must add practical visual relief
guidance; a copy-only or text-plus-ember revision does not satisfy this
requirement.

REQ-020: Each illustrated practice shows a quiet, positive elapsed-time line
for the current visit. It starts when the practice page becomes active and
stops when that page is left. It is an elapsed companion clock, not a target,
countdown, efficacy measure, completion trigger, or analytics event. Duration
is never persisted. Copy may say, for example, "Miso has been here with you
for 4 minutes — 4 quiet minutes of listening to your body."

REQ-021: The person may give the companion cat a name in the `Care companion`
editor in Settings. Care never interrupts a difficult moment with a naming
prompt. A new or replacement name is written only after `Save name`. Cancel,
blank input, and whitespace-only input do not write. Trim surrounding
whitespace, enforce the 24-visible-character limit, and preserve Unicode
names.

REQ-022: The companion name persists only in the app's existing device-local
preferences. It is ordinary personalization, not a health record; it is not
uploaded, exported into clinician reports, used for analytics, or included in
care completion payloads. Existing stored preferences migrate without loss.
If no name is saved, copy uses `your cat` and all care remains available.

## Interaction Model

```text
SETTINGS
OPTIONAL CAT NAME -> SAVE LOCALLY

BODY CARE
CHOOSE -> ARRIVE -> FOLLOW STATIC COMFORT PANELS -> OPEN REST
  |          |                                  |
  +-> SAFETY +-> PAUSE / SKIP / EXIT             +-> EXPLICIT EXIT

EVERYDAY CARE
CHOOSE -> STATIC, SELF-PACED STORYBOARD -> REST / EXIT
          cat companion remains beside the practice
          elapsed visit time is visible but never saved
```

Existing completion callbacks fire only through their existing deliberate
user action. Browsing, pausing, skipping, and exiting do not create records.

## Non-Goals

- changes to any Care scene other than the two in scope;
- automatic symptom-based recommendations or health-data personalization;
- diagnosis, treatment plans, efficacy guarantees, herbal dosage, or
  medication guidance;
- forced countdowns, fast or attention-seeking decorative loops, or a
  requirement to finish an exercise; calm intermittent companion motion is
  explicitly allowed by REQ-006 and REQ-015;
- new health persistence, analytics, navigation, network services, or
  dependencies; companion-name persistence is the sole approved data addition;
- changing app-store declarations as a side effect of Care implementation.
