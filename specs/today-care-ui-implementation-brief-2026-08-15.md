# Today + Care UI Implementation Brief — 2026-08-15

> Superseded for implementation. The active owner scope is Today only; use
> `today-ui-implementation-brief-2026-08-15.md`. Care and Cycle are frozen.

## Purpose

Complete the presentation and interaction paths for Letter Within's **Today**
and **Care** destinations in the canonical Flutter app. The current
`visual-v2` implementation is the visual baseline: warm editorial daylight for
Today and a dark plum, low-stimulation world for Care. Preserve that product
identity, but do not treat the current widget layout as fixed. Kimi owns the
layout, grouping, progressive disclosure, sheets/pages, and interaction path
inside these two destinations.

This pass completes UI and presentation behavior. It must not invent backend
success, rewrite domain algorithms, change prediction math, or implement the
deferred high-fidelity Care animation system.

All user-facing copy and generated Dart UI must be English.

## Product position

Letter Within combines period tracking with low-effort daily recording and
immediate Care for sudden premenstrual emotional or physical distress. In a
hard moment, Care should make the user feel met within seconds, guide one
finite useful action, and make leaving easy within roughly 20–90 seconds.
Emotional value and a sense of non-judgmental presence are core product value.

## Today — required capabilities

- Today is the default current-moment surface and supports recording on both
  bleeding and non-bleeding days.
- Show the current date and honest cycle/prediction context. Ring placement is
  not prescribed: keep it only if it improves hierarchy. All prediction copy
  and geometry must come from existing adapter/domain values; do not calculate
  a midpoint, countdown, confidence, or date in UI.
- Quick interaction immediately persists one primary mood, flow, and a
  conditional bleeding color. A mood-only action is valid and complete.
- Give immediate, quiet saved/error feedback without requiring a final form
  submission for quick fields.
- Provide a complete **Record today** editor. It opens for today, is prefilled
  from already-saved quick values, stages edits locally, and performs one
  explicit commit.
- **Open today's record** must open that editor directly and return to Today
  with saved values visible. It must not merely switch to Cycle.
- Notes remain a separate, low-priority route. Do not place a note field in the
  daily editor or visually pressure the user to write.
- Starting a period is independent from choosing flow. Spotting never starts
  or extends a period.
- A difficult primary mood may reveal a quiet route into Care; it must never
  open Care automatically.

## Daily record semantics

- Exactly one date-bound primary mood, with no mood intensity.
- Primary mood and emotional symptoms are separate concepts. Mood is a fast
  description of the current moment; emotional symptoms are confirmed symptom
  records used in longitudinal comparison.
- Multiple symptoms may be recorded on any non-future date in any cycle phase,
  including non-bleeding days.
- Every selected symptom has its own named severity: **Minimal, Mild,
  Moderate, Severe, Extreme**. Never show **Not at all**.
- Pain exists only as pain symptoms using those same five severities. Do not
  show a 0–10 pain score or a pain-location field.
- Flow is **None, Spotting, Light, Medium, Heavy**, using words plus distinct
  graphics. `null` means unanswered; explicit **None** is a saved answer.
- Bleeding color is **Pink, Bright red, Dark red, Brown**, using words plus
  swatches/graphics. It appears only when flow is Spotting, Light, Medium, or
  Heavy.
- Flow and color do not feed prediction, symptom severity, Gravity, Spectrum,
  or Twin.
- Selecting a symptom that requires a safety route opens the existing safety
  route immediately, preserves the staged editor draft, and does not auto-save
  that symptom.
- Failed saves preserve the draft and selections for Retry. Use `Saved.` only
  as the fallback success copy and `Letter Within couldn't save that. Try
  again.` only as the fallback error copy.

## Care — required information architecture

Care has two reasons to enter:

1. **Right now is hard:** sudden emotional or physical distress requiring a
   low-decision finite response.
2. **Everyday care:** the user is stable and chooses a guided comfort action.

The five acute entrances are stable, visible, and never inferred, ranked,
reordered, preselected, or auto-opened:

1. `I want to explode`
2. `I feel heavy`
3. `My mind won't stop`
4. `I need everyone away`
5. `My body needs care`

Each entrance needs text plus a meaningful supporting icon/graphic. Every
visible entrance and subsequent action must be clickable in this pass.

## Care — finite acute flow

Every acute path follows this product grammar, while Kimi owns its visual and
navigation expression:

