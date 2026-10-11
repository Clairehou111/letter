# Record Hub data and state contract

Date: 2026-10-09  
Status: approved and implemented on `feat/record-hub-2026-10-09`. P-01/P-02 and package defaults P-03…P-06 were approved by the owner on 2026-10-09. Native schema is 17; implementation and verification evidence is recorded separately.

## Approved timing and engineering defaults

Owner explicitly confirmed P-01/P-02: “按最新版原型冻结（推荐）”. They are no longer open questions. P-03…P-06 are proposed engineering defaults, not clinical policies; review with the requirements/validation package before implementation. Do not restart settled IA/timing research.

| ID | Proposal | Why it must be explicit |
| --- | --- | --- |
| P-01 (approved) | Strict actual local-day writes for same-day timing; no 04:00 grace | Owner chose latest prototype; old grace superseded |
| P-02 (approved) | Active past-day edited value becomes later recall; original creation timing/provenance retained separately | Owner confirmed active-value recall plus preserved original metadata |
| P-03 | Store selectable duration buckets as categorical ranges; exact minutes only when entered; never invent bucket midpoints | Prototype labels overlap at sleep boundaries and `30+ min` is not exactly 30 minutes |
| P-04 | Keep the approved fixed native symptom catalog; allow free text only in explicitly custom action/context/product fields | Older broad scope suggested custom symptoms; current prototype and native ID contract do not define them |
| P-05 | Use additive typed tables/repositories in the existing encrypted local store; no generic JSON health-record table or parallel symptom store | Many new entities have no incumbent persistent repository |
| P-06 | Record date is captured for the session; actual Today refreshes on midnight/resume; zone changes never reinterpret stored provenance | Native Today/Cycle clocks and lifecycle refresh need one deterministic policy |

P-01/P-02 resolve the documented conflicts, not a clinical coverage policy. Clinical qualification changes require separate review. Apply scoped successor amendments explicitly, not as an undocumented release-2.0 change.

## Date and navigation state

Use incumbent `LocalDate`, not UTC DateTime equality or ad-hoc ISO string rules. Store experienced calendar date independently from event timestamps. Inject a clock and zone provider for testing; production never uses the HTML’s demo date.

Conceptual immutable session (type names are illustrative, public APIs must be reviewed):

```text
RecordSession
  sessionId
  selectedDate: LocalDate
  origin: today | cycle | care | patterns
  returnContext: tab + optional cycleId/sourceId + route/focus state
  sectionFocus: optional stable section/symptomId
  childEditor: optional entityId + inherited date + guarded draft
```

State transitions:

```text
Closed → Open(origin, date)
Open → Calendar(date) → Open(chosenDate)       [cancel retains old date]
Open → Child(date) → Open(sameDate)            [save/close child]
Open → Safety → Open/Child(sameDate, draft)    [no automatic fact]
Open → Done → captured returnContext
Restart → Closed                             [durable records retained]
```

No session date is persisted as Today. No editor chooses a second day while inherited-date mode is active. Period/episode start-stop controls are separate range fields. Every write validates date eligibility again, not just calendar disabled styling. A changed clock/zone that makes the selected date future must block fact writes and offer choosing an eligible date; never silently retarget an entered draft.

Today refreshes local-day data on midnight/resume without changing an already open Record’s selected date. While Record is open, writes refresh shared data revision without mutating the retained background tab/date/route. Delete/correction of a source invalidates relevant projections and report previews.

## Shared facts and identity

| Source family | Identity / cardinality | Incumbent reuse or extension |
| --- | --- | --- |
| Symptom | One current source per symptomId + experiencedDate | Keep existing unique key, stable ID, labels and vocabularyVersion |
| Daily impact | One current overall impact per date; optional domains | New typed source, independent of symptom impacts |
| Bleeding | One current fact per date, nullable period association | Reconcile existing period-flow IDs, add standalone spotting/none support |
| Period | Stable period ID + observed start/end | Existing repository, validated range corrections and merge confirmation |
| Moment | Existing timestamped source semantics | Today-only entry; preserve legacy history, no duplicate Hard record |
| Private note | Individually identified dated note sources | Extend timestamp-only capture model; keep Quick note / Care reflection / Cycle Letter separate |
| Sleep/appetite | Typed dated observations | New context repositories; optional fields remain null |
| Activity/context event | Individually identified dated events | Multiple distinct activities/events on one day allowed |
| Temperature | Individually identified measurement with experienced date and optional measured time | New typed manual observation, separate entered unit/method series |
| Product/method episode | Stable episode ID, explicit start/stop and user exact name | New reusable episodes, validation independent of selected day |
| Product/method use | Stable ID + episode + date/event identity | Idempotent daily shortcut; distinct events may coexist when genuinely different |
| Care action | Stable event ID + completionToken/source + exact action set | Automatic completion deduped; manual actions/bundles may repeat |
| Care check-back | Stable source ID linked to action event | One current outcome per action/bundle; retain outcome correction metadata |
| Pattern programme | Stable config ID/version + bounded dates + dated pauses | Shared source references, not another copy of ratings |
| Preparation plan | User-confirmed selections/text + source snapshot/version | Preserve incumbent Kit; separate durable plan reference |

