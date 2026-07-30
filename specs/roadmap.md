# Letter Roadmap

Status values: `proposed`, `specifying`, `approved`, `in_progress`,
`validated`, `merged`, `deferred`.

Only one product feature should normally be `in_progress`.

Current roadmap exclusions:

- contact access, trusted-contact management, or direct messaging
- medication history, medication reminders, or medication guidance

## Phase 0: Architecture Validation

| Order | Feature | Status | Specification |
| --- | --- | --- | --- |
| 1 | Flutter UI fidelity spike | validated | `features/2026-07-27-flutter-ui-fidelity/` |
| 2 | Production workspace foundation | validated | `features/2026-07-27-production-workspace-foundation/` |
| 3 | Letter Care-loop product redesign | approved | `features/2026-07-28-letter-care-loop-redesign/` |

The user accepted the Flutter visual result on 2026-07-27. Flutter is the
confirmed mobile stack.

## Phase 1: Period And Context Foundation

| Order | Feature | Status |
| --- | --- | --- |
| 1 | Local onboarding and privacy choices | validated |
| 2 | Period logging and history editing | validated ([spec](features/2026-07-28-period-logging-history/)) |
| 3 | Cycle prediction and confidence display | validated ([spec](features/2026-07-28-cycle-prediction-confidence/)) |
| 4 | Today context and low-effort logging entry | validated ([spec](features/2026-07-28-today-cycle-context/)) |

Period logging is validated for shared logic, widget behavior, visual baseline,
and the non-persistent web preview. Native cipher-at-rest verification remains
deferred under the approved native validation gate.

Cycle prediction is a derived, local-only date range based on at least two
observed start-to-start intervals. It shows confidence and recorded variation
without fertility, phase, or diagnostic claims.

Today now derives its date, period or cycle day, and supported prediction from
the same local period repository. Quick-state choices are intentionally
session-only and cannot appear in history or reports yet.

The validated onboarding persistence and privacy architecture remains. Its copy
and goals require a separate revision after the Care-loop redesign is approved.

## Phase 2: Personal Care Memory

| Order | Feature | Status |
| --- | --- | --- |
| 1 | Five-way Care entrance and finite reward shell | validated ([spec](features/2026-07-28-five-way-care-shell/)) |
| 2 | Angry/overloaded impulse buffer | validated ([spec](features/2026-07-28-angry-impulse-buffer/)) |
| 3 | Heavy/low presence flow | validated ([spec](features/2026-07-28-heavy-low-presence-flow/)) |
| 4 | Racing-thoughts convergence flow | validated ([spec](features/2026-07-28-racing-thoughts-convergence-flow/)) |
| 5 | Need-space safe cocoon and boundary card | validated ([integration spec](features/2026-07-28-need-space-flow-integration/)) |
| 6 | Physical-pain comfort flow and medical boundary | validated ([spec](features/2026-07-28-physical-pain-comfort-flow/)) |
| 7 | Care action check-back and personal kit | validated ([spec](features/2026-07-28-care-checkback-personal-kit/)) |
| 8 | Clearer-day reflection and future-self note | validated ([spec](features/2026-07-28-clearer-day-reflection/)) |
| 9 | Cycle Letters archive | validated ([spec](features/2026-07-28-cycle-letters-archive/)) |

The Care gate is now a working primary destination. All five experiential
entrances use a finite, escapable response shell with explicit emotional or
physical safety boundaries. Angry/overloaded Care now adds Shatter, a private
local draft, and an honest app-enforced 24-hour cooldown. Shared logic, schema
migration, and Web behavior are validated; native cipher-at-rest runtime checks
remain deferred under the approved native validation gate. Heavy/low Care now
adds a one-tap light, finite protective copy, optional foreground-only
two-minute presence, and a practical hand-off without storing an episode.
Racing-thoughts Care now uses one-tap visual convergence, then allows optional
one-thought naming, unnamed set-down, or immediate exit. Any entered text lives
only on the current screen and is cleared rather than saved or resurfaced the
next day. Need-space Care now closes one symbolic curtain, then offers an
optional session-only boundary card with explicit clipboard copy and no
contact, recipient, send, share, or phone-isolation capability. The
physical-pain flow now provides five low-effort comfort paths and a persistent
medical boundary without medication guidance or treatment claims. A completed
Care action offers one optional Better/Same/Worse check-back; only an explicit
outcome becomes a local record, and pinning into the Care Kit is also explicit.
The Letters tab now groups completed cycles from real period starts, opens
user-authored clearer-day reflections, and can return matching future-self
notes only after the first acute response. No Phase 2 feature creates a
clinical score, cloud request, analytics event, or LLM request.

