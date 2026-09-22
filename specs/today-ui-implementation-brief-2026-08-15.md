# Today UI Implementation Brief — 2026-08-15

## Scope

Complete **Today only** in the canonical Flutter app. Do not modify Cycle,
Care, Patterns, Reports, Plus, You, or the five-tab shell. The current Cycle
destination — especially its period detail, `Edit dates`, `Fill in days`,
`Delete period`, day editor, and bleeding-day history — is frozen.

The visual baseline is visual-v2: warm editorial daylight, coral phase hero,
Newsreader-led hierarchy, illustrated degrees, and compact soft cards. Kimi
owns the layout inside Today, but must not redesign the product shell.

All user-facing copy and generated Dart UI must be English.

## User behavior model

Today means **record what is happening today with the least possible effort**.
It must not feel like opening and completing a form. Mood, bleeding, bleeding
color, and symptoms must all be recordable from Today through compact cards
or compact sheets. Every successful choice persists immediately.

Remove the separate `Record today`, `Record today in detail`, and `Open today's
record` form journey. There is no final page-level Save button and no required
complete daily submission.

## Persistent top hero

Restore the coral gradient cycle-status card at the top of Today. It is the
first answer to “where am I now?” and must never disappear merely because the
full ring model lacks enough history.

The card has honest data states:

- **Supported context/prediction:** show the adapter/domain-supplied phase or
  cycle context, current cycle day, and predicted menses **range**.
- **Partial history:** show only factual known context/day plus a concise
  learning/rough-estimate message. Show an estimate only if the existing
  prediction contract supplies one.
- **No history:** keep the card and explain that one recorded period start
  begins the cycle story; provide the existing period-start action.

Preserve the visual character of the approved coral card, but do not restore
its stale logic. UI must not calculate or display a prediction midpoint,
single “next period” date, countdown, approximate cycle length, confidence, or
phase that is not supplied by the existing contract.

Remove the large ring from Today so the page has enough space for fast daily
recording. The coral hero remains the cycle-context surface. The Cycle ring is
outside scope and must remain unchanged.

## Compact Today recording

The complete page should remain visually tight and calm. Do not render every
choice as a full-width row or create a long form.

### Primary mood

- Display a compact set of the highest-priority/frequent moods directly on
  Today, with `More` opening the remaining catalog in a compact sheet.
- Exactly one primary mood is stored for the date, with no mood intensity.
- Selecting a mood immediately saves it. Selecting another replaces today's
  primary mood.
- A mood-only interaction is a complete valid daily action.
- Difficult moods may reveal a quiet Care doorway, but Care never opens
  automatically.
- Primary mood remains separate from emotional symptoms.

### Bleeding and color

- Keep bleeding in one compact card/cluster, not one full-width row per degree.
- Use words plus distinct illustrated droplets for `None`, `Spotting`, `Light`,
  `Medium`, and `Heavy`.
- `null` means unanswered; explicit `None` is a saved answer.
- Selecting a flow immediately saves it and gives quiet feedback.
- For Spotting/Light/Medium/Heavy, offer Pink, Bright red, Dark red, and Brown
  through a compact inline control, popover, or sheet that collapses after the
  choice. Do not permanently expand the page with a second long section.
- Flow changes atomically clear an incompatible color through the existing
  repository behavior; UI must not fake a second save.
- Spotting never starts or extends a period.
- Starting a period and ending today's open period remain explicit, separate,
  compact controls inside or next to the bleeding card.
- Flow/color never feed prediction, symptom severity, Gravity, Spectrum, or
  Twin.

### Symptoms

- Symptoms are available every day, whether bleeding or not.
- Keep Today compact: show saved symptoms as concise editable chips/rows plus
  one `Add a symptom` action. Do not show the entire catalog on the page.
- The add flow is one symptom at a time:
  `Choose symptom → choose severity → immediate save → return to Today`.
- After saving, the user can add another symptom.
- Multiple symptoms may exist on the same date. Selecting an already-recorded
  symptom edits that record rather than creating a duplicate.
- Each symptom has its own named severity: `Minimal`, `Mild`, `Moderate`,
  `Severe`, `Extreme`. Never show `Not at all`.
- Pain is represented only by pain-kind symptoms using the same five
  severities. Never show a 0–10 pain score or pain-location field.
- Selecting a safety-route symptom opens the existing safety route immediately,
  preserves the in-progress selection, and does not auto-save that symptom.
- Saved symptom items support edit and explicit remove/withdraw.

## Notes and memory

- `A note to self` remains a separate, low-priority route. Do not place a note
  field inside Today recording or imply that a note is expected every day.
- Evidence-backed remembered-help content may remain, but it must never use
  fabricated sample claims or hard-coded counts. Keep it subordinate to the
  current-day recording flow.

## Feedback and errors

- Each mood, bleeding, color, symptom, period-start, and period-end mutation
  gives an immediate quiet saved/error response near its originating control.
- Failed saves preserve the visible selection and allow Retry.
- Use `Saved.` only as fallback success copy.
- Use `Letter Within couldn't save that. Try again.` only as fallback error
  copy.
- No visible Today control may silently do nothing or route to an unrelated
  tab.

## Ownership boundaries

- May edit `lib/experience/today/today_experience.dart`.
- May add private presentation files under `lib/experience/today/` if useful.
- May edit shared degree/observation presentation widgets only if strictly
  required and only when Cycle remains source-compatible and visually intact.
- Must not edit `lib/experience/cycle/`, Care, the tab shell, app adapters,
  domain/data repositories, prediction, Gravity, Spectrum, Twin Matrix,
  database, auth, entitlement, reports, or backup.

## Acceptance

- The coral context hero is visible for populated, partial-history, and empty
  states without invented prediction facts.
- Today does not render the large cycle ring.
- Mood, bleeding, conditional color, and any number of symptoms can be
  recorded quickly from Today without a full daily form.
- Bleeding choices are compact rather than one item per line.
- Symptoms are added one at a time and saved independently.
- There is no `Record today`/full-editor journey.
- Today remains compact at phone width and accessible with larger text.
- Cycle is byte-for-byte untouched.
- Changed files format and Flutter analysis passes.
