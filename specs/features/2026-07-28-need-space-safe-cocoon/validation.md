# Need-Space Safe Cocoon Validation

Status: validated

No implementation has been performed. All checks below are proposed merge
criteria for later approval.

## Behavioral Checks

- [x] entering from `I need everyone away.` opens directly on the curtain frame
- [x] one tap on `Close the curtain` reaches the cocoon
- [x] the short downward gesture reaches the same cocoon state
- [x] the gesture is never the only way to close the curtain
- [x] the curtain transition runs once and resolves deterministically
- [x] interrupted or disabled animation cannot trap the user
- [x] the cocoon requires no task, text, timer, or repeated interaction
- [x] `Prepare words` invokes its parent callback exactly once
- [x] `Nothing else right now` invokes its parent callback exactly once
- [x] neither stage exit autoplays or recommends another Care mode
- [x] re-entry starts at the open curtain with no restored state

## Safety And Honesty Checks

- [x] back to Care choices is available in every state
- [x] leave Care is available in every state
- [x] `I may not be safe` is available in every state
- [x] dismissing the emotional safety boundary restores the prior state
- [x] leaving from the emotional safety boundary exits without obstruction
- [x] no copy says or implies that the user is guaranteed to be safe
- [x] no copy says or implies that Letter blocks people, contacts, calls,
      messages, notifications, networks, or other apps
- [x] the device-control limitation is readable before the curtain closes
- [x] the cocoon does not resemble a lock, cage, restraint, surveillance
      surface, or emergency service
- [x] there is no coercive countdown, forced delay, shame, urgency, or
      completion pressure

## Privacy And Scope Checks

- [x] no contact or recipient permission is requested
- [x] no message, send, share, copy, or external-app action appears
- [x] no reason, symptom, severity, health detail, or free text is requested
- [x] no state, duration, completion, outcome, or interaction count is persisted
- [x] no API, LLM, analytics, notification, background task, or clinical value
      is created
- [x] no Focus or Do Not Disturb control is used
- [x] no logs contain user behavior or health information

## Accessibility And Responsive Checks

- [x] Reduced Motion reaches the cocoon without curtain travel, parallax,
      scaling, or simulated depth
- [x] Reduced Motion preserves the same state, copy, controls, and outcome
- [x] the experience works at 320 logical pixels and 200 percent text scaling
- [x] text does not clip, overlap, or require horizontal scrolling
- [x] every interactive target is at least 44 by 44 logical pixels
- [x] all controls expose clear accessibility labels and roles
- [x] open and cocoon states are not communicated by color alone
- [x] focus order keeps back, primary action, safety, and leave controls
      predictable
- [x] screen-reader announcements do not claim device-level isolation
- [x] contrast remains sufficient in the low-stimulation palette

## Visual And Product Review

1. Enter `I need everyone away.` and confirm the first frame has one obvious,
   one-thumb curtain action.
2. Confirm the platform limitation is honest but visually subordinate to the
   immediate protective interaction.
3. Close the curtain by tap and verify that visual complexity decreases after
   one action.
4. If the optional gesture is retained, repeat with one thumb and verify that
   no precision drag or hold is required.
5. Stay on the cocoon screen and confirm that nothing loops, counts, rewards,
   vibrates, plays, or pressures the user.
6. Open and dismiss the emotional safety boundary from every state.
7. Leave directly from every state and verify that the flow never resists exit.
8. Repeat with Reduced Motion.
9. Repeat at 320 logical pixels with 200 percent text scaling.
10. Review representative iPhone and Android screenshots with real fonts.

## Approval Gate

- [x] the user approves the proposed copy
- [x] the user approves the downward pull plus tap alternative
- [x] product review confirms the cocoon feels protected without feeling locked
- [x] requirements status changes from `draft` to `approved`
- [x] validation status changes from `draft` to `approved`
- [x] implementation begins only after approval