## Phase 3: Effortless Logging And Learning

| Order | Feature | Status |
| --- | --- | --- |
| 1 | Confirmed health-record foundation | validated ([spec](features/2026-07-28-health-record-foundation/)) |
| 2 | Care-linked recovery receipt | validated ([spec](features/2026-07-28-care-recovery-receipt/)) |
| 3 | Text and on-device voice capture | validated ([spec](features/2026-07-28-text-voice-capture/)) |
| 4 | NLP-first candidate confirmation | validated ([spec](features/2026-07-28-nlp-candidate-confirmation/)) |
| 5 | Personal patterns and support-action matching | validated ([spec](features/2026-07-28-personal-patterns-support-matching/)) |
| 6 | Archive Story and Pattern views | validated ([spec](features/2026-07-28-archive-story-pattern-views/)) |

Phase 3 is usable without cloud processing or LLM access. Direct structured
records are the source of truth. Care becomes a delayed, user-confirmed input
to the same record model through Recovery Receipt. NLP and optional LLM output
remain editable candidates and never assign severity, diagnosis, or function.

The first Phase 3 implementation slice is now present as local-first modules:
the health-record foundation, Recovery Receipt, text capture, personal
patterns, archive views, and Cycle and Care Summary navigation use the shared
local repositories. Voice recognition remains unavailable until a reviewed
system-speech adapter is installed; NLP and optional LLM output remain editable
candidates rather than records.

## Phase 4: Reports And Commercial Readiness

| Order | Feature | Status |
| --- | --- | --- |
| 1 | Encrypted local export and import | validated ([spec](features/2026-07-28-encrypted-local-export-import/)) |
| 2 | Cycle and Care Summary export | validated ([spec](features/2026-07-28-cycle-care-summary-export/)) |
| 3 | Doctor Mode, prospective diary, and clinical report | proposed ([spec](features/2026-07-28-doctor-mode-prospective-diary/)) |
| 4 | Authentication and subscription entitlement | proposed ([spec](features/2026-07-28-auth-subscription-entitlement/)) |
| 5 | Privacy-safe operational analytics | proposed ([spec](features/2026-07-28-privacy-safe-operational-analytics/)) |
| 6 | Optional encrypted-backup demand test | proposed ([spec](features/2026-07-28-encrypted-backup-demand-test/)) |

Local export/import is separate from optional cloud backup. Reports are
generated from local, user-confirmed data. Doctor Mode cannot use DRSP wording
or claim diagnostic equivalence until clinical review, wording, scoring, and
licensing requirements are satisfied.

## Phase 5: MVP Release Readiness

Release-blocking work for the first paid public MVP, ordered by dependency.

| Order | Feature | Status |
| --- | --- | --- |
| 1 | Safety boundary content (locale-aware crisis + medical red flags) | validated ([spec](features/2026-07-29-safety-boundary-content/)) |
| 2 | Paid split and paywall | validated ([spec](features/2026-07-29-paid-split-and-paywall/)) |
| 3 | Design token layer completion (V1) | validated (shipped in branch `feature/safety-boundary-content`) |
| 4 | Today letter hero (ritual envelope surface) | validated (shipped in branch `feature/today-letter-hero`) |

Safety routing is now configured: US 988 call/text + 911, CA 9-8-8 + 911, and
an honest no-invented-numbers fallback elsewhere; medical Care shows urgent
and book-assessment red-flag tiers. All contacts are tappable with the visible
number as fallback. Native dialer tap-through remains deferred to the release
gates.

## Release Acceptance Gates

| Order | Gate | Status |
| --- | --- | --- |
| 1 | Native encryption, migration, and recovery validation | proposed ([spec](features/2026-07-28-release-acceptance-gates/)) |
| 2 | Target-user Care usability and adverse-response validation | proposed ([spec](features/2026-07-28-release-acceptance-gates/)) |
| 3 | Clinical report provenance and clinician comprehension validation | proposed ([spec](features/2026-07-28-release-acceptance-gates/)) |
| 4 | Accessibility, privacy, billing, and store-readiness validation | proposed ([spec](features/2026-07-28-release-acceptance-gates/)) |
