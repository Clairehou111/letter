# Health-record acceptance

Status: automated local coverage exists; final 2.0 native and accessibility
passes remain open.

| Case | Required result |
| --- | --- |
| Direct capture | A symptom requires an explicit five-level choice; date, provenance, and selected impact persist. |
| Same-day update | Repeating the same symptom/day updates one record and retains original `recordedAt`; a different symptom or date stays distinct. |
| Edit/delete | All derived Today, Cycle, Pattern, and report views recompute; no ghost record or duplicate count remains. |
| Candidate | Negation and source are visible; unresolved/rejected suggestions never persist or export; acceptance requires the person's chosen intensity. |
| Text/voice | Optional authored text persists only when saved; voice remains unavailable until an approved on-device adapter, permission/error flow, transcript review, and text fallback pass. |
| Safety | Self-harm/suicidal signals open crisis routing; palpitations open medical routing; no routine rating is saved from the interrupted choice. |
| Migration and privacy | Vocabulary v3 reads older codes; native encrypted store and web in-memory adapter have matching semantics; errors/logs contain no health values. |
| Accessibility | 320px/200% text, screen reader, Reduced Motion, errors/retry, and 44px controls remain usable. |

Representative implementation checks live in `apps/mobile/test/` for the
health-record repository, form, NLP review, and safety navigation. Dated
release proof belongs in [`validation/2.0/`](../../../validation/2.0/).
