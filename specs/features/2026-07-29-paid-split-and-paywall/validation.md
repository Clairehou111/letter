# Paid Split And Paywall Validation

Status: bounded implementation validated; external store/native validation pending

## Automated Checks

- [x] every REQ-001 capability is available with lapsed/no entitlement
- [x] every REQ-002 capability requires active entitlement
- [x] lapse pauses premium memory but deletes nothing
- [x] plans sheet shows monthly/yearly/lifetime options, explicit selection,
      Restore Purchases, and store-localized prices when offerings are present
- [x] no countdown, scarcity, or preselected consent exists
- [x] paywall is unreachable from Care flows, safety routes, and export flows
- [x] locked surfaces show honest previews, never fabricated content
- [x] offline state keeps free capabilities working
- [x] pending, active-intro, active-paid, grace, lapsed, offline-unknown, unconfigured,
      failure, and cancellation states remain truthful
- [x] no health value appears on purchase surfaces
- [x] goldens reviewed; 320px at 200 percent text passes
- [x] `flutter analyze` clean; full `flutter test` passes; web build passes
- [ ] actual RevenueCat keys, store products, entitlement/offering, agreements,
      sandbox accounts, and native iOS/Android purchase flows are configured and
      validated

## Manual Product Review

1. Fresh install: purchase surface appears before any personal question.
2. Read the plans sheet: renewal terms obvious without fine print.
3. Lapse entitlement: acute Care, tracking, and export all still work;
   premium surfaces show locked previews.
4. Confirm no urgency, shame, or surprise language anywhere.

## Merge Gate

- [x] free/paid split matches the 2026-07-29 decisions exactly
- [x] safety and data access never depend on billing
- [x] local changes committed
- [ ] user explicitly requests merge
