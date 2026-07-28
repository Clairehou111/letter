# Letter

Letter is a private, local-first period and PMS/PMDD companion. This repository
contains independently runnable mobile and API applications.

## Structure

```text
apps/
  mobile/              Flutter application for iOS and Android
  api/                 FastAPI operational service
contracts/openapi/     Generated API contract
tools/                 Contract generation and repository validation
specs/                 Product roadmap, architecture, and feature specifications
```

Readable health records remain on the device. Period start/end records and
history editing are implemented in the Cycle tab. The angry Care flow can also
hold one private unsent draft and apply an app-enforced 24-hour cooldown.
Native builds share one Drift database configured for
SQLite3MultipleCiphers across period and impulse-buffer records; the web
development preview uses non-persistent in-memory repositories. The API
foundation contains only non-sensitive operational routes and must not receive
health records, private drafts, or synthetic Today-screen state.

After two complete start-to-start intervals, Cycle derives a local next-period
date range from recent history. The range includes Low, Medium, or Higher
confidence and the observed cycle-length evidence. It does not calculate
fertility, ovulation, cycle phases, or PMDD windows.

Today now reads the same local period repository. It shows the real local date,
inclusive period or cycle day, and the shared prediction range when supported.
No-history and insufficient-history states stay explicit. Prototype phase
claims, fake Recent entries, personal notes, remedies, contacts, and Care plans
have been removed. Quick-state input remains session-only until the dedicated
health-record feature defines persistence, editing, deletion, and provenance.

Care is now a working primary destination with five direct entrances:
exploding, heavy, racing thoughts, needing everyone away, and physical pain.
Each entrance has explicit exit and safety boundaries. `I want to explode` now
uses a finite Shatter interaction, low-stimulation transition, private unsent
draft, exact 24-hour seal, hidden locked and ready-envelope states, and
unopened deletion. `I feel heavy` now uses a one-tap light, at most three
bounded lines, an optional foreground-only two-minute presence interval, and a
practical hand-off. `My mind won't stop` now turns scattered fragments into one
calm point after one tap, then offers optional current-screen-only naming,
unnamed set-down, or immediate exit. Entered text is cleared on set-down,
discard, reconstruction, or leave and is never saved for tomorrow. `I need
everyone away` now closes one symbolic curtain around a protected cocoon, then
offers either immediate rest or an optional session-only boundary card. Copying
is explicit and discloses the device clipboard boundary; Letter never reads
contacts, chooses a recipient, sends, shares, silences other apps, or persists
the text. `My body hurts` now offers five symptom-appropriate, low-effort
comfort paths with an always-available medical boundary and no medication
guidance or treatment claim.

After a completed Care action, Letter offers one optional Better/Same/Worse
check-back. Skipping creates no record; an explicit outcome is stored only in
the local health database and can be explicitly pinned into the Care Kit.
The enabled Letters tab groups completed cycles from real period starts,
supports user-authored clearer-day reflections, and returns matching
future-self notes only after acute feedback has already occurred. It never
fabricates missing history, narrative, symptoms, or clinical conclusions. No
Care behavior creates an inferred severity, analytics event, API request, or
LLM request.

The current product direction is defined in
[`specs/product-philosophy.md`](specs/product-philosophy.md). Letter combines
period tracking with a cross-cycle Care loop: contain a hard moment, check back
later, let the user author what it meant, and return their own helpful actions
and words next time.

The acute interaction model is defined in
[`specs/care-experience-system.md`](specs/care-experience-system.md). Care uses
finite, one-thumb game loops that produce immediate feedback and then hand the
user back to a practical action; it does not optimize for time spent.

Clinical reporting is defined in
[`specs/clinical-data-and-reporting.md`](specs/clinical-data-and-reporting.md).
Care behavior may propose a symptom for later confirmation but never becomes an
inferred clinical severity score.

The global Letter metaphor and visual responsibilities are defined in
[`specs/brand-and-experience-system.md`](specs/brand-and-experience-system.md).
Ritual styling never replaces familiar health controls or clinician-readable
evidence.

## Mobile

```bash
cd apps/mobile
flutter pub get
flutter analyze
flutter test
flutter run
```

Web is available for visual development only. iOS and Android are the product
targets.

## API

```bash
cd apps/api
uv sync --locked
uv run fastapi dev src/letter_api/main.py
uv run pytest
```

The local service exposes:

- `GET /health`: process liveness
- `GET /v1/status`: contract smoke path
- `GET /docs`: local OpenAPI documentation

No Supabase connection or secret is required for the foundation.

## Contract

From the repository root:

```bash
uv run --project apps/api python tools/export_openapi.py
python3 tools/generate_dart_client.py
```

Use `--check` with either command to fail when committed generated output is
stale.

## Validation

```bash
python3 tools/validate.py
```

Native simulator and emulator checks require complete Xcode, CocoaPods, and
Android SDK installations.
