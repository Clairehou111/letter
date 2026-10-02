# Build 14 physical iPhone verification

Target: TestFlight **Letter Within 1.0.0 (14)** (`app.letterwithin`). This is a
device acceptance checklist, not a record of completed device testing. Use
synthetic dates and notes on a disposable app account. Before each case, record
the iPhone model, iOS version, tester Apple ID alias, app account alias, local
time zone, build number shown in TestFlight, and Pass/Fail/Blocked. Save a
redacted screenshot or short recording for a failure; do not upload health
entries or private notes to a bug tracker.

## Run order

1. **D01 — Install and first launch.** Install build 14 from TestFlight on a
   physical iPhone. Confirm TestFlight and the app both show 1.0.0 (14), launch
   without a crash, and reach onboarding. For a clean install, use a disposable
   account/device state; deleting an existing app also deletes its local data.
   On a separate device or installation with synthetic Build 13 records,
   install Build 14 as an update and confirm the records and settings persist.
2. **D02 — Onboarding and account.** Complete the current onboarding, including
   returning to the app after an interrupted/backgrounded step. Sign in with
   Apple and the configured email sign-in path with separate fresh test app
   accounts; check each callback returns to the app. Relaunch and verify the
   session persists. Check error and retry after a temporary network loss.
   Record any unexpected blank/loading screen. Confirm Settings is reachable
   from Today and the main destinations are Today, Cycle, Care, Patterns.
3. **D03 — Privacy defaults and Screen Cover.** Before opting into anything,
   check Anonymous analytics is off and notifications are not silently enabled.
   Enable Screen Cover, move the app to the switcher, and confirm sensitive
   content is hidden in its preview; return and confirm records remain. Turn
   analytics on and off and confirm the preference survives relaunch. This UI
   check does not prove the public policy or App Store privacy answers are
   aligned; those remain separate release gates.
4. **D04 — Cycle first load and ordinary edits.** With no periods, verify Cycle
   has a usable empty state. Add one completed period and check Today/Cycle
   agree on the available estimate state. Add a second eligible start, leave
   and re-enter Cycle, then force-close/relaunch: the first completed local
   read should show the estimate without a transient “forming” state. Edit a
   start or day once, wait for refresh, and check Today, Cycle, and Patterns
   agree. Delete a day or period once, wait for refresh, and check all views
   again.
5. **D05 — Cycle rapid edits and delete.** On disposable synthetic records,
   make two quick date/day edits, then delete the newest record before earlier
   refreshes finish. Navigate Today → Cycle → Patterns and back, then relaunch.
   The final record set and estimate must match the last completed action;
   deleted entries must not reappear and an older result must not replace the
   latest state. Repeat one rapid sequence while opening the Cycle day editor.
   Capture action order and timestamps if a stale frame persists.
6. **D06 — Today check-ins and Care.** Save one mood, then change it normally;
   make two rapid mood choices and verify the last saved choice persists after
   relaunch. Add/edit/delete a symptom and check Cycle/Patterns reflect the
   final state. Open “My body needs care”: it should present the symptom
   chooser before a practice. Open “Everyday care”: it should present its
   ritual list. Complete a Care action explicitly and check the resulting
   record; exiting without completion must not claim a completed action.
7. **D07 — Comfort Kit and writing.** Pin a Care action, mark an appropriate
   completed Care outcome Better, add a future-self note, and create a Quick
   note with **Keep in Comfort Kit** explicitly enabled. Check the Kit in Care,
   including authored items, then test Remove, Replace, and Don't show again.
   Edit a Quick note and turn its Kit toggle off; verify the Kit refreshes and
   the note remains in local history. Before a forecast window, the Kit may be
   retrieved from Care but should not be pushed on Today as if a window is
   active. A forecast-window invitation requires the product's evidence gate.
8. **D08 — Free Reports and Plus first load.** On a fresh account with no paid
   entitlement, open Reports. Verify the limited factual on-screen view for
   the most recent three months, while longer/custom/all ranges and **all**
   generated files require Plus. Open Plus immediately after sign-in, after
   backgrounding, and again after relaunch. Wait for real StoreKit offers:
   record every title, duration, localized price, and product type, using the
   store response as the price source. Check Privacy Policy and Terms of Use
   links, scroll/close controls, loading, error, and retry. No desktop or
   Google Play wording should appear on iPhone.
9. **D09 — Purchase, persistence, restore.** Use an eligible TestFlight sandbox
   tester and a disposable app account. Complete one test purchase only after
   confirming the Apple sheet identifies the sandbox transaction. Confirm Plus
   unlocks paid interpretation, extended ranges, and PDF/CSV generation;
   relaunch and confirm entitlement remains. Invoke Restore and verify the
   same entitlement without a second purchase. On a separate clean test app
   account with no entitlement, verify the unpaid offer state first; keep this
   observation distinct from the already subscribed account. Record any
   product-not-found, canceled purchase, interrupted restore, or offline retry
   outcome. Use a separate sandbox Apple ID for the clean unpaid account if
   the first tester's Apple entitlement would otherwise carry over. Do not
   use a production Apple ID purchase for this case.
10. **D10 — Report files and sharing.** With Plus active, generate Visit Summary
    PDF, raw CSV, and Clinical Pattern Report PDF from a selected synthetic
    range. Check the saved path, exact selected range, file opening, chart
    labels, and share sheet. Share only to a tester-owned destination or cancel
    the sheet. Confirm existing generated files remain readable after an
    entitlement change if a controlled lapse is available. Check that a no-card
    preview, if active, cannot generate files.
11. **D11 — Reminder and notification.** On a current build, verify reminder
    opt-in is available before a reliable Clearer Comfort Window exists; the
    saved preference remains on but no notification is scheduled yet. “Not now”
    persists.
    With a qualified synthetic fixture or naturally eligible history, enable
    the 0/1/2-day lead options, grant iOS notification permission, and check
    Settings' saved state and 09:00 local copy. Check actual delivery at the
    scheduled time, destination after tapping, and cancellation after turning
    the reminder off or editing/deleting qualifying records. If a reliable
    window cannot be created on device, mark delivery **Blocked**, not Pass.
12. **D12 — UI, accessibility, and recovery.** On the physical display, check
    Onboarding, Today, Cycle, Care, Patterns, Settings, Reports, Plus, and Kit
    with standard and large Dynamic Type, VoiceOver, Reduce Motion, Increase
    Contrast, keyboard, safe areas, and daylight legibility. Check SP6/LV3
    locator image and safety text for clipping and readability only; qualified
    clinical approval of placement, words, pressure, and safety remains a
    separate mandatory sign-off. Repeat Plus and core navigation after a
    temporary offline period and app relaunch.

## Acceptance evidence and handoff

- Keep one result row per case: case ID, Pass/Fail/Blocked, device/iOS, build,
  account alias, timestamp, observed result, and evidence path. Report a failure
  with exact action order, expected versus actual result, and whether relaunch
  changes it.
- D01–D10 and D12 should pass on the distributed TestFlight build before an
  App Review decision. D11's delivered notification must be observed or
  explicitly tracked as blocked; a Settings screenshot alone is insufficient.
- Separate owners must align the public privacy policy and App Store Connect
  answers with the optional PostHog behavior and sign off SP6/LV3 clinically.
  The Android Apple EULA destination is an Android subscription release issue.
