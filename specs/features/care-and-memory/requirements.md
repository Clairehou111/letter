# Care and personal memory

Status: current 2.0 feature contract. The body-care and Everyday care extension
is specified in [Care relief](../release-2.0/care-relief.md).

CM-01. Care is a primary destination with five text-labeled entrances for
exploding/overloaded, heavy/low, racing thoughts, needing space, and physical
discomfort. The app does not infer, preselect, or rank a mode from cycle dates,
symptoms, mood, or behavior. Selecting an entrance opens its scene promptly.
Each scene provides an immediate response, bounded handoff, visible exit, and
an appropriate safety or medical route. Leaving without completing is valid.

CM-02. The emotional scenes provide `I may not be safe` access to the
region-aware crisis boundary. Physical Care provides a visible route for new,
unusual, or severe symptoms and does not replace medical assessment. Safety
routing is deterministic and never delegated to AI. No scene promises relief,
teaches treatment, assigns severity, or blocks exit behind sound, haptics,
motion, repeated tapping, a timer, or a reward loop.

CM-03. The current Care scenes are five guided, self-paced sequences: Release
notices pressure, breathes out, presses and releases, then lands; Heavy names
the weight and rests into support; Focus lets thoughts pass and chooses one
thing; Space makes a quiet boundary; Body settles, considers warmth, and
shows a medical boundary. Each sequence names its steps for interruption
recovery. Its final action is deliberate; reaching a step, waiting, leaving,
or opening safety does not complete it. No current scene collects an impulse
draft, thought text, or boundary-card text. The
[2.0 Care relief contract](../release-2.0/care-relief.md) governs proposed
extensions to the Body scene and Everyday care.

CM-04. A completed action may ask one optional question, “How is this moment
now?”, with Better, Same, Worse, and Skip/Not now. It is never delivered as
an automatic notification that assumes readiness. Skipping creates no
outcome record. Only an explicit response
stores a local Care event with stable action identity, mode, occurrence time,
and the person's chosen outcome. `Worse` stays visible as reported; it is not
reframed as progress. Taps, dwell time, scene choice, unsaved text, and
interaction intensity never become clinical evidence or an outcome by
themselves. Deleting an outcome removes it from counts; unpinning an action
does not erase its history.

CM-05. A person may pin an action, keep a Better result, or deliberately keep
their own future-self/Quick note in the Comfort Kit. An item can be removed,
replaced, or hidden. The Kit is available from Care once formed and may appear
proactively only under the qualified Comfort Window rules. Basic assembly is
free; Plus can explain cross-cycle ranking but cannot make acute access paid.
The exact ranking and preview rules are in [2.0 requirements](../release-2.0/requirements.md).

The steps and persistence rules for each established scene are in
[scene behavior](scenes.md).

CM-06. A cycle starts at one observed period start and ends the day before
the next. Its reflection is user-authored, editable, and attached to the
starting period's stable ID. An incomplete current cycle is distinct from
completed history. Care events are placed by their actual local dates;
unassigned events remain retrievable if no period contains them. Do not
fabricate cycle numbers, missing stories, repeated actions, or a future-self
note. A reflection is returned only after acute feedback, when relevant.

CM-06A. A recovery receipt begins only from a persisted Care record and an
explicit user action. It may offer editable symptom candidates or direct
ratings; abandoning it creates no partial clinical record. Any later-entered
rating is labeled `later_recall`, not prospective or same-day merely because
the original Care event happened earlier. The person confirms each reportable
value and impact directly.

CM-07. Care and memory remain in encrypted local storage; the web preview is
memory-only. No raw Care text, outcome, note, mode, clinical inference, or
cycle association enters account data, immediate analytics, API calls, logs,
or AI services. The narrowly permitted delayed aggregate usage bucket is
defined in [2.0 requirements](../release-2.0/requirements.md). All Care
surfaces support Reduced Motion, screen reader, 44px targets, and large text.
