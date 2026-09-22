# Paid Split And Paywall Requirements

Status: superseded in part by `../../pricing-and-entitlement-strategy.md`

The safety and local-data-access requirements below remain approved. The
price points, plan architecture, and upfront paywall placement are historical
and must not be used for release configuration.
Branch: `feature/paid-entitlement-split`
Base branch: `feature/safety-boundary-content`
Depends on: `2026-07-28-auth-subscription-entitlement` (entitlement source)

## Context

Historical decision (superseded for current implementation): the MVP launches
paid from day one with a `$0.99` first month, `$8.99/month`, six-month, and
`$50.99/year` catalog. The current approved catalog is monthly, yearly, and
lifetime with reference prices `$6.99`, `$29.99`, and `$79.99`; store offerings
are authoritative for localized labels.
Until now no spec defined which features are free, which are premium, or how
the paywall behaves. The corpus is explicit that gating value at the moment of
need reads as irresponsible (mg-009, mg-018, mg-052), and the 2026-07-29
product decisions set the split and the transparency rules.

## Goal

Define and enforce the free/paid split so the acute experience is never held
hostage, the paid layer is the compounding personal memory, and every purchase
surface is transparent before any personal question.

## Requirements

REQ-001: Free forever, regardless of entitlement state:

- all five acute Care flows, complete (no premium-only scene content)
- crisis and medical safety boundary routes
- period tracking: start/end, history, edit, delete
- cycle prediction display
- local encrypted backup/export/import and data deletion

REQ-002: Premium (requires active subscription or intro month):

- personal memory: check-back history, future-self notes, and ranked comfort
  actions
- Today prepare surface and personal danger-window estimate
- personal patterns and cross-cycle Letters archive detail
- any future reports

REQ-003: When entitlement lapses, premium memory pauses but is never deleted.
A lapsed user keeps REQ-001 features plus read access to their existing data.
Care safety routes and local data read/export/delete never depend on billing
state (mirrors auth-subscription-entitlement REQ-005/007).

REQ-004: Premium-gated surfaces must degrade honestly: a locked surface shows
what it would contain and one upgrade action, never fabricated content.

REQ-005: The purchase surface appears after an eligible user has seen the real
free preview, outside Care and safety. It must show, on one surface:

- monthly, yearly, and lifetime options;
- store-provided localized prices and renewal terms when configured;
- the approved reference prices `$6.99/month`, `$29.99/year`, and `$79.99 once`
  only as non-authoritative marketing anchors;
- explicit plan selection; no preselected consent, no countdowns, no false
  scarcity, no hidden renewal language

REQ-006: The paywall never interrupts an acute Care flow, a safety route, or
a data export. Upgrade surfaces are reachable from locked premium surfaces
and from You, nowhere else.

REQ-007: Purchase state changes (pending, restored, expired, grace, offline)
must keep REQ-001 features working and never delete or lock local data.

REQ-008: No health values, cycle dates, symptoms, notes, or inferred state may
appear on purchase surfaces, in purchase analytics, or in paywall copy beyond
generic feature descriptions.

## Non-Goals

- production store configuration is outside this bounded code slice: actual
  RevenueCat keys, App Store/Play products and entitlement/offering, store
  agreements, sandbox accounts, and native validation remain release gates
- promotional offers, discounts, or win-back flows
- server-side paywall or remote paywall configuration
- a one-time report SKU (rejected 2026-07-29: fake-door validation only)

## Product Decisions

- Acute Care is the proof, not the paywall. The $0.99 intro month exists to
  create paid identity and commitment, not revenue.
- Purchase copy never claims the intro includes a complete cycle; cycles vary
  and irregular-cycle users are a core segment. Approved framing:
  `your next difficult window, prepared`.
- The upgrade action inside a locked surface uses calm, descriptive copy
  (`See plans`), never urgency or shame.
