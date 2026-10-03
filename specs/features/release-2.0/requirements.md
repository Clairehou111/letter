# Release 2.0 Requirements

Status: approved target; implementation evidence exists, final release gates open
Date: 2026-09-25

## Goal

Turn Letter Within's existing local records into an honest early warning for
personally harder cycle days, then surface a small personal Comfort Kit before
and during that window. Preserve acute Care, make privacy visible without
creating a security dashboard, and improve the whole app's visual coherence
for users who may already be irritable, overwhelmed, or crying.

## Product Contract

REQ-001: The app remains local-first and deterministic. Health records, free
text, predictions, report content, and Care details never leave the device.
No AI or population model interprets user data.

REQ-002: Main navigation contains Today, Cycle, Care, and Patterns. Former You
content moves to a low-frequency Settings route reachable within two steps from
a daylight screen. Settings is absent from an active immersive Care scene.

REQ-003: Period estimates, record review/correction/deletion, all acute Care,
safety resources, encrypted local backup, basic Comfort Kit assembly, and a
limited on-screen factual Reports view for the most recent three months remain
free. A free surface must not reproduce a complete shareable clinician
artifact.

REQ-004: Plus unlocks personal Patterns, deeper cross-cycle explanation and
ranking, report ranges beyond the most recent three months (including custom
and all-record ranges), and every report/export file: factual Visit Summary
PDF, raw CSV, and Clinical Pattern Report PDF. Files generated while access was
valid remain readable after entitlement lapse; a lapse never deletes local
records or previously generated files.

REQ-005: Reference prices are `$7.99/month`, `$39.99/year`, and `$99.99`
lifetime. Store-provided localized prices remain authoritative. A no-card Plus
preview begins only when Plus-grade evidence first exists, covers the next
cycle, and expires after at most 45 days. Preview access may demonstrate
in-app Plus interpretation, but it never grants the file-generation capability
for Visit Summary PDF, raw CSV, or Clinical Pattern Report PDF.

## Comfort Window

REQ-006: An observed day contains a mood check-in or confirmed symptom. A
harder day contains any confirmed symptom or a difficult/physical mood. A
non-hard observed day contains a positive/steady mood and no symptom. Flow,
Care use, and note-only days are excluded from this classification.

REQ-007: Analyze at most the six most recent completed cycles using offsets
`-14...+3` relative to the following period start. A cycle is eligible only
with at least nine observed days and at least three non-hard observed days.
The current cycle never trains its own forecast.

REQ-008: Evaluate every contiguous 3-7 day candidate. A cycle may vote only
when at least `max(2, ceil(windowLength/2))` inside days and five outside days
were observed. Support requires at least two inside harder days, inside rate
`>= 0.50`, and lift over outside rate `>= 0.25`.

REQ-009: Emerging means two of two voting cycles support the window. Clearer
means at least three voting cycles and at least 75% support. Select one window
using, in order: support ratio, average lift, inside harder-day count, shorter
length, proximity to period, then earlier offset.

REQ-010: Project the selected offsets through the existing period estimate.
Never send a proactive reminder without Clearer evidence, a non-low-confidence
period prediction, forecast spread no wider than seven days, composed display
range no wider than ten days, and explicit reminder opt-in.

REQ-011: Today may show preparation from two days before the forecast start.
Reminder lead options are 0, 1, or 2 days; default is two days, notifications
default off, and delivery defaults to 09:00 local time. Copy uses estimates and
patterns, never a breakdown countdown or diagnostic certainty.

REQ-011A: Today does not keep Comfort Window visible throughout the cycle. A
preparation surface appears only from two days before a reliable Clearer
forecast through its estimated end. Before that interval, Today may show one
dismissible reminder invitation only after the same reliability gate passes.
Choosing `Not now` is a stored local decision and must stop repeat invitations.
The user can explicitly enable, change, or turn off a reminder; ignoring the
invitation never enables notifications.

REQ-011B: The preparation surface names an estimated date range without a
countdown. It opens the user's Comfort Kit only when a Kit has formed; otherwise
it opens ordinary Care and must not imply that a personalized Kit exists.
Reminder copy states the selected lead and the 09:00 local delivery time.

REQ-011C: Settings is the durable management surface for the Comfort Window
reminder. It shows the saved on/off preference and timing, and allows opting in,
changing timing, or turning it off at any time. Explicit opt-in requests system
notification permission. A reminder is scheduled only when the complete
reliability gate passes; if evidence is not yet reliable enough, Settings says
that the preference is on but nothing is currently scheduled. When later local
records make the estimate eligible, the saved preference applies automatically.
System notification settings remain authoritative.

