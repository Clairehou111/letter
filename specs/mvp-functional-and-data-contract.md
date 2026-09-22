# Letter Within MVP Functional And Data Contract

Status: implementation baseline before Flutter experience refactor
Date: 2026-08-13

## Purpose

This document separates product truth from UI examples. HTML prototypes show
hierarchy, interaction, color, and atmosphere; they never define the complete
health vocabulary, persistence schema, algorithm inputs, entitlement boundary,
or release scope.

After this contract is approved, non-animation surfaces move directly to
Flutter/Dart. Care's high-fidelity animation assets remain a final production
phase, but Care navigation, state, safety, persistence, and accessible fallback
must be implemented with the rest of the app.

## Primary App Structure

The release shell uses five destinations:

1. **Today** — current cycle context, quick check-in, today's bleeding/pain,
   recent record, and the shortest route into Care.
2. **Cycle** — calendar and cycle history, add/edit past periods, day detail,
   bleeding flow/color, pain, symptoms, and a reply to self.
3. **Care** — `Right now is hard`, Everyday Care, safety routes, completed
   action check-back, and remembered helpful actions. High-fidelity scene assets
   plug into this destination later without changing its domain contracts.
4. **Patterns** — plain-language observations, current and longitudinal charts,
   Letters, and Reports. Locked Plus depth is shown contextually; Plus is not a
   navigation destination.
5. **You** — account, privacy/protection, reminders, analytics consent,
   backup/restore, raw export, subscription management, help, and About.

All destinations preserve current local-first behavior. Care and safety never
require an entitlement check. Logging, correction, privacy, backup, restore,
and raw export are never paywalled.

### Today cycle ring

Today belongs visibly inside the user's current menstrual cycle. Its primary
visual anchor is the multi-color segmented ring established by the approved
prototype, using the familiar four-part consumer cycle model:

1. `Period`
2. `Follicular`
3. `Estimated ovulation`
4. `Luteal`

The four segments are visually distinct but belong to one coherent palette,
not four unrelated saturated colors. The current day is a clear point or glow
on the ring; the center shows cycle day and a concise current-phase label. The
ring is interactive and opens the corresponding date or Cycle detail.

This is a visualization model, not four equally certain measurements:

- recorded period days are observed;
- future period range, follicular/luteal boundaries, and ovulation timing are
  calendar estimates unless the product later accepts appropriate biomarker
  inputs;
- the UI uses `Estimated ovulation` or `Around estimated ovulation`, never
  claims ovulation is confirmed from calendar dates;
- estimated boundaries use soft transitions/ranges rather than exact hard-day
  certainty;
- a late-luteal/premenstrual portion may carry the stronger Gravity treatment
  without becoming a fifth biological phase;
- insufficient or highly irregular history simplifies the ring and labels the
  estimate as limited rather than inventing precise phase dates.

The Today screen must not replace the ring with a three-chapter model merely to
avoid estimation. Accuracy is expressed through range, opacity, labels, and
source detail while retaining the familiar four-phase mental model.

## Observation Model

### Stable catalog, not UI-bound enums

User-selectable observations are defined by a versioned local catalog with
stable string IDs. The UI obtains labels, categories, search aliases, visual
degree rules, and behavior metadata from this catalog. It does not switch over
an exhaustive enum to construct the interface.

Each definition contains:

- `id`: stable storage key, never derived from the displayed English label;
- `category`: physical, mood, cognitive, energy, sleep, or digestion;
- `label` and `searchAliases`: localizable display/search vocabulary;
- `recordingKind`: presence/severity, pain, safety-only, or free text;
- `severityScale`: none, five-level symptom scale, or 0–10 pain scale;
- `patternRole`: spectrum, relationship-only, report-only, or excluded;
- `safetyRoute`: none, urgent-emotional, or medical-attention;
- `quickPickPriority`: default, contextual, recent, favorite, or search-only;
- `availableForNewRecords` and optional replacement ID for deprecation;
- `catalogVersion` for deterministic import/export interpretation.

The release catalog ships locally with the app. Adding or renaming a catalog
item must not require redesigning the recording screen. User-authored notes are
stored separately and never converted into a confirmed symptom without user
confirmation.

### Symptom presence and severity

A symptom is recorded only when the user selects it. Therefore the symptom
severity scale has five values and no `Not at all` option:

