# Account, privacy, and Plus access

Status: current 2.0 target contract. Release configuration, StoreKit, and
public privacy alignment still require validation.

AA-01. New users make one successful Supabase sign-in before full entry.
Sign in with Apple is the primary iOS route; the configured email route
supports App Review and fallback access. Do not create an anonymous account
for pre-registration use. A returning user with local history can reach their
records and acute Care while offline or with an expired server session;
operations that need the server can request reauthentication separately.

AA-02. Account identity, consent receipt, and entitlement are operational
data. Supabase and RevenueCat do not receive readable period, symptom, Care,
note, Pattern, or report content. Signing in on a second device restores
account/Plus state, not local health history. Account deletion and local
health deletion are separate explicit actions with clear consequences;
neither may silently erase the other domain. A deleted account has a route
to connect a new one without discarding existing local records.

AA-03. RevenueCat associates Plus with the authenticated operational account.
The app displays store-provided localized products/prices and supports
purchase, Restore, pending, cancellation, grace, expiry, and offline
reconciliation. A transient network or store failure does not erase a still
valid locally known entitlement. A confirmed lapse gates future Plus actions
without deleting local records or previously generated files. Purchase and
Restore failure must be distinguishable from missing-account state.

AA-04. Free always includes acute Care/safety, period and health recording,
correction/deletion, encrypted local backup, basic Kit, and the bounded recent
on-screen factual report. Plus features and reference prices are specified in
[entitlements](../../entitlements.md). The no-card preview starts only when
Plus-grade evidence exists, lasts through the next cycle for at most 45 days,
and cannot generate report/export files. Paywall and purchase terms disclose
the actual capability and billing period before purchase.

AA-05. PostHog is optional and off by default. Consent is explicit and
revocable; turning it off clears pending Care usage aggregates. Disable
autocapture, replay, and person profiles. Use a random analytics-only
identifier, never a Supabase user ID. Immediate events are limited to
non-health settings and commercial flows. The only Care telemetry is the
delayed 30-day `1`, `2-5`, or `6+` usage bucket in the
[2.0 requirements](../release-2.0/requirements.md), with no mode,
outcome, duration, timestamp, note, or health context.

AA-06. The app explains the accurate health/account boundary: readable health
history is encrypted locally, while operational account, purchase, and
consented analytics services exist. Retire the former cloud-AI preference and
App Lock control. The app-switcher Screen Cover and optional analytics
control remain separate Settings actions. Public privacy policy and App Store
declarations must match the exact configured build before submission.

The privacy UI uses quiet, accurate signals: `Private on this device` on
Today, `Saved on this device.` after a sensitive local save, and a compact
Settings block for Screen Cover and Anonymous analytics. Show at most one
privacy signal on a screen; do not turn storage into a security dashboard.
