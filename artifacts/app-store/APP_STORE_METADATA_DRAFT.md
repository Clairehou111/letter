# App Store metadata draft

Status: entered and saved in App Store Connect on 2026-09-25, except for the
copyright field, which still requires the confirmed legal rights holder.

This draft matches the approved ten-frame screenshot set and the United States
+ Canada launch boundary. Build `1.0.0+12` is attached to version 1.0. The
listing copy and stable URLs below are saved. This does not authorize adding
the app version to the review draft or submitting the draft for review.

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
- Optional privacy choices URL: omit for 1.0; the proposed
  `https://letterwithin.app/account-deletion` route currently returns 404.

The Privacy and Support routes were verified live on 2026-09-25. The Support
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
and are mapped to the RevenueCat `letter_plus` entitlement. On 2026-09-25 the
lifetime purchase, the subscription group, and both subscriptions were added
to one App Store Connect review draft. The draft has not been submitted.

## Blocking owner decisions

1. Confirm the legal rights holder for Copyright.
2. Confirm whether version release should be manual. App Store Connect is
   currently set to automatic release; manual release is safer for a first
   launch.
3. Publish the fully configured App Privacy declaration after final
   owner/legal approval.
4. Complete the Canada/privacy/subscription legal review before submission.
5. Confirm the applicable Terms of Use/EULA treatment for the two
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