1. Minimal
2. Mild
3. Moderate
4. Severe
5. Extreme

The number may be stored and used internally, but normal recording UI shows
words plus a distinct visual degree. Charts may show a numeric axis only when
the legend keeps those verbal meanings visible.

### Initial catalog scope

The first catalog is broad enough for period/PMS/PMDD-related tracking without
pretending to catalog every possible health condition.

**Physical and pain**

- cramps; pelvic pain; lower-back pain; headache; migraine;
- breast tenderness; bloating; nausea; body aches; joint or muscle pain;
- water retention; appetite change or cravings; acne; dizziness;
- hot flashes or sweating; diarrhea; constipation; heart palpitations.

**Mood and emotional**

- depressed/low mood; crying; hopelessness; loss of interest or pleasure;
- irritability; rage; mood swings; anxiety or worry; panic;
- feeling unusually sensitive; overwhelm; social withdrawal;
- suspicious/paranoid thoughts; impulsive urges.

**Cognitive, energy, and sleep**

- difficulty concentrating; brain fog; forgetfulness;
- fatigue; low energy; sleepiness;
- insomnia; sleeping much more; broken/disrupted sleep.

Heart palpitations are recordable only through an appropriate medical-attention
route. Self-harm and suicidal thoughts are safety signals, not ordinary scored
symptoms: selecting them immediately opens real-world crisis support and they
are not stored, trended, or used for personalization.

### Mood check-in versus mood symptoms

These are separate concepts:

- The Today pulse is a quick, low-effort description of the moment. It may
  include positive and difficult states and drives immediate visual feedback
  and Care routing.
- Detailed mood symptoms are user-confirmed health observations with the same
  five-level severity semantics as other symptoms. They may appear in Spectrum,
  Patterns, and a user-approved report.

The Today pulse must never silently create a clinical symptom or severity.
Users may explicitly turn a pulse into a detailed record.

The first Today pulse catalog supports at least: good, calm/steady, energized,
hopeful, tender/sensitive, low, irritable, anxious/restless, overwhelmed,
exhausted, and physically uncomfortable. UI shows a small contextual set,
recent choices, and a searchable `More` sheet rather than all items at once.

### Bleeding, color, and pain

- Bleeding flow: spotting, light, medium, heavy. Every degree has text and a
  recognizable visual example.
- Bleeding color: pink, bright red, dark red, brown. Every option has text and
  a visual swatch/example.
- Pain: optional 0–10 value with verbal anchors and visual degrees, plus one or
  more locations. A pain symptom may also have the five-level general severity;
  the UI must explain the distinction or collect only the 0–10 pain measure for
  that record to avoid duplicate questions.
- Functional impact is optional and multi-select: work/school, home tasks,
  relationships, social activity, and sleep.
- A day with no selected symptom does not receive zero-valued symptom rows.

Bleeding flow and color do not alter period prediction, Gravity dates, or mood
scores. They may power their own history/trend views and clinician report rows.

## Algorithm And Chart Inputs

All chart detail views expose `What this uses` and allow the user to inspect the
source dates/records behind a selected point.

### Cycle prediction

Uses confirmed period start dates and completed period durations. Bleeding
degree, color, mood, Care interaction, and text do not move the predicted period
range. Irregular or insufficient history produces a wider/limited-confidence
presentation rather than false precision.

### Estimated Cycle Gravity

Shows the estimated cycle-time window in which difficult premenstrual symptoms
may be more likely for this user. Its horizon is derived from the predicted
luteal/premenstrual window and clearly separates estimated dates from observed
records. It is a forecast visualization, not a diagnosis or clinical finding.

### Spectrum Log

- Current view shows the typical confirmed level for each selected symptom in
  the relevant premenstrual window, not the maximum across cycles.
- Trend view shows cycle-by-cycle values and missingness, so one extreme entry
  cannot visually overwrite otherwise mild cycles.
- Only user-confirmed severity records participate. Today pulses, text
  candidates, Care gestures, and absent symptoms do not become scores.

### Twin Matrix

Compares user-confirmed observations in matched cycle windows. It must show the
actual compared dates, number of usable cycles, missing data, and the underlying
records. It does not infer symptom severity from engagement.

### Bleeding and pain trends

