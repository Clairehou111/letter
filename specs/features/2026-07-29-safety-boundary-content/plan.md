# Safety Boundary Content Plan

Status: in_progress

1. Specification
   - [x] Confirm scope with the user (MVP release plan, launch blocker first).
   - [x] Derive crisis content from batch-004 clinical anchor rules.
   - [x] Define region model, red-flag tiers, and persistence/analytics bans.
   - [x] Create the feature branch and specification.

2. Safety Domain
   - [ ] Immutable region model: US, CA, fallback; pure `regionCode` mapping.
   - [ ] Immutable crisis content per region (lifeline name, call/text numbers,
         emergency number, fallback copy).
   - [ ] Immutable medical boundary content (urgent and non-urgent tiers).
   - [ ] Unit tests: US/CA/other/unknown mapping, content completeness, no
         invented numbers for fallback regions.

3. Dialer Boundary
   - [ ] Add `url_launcher`; configure `tel` schemes (iOS
         LSApplicationQueriesSchemes, Android queries).
   - [ ] Dialer adapter abstraction with a test fake; failure leaves the
         visible number as fallback.

4. Safety Sheets
   - [ ] Rebuild the emotional sheet from region content: honest opening line,
         lifeline block (call + text), emergency block, trusted-person line,
         Leave Care / Return to scene.
   - [ ] Rebuild the physical sheet: urgent tier, non-urgent tier, no-diagnosis
         line, Leave Care / Return to scene.
   - [ ] Semantics, 44px targets, 320px at 200 percent text, no animation
         dependence.

5. Validation
   - [ ] Widget tests: every Care mode opens configured safety content; region
         override renders US, CA, and fallback variants; dialer failure keeps
         numbers visible; return paths work.
   - [ ] Copy review against batch-004 rules (988/911 present; no diagnosis,
         no medication guidance).
   - [ ] Golden baselines for both sheets and both regions.
   - [ ] `flutter analyze`, full `flutter test`, web build.
   - [ ] Amend shell spec REQ-010 supersession note; update roadmap.

6. Handoff
   - [ ] Update validation evidence and mobile README if needed.
   - [ ] Review the complete diff.
   - [ ] Commit locally without push or merge.
