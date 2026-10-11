# Onboarding and safety acceptance

Status: implementation coverage exists; final native route and accessibility
pass remains open.

| Case | Required result |
| --- | --- |
| First/returning entry | Correct screen with no flash; optional goals; clear progress and Back/Continue; retry after secure-storage error. |
| Privacy migration | Legacy `cloud_tools` loads safely; new saves omit it; no AI choice reappears; goal identifiers remain local. |
| Regions | US and Canada show verified call/text resources and emergency route; unknown region shows no invented number. |
| Contact controls | Each number remains visible and tappable; dialer failure leaves a usable text fallback. |
| Safety behavior | All relevant Care states and selected safety signals route immediately; no ordinary flow continues underneath. |
| Data boundary | Opening/leaving safety creates no record, candidate, event, notification, log, or report content. |
| Accessibility | 320px/200% text, screen reader order, 44px targets, no motion/sound/haptic dependency. |

US and Canadian contact details were checked against the linked official
services on 2026-10-03. Reverify at release-copy review; a documentation
check alone is not physical-device dialer validation.
