# Record Hub native requirements

Date: 2026-10-09  
Status: implementation contract prepared for owner approval. Product responsibilities below are confirmed; technical proposals and native acceptance remain subject to the gates in [README](README.md).

## Authority, goal and scope

Latest owner decisions override superseded research. For unchanged behavior, preserve the current native feature contracts and public APIs. The HTML is evidence of an interaction contract, not a production data model, clinical engine, native runtime or pixel-perfect port.

Goal: `Understand → Record → Prepare → Care → Learn → Share`, with low-effort ordinary tracking and an optional PMS/PMDD evidence-recording programme. Do not introduce a PMSS score, modified clinical questionnaire, diagnosis or compulsory whole-day rating.

RH-001 — Keep Today / Cycle / Care / Patterns as four destinations. Add central `+ Record` as an action, never a selected destination. Move existing You/settings/history/account/privacy/purchase access to a low-frequency Settings route reachable within two steps, preserving all its capabilities. Preserve the incumbent bar-hidden immersive Care behavior; global + need not interrupt an active exercise.

RH-002 — Today is fixed to the device’s actual local today. Preserve cycle orientation, observed/estimated distinction, existing prediction source explanation, Care/safety access, and optional tasks/preparation context. Do not create a second Today homepage or historical Today. The HTML’s fixed 2026-10-08 clock is only a synthetic fixture.

RH-003 — Complete Record is one independent dated workspace. Entrances: global +; Today Add a symptom / descriptive Record more; Cycle day / Choose any day / Fill in dates complete-record link; Patterns missing date / dated symptom source. A fresh global + always defaults to actual today, regardless of the previous workspace date or current destination.

RH-004 — The workspace may record all occurred days, including nonbleeding, premenstrual and dates before any period exists. It never requires a period first. Editors inherit the selected date without another date step. Existing episode start/stop and period date-pair editors remain explicit range corrections, not single-day fields.

RH-005 — Child save/close stays in Record at its selected date. Done/system back returns to the exact originating tab and retained Cycle detail or source list. Choose today changes Record’s date without exiting. Restart closes transient Record navigation but preserves durable records. Opening or reading a historical record creates no fact and changes no timestamp or provenance.

RH-006 — Record’s date button opens an accessible month calendar: full date header, month navigation, year selection, selected date, today indication, real saved-record indicators, disabled future days and one-tap day selection. No manual date typing, seven-day strip or extra confirmation. Selected-cycle chooser initially constrains to that cycle’s dates, including nonbleeding days; the resulting complete workspace can subsequently choose any occurred date. Existing period/episode forms may retain incumbent adaptive date-pair controls.

## Quick recording and shared Symptoms

RH-010 — Today retains the 12 incumbent Moment states and actual Today quick-pick/More layout. Moment and More are absent from Record and its type index, even when Record is showing today. Existing Moment records remain readable/deletable/correctable through source-detail behavior; do not delete history or add a new historical Moment entry route. Mood-category symptom severity remains available in Record.

RH-011 — Remove independent Fine today / Hard day entries. Difficult Moment states Low / Irritable / Anxious / Overwhelmed / Exhausted / Physical contribute a derived difficult-observation signal, not a duplicate persisted Hard-day event. Positive states prove that Moment only: they never create symptom zeros or a full-day non-hard classification. Difficult selection may progressively offer Add symptoms / Open Care; recording remains complete without using either.

RH-012 — Today and Record show the same 2–4 stable user-selected symptom pins in the same saved order. Never replace them automatically by recent use, forecast phase or selected Moment. Removing a pin hides the shortcut only, not its records. Pins are symptoms, not Sleep/Daily impact/Care pins. Preserve native default behavior unless the owner approves suggested initial pins; suggestions require confirmation.

RH-013 — Embed the incumbent ObservationCatalog picker in Record: native quick picks, alias/name/stable-ID search, Physical / Mood / Mind / Energy / Sleep / Digestion, degree graphics and optional symptom-specific impacts. Preserve all 40 currently available symptom IDs, vocabularyVersion 3 and incumbent labels. Difficulty sleeping is search-only; unavailable Difficulty concentrating and Heart palpitations are retained for legacy source compatibility but not offered as new ordinary symptoms. Safety remains directly accessible.

