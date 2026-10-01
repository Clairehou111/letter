# App Privacy declaration draft

## 2026-10-02 configured next-candidate state

The owner kept the optional Anonymous analytics control and SP6/LV3 guidance.
The previously empty PostHog project in the LetterHealth organization was
renamed **Letter Within** (project ID `534876`, US Cloud). Its public project
token is now in this worktree's ignored `apps/mobile/config/release.local.json`
with host `https://us.i.posthog.com`. Do not copy the token into tracked specs.
Build 14 still contains the empty-token configuration used for its archive;
this local change affects only a later build made with this worktree's config.

App Store Connect App Privacy was updated and published on 2026-10-02 for the
next analytics-enabled build. It now lists eight types: the existing Email
Address, User ID, and Purchase History, plus Coarse Location, Device ID,
Product Interaction, Other Usage Data, and Other Diagnostic Data. All five new
types are marked linked under Apple's account/device/details test, and not
used for tracking. This label does not claim that a real-world name or account
is attached to PostHog events. Coarse Location, Device ID, Product Interaction,
and Other Usage Data are marked for Analytics; Other Diagnostic Data is marked
for App Functionality. The published page was reread after the changes and
showed no pending setup items. No build or App Review submission followed.

The website's latest redesign source is
`/Users/clairehou/pyProjects/letter-cycle-companion/src/routes/privacy.tsx`.
Its optional analytics paragraph now uses the shorter phrase “basic technical
information” and does not call out IP address or region in user-facing copy.
The redesigned privacy page was subsequently merged to website `main` at
`79005b0`. The live URL must be rechecked before the next App Review
submission; a repository commit alone does not prove the live policy is
current. Recheck the final archive's PostHog settings, SDK privacy manifest,
and an opted-in sample event before submitting it.
Website commit `7f1f8cb` was pushed from an isolated pre-redesign checkout; it
updates privacy copy but is not the latest redesigned page. Do not treat that
commit or a deployment of it as acceptance of the website redesign.

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
It then omitted optional product analytics. The App Store Connect declaration
was published on 2026-10-02 as described above. The latest website redesign
privacy page is now in website `main`; the owner will verify the live page
before the next App Review submission.

Suggested policy copy for the website owner:

> The Help improve Letter Within setting is off until you turn it on. If
> enabled, the app sends limited app-use and error-category events to PostHog
> to help us improve the app and investigate problems. This can include a broad
> Care-use count. Events carry a random app identifier and basic technical
> information, but no account ID or readable health records. Turning the
> setting off stops new events and clears those waiting on your device. Contact
> us to request deletion of events already sent. We do not use analytics for
> advertising or session recording.

Website source is outside this release worktree at
`/Users/clairehou/pyProjects/letter-cycle-companion/src/routes/privacy.tsx`;
`/Users/clairehou/pyProjects/letter-cycle-companion/WEBSITE_REDESIGN_HANDOFF.md`
is its website handoff. The redesign file and copy are in website `main`;
production verification remains with the website owner.

The five new App Store Connect types were marked linked because Apple includes
device-based linkage in that field, the configured PostHog project does not
discard IPs, and its anonymous distinct ID persists across events. This does
not mean the app sends an account ID or real-world name to PostHog. Inspect an
actual opted-in event and the final archive's SDK/device fields before treating
these answers as final for that archive. The historical
"PostHog dormant" declaration below does not describe the next archive.

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