No new health value is encoded as a fabricated `SymptomType`. Latest projection deduplication is deterministic but never deletes raw legacy source history. Saving a pinned value then updating it from core/catalog keeps the same ID and original creation timestamp. Failed or concurrent writes require transactional uniqueness; a widget cache is not the source of truth.

Immediate write success follows durable repository success. Withdrawal deletes the explicit fact; zero writes a fact. Undo restores the same source transactionally and invalidates derived views. If a subsequent edit prevents safe Undo, do not overwrite it blindly—explain that the earlier action can no longer be restored.

## Zero, labels and scales

Symptom and overall impact use explicit integer 0–5. Decode persisted scores by explicit numeric mapping, never `.values[score - 1]` or enum-length bounds. Maintain 1–5 scores unchanged. Zero gets its own semantic label and accessible graphics; it is not a 1–5 palette index. A nullable/missing row stays absent, including migration, form defaults, charts and CSV.

Sleep quality uses its own named 0–5 scale: Very poor / Poor / Restless / Fair / Good / Restful. Appetite uses Less / About / More than usual plus independent craving 0–5. Do not pool these values into symptom severity or a daily diagnosis score. Daily impact domains and symptom functional impacts are independent nullable selections, not implied by an overall number.

Duration catalogs preserve the current HTML labels, including sleep Under 5 h / 5–7 h / 7–9 h / Over 9 h / Enter exact, activity Under 10 min / 10–20 / 21–40 / 41–60 / Over 60 and What I tried 5 / 10 / 20 / 30+ / Other. Proposal P-03: save the chosen bucket ID and label/version, not a guessed exact duration or automatic numeric bucket assignment. Exact input stores positive minutes separately; selecting Enter exact/Other requires valid input. A future numeric boundary redesign is a catalog amendment, not silent interpretation of legacy categories.

Other/custom fields keep an exact user string; blank custom values are invalid only when that custom choice requires them. Optional dose/unit/route/target cannot be represented by a default selected product or invented adherence. BBT requires finite positive entered temperature/unit/method; suspicious readings may receive a non-diagnostic confirmation, not an inferred illness or prediction change. Preserve original unit/value alongside any deterministic conversion.

## Timing and provenance

Separate at minimum: source ID, experiencedDate, initial recordedAt, current updatedAt, original timing, active-value provenance, vocabulary/scale version and write-zone metadata. Use explicit `same_day`, `later_recall`, `timing_unknown`; period/flow correction additionally exposes backfill metadata where relevant.

- Opening a source, choosing a day, generating a preview or browsing a calendar is read-only.
- New fact: classify using actual save clock/zone, not viewed day. Approved P-01 is strict same-local-day, no 04:00 grace.
- Changing a past value: approved P-02 marks active value later recall and excludes it from prospective coverage; retain original same-day creation metadata. Unchanged save is a no-op.
- Imported legacy rows with explicit trustworthy timing preserve it. Missing/ambiguous timing becomes unknown; never blanket-relabel all existing rows unknown or same-day.
- Unknown imported strings are not silently coerced to same-day; provide a versioned migration/decoder path. Malformed unsupported data fails safely and does not partially write.
- Source date correction validates uniqueness and explicitly resolves collision; do not silently overwrite another date’s fact.
- Later recall and unknown remain visible in facts/reports but cannot increase same-day coverage. The viewing date cannot reclassify provenance.

Freeze provenance/zone evidence at write time so travel/replay cannot rewrite past timing. A retrospective source remains retrospective even if UI now shows Today. Clinical completeness and Comfort Window classification use the active source version rather than preserved-but-replaced original values.

## Pattern programme and Comfort Window

Persist programme selected stable IDs, config version, start/end and dated pause intervals. Expected daily fields are the configured set plus overall impact; configured-date changes have a dated effective version, not retroactive coverage inflation. Pins and programme fields can overlap without changing each other’s configuration. Legacy diary keys are mapped only when their meaning exactly matches a stable native symptom; broad aggregate keys stay readable legacy fields, not guessed mappings.

