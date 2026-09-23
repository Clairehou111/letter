# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

## Users

Letter Within is for people who menstruate, especially people navigating PMS or
PMDD and days when emotional or physical symptoms feel heavier. The primary job
is to notice what is happening, get appropriate in-the-moment care, understand
patterns across cycles, and bring a clear personal record into a clinician
conversation when useful.

## Product Purpose

Letter Within is a private period companion and tracker. It combines cycle and
symptom tracking with gentle care experiences, personal pattern summaries, and
clinician-ready reports. Success means the product is useful both in a difficult
moment and later, when the user is preparing for another cycle or explaining
their experience to a care professional.

## Positioning

The two primary launch promises are:

1. **Cycle care for the days that feel heavier.**
2. **Encrypted on your device. No AI.**

The product differentiates itself by treating care, reflection, pattern review,
and reporting as one private cycle-care loop. “No AI” is a permanent product
constraint, not a launch-only campaign claim.

## Operating Context

Users can record cycle dates, bleeding, symptoms, functional impact, check-ins,
and notes; use care exercises during difficult moments; review recurring
patterns across cycles; remember what helped; and create PDF or CSV material for
a clinician conversation. Launch marketing is for the United States and Canada.
Only synthetic data may appear in tests, demonstrations, or store screenshots.

## Capabilities and Constraints

- Readable health records are stored locally in an encrypted SQLCipher database;
  the encryption key is held in platform secure storage.
- Cycle and symptom interpretation is implemented with deterministic local code.
- The product does not send health records to an AI model and does not include
  AI-generated interpretations, suggestions, or summaries.
- Supabase is used for operational account and entitlement functions. RevenueCat
  receives the authenticated account identifier required for entitlements.
  Therefore public copy must not imply that absolutely no app data ever leaves
  the device.
- Health values, cycle dates, notes, report contents, and inferred health state
  must not enter analytics, logs, crash metadata, or cloud account records.
- The first App Store release is iPhone-only. Android remains a supported product
  platform, but the initial Apple binary does not target iPad.
- The product is supportive and evidence-aware, but is not a diagnostic tool,
  emergency service, or substitute for professional medical care.
- Patterns must communicate evidence quality and missingness rather than
  presenting false certainty.

## Brand Commitments

- Product name: **Letter Within**.
- Category language: **private period companion and tracker**.
- Voice: calm, intimate, supportive, precise, and non-judgmental.
- Lead with care and felt experience; support the promise with privacy and useful
  proof rather than fear-based messaging.
- Avoid generic “wellness app” language, surveillance language, diagnostic
  certainty, and fabricated authority.
- Launch screenshot captions are short, plain-language claims shown alongside
  real native app UI.

## Evidence on Hand

- Product and system specifications: `specs/`
- Flutter mobile application: `apps/mobile/`
- Current release handoff: `CODEX_HANDOFF_APP_STORE.md`
- Existing synthetic visual QA captures: `artifacts/`
- Public marketing site source:
  `/Users/clairehou/pyProjects/letter-cycle-companion`
- Public site: `https://www.letterwithin.app`
- There are no approved testimonials, customer counts, clinical outcome claims,
  or performance benchmarks. Future marketing must not fabricate them.

## Product Principles

1. Care before administration: be useful when a day feels heavy, not only when
   the user is logging data.
2. Privacy must be technically true and explained precisely.
3. No AI means no model calls, model-generated content, or dormant user-facing
   cloud-AI path in the shipped product.
4. Patterns should clarify lived experience without pretending to diagnose it.
5. Give users portable records and control over what they share.

## Accessibility & Inclusion

Use inclusive language for people who menstruate without assuming gender,
pregnancy intent, regular cycles, or access to a clinician. Native interfaces
must preserve platform safe areas, system navigation, Dynamic Type or font
scaling, reduced-motion preferences, and minimum touch-target guidance. Care and
safety language must remain understandable during high-distress moments.
