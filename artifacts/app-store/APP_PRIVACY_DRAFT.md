# App Privacy declaration draft

Status: entered and fully configured in App Store Connect on 2026-09-25, but
not published. Final publication remains an owner/legal confirmation gate.

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

App Store Connect now shows the narrower 1.0 label ready to publish. Publishing
still requires owner/legal approval after reviewing the final build-12 privacy
report, because the dormant SDK manifests remain embedded.

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

Publishing App Privacy includes an accuracy/compliance confirmation in App
Store Connect. Stop before that confirmation unless the owner explicitly
approves the final answers.
