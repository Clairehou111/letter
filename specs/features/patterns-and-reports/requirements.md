# Patterns and reports

Status: current 2.0 target contract. Entitlement scope is in
[access](../../entitlements.md); final export and clinical-comprehension gates
remain open.

PR-01. Patterns operate on user-confirmed local period, symptom, impact, and
Care outcome records. They display source counts, covered dates/cycles, and
missingness. No missing day is imputed, and no check-in or Care gesture
becomes a symptom severity score. A pattern needs comparable evidence from
at least two records; one observation is shown as history, not recurrence.
Cycle-day and date comparisons do not imply a hormone phase or cause.

PR-02. What helped describes explicit check-backs, for example “Better in 2
of 3 check-backs,” and also shows Same and Worse. A returned action is pinned
or supported by prior user-reported outcome, not a hidden distress score.
Deleting or correcting a source record recomputes every derived view. Generic
comfort suggestions remain clearly separate from personal history. No result
claims treatment, prevention, efficacy, diagnosis, or certainty.

PR-03. A cycle story starts with the person's reflection, then factual Care
history and selected observations grouped by the stable starting period ID.
The incomplete current cycle is separate. An older Care note remains under
its originating action. Archive history is read-only except for explicit
navigation to the source editor. Never fabricate a letter, numbering,
trend, or missing event.

PR-04. The free Reports surface offers a limited factual on-screen view for
the most recent three months. Plus unlocks longer, custom, and all-record
ranges and every generated file: factual Visit Summary PDF, raw source CSV,
and Clinical Pattern Report PDF. A no-card preview may demonstrate Plus
interpretation in-app but cannot create files. Expiration never deletes local
records or files already generated. Every export uses exactly the range
reviewed immediately before generation.

PR-05. The factual report can include observed period and flow dates,
confirmed symptom severity and direct impact, factual Care actions and
selected outcomes, missingness, and notes the person explicitly selects.
Prediction ranges are labeled separately from observations. Legacy sealed drafts,
unresolved candidates, unsaved text, clipboard content, contacts, medication
history, and inferred causes are excluded. Every included value has a source,
experienced date, and same-day/later-recall or factual-event provenance.

PR-06. Cross-cycle visualizations use actual observations on both sides of a
period boundary. A Twin Matrix or similar summary leaves missing cells blank,
keeps explicit zero distinct from missing when supported, and never mirrors
data into unobserved days. Underlying symptom codes remain traceable through
any scanability grouping. Aggregate cells show their method and coverage.
Do not call a modified or incomplete diary DRSP or diagnostically equivalent.

PR-07. Report setup previews inclusion, range, provenance, and omissions
before file generation. PDFs use clinician-readable direct headings, labeled
grayscale-safe charts, and neutral print styling. CSV contains source rows,
not fabricated derived observations, and is not advertised as an EHR format.
Save locally, show the resulting path after success, then offer the OS share
destination. A failed save never reports success. The file is shared only by
the person's explicit action.

PR-08. All computation and file creation are deterministic and on-device.
Reports are a user-recorded summary for a conversation, not a diagnosis or
professional conclusion. A prospective clinical diary or DRSP-equivalent
claim requires separate rights, clinical, implementation, and release review;
it is outside this 2.0 contract.

The historical Doctor Mode proposal remains deferred. If pursued later, it
must be opt-in, gather daily self-ratings across at least two consecutive
cycles, let the person choose reminder time and pause/stop/edit/delete, keep
missed days missing, and mark retrospectively entered values honestly. It
cannot inherit a validated-instrument name or claim diagnostic equivalence
without rights and clinical review.