RH-014 — Add `0 Not present` to existing 1 Minimal / 2 Mild / 3 Moderate / 4 Severe / 5 Extreme without renumbering old values. Blank is no record. Save a selection immediately without a page-level Save; tapping the same saved degree withdraws it. Undo restores the exact source ID/date/value/timestamps. Pinned, catalog, Pattern Record and Cycle views upsert one symptom/day record, never mirrored copies.

RH-015 — Daily impact is a distinct optional 0–5 fact (0 No impact; 1–5 incumbent labels), not inferred from symptoms, Moment or Care. Optional domains: work/school, home responsibilities, relationships, social activity, sleep, hobbies/interests. Existing symptom functional impacts remain distinct. Record embeds impact and optional note; it is not a mandatory complete form.

RH-016 — Bleeding is always accessible on Today and Record. Preserve Spotting / Light / Medium / Heavy, Pink / Bright red / Dark red / Brown and progressive color/clots. Explicit no bleeding is different from blank. First spotting outside a period can be saved without starting/extending a period. Period changes require validation and confirmation where adjacent merge or attached data is affected; preserve all flow/reflections. Never infer symptom degree from flow.

RH-017 — Dated log lists real saved facts with source detail/edit/delete; honest empty state. Save feedback names the fact and date, shows local save status without exposing health in logs, and permits Undo for immediate changes. An asynchronous failed save must not appear as durable success. Switching date, leaving Record or leaving a child form guards unsaved drafts; safe return preserves draft/date/focus.

## Complete recording surface

RH-020 — Named visible groups: Symptoms / Bleeding / Daily impact / Context (Sleep, Activity/rest, Appetite/cravings, Significant event) / What I tried / Medication & methods (Medication, Supplement, Birth control) / Temperature / Private note. Full All record types is an optional index, not the only discovery path. Do not hide these behind an unexplained Other button or render the whole taxonomy on Today.

RH-021 — Use typed optional context records, not pseudo-symptoms. Preserve the HTML’s visible catalog labels; numeric bucket semantics and custom-value handling are proposals in `data-contract.md`. Sleep is the night ending on the selected day. Context can be described as recorded alongside symptoms, not as a cause or prediction input.

RH-022 — Manual BBT stores entered value/unit, method, experienced date, optional measured time and quality flags. Current demonstrated methods are Manual oral / Manual other; no import or inferred wearable source. Show dated method-separated trend, without changing period prediction, phase, fertility or reminder gates. HealthKit/Health Connect and temperature-shift prediction remain conditional future work.

RH-023 — Medication/supplement retain exact user-entered name and optional dose/unit/route/target; catalogs are recording aids, never product/dose recommendations. Separate reusable actual start/stop episodes from dated Taken / Skipped / As needed use. Saving an episode alone never creates a taken record. Eligible historical use remains possible after an episode has stopped; an historical new episode requires its actual start. Birth-control method episodes/use/emergency events follow the same separation. Stopping/removing/changing an episode must not silently orphan or delete existing use events.

RH-024 — What I tried is one entrance. Base catalog: Meditation, Breathing, Heat/warmth, Gentle movement, Rest/lower expectations, Comfort setup, Talk to someone trusted, Other. Actual local reuse history and custom actions supplement it; no fabricated recommendations/history. Store status, optional duration/target, source and exact action set. Outside-app historical entry is not an in-app completion.

RH-025 — Care deliberate completion creates one idempotent action event automatically; exit/abandonment creates none. Preserve native gestures, timing, audio/haptics, safety, completion and distinct reflections. Multiple combined actions are one bundle with one check-back. Better / Same / Worse / Mixed / Couldn’t try, optional target degree, unexpected/uncomfortable and reflection remain available; skip preserves action but creates no outcome. Historical recalled actions do not schedule belated notifications or claim a prospective experiment.

RH-026 — Factual Care memory groups exact action sets/bundle identity and exact target, includes all outcomes plus unchecked count, and labels self-reported evidence. Never allocate a bundle’s Better outcome to each component action, pool unspecified legacy targets with named targets, or claim causality. Template selection creates no event until Save.

## Optional PMS/PMDD path and interpretation

RH-030 — Onboarding and Patterns start the same optional Pattern Record programme, with selected stable symptom IDs plus independent impact; Today has an optional continuation. It is not another symptom database. Fixed fields update the same daily sources as pins/catalog. No streak, forced goal or forced daily completion.

RH-031 — Show expected fields/dates, missingness, same-day / later recall / timing unknown and before/after coverage. Dated pause/resume/end preserve all sources; undated legacy pauses remain unresolved until confirmed. Ended programme summaries use its bounded dates and configuration version, never future records or a silently restarted programme.