REQ-012: Every result records its algorithm version, source cycle ids, offsets,
coverage, support, lift, confidence, and projected range. Record edits and
deletions deterministically recompute the result and pending reminder.

## Comfort Kit And Writing

REQ-013: Comfort Kit items can come only from a pinned Care action, a Care
outcome marked Better, a Care/Cycle future-self note, or a Quick note explicitly
marked `Keep in Comfort Kit`. Free text never becomes forecast evidence.

REQ-014: The Kit is always retrievable from Care once formed, proactively
surfaces only before or during a forecast window, and recedes afterward. Items
support Remove, Replace, and Don't show again.

REQ-015: Free ranking is deterministic: repeated recent Better evidence,
pinned Care, recent Better Care, future-self note, then explicitly kept Quick
note; ties use recency. Plus may explain and refine cross-cycle ordering but
must not make basic personalization paid-only.
The full replacement list keeps that rank. If the three visible Kit slots
would all be Care actions, the third slot shows the first eligible authored
entry from the ranked list when one exists; the displaced action remains
available in Replace.

REQ-016: Rename `A note to self` to `Quick note`; add local history, edit,
delete, and a detail-only Comfort Kit toggle. Preserve the existing Care
reflection and Cycle Letter as distinct optional forms.

## Reports, Privacy, And Analytics

REQ-017: Reports offers a limited factual on-screen view for the most recent
three months without Plus. Longer presets, all-record and custom ranges, and
all generated files require paid Plus access. The Visit Summary PDF contains
selected dates, flow, confirmed symptoms, missingness, and user-selected notes.
The raw CSV contains confirmed source records. The Clinical Pattern Report PDF
may additionally contain cross-cycle interpretation, Comfort Window evidence,
and What helped summaries. A no-card preview cannot generate any of these
files. Every export uses the exact range shown before generation and displays
the local saved path after a successful save.

REQ-018: Privacy appears through only three quiet signals: `Private on this
device` on Today, `Saved on this device.` after sensitive saves, and a compact
Settings privacy block for Screen Cover, Anonymous analytics, and one accurate
sentence. At most one privacy signal appears per screen. App Lock is not a
current or future product surface.

REQ-019: PostHog consent defaults off. Disable autocapture, replay, and person
profiles. Immediate events are restricted to non-health settings/paywall/
purchase funnels and use an analytics-only random identifier, never Supabase id.

REQ-020: Care analytics are local 30-day usage buckets only: `1`, `2-5`, or
`6+`, uploaded with randomized delay and no timestamps, Care mode, outcome,
duration, notes, or health context. Turning consent off clears pending buckets.

## Care And Visual System

REQ-021: Preserve behavior of the five current native Care scenes: Explode,
Heavy, Racing, Space, and Physical with its four contexts. Visual work may tune
canvas, palette comfort, hierarchy, and controls but may not change gestures,
timing, sound, haptics, exit, safety, completion, or persistence rules.

REQ-022: Visual direction is `One refuge, changing depth / Quiet Dusk` and
remains `Calm, expressive, never agitating.` Onboarding, Today, Cycle,
Patterns, Settings, report configuration, and other app chrome share one warm,
low-luminance plum environment. Care, Comfort Window, and Comfort Kit deepen
that same environment rather than switching to a separate visual world. Avoid
flashing, harsh saturation, aggressive pulse/bounce, noisy textures, obvious
drop shadows, and harsh pure black/white contrast. Headache remains still and
dim.

REQ-022A: Letters and in-app report reading may use an inset warm-paper surface
with visible Quiet Dusk around it; paper is not app chrome and never becomes a
second full-screen theme. Clinician PDF output uses a neutral white clinical
print style with near-black ink and grayscale-safe, explicitly labeled charts.

REQ-022B: Release 2.0 ships Quiet Dusk as its sole branded runtime appearance;
it does not add a separate daylight/light theme. Surfaces use tonal luminance
instead of shadow for hierarchy, pure white text is prohibited, and one coral
accent is reserved for the primary action and Comfort Window emphasis. Data,
flow, symptoms, mood, warnings, and errors use distinct semantic roles and
never rely on color alone. Exact token values belong to the approved Experience
System and may be corrected by scoped accessibility/contrast review. They must
pass contrast, Dynamic Type, Increase Contrast, and supported-device
validation.

## Non-Goals

- fertility, ovulation, treatment, medication, diagnostic, or crisis prediction;
- cloud training or health analytics;
- merging Quick note, Care reflection, and Cycle Letter into one record;
- replacing the original Care scenes with the synthetic App Store orb screens;
- changing store configuration as a side effect of product implementation.
