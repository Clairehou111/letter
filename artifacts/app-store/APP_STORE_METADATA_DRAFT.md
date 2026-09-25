# App Store metadata draft

Status: submitted to App Review on 2026-09-25. After an automated 3.1.2
metadata rejection, the Standard Apple EULA link was added to the App
Description and the same five-item package was resubmitted. All five items now
show `Waiting for Review`.

This draft matches the approved ten-frame screenshot set and the United States
+ Canada launch boundary. Build `1.0.0+12` is attached to version 1.0. The
listing copy and stable URLs below are saved. App version 1.0 and all four paid
product items are in the same five-item submission.

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

Terms of Use (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
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

Saved as `2026 Xiaoneng Hou`, using the owner-confirmed Pinyin legal name.

## App-level release settings

- App price: free (`US$0.00`). The monthly, yearly, and lifetime Plus products
  remain separately priced as listed below.
- App availability: United States and Canada only (`2 of 175`).
- Distribution: public App Store distribution.
- Apple silicon Mac availability: off for the iPhone-only first release.
- Apple Vision Pro availability: off for the iPhone-only first release.
- Apple School Manager reduced-price option: off.
- Version release: manual after App Review approval.
- Content rights: the app does not contain, show, or access third-party content.
- Primary category: `Health & Fitness`; no secondary category.
- Regulated medical device declaration: no.
- Age rating questionnaire: Health or Wellness Topics = Yes; Medical or
  Treatment Information = None; all other capabilities/content answers are
  No or None. App Store Connect calculated 9+ in 172 countries or regions,
  with regional exceptions (12+ in Brazil and Vietnam, All in Korea).

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
lifetime purchase, the subscription group, both subscriptions, and app version
1.0 were added to one five-item App Store Connect submission. The initial
submission received an automated 3.1.2 metadata rejection because its public
description lacked a functional Terms of Use link. The Standard Apple EULA
link was added and saved, and submission
`71fb461c-dead-493a-bc4f-f8ade898b693` was resubmitted on 2026-09-25. All five
items now show `Waiting for Review`.

## Remaining pre-release checks

1. Complete the Canada/privacy/subscription legal review before public release.
2. Correct the public Support page's stale iPhone/Android “coming soon” copy.
3. Monitor App Store Connect for Apple review questions or a status change.

Version 1.0 uses Apple's Standard EULA. No custom `/terms` route is required
for this submission.

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
