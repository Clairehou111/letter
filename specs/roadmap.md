# Letter Roadmap

Status values: `proposed`, `specifying`, `approved`, `in_progress`,
`validated`, `merged`, `deferred`.

Only one product feature should normally be `in_progress`.

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
| 4 | Today context and low-effort logging entry | proposed |

Period logging is validated for shared logic, widget behavior, visual baseline,
and the non-persistent web preview. Native cipher-at-rest verification remains
deferred under the approved native validation gate.

Cycle prediction is a derived, local-only date range based on at least two
observed start-to-start intervals. It shows confidence and recorded variation
without fertility, phase, or diagnostic claims.

The validated onboarding persistence and privacy architecture remains. Its copy
and goals require a separate revision after the Care-loop redesign is approved.

## Phase 2: Personal Care Memory

| Order | Feature | Status |
| --- | --- | --- |
| 1 | Five-way Care entrance and finite reward shell | proposed |
| 2 | Angry/overloaded impulse buffer | proposed |
| 3 | Heavy/low presence flow | proposed |
| 4 | Racing-thoughts convergence flow | proposed |
| 5 | Need-space messages and boundary plan | proposed |
| 6 | Physical-pain comfort flow and medical boundary | proposed |
| 7 | Care action check-back and personal kit | proposed |
| 8 | Clearer-day reflection and future-self note | proposed |
| 9 | Cycle Letters archive | proposed |

## Phase 3: Effortless Logging And Learning

| Order | Feature | Status |
| --- | --- | --- |
| 1 | Symptom, severity, pain-location, mood, and energy logging | proposed |
| 2 | Text and on-device voice capture | proposed |
| 3 | LLM-assisted structured confirmation | proposed |
| 4 | Recovery receipt and confirmed clinical ratings | proposed |
| 5 | Cautious personal patterns and remedy matching | proposed |

## Phase 4: Reports And Commercial Readiness

| Order | Feature | Status |
| --- | --- | --- |
| 1 | Doctor Mode, provenance-safe report, and export | proposed |
| 2 | Authentication and subscription entitlement | proposed |
| 3 | Privacy-safe operational analytics | proposed |
| 4 | Optional encrypted backup demand test | proposed |
