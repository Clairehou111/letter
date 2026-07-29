# Safety Boundary Content Validation

Status: in_progress

## Automated Checks

- [ ] region mapping returns US content for `US`, CA content for `CA`, and the
      honest fallback for any other, missing, or malformed region code
- [ ] US content includes 988 (call and text) and 911; CA content includes
      9-8-8 (call and text) and 911
- [ ] fallback content contains no invented crisis numbers
- [ ] every emotional Care scene renders configured crisis content (never the
      old "not configured" statement)
- [ ] physical Care renders both red-flag tiers
- [ ] each phone number is both tappable and visible as text
- [ ] dialer failure keeps all numbers visible
- [ ] Leave Care and Return to scene both work from every sheet state
- [ ] safety-route use creates no record, event, candidate, log, or analytics
- [ ] controls meet 44px targets; 320px at 200 percent text does not overflow
- [ ] screen-reader semantics announce the crisis actions
- [ ] goldens reviewed for both sheets, US and fallback variants
- [ ] repository-wide validation passes (`flutter analyze`, `flutter test`)
- [ ] Flutter web build passes

## Manual Product Review

1. From each of the five Care entrances, open the safety route and confirm the
   normal interaction stops.
2. With a US locale, confirm 988/911; with a CA locale, 9-8-8/911; with any
   other locale, confirm the honest fallback and no fabricated numbers.
3. Read every line aloud: no diagnosis, no moralizing, no promises, no
   medication or supplement guidance.
4. Confirm the sheet never traps the user: return and leave both require one
   tap and no explanation.
5. Confirm numbers can be read and dialed manually if the dialer fails.

## Clinical Copy Gate

- [ ] 988 and 911 present for the US per batch-004 rules
- [ ] urgent red flags match batch-004 emergency-routed categories (fainting,
      palpitations, severe acute symptoms, heavy bleeding with weakness)
- [ ] no app-generated diagnosis or treatment recommendation anywhere

## Merge Gate

- [ ] no Care safety route shows unconfigured content
- [ ] region behavior is deterministic and tested
- [ ] nothing about safety use is persisted or measured
- [ ] local changes are committed
- [ ] user explicitly requests merge
