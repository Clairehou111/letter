# Authentication And Subscription Entitlement Validation

Status: in_progress (Android and iOS Supabase email sign-in plus RevenueCat Test
Store billing/restore pass; production SMTP is verified, while Apple auth,
failure-state validation, and real stores remain)

- [x] A first-install signed-out state is held behind the auth gate; the
  focused `LetterApp` gate test passes.
- [x] Apple and email magic-link entry points are implemented; Apple is shown
  only when its provider-ready build flag is enabled.
- [x] A returning prior-auth user in `offlineOrExpired` state can open local
  data without reopening the sign-in gate.
- [x] Explicit sign-out closes the local-data gate without deleting records.
- [x] Account deletion copy and behavior distinguish server deletion from local
  health-data deletion.
- [x] Auth state contains account identity metadata only; no health data is
  carried by the auth boundary.
- [x] Configured production application wiring enables the auth gate; mobile
  release builds fail closed when required public Supabase or RevenueCat values
  are absent.
- [x] Supabase email auth is enabled, `app.letterwithin://login-callback` is an
  allowed redirect, and the deployed `delete-account` function rejects a
  missing bearer token with HTTP 401.
- [x] Supabase Auth logs identify repeated iOS initiation failures as HTTP 429;
  the default mailer is capped at two auth emails per hour. Letter Within now maps 429
  to a specific wait-and-retry message without exposing provider details.
- [x] Supabase production SMTP is configured with Resend and a branded sender
  on `letterwithin.app`; DKIM, SPF, and return-path MX records resolve publicly,
  and Resend reports the domain verified and ready to send.
- [ ] Revalidate live email delivery, callback completion, and production rate
  limits on iOS before release.
- [x] Android email magic-link return creates the authenticated account state
  and opens onboarding without uploading health records.
- [x] A real iOS magic-link callback creates the authenticated account state
  and opens onboarding without uploading local health records.
- [x] A successful magic-link request disables immediate resubmission until the
  email address is edited, preventing accidental duplicate OTP emails.
- [ ] Enable and verify the Apple provider and validate authenticated account
  deletion.
- [x] Keep Apple sign-in hidden while the Supabase Apple provider is disabled.
  Enabling it requires the Apple App ID, Services ID/client ID, signing key and
  generated secret, plus the Supabase callback configuration.
- [x] The observed Apple `400 Unsupported provider: provider is not enabled`
  response is expected while the provider remains disabled.
- [x] Configured iOS and Android native launches reach the real Supabase auth
  gate while preserving the local-health-data boundary copy.
- [x] Android restores the real Supabase session after a process force-stop and
  cold relaunch.
- [x] Native builds disable Flutter's route parsing for auth callbacks so the
  Supabase app-links integration owns them; the rebuilt iOS callback launch
  returns to the auth screen without a named-route exception.
- [x] iOS restores the real Supabase session after app termination and a cold
  configured rebuild without requesting another sign-in email.
- [ ] Validate iOS native offline and expired-session failure behavior.
- [x] Local tracking and Care remain usable after a prior successful sign-in
  when the session is offline or expired.
- [ ] API payload inspection finds no readable health data.
- [x] RevenueCat adapter tests cover configured/unconfigured, purchase, restore,
  active, lapsed, offline-unknown, pending, failure, and cancellation states.
- [x] RevenueCat Test Store contains `letter_monthly`, `letter_yearly`, and
  `letter_lifetime`, attached to `letter_plus` through the current
  `letter_default` offering; the ignored local release config uses the public
  Test Store key on both native platforms.
- [x] Android Test Store validation completes a valid `letter_yearly` purchase,
  activates `letter_plus`, restores it explicitly, and preserves it after a
  process force-stop, cold relaunch, and rebuilt-app install.
- [x] iOS Test Store validation loads the localized monthly, yearly, and
  lifetime plans, recognizes the authenticated account's active `letter_plus`
  entitlement, and completes an explicit restore.
- [x] The RevenueCat dashboard retains the approved lifetime base price of
  `$79.99`; the Android Test Store SDK currently returns `$79.98` in its
  localized `priceString`, while real-store prices remain authoritative.
- [ ] Validate RevenueCat delayed purchase, expiry, grace, and offline behavior
  plus restoration against real App Store and Play sandbox products; those
  store products remain unconfigured.
- [x] No contact, message, or medication capability is introduced.
