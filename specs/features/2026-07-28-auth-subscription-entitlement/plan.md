# Authentication And Subscription Entitlement Plan

Status: in_progress (Android email auth and RevenueCat Test Store purchase,
restore, and cold relaunch validated; production SMTP, Apple provider, iOS
sign-in/restore, and real stores pending)

1. [x] Define signed-out, authenticated, offline/expired-session, entitlement,
   and deletion states.
2. [x] Add the mobile Supabase Auth provider boundary, Apple and magic-link
   entry points, persisted prior-sign-in marker, and LetterApp auth gate.
3. [x] Enable Supabase email auth, configure the native redirect URL, and deploy
   the authenticated delete-account function.
4. [ ] Replace the test-only Supabase default mailer with production SMTP
   (host, port, username, password, and branded From address; domain
   authentication remains with the provider), enable Apple auth, verify iOS
   magic-link and session recovery, and validate authenticated account deletion.
   Android magic-link/session recovery passes; the default two-emails-per-hour
   limit was observed and now has specific privacy-safe UI handling.
5. [x] Add RevenueCat purchase, restore, pending, lapsed, offline-unknown,
   active-intro, and active-paid handling.
6. [x] Add local-first plans, store-localized pricing, restore/manage entry,
   and entitlement checks with no health upload.
7. [x] Configure the exact product, entitlement, and current-offering contract
   in the RevenueCat Test Store.
8. [ ] Validate account deletion, offline use, reinstall messaging, iOS restore,
   and billing failure/lifecycle states. Android Test Store purchase, restore,
   and cold-relaunch persistence pass.

## Implemented payment boundary

- RevenueCat receives the authenticated Supabase UUID supplied to the adapter;
  automatic device identifier collection and diagnostics are disabled.
- The entitlement id is `letter_plus`; product ids are `letter_monthly`,
  `letter_yearly`, and `letter_lifetime`.
- Store offerings provide localized labels when configured; the local adapter
  remains deterministic for tests and previews.
- Purchase and restore expose truthful pending, active-intro, active-paid, grace,
  lapsed, offline-unknown, and free states. Cancellation does not claim failure
  or grant access.
- Restore Purchases and provider-supplied subscription-management entry are
  exposed from the plans surface.

## External release gates

The RevenueCat Test Store and its public key are configured for native
validation. Real App Store/Play products and public keys, store agreements,
sandbox accounts, tax/banking setup, and native store lifecycle validation
remain pending.

## Implemented mobile auth slice

The mobile slice now includes:

- `SupabaseAuthService` for Supabase sessions, Apple OAuth, and email magic
  links.
- `AuthScreen` for the two approved first-install sign-in paths.
- `LetterApp` auth gating when `requireAuthentication` is enabled.
- A persisted prior-sign-in marker so an expired or unavailable session can
  still open existing local data.
- Explicit sign-out that returns to the signed-out gate without deleting local
  records.
- Account deletion through the `delete-account` Supabase function boundary;
  local health data remains a separate deletion action.

The default application wiring still leaves `requireAuthentication` disabled
for development/test compatibility. Configured builds enable the real Supabase
gate. Apple sign-in remains hidden until the Supabase provider is explicitly
configured with Apple App ID, Services ID/client ID, signing key/generated
secret, and callback settings. The Apple `400 Unsupported provider: provider is
not enabled` response is therefore expected while setup is incomplete. Native
redirect/session validation and real-store billing remain release gates.
