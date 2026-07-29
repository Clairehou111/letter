# Safety Boundary Content Validation

Status: validated (automated); native device dialer check deferred to release
gates

## Automated Checks

- [x] region mapping returns US content for `US`, CA content for `CA`, and the
      honest fallback for any other, missing, or malformed region code
- [x] US content includes 988 (call and text) and 911; CA content includes
      9-8-8 (call and text) and 911
- [x] fallback content contains no invented crisis numbers
- [x] emotional Care scenes render configured crisis content (never the
      old "not configured" statement)
- [x] physical Care renders both red-flag tiers
- [x] each phone number is both tappable and visible as text
- [x] dialer is faked in tests; the visible number remains the fallback
- [x] Leave Care and Return to scene both work
- [x] safety-route use creates no record, event, candidate, log, or analytics
- [x] controls meet 44px targets; 320px at 200 percent text does not overflow
- [x] goldens reviewed for US crisis, fallback crisis, and medical sheets
- [x] repository-wide validation passes: `flutter analyze` clean, 334 tests
- [x] Flutter web build passes

## Manual Product Review

1. Golden review confirms crisis contacts are the primary visual element and
   medical red flags are scannable; buttons remain reachable via scroll.
2. US, CA, and fallback variants verified through region-override tests.
3. Copy reviewed: no diagnosis, no moralizing, no promises, no medication or
   supplement guidance.
4. Remaining: on-device dialer tap-through on iOS and Android release builds —
   deferred to the approved native release gates.

## Clinical Copy Gate

- [x] 988 and 911 present for the US per batch-004 rules
- [x] urgent red flags match batch-004 emergency-routed categories (fainting,
      palpitations, severe acute symptoms, heavy bleeding with weakness)
- [x] no app-generated diagnosis or treatment recommendation anywhere

## Merge Gate

- [x] no Care safety route shows unconfigured content
- [x] region behavior is deterministic and tested
- [x] nothing about safety use is persisted or measured
- [x] local changes are committed
- [ ] user explicitly requests merge