Programme enrollment is optional and cannot gate ordinary recording. Onboarding and Patterns share enrollment identity. Unknown undated legacy pauses block claims of literal complete recording until confirmed. Ended history has a bounded date range and remains editable/readable without restarting.

Approved amended daily classification from confirmed, supported-vocabulary, same-day current sources (`native-comfort-window-explicit-zero-v1`):

| Evidence | Daily class |
| --- | --- |
| Any symptom >0, difficult/physical Moment, or independent impact >0 | Harder |
| All configured core symptoms explicitly 0 and impact explicitly 0, no harder evidence | Non-hard |
| Positive Moment alone, partial zeros, impact=0 alone | Observed partial/Moment evidence, no daily class |
| Later recall or timing unknown | Context only; does not satisfy prospective day class |
| Flow/Care/note only | No observed symptom-day class |

“Configured core” must be an explicit versioned set; do not use today’s visible pins as a historical denominator or invent a default non-hard set for unenrolled users. The approved native version derives classifications anew from current source revisions. Legacy engine behavior remains separately available under its existing algorithm; old classifications are not copied into the amended denominator. Partial/Moment observations remain factual evidence but, because they have no harder/non-hard class, do not enter the nine classified observed-day eligibility count or candidate-rate denominators. Numerical eligibility, voting, support and reliability thresholds are unchanged.

Preserve REQ-007…012 thresholds and completed-cycle windows; new classifier gets a new native algorithm ID. HTML `comfort-window-v3-explicit-zero` is not proof of a released algorithm. Current cycle cannot train its forecast. Derived outputs include source IDs, version, support/coverage/lift/confidence; recompute after write/delete/Undo/restore and reconcile any pending reminder. Zero is observed absence, not a positive symptom.

Free summaries do not require the CW 9/3 gate. Separate elapsed cycles from literal complete fixed-set cycles and clinical qualification. Show provisional counts/levels for partial or persistent evidence. Do not port HTML demonstration comparisons as a new clinical significance threshold; clinical wording/qualification remains a reviewed release gate.

## Care and products

Automatic Care event idempotency belongs in the repository/controller, not a render callback. Keep native completion semantics intact; failed persistence can retry the same completion token without duplicating an event. Outside-app events have independent experienced date and actual recording time. Bundle identity uses a canonical sorted exact action set plus explicit bundle flag and exact target identity; unspecified legacy targets never become named targets.

Check-back outcome and check-back time are not symptom baseline; target severity is optional and separately labeled. Skipping creates no outcome; Couldn’t try is explicit status/outcome, not missing. Historical entry must not start a retroactive push or pretend the user completed an in-app scene at that past time. No action/checkbox generates diagnostic or efficacy claims.

Episode creation is not use. Past use must fall within an eligible episode or require explicit correction. Dose changes create versioned episode/event history rather than rewriting past saved doses. Deleting/stopping/editing an episode shows affected use history and requires an explicit preservation/cascade policy; use edits never infer episode starts. Regimen side-effect/safety round-trips preserve unsaved dose/name/date.

## Storage, migration, backup and export

Extend `LocalHealthStore` and current SQLCipher database; avoid a new unencrypted preferences/JSON source of health truth. P-05 allows additive typed repositories with one shared transactional snapshot. Select next schema version from the actual working tree at implementation time (current inspected version 11); do not reserve a version number now or edit generated Drift output by hand.

Migration acceptance:

1. Preserve all existing 1–5 values, symptom IDs, unavailable legacy symptoms, initial timestamps, flow, Moment, reflections, plans and entitlement references.
2. Missing rows stay missing. Existing explicit provenance stays explicit. Unknown data never becomes clinical certainty.
3. Extend zero/unknown validation in domain, decoder, graphic semantics, charts, report composer, native backup and import validators together.
4. Notes gain a date only from trustworthy source metadata; otherwise retain readable undated history instead of guessing the last viewed day.
5. Add standalone bleeding without inventing periods or changing prediction anchors; period merge/delete must preserve attached facts/reflections under explicit policy.
6. Every new typed entity participates in encrypted backup, transactional restore, account/local deletion and the export whitelist (excluded until declared).
7. Old backups migrate atomically; newer incompatible backups are rejected before any write. Injected failure rolls back. Restore recomputes derived outputs; projections never replace source facts.
8. Deterministic replay produces equal canonical outputs after reopen/restore (exclude incidental run-time timestamps from canonical comparison).

All tests use synthetic data. Never log failed values/notes/database contents. Analytics consent cannot authorize health payloads. Draft buffers are not export sources. Each export declares exact selected categories/range/notes, keeps opt-ins separate from tracking settings, and shares the incumbent PDF/CSV range pipeline. Any new entity without an export contract is fail-closed.