RH-032 — Distinguish elapsed cycles, literally fully recorded fixed-set cycles and Comfort Window eligibility. Literal completeness requires every expected non-paused day/field recorded same-day, including explicit zeros; it is not clinical qualification. Incomplete evidence still supports provisional free facts. No new clinical completeness percentage is approved.

RH-033 — Free two-cycle factual summary exposes source counts, typical level, separate peak/distribution, independent impact, missingness and recalled/unknown share. Preserve Spectrum/Twin/Gravity responsibilities and windows; no second clinical engine or rewritten charts. No-difference wording requires comparable support. Persistent symptoms do not need non-hard days to see facts. Diagnosis/clinical qualification and modified-questionnaire labels are prohibited.

RH-034 — Amend Comfort Window day classification as documented in `data-contract.md`; preserve incumbent completed-cycle, candidate, voting, support/lift, confidence and reminder gates. REQ-007’s 9 observed / 3 non-hard rule applies only to Comfort Window, not availability of free factual summaries. Every amended result is versioned and source-traceable; current cycle never trains itself.

RH-035 — Prepare appears only under incumbent reliable-window conditions. It opens ordinary Care if no personal plan/Kit exists. User-confirmed plans snapshot selected own words/evidence and remain accessible; source changes label the saved reference rather than silently rewriting it. Preserve Kit vs preparation-plan distinctions. Dismissal persists; notifications remain default-off with explicit opt-in, real platform permission and 09:00 local scheduling under the reliable gate, not simulated delivery.

## Privacy, access and release boundaries

RH-040 — Health stays in encrypted local storage; no cloud health AI or analytics payloads. Never include health dates, symptom/value, note, Care outcome, report contents or derived state in logs/crash/telemetry. All synthetic screenshots/test data are explicitly fictional. Screen cover and safe deletion/settings access remain intact.

RH-041 — Every entity declares export eligibility. Unknown entity defaults to excluded. Sensitive category opt-ins default off, including medication/supplement/contraception/emergency, BBT, selected notes/reflections, sensitive context and adverse free text. Exact range/fields and sensitive selections are previewed before local generation; form drafts and internal snapshots never export.

RH-042 — Approved successor access amendments: all-record raw source CSV free; recent-three-month factual Visit Summary PDF free; longer/custom PDF and Clinical Pattern Report/deeper interpretation remain Plus. Free factual two-cycle summary/manual BBT trend/factual Care memory do not become an upsell. Existing release-2.0 REQ-003/004/005/015/017, entitlement/report/store copy must be reconciled together before the successor ships. Existing generated files survive lapse. Do not silently change the approved 2.0 binary while preparing this proposal.

RH-043 — Reuse native PDF/share/save-path infrastructure, not prototype JSON as a substitute PDF. Backup/restore, source correction/deletion, clinical safety, regional resources, notifications and purchases require native evidence. Preserve plain offline US/CA resources and other-region fallback; no automatic call/text. Severe/adverse paths prioritize safety and recover recording drafts.

RH-044 — Excluded: sex/pleasure, weight, mucus, weather, full food diary, Belle symptom enums, custom diagnostic symptom definitions, fertility/ovulation/contraception prediction, health import, new diagnosis/PMSS score, causal relief claims. Preserve approved calendar-period prediction; contradictory historical research references to ovulation are not implementation authority.

## Explicit incumbent amendments

| Incumbent contract / code | Successor change | Required coordinated acceptance |
| --- | --- | --- |
| REQ-002; native five-item shell | Four tabs, + action; You content relocated, not deleted | RH-001, navigation/settings/account/privacy regressions |
| REQ-006; degree/storage 1–5 | Zero/missing and source-aware daily classification | RH-014, RH-034; scores, backup and engine replay |
| REQ-003/004/005/015/017; entitlements/data reports | Approved free source/factual boundaries | RH-042; account/preview/lapse/export matrix |
| Current period-bound flow | Independent nonperiod spotting/bleeding facts | RH-016; period merge/delete and flow preservation |
| Current note creation timestamp only | Dated note sources without rewriting Care/Cycle letters | RH-017; history and migration |
| Diary’s independent string keys/in-memory store | Optional programme uses shared native symptom/date sources | RH-030–033; lossless legacy mapping or explicit unknown |

Requirements approval does not waive the independent clinical, rendered-accessibility, purchase, or release gates.
