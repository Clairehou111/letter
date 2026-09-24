# App Store metadata draft

Status: ready for owner review; not entered in App Store Connect.

This draft matches the approved ten-frame screenshot set and the United States
+ Canada launch boundary. Build `1.0.0+11` is uploaded, but the intended review
candidate is now build 12 after its auth changes and provider configuration are
verified. This does not authorize saving, publishing, attaching a build or
products, or submitting for review.

## Product identity

- App name: `Letter Within: Period Care`
- Subtitle (29/30): `Private cycle care & tracking`
- Primary category: `Health & Fitness`
- Secondary category: leave blank unless the owner explicitly chooses one.

## Version 1.0 listing

### Promotional text

```text
Cycle care for the days that feel heavier. Track periods and symptoms, see patterns across cycles, and prepare a clear report—without AI.
```

### Description

```text
Letter Within is a private period companion and tracker for the days that feel heavier.

CARE FOR THE MOMENT
Choose a gentle Care scene when you feel heavy, restless, flooded, low-energy, or need space. Leave at any time. Care is never locked behind Plus.

TRACK MORE THAN DATES
Record bleeding, color, cramps, symptoms, mood, energy, and notes. Edit any day and see each cycle in one clear history.

SEE PATTERNS, WITH THE EVIDENCE VISIBLE
Compare cycles and harder days using the observations you saved. Missing days stay missing—Letter Within does not guess or diagnose.

PREPARE FOR A CLINICIAN CONVERSATION
Create a bounded summary or report from your own records and choose what to export or share.

REMEMBER WHAT HELPED
Optional check-backs help you keep the actions that supported you and leave the rest.

PRIVATE BY DESIGN
Readable health records stay encrypted on your device. Letter Within does not use AI. Account access and subscription entitlement use operational services, but your readable cycle, symptom, Care, and note records are not uploaded with sign-in.

Letter Within is supportive software, not a medical device. It does not diagnose, treat, or provide emergency care.
```

### Keywords

```text
period tracker,cycle tracker,PMS,PMDD,symptoms,mood,cramps,flow,cycle care,period report
```

### URLs

- Support URL: `https://letterwithin.app/support`
- Marketing URL: `https://letterwithin.app`
- Privacy Policy URL: `https://letterwithin.app/privacy`
- Optional privacy choices URL: `https://letterwithin.app/account-deletion`

The Privacy and Support routes were verified live on 2026-09-24. The Support
page still says iPhone and Android are both coming soon; update that site copy
before public launch, but keep the stable `/support` URL.

### Copyright

Enter `2026 [legal rights holder]` only after the owner confirms the legal
person or entity that owns the app. Do not guess this field.

## App Review notes draft

```text
Letter Within requires sign-in for account access and subscription entitlement. Readable health records remain encrypted on the device and are not restored by sign-in.

REVIEW ACCESS
Tap "Use a password instead" and sign in with the dedicated App Review account below.
Username: [enter only in App Store Connect]
Password: [enter only in App Store Connect]

Customers normally create or access accounts with Sign in with Apple or an email magic link. The password account is a stable existing account supplied so review does not depend on access to an email inbox.

SUGGESTED REVIEW PATH
1. Sign in and complete onboarding with synthetic information.
2. Today: add bleeding, color, and symptoms.
3. Cycle: open a saved date and edit its details.
4. Patterns: review Cycles & bleeding, Mood & patterns, and What helped.
5. Reports: create a Cycle & Care Summary and export it locally.
6. Settings: open Backup & restore and create a password-protected export.

PURCHASES
Letter Within Plus has monthly, yearly, and one-time lifetime options. Plus unlocks continuing patterns, preparation, and extended reports. Care, safety, tracking, predictions, backup, and raw export remain free.

SAFETY AND SCOPE
Letter Within does not use AI. Pattern text and cycle estimates are deterministic and run on-device. The app is supportive software, not a medical device; it does not diagnose, treat, or provide emergency care.
```

## Paid products to attach to version 1.0

| Product | Apple ID | Type | US price |
| --- | --- | --- | --- |
| `letter_monthly` | `6800577122` | Auto-renewable monthly | US$6.99/month |
| `letter_yearly` | `6800577443` | Auto-renewable yearly | US$29.99/year |
| `letter_lifetime` | `6800577621` | Non-consumable lifetime | US$79.99 one time |

All three are configured for United States + Canada, have review screenshots,
and are mapped to the RevenueCat `letter_plus` entitlement. Attaching them or
clicking `Add for Review` requires explicit owner approval.

## Blocking owner decisions

1. Confirm the legal rights holder for Copyright.
2. Configure and verify the Supabase Apple provider, then enable
   `LETTER_APPLE_SIGN_IN_ENABLED` for build 12. The iOS entitlement and app UI
   already exist, but the provider currently reports disabled.
3. Create one dedicated password-based App Review account and put its
   credentials only in App Store Connect. Build 12 code now supports this
   existing-account fallback; it intentionally does not add public password
   signup without verification and recovery UX.
4. Confirm whether version release should be manual. App Store Connect is
   currently set to automatic release; manual release is safer for a first
   launch.
5. Complete and publish App Privacy using the separate code-backed draft.
6. Complete the Canada/privacy/subscription legal review before submission.
7. Confirm the applicable Terms of Use/EULA treatment for the two
   auto-renewable subscriptions. No public `/terms` route exists today.

## Complimentary access after launch

- Small private group: grant `letter_plus` to the authenticated RevenueCat
  customer ID for a fixed duration or lifetime. This is operational data, not
  an App Store purchase, and can be revoked from the customer profile.
- Public campaign: create Apple offer codes after the app and products are
  approved. Apple supports free or discounted codes for subscriptions and
  in-app purchases, including one-time-use codes for targeted distribution.
- Pre-launch friends and testers: continue using TestFlight; StoreKit purchases
  there use the sandbox and do not charge the tester.

Do not add a hard-coded email whitelist to the binary.
