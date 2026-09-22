# Paid Split And Paywall Plan

Status: bounded implementation validated; external store release pending

1. Specification
   - [x] Record 2026-07-29 pricing and split decisions.
   - [x] Derive transparency rules from corpus paywall evidence.
   - [x] Create branch and specification.

2. Entitlement Domain
   - [x] Immutable entitlement state model (pending, active-intro, active-paid,
         lapsed, offline-unknown, free) with pure mapping from store snapshot.
   - [x] Free/paid capability map encoding REQ-001/002 as testable data.
   - [x] Unit tests: state transitions, lapse keeps free capabilities, offline
         keeps local access.

3. Entitlement Boundary
   - [x] EntitlementRepository abstraction; deterministic local adapter and
         RevenueCat adapter behind the same interface.
   - [x] Authenticated UUID binding, approved monthly/yearly/lifetime catalog,
         store-localized pricing, purchase, restore, and cancellation handling.
   - [x] No health data touches entitlement state.

4. Paywall Presentation
   - [x] Plans sheet with the current catalog, accessible plan picker, restore,
         and visible unavailable/error/pending states.
   - [x] Locked premium surface component (honest preview + `See plans`).
   - [x] Paywall reachable from locked surfaces and You only.
   - [x] Goldens: plans sheet, locked surface.

5. Validation
   - [x] Widget tests: free user keeps Care + tracking + export with lapsed
         state; premium gates degrade honestly; paywall never appears inside
         Care or export flows.
   - [x] `flutter analyze`, full `flutter test`, web build.
   - [x] Update roadmap; preserve public store configuration as pending.

6. Handoff
   - [x] Review diff, commit locally without push or merge.