Flow, color, pain, location, and functional impact receive a dedicated readable
history/trend surface. Unexpected change can be shown descriptively (for
example, `heavier than your recent typical record`) without diagnosing a cause
or predicting future health.

## Letters And Personal Memory

- A cycle may contain a private reply to self and selected free-text notes.
- Letters are readable without Plus.
- Plus may add cross-letter search, themes, comparisons, and contextually
  resurfacing a user's own past words.
- Care outcomes (`Better`, `Same`, `Worse`) are observations about one action,
  not clinical improvement scores.
- Suggestions such as `Warmth helped you twice before` require enough explicit
  completed actions and user check-backs; no claim is made from scene completion
  alone.

## Patterns, Reports, And Entitlement

### Free

- complete recording, history, correction, and deletion;
- cycle prediction, current Estimated Cycle Gravity, current Spectrum, and
  basic Twin/bleeding/pain visibility;
- readable Cycle Letters;
- all acute Care and safety routes;
- privacy/protection controls, encrypted local backup/restore, and raw export.

### Plus

- multi-cycle Personal Patterns and cautious text observations;
- longitudinal Gravity and Spectrum trends;
- symptom, bleeding, pain, functional-impact, and Care-outcome relationships;
- remembered preparation and future-self resurfacing;
- cross-letter comparison/search;
- clinician-ready PDF with custom range and user-selected sections.

Previously generated local material remains readable after entitlement lapses.
Plus gates generating/refreshing advanced analysis, not ownership of records.
The paywall never interrupts Care, safety, logging, backup, restore, or raw
export.

### Reports

The report builder supports:

- preset or custom date range;
- included sections preview;
- observed periods and predictions clearly distinguished;
- symptom severity, pain, impact, bleeding, Care events, and user-selected
  notes with provenance;
- missing-data statement;
- on-device PDF generation, local save into a `Letter` folder when the OS
  allows it, and the native share sheet;
- no medication section and no inferred clinical diagnosis.

## Privacy, Protection, Backup, And Data

The You destination must provide working states, not informational mockups:

- Screen cover toggle, default on;
- App lock toggle using available device authentication;
- cycle reminder toggle and permission state;
- optional operational analytics consent, with no health values in analytics;
- account identity and sign-out;
- Restore Purchases and Manage Subscription;
- encrypted backup creation, optional locally secured password reuse, native
  save, then native share destinations such as iCloud Drive, Google Drive, or
  Dropbox when installed;
- encrypted restore with password, Merge/Replace choice, record-level preview,
  confirmation, rollback-safe staging, and understandable errors;
- free raw export;
- concise help based on the implemented format, not cryptographic internals.

Native storage providers are selected through the operating-system file/share
surface. The app does not claim simultaneous cloud upload or maintain its own
cloud backup service.

Account deletion remains a release-policy flow distinct from local record
deletion and subscription history held by Apple/Google/RevenueCat. Its final
retention language must match the deployed Supabase deletion implementation
before App Store submission.

## Important Missing Or Easily Forgotten MVP States

- first-use and no-history previews for Cycle and Patterns;
- search, recent, and favorite observation pickers;
- historical-date and later-recall provenance;
- edit, cancel, unsaved-change confirmation, and record deletion;
- loading, storage error, offline entitlement, empty, partial-data, and retry;
- chart source-detail sheets and missing-data legends;
- report range/section preview and export failure recovery;
- backup password forgotten guidance and import conflict preview;
- notification denied/restricted state;
- text scaling, screen reader semantics, contrast, and reduced motion;
- Care scene accessible fallback that provides the same guided action without
  animation;
- no streaks, points, missed-day pressure, diagnosis, or hidden scoring.

## Implementation Boundary

Codex owns domain/storage/algorithm contracts and tests. Kimi owns Flutter
presentation composition through UI Forge. Kimi may propose presentation
features and local interaction states but must not:

- change prediction or chart formulas;
- infer new repository APIs;
- narrow the catalog to the items visible in a mockup;
- store safety selections or translate interaction behavior into severity;
- move a Free right behind Plus;
- implement backup, auth, entitlement, or persistence logic inside widgets.

Care animation components expose stable presentation ports for `play`, `pause`,
`reduceMotion`, scene state, progress, and completion. Initial Dart uses an
accessible authored fallback. Professional Rive/character assets replace that
renderer at the final phase without rewriting navigation, persistence, safety,
or Care Memory.
