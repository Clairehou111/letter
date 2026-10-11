# Period and cycle records

Status: current 2.0 feature contract. The app implements most of this behavior;
the [validation record](validation.md) names code/spec differences still open.
Sources reconciled: the former period-logging, cycle-flow, prediction, Today
context, and exceptional-cycle specifications, plus current repository code.

## Period identity and editing

PC-01. A person can start a period today, add an earlier period with a chosen
start and optional inclusive end, end or reopen an open period, edit either
boundary, and delete a period after explicit confirmation. The list is newest
start first and each period has a stable local ID. Calendar dates are date-only;
travel between time zones cannot move a recorded day. Creation and editing
work after the first successful account sign-in while offline.

PC-02. Reject future start/end dates, end before start, overlapping inclusive
ranges, and a second open period. Show a specific recoverable error and keep the
draft. There is no arbitrary maximum bleeding duration. Never auto-close an
open period; after more than seven days, a gentle “Still bleeding?” check may
offer End today or Keep open. A one-day period remains exactly one day.

PC-03. A new start fewer than ten days after the preceding start needs an
explicit review path. Offer editing or continuing the previous period as an
alternative. Merging directly adjacent ranges requires explicit confirmation
that names the affected periods and any attached reflections. Cancellation
leaves every record unchanged. A merge must preserve flow and keep every
user-authored reflection retrievable. Current code merges without confirmation
and can detach a reflection from an absorbed period; this is an open defect.

PC-04. Deletion removes the local period and its owned bleeding-flow rows. If
a cycle reflection is attached to that period ID, the confirmation names that
reflection and deletion removes it. Symptoms, mood, notes, and Care events are
owned by their own timestamps and stay intact. Editing a period preserves its
ID and attached reflection, keeps flow days still inside the corrected range,
and removes only flow days now outside it. Neither edit nor delete rewrites
independently dated records.

PC-05. Recorded history is retained even when unusual or excluded from an
estimate. A short or long interval is not labeled pathological. Do not invent
a missing period, infer pregnancy, or silently turn spotting into a period.
Current cycle means the span beginning at the latest recorded start; a
completed cycle length is start-to-next-start, never bleeding duration.

## Day observations and presentation

PC-06. A user may record, replace, or clear Spotting, Light, Medium, or Heavy
flow for a date inside a recorded period. For an open period the latest valid
day is today. Flow never starts, extends, or ends a period. A color observation
is optional after flow and can be Pink, Bright red, Dark red, or Brown; color
has no diagnostic meaning and does not feed estimates. Flow and color use the
period ID and local date in the encrypted database and encrypted backup.

PC-07. Show bleeding duration and completed cycle length separately. Pin the
current cycle, show three recent completed cycles, and provide one route to
all recorded periods. Use dates and stable identity rather than mutable
`Letter No. N` numbering. The archive is newest first with clear edit/delete
actions; loading, empty, error, and retry states cannot display fabricated
history. Primary targets are at least 44 logical pixels and remain usable at
320 logical pixels with 200% text scaling.

PC-08. Today and Cycle read the same period repository and prediction result.
Today shows the real local date, observed period or cycle day, and qualified
estimated range. With no history it offers a route to add a period; with
insufficient history it says the record is still taking shape. Returning from
an edit refreshes both surfaces. Never substitute a population average,
fictional note, inferred mood, fertility/ovulation phase, or PMDD claim.

## Period estimate

PC-09. The formal next-period estimate requires two usable observed
start-to-start intervals, uses at most six recent intervals, takes their
rounded median as the midpoint length, and shows a range. The current period
start may anchor the estimate but its incomplete interval cannot train it.
The engine currently accepts 15–90-day intervals as basic quality candidates,
then removes intervals more than 1.5 times or less than 1/1.5 times the
quality-valid baseline median. The 21–45-day band is a review cue, not an
automatic exclusion. This reflects tested current behavior and supersedes the
older 21–45-day eligibility rule.

PC-10. The range half-width is at least seven days for a one-interval early
orientation estimate, four for two formal intervals, three for three, and two
for four or more. Observed variation can widen either side. A one-interval
orientation estimate must be labeled limited and cannot feed Patterns,
Comfort Window, reports, or notifications. Formal confidence is Low with two
intervals or spread over seven days; Higher requires at least four intervals,
spread at most four days, and no exclusions; other usable estimates are Medium.
Show contributing interval count, observed range, and exclusions where useful.

PC-11. Recompute derived estimates after create, edit, or delete; never store
them as independent health records. If today is within the estimated range,
say so. After it passes, say “Past the estimated window” or “No period recorded
yet” and do not roll forward a chain of predicted cycles. An estimate is not
contraception, a phase detector, a diagnosis, or proof of pregnancy status.

## Storage and privacy

PC-12. Native period/flow records use the encrypted local health database and
fail closed if cipher support or its secure key is unavailable. The web preview
uses memory only. Neither the API, analytics, logs, crash metadata, nor AI
services receive period dates, flow, color, or derived estimates.

PC-13. The 2.0 target uses the explicitly opted-in Comfort Window reminder in
[release requirements](../release-2.0/requirements.md). The older Cycle
Check-in notification is not an alternate way to enable it: its day-after-
estimate timing, default-enabled preference, and weaker evidence gate do not
satisfy 2.0. Current code still contains that legacy scheduler. Retire it or
approve it as a separately specified product feature before 2.0 release;
until then, do not claim the notification contract is complete.
