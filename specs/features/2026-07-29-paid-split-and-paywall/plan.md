# Paid Split And Paywall Plan

Status: validated

1. Specification
   - [x] Record 2026-07-29 pricing and split decisions.
   - [x] Derive transparency rules from corpus paywall evidence.
   - [x] Create branch and specification.

2. Entitlement Domain
   - [x] Immutable entitlement state model (active-intro, active-paid, lapsed,
         offline-unknown) with pure mapping from store snapshot.
   - [x] Free/paid capability map encoding REQ-001/002 as testable data.
   - [x] Unit tests: state transitions, lapse keeps free capabilities, offline
         keeps local access.

3. Entitlement Boundary
   - [x] EntitlementRepository abstraction; local development adapter (manual
         state for previews/tests); RevenueCat adapter behind the same
         interface with store keys deferred to release preparation.
   - [x] No health data touches entitlement state.

4. Paywall Presentation
   - [x] Plans sheet with all REQ-005 elements; accessible plan picker.
   - [x] Locked premium surface component (honest preview + `See plans`).
   - [x] Paywall reachable from locked surfaces and You only.
   - [x] Goldens: plans sheet, locked surface.

5. Validation
   - [x] Widget tests: free user keeps Care + tracking + export with lapsed
         state; premium gates degrade honestly; paywall never appears inside
         Care or export flows.
   - [x] `flutter analyze`, full `flutter test`, web build.
   - [x] Update roadmap; mark auth-subscription-entitlement in_progress.

6. Handoff
   - [x] Review diff, commit locally without push or merge.