1. Name the state with one tap.
2. Respond immediately so the interface visibly acknowledges the tap.
3. Guide one finite action or symbolic transformation.
4. Offer at most one short validating/protective line at a time.
5. Hand off to one real-world action, optional symptom recording, or permission
   to do nothing.
6. Provide an obvious exit at every stage.

Do not add feeds, streaks, scores, coins, failure states, forced completion,
or autoplay into another distress mode. Acute Care and safety are never
paywalled. Do not ask for reflection during the acute loop.

### Acute mode intent

- **I want to explode:** contain high energy and create time between feeling
  and action. The UI may offer a private unsent draft or pause action, but must
  never imply that anything was sent or shared.
- **I feel heavy:** require almost no effort; acknowledge crying, emptiness,
  low energy, or hopelessness. Offer `Stay with me`, `Record symptoms`, and
  `Nothing else right now` without pressure.
- **My mind won't stop:** reduce many thoughts to one point or allow the user
  not to name the thought. Any current-session thought text is ephemeral and
  must not be presented as saved memory.
- **I need everyone away:** create a symbolic boundary. If editable boundary
  words are offered, copying must be explicit; never claim delivery, contact
  access, Focus control, or message sending.
- **My body needs care:** first choose the closest physical experience:
  cramps/pelvic/lower-back pain; headache/migraine; nausea/bloating;
  breast/joint/muscle tenderness; or exhaustion/depletion. Comfort comes before
  form filling. A visible `This is new, unusual, or severe` route must open the
  existing medical boundary instead of the ordinary comfort flow.

`I may not be safe` / self-harm crisis support must remain deterministic,
visible, and immediately reachable. It replaces the ordinary flow and never
depends on subscription or cycle timing.

## Everyday Care

- Everyday Care must be guided interaction, not a static advice card list.
- Initial actions may include warmth, gentle movement, a warm shower, lower
  belly/back massage, a comfortable rest position, or a warm drink/comfort
  ritual.
- Each action must have a short step-by-step path, one step at a time, and a
  clear action outside the app.
- Use cautious comfort language; do not claim to treat pain or guarantee
  relief. Do not make a specific claim for brown sugar.
- A realistic companion cat and rich animation remain future animation work.
  This pass may reserve their stage/space but must not create crude substitute
  animation or make the user wait for it.

## Completion, outcome, and memory

- After a deliberately completed Care action, optionally ask `Did this help?`
  with **Better, Same, Worse**. Only an explicit answer becomes an outcome.
- Merely reading a suggestion is not a completed action and not a helpfulness
  record.
- Symptom recording remains a separate explicit action after Care; Care
  gestures, duration, or completion never infer symptom severity.
- Past-help statements appear only when existing evidence supports them. Do
  not generate sample personal claims or hard-coded counts.
- Recovery-receipt persistence and high-fidelity animation remain deferred;
  keep their existing seams intact.

## Current dead-entry requirements

- Fix Today's `Open today's record` path so it opens the actual Today editor.
- Within Today and Care, no visible control may silently do nothing or route to
  an unrelated tab. If persistence/backend is not connected, keep the UI
  honest and do not fabricate success.
- Pattern source edit identity, PDF/CSV export, encrypted backup, and restore
  are known separate adapter tasks and are outside this Today + Care UI pass.

## Visual and ownership boundary

- Preserve the current visual-v2 color identity, typography, illustrated
  degree language, and the daylight/dark-Care contrast.
- Kimi may freely reorganize Today and Care screens and their internal routes
  to best serve the above capabilities.
- Do not redesign the five-tab shell, Cycle, Patterns, Reports, Plus, or You.
- Do not modify prediction, Gravity, Spectrum, Twin Matrix, database, storage,
  authentication, entitlement, report, or backup logic.
- Do not restore removed pain-rating or pain-location contracts.
- Do not replace the existing `CareAnimationPort`; detailed immersive motion
  is a later pass.

## Acceptance

- Every visible Today/Care control is reachable and has an honest result.
- Quick Today fields save independently; the full editor commits explicitly.
- The complete five-way Care gate, physical subchoices, Everyday Care paths,
  safety routes, completion, optional outcome, and exits can all be traversed.
- UI compiles, formats, and passes Flutter analysis.
- Existing prediction, Care-memory, and Twin Matrix tests remain unchanged and
  passing.
