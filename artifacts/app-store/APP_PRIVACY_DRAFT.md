# App Privacy declaration draft

## 2026-10-02 configured next-candidate state

The owner kept the optional Anonymous analytics control and SP6/LV3 guidance.
The previously empty PostHog project in the LetterHealth organization was
renamed **Letter Within** (project ID `534876`, US Cloud). Its public project
token is now in this worktree's ignored `apps/mobile/config/release.local.json`
with host `https://us.i.posthog.com`. Do not copy the token into tracked specs.
Build 14 still contains the empty-token configuration used for its archive;
this local change affects only a later build made with this worktree's config.

The live privacy policy and published App Store Connect privacy answers have
not been updated for an analytics-enabled build. The future-build policy copy
and data-type review below remain open before App Review submission. Confirm
the final archive's PostHog settings, SDK privacy manifest, and actual event
payloads before filing the answers.

The next source candidate also adds `plan_catalog_load` with fixed success or
failure categories to diagnose missing plans. It sends only when analytics is
enabled; a fixed reason code is also written to the local device log on failure.
The PostHog SDK uses an anonymous distinct ID even without person profiles, so
do not describe these events as identifier-free. Review SDK-added device and
network properties in the final archive and disclose the relevant diagnostic,
usage, and identifier types in App Store Connect as applicable.

## Release 2.0 recheck — 2026-10-01 (open)

The declaration below describes the published Build 11/12 state, **not** the
current Release 2.0 source. Release 2.0 adds an optional, default-off
`Anonymous analytics` control. When the person enables it and a PostHog project
is configured, the app can send coarse product-use and settings-action events.
The payload contract excludes account IDs, readable health records, cycle
dates, symptoms, notes, and Care details. Consent withdrawal opts out and clears
the pending event queue. Production PostHog settings must not be changed as a
shortcut for this disclosure review.

The live policy at `https://letterwithin.app/privacy` was read on 2026-10-01.
Its `Can leave your device` list omits optional product analytics, while its
`Stays on your device` list says app settings stay on-device without qualifying
the analytics setting-action event. Before submitting the Release 2.0 app for
review, publish matching policy language and update the App Store Connect App
Privacy answers for the actual production build. Recheck the live page and
declaration after publishing; this document is not proof that either changed.

Suggested policy copy for the website owner:

> App analytics and diagnostics are off unless you turn them on in Settings. If
> you opt in, Letter Within sends limited feature-use, settings-action, and
> reliability events to PostHog to help us find problems such as plans failing
> to load. These events use a random app identifier but do not include your
> account ID, period dates, symptoms, notes, Care details, or readable health
> records. Turning analytics off stops future
> collection and clears events waiting to be sent from this device. Your
> settings are stored on your device; when analytics is on, an event may report
> that analytics was enabled or that Screen Cover changed. The Screen Cover
> event does not send the setting's value or your health data.

Website source is outside this release worktree at
`/Users/clairehou/pyProjects/letter-cycle-companion/src/routes/privacy.tsx`;
`/Users/clairehou/pyProjects/letter-cycle-companion/WEBSITE_REDESIGN_HANDOFF.md`
is its website handoff. This is a prepared copy change, not a published edit.

App Store Connect answers require a fresh data-type, purpose, linkage, and
tracking review against the exact configured PostHog SDK and privacy manifest.
Inspect automatic SDK/device fields and transport metadata before adopting the
suggested policy wording as final legal copy.
Do not assume that the historical "PostHog dormant" declaration below still
describes the next archive.

## Historical published declaration — 2026-09-25

Status: published in App Store Connect on 2026-09-25.

Apple requires a privacy policy URL and answers covering the app and integrated
third-party partners. The attached review candidate is `1.0.0+12`; PostHog
remains integrated but dormant.

## Policy URLs

- Privacy Policy URL: `https://letterwithin.app/privacy`
- Optional User Privacy Choices URL: omitted because the proposed
  `https://letterwithin.app/account-deletion` route returns 404.

The privacy policy route is public and states that readable health records
remain encrypted on-device; Supabase handles account identity and RevenueCat
handles subscription entitlement.

## Proposed collected data types

### Contact Info — Email Address

- Collected: yes
- Purpose: App Functionality
- Linked to identity: yes
- Used for tracking: no
- Basis: email magic-link authentication in Supabase Auth.

### Identifiers — User ID

- Collected: yes
- Purpose: App Functionality
- Linked to identity: yes
- Used for tracking: no
- Basis: the Supabase UUID identifies the account and is also used as the
  RevenueCat App User ID.

### Purchases — Purchase History

- Collected: yes
- Purposes: App Functionality and Analytics
- Linked to identity: yes
- Used for tracking: no
- Basis: RevenueCat validates receipts, provides entitlement state, and uses
  purchase information in its customer history and aggregate dashboard. The
  custom RevenueCat App User ID is tied to the Supabase account.

## Proposed not-collected data types

- Health & Fitness: readable cycle, symptom, Care, mood, note, and report data
  remain in the local encrypted database and are not sent to the operational
  services.
- Financial Information: Apple processes payment; the app does not receive
  payment-card details.
- Location, Contacts, Photos or Videos, Browsing History, Search History,
  Sensitive Info, and Advertising Data: no collection path was found.
- Device ID for advertising and tracking: no IDFA use or cross-app tracking was
  found.

## Analytics and diagnostics finding

Build 11 embeds the PostHog SDK and its privacy manifests, but product analytics
are not active in this release:

- the release configuration has no PostHog project token;
- `com.posthog.posthog.AUTO_INIT` is `false` in the archived app;
- the app forces `AnalyticsConsent.optedOut` and exposes no release control
  that can grant consent;
- lifecycle events and session replay are disabled in the adapter.

The embedded SDK manifests nevertheless declare potential Product Interaction,
Other Usage Data, Crash Data, and Other Diagnostic Data collection. The owner
has chosen to retain PostHog for a future release. For version 1.0 it must remain
unconfigured and opted out, so the proposed label is based on actual collection
and does not add those dormant categories.

Before any future release activates PostHog:

1. add an explicit consent control that defaults off;
2. keep health values, cycle dates, notes, report contents, and inferred health
   state out of events, properties, logs, replay, and diagnostics;
3. update the public privacy policy and App Store privacy answers before that
   build is submitted; and
4. re-review the Xcode privacy report and the exact PostHog configuration.

App Store Connect now shows the narrower 1.0 label as published. The published
label declares Email Address, User ID, and Purchase History as collected and
linked to the user; none are used for tracking. Email Address and User ID are
used for App Functionality. Purchase History is used for App Functionality and
Analytics. The dormant PostHog SDK remains embedded and must stay unconfigured,
auto-init disabled, and forced opted out for this release.

## Evidence checked on 2026-09-24

- `apps/mobile/lib/features/auth/data/supabase_auth_service.dart`
- `apps/mobile/lib/features/entitlement/data/revenue_cat_entitlement_repository.dart`
- `apps/mobile/lib/features/analytics/data/posthog_analytics_service.dart`
- `apps/mobile/lib/app/letter_app.dart`
- build 11 archive `Info.plist` and embedded SDK `PrivacyInfo.xcprivacy` files
- release configuration key presence (values were not printed or recorded)
- Apple App Store Connect App Privacy guidance
- RevenueCat Apple App Privacy guidance
- Supabase Auth user documentation

The App Store Connect accuracy/compliance confirmation was completed when the
declaration was published on 2026-09-25.
