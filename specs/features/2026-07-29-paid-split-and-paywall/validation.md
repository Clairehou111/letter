# Paid Split And Paywall Validation

Status: in_progress

## Automated Checks

- [ ] every REQ-001 capability is available with lapsed/no entitlement
- [ ] every REQ-002 capability requires active entitlement
- [ ] lapse pauses premium memory but deletes nothing
- [ ] plans sheet shows intro price, renewal price, alternatives, effective
      monthly prices, and the `$1 more` note with explicit selection
- [ ] no countdown, scarcity, or preselected consent exists
- [ ] paywall is unreachable from Care flows, safety routes, and export flows
- [ ] locked surfaces show honest previews, never fabricated content
- [ ] offline state keeps free capabilities working
- [ ] no health value appears on purchase surfaces
- [ ] goldens reviewed; 320px at 200 percent text passes
- [ ] `flutter analyze` clean; full `flutter test` passes; web build passes

## Manual Product Review

1. Fresh install: purchase surface appears before any personal question.
2. Read the plans sheet: renewal terms obvious without fine print.
3. Lapse entitlement: acute Care, tracking, and export all still work;
   premium surfaces show locked previews.
4. Confirm no urgency, shame, or surprise language anywhere.

## Merge Gate

- [ ] free/paid split matches the 2026-07-29 decisions exactly
- [ ] safety and data access never depend on billing
- [ ] local changes committed
- [ ] user explicitly requests merge
