# Session-Only Boundary Card Validation

Status: validated

## Automated Checks

- [x] no more than two static local templates are offered
- [x] templates contain no invented illness, migraine, diagnosis, emergency, or
  safety claim
- [x] durations are limited to 30 minutes, 2 hours, and 4 hours
- [x] no custom, indefinite, recurring, or background duration exists
- [x] selecting a template and duration produces editable local text
- [x] editing accepts 1 to 280 non-whitespace characters
- [x] no recipient, contact, address, subject, attachment, or destination field
  exists
- [x] clipboard writing occurs only after an explicit `Copy text` tap
- [x] selecting, editing, completing, and navigating do not copy automatically
- [x] Letter never reads existing clipboard content
- [x] clipboard disclosure is visible before or beside the copy action
- [x] successful copy says only that text was copied to the device clipboard
- [x] no copy state claims sending, sharing, delivery, scheduling, or receipt
- [x] no share sheet, composer, deep link, contact picker, or external app opens
- [x] `Continue without copying` finishes without a clipboard action
- [x] `Discard` finishes without valid text or a clipboard action
- [x] the parent Care flow can finish without opening the boundary card
- [x] discard clears the caller-owned controller before hand-off
- [x] every leave-Care path clears the caller-owned controller
- [x] leaving through safety clears the caller-owned controller
- [x] dismissing safety restores the same active ephemeral state
- [x] reconstruction or re-entry contains no prior edits or copy acknowledgement
- [x] no template, duration, text, copy result, or interaction count persists
- [x] no API, LLM, analytics, logs, notification, background task, or clinical
  value is created
- [x] no contact, SMS, phone, email, notification, Focus, or background
  permission is requested
- [x] Reduced Motion preserves every state and action without required animation
- [x] 320-pixel width at 200 percent text does not overflow or hide actions
- [x] primary controls meet the 44-by-44-pixel target
- [x] screen readers announce labels, selected states, validation, and copy
  acknowledgement
- [x] boundary-card visual baselines are reviewed
- [x] isolated tests pass before integration

## Manual Product Review

1. Enter the protected cocoon and confirm that opening the boundary card is
   optional.
2. Open the card and inspect both templates for truthful, non-medical wording.
3. Select each duration and confirm only the visible session text changes.
4. Edit one template without entering any recipient information.
5. Continue without copying and confirm no clipboard acknowledgement appears.
6. Re-enter, discard, and confirm the text does not return.
7. Re-enter, read the clipboard disclosure, then explicitly copy synthetic text.
8. Confirm Letter reports only that the text was copied to the device clipboard.
9. Leave and re-enter; confirm Letter forgot the text while making no claim that
   the OS clipboard was cleared.
10. Open and dismiss safety; confirm active text remains.
11. Leave through safety; confirm the session text is cleared.
12. Repeat at 320 logical pixels, 200 percent text, and with Reduced Motion.

## Privacy Inspection

- [x] search production code for persistence or repository calls from the card
- [x] search production code for API, LLM, analytics, and logging calls
- [x] search production code for contact, share, send, and composer APIs
- [x] verify the clipboard API is called only by the explicit copy handler
- [x] verify user-entered text never appears in diagnostics or test snapshots
- [x] verify the parent owns controller disposal and clears before navigation

## Parallel Integration Gate

- [x] requirements are approved before implementation
- [x] isolated component files do not overlap with cocoon ownership
- [x] callback and controller ownership match the integration specification
- [x] isolated component tests pass without app-level navigation
- [x] integration tests independently prove all leave-path clearing

## Feature Merge Gate

- [x] protected isolation remains the primary experience
- [x] typing and copying remain optional
- [x] no contact or messaging capability exists
- [x] clipboard limitations are stated honestly
- [x] Letter forgets all boundary-card data after the Care session
- [x] safety and accessibility requirements pass
- [ ] user explicitly requests merge
