# Lovable UI Redesign Handoff

Status: design-lab reference

The production Flutter MVP is the source of truth for behavior, data,
navigation, privacy, accessibility, and safety. Lovable may explore visual
design only. Do not add backend services, authentication, analytics, new data,
or health claims.

## First implementation batch

Build only the shared design-system foundation and the low-risk shell/utility
family:

- app shell and five-tab navigation
- onboarding and privacy/You surfaces
- local backup and export surfaces
- loading, empty, failure, disabled, and in-progress variants for those screens

Do not redesign Today, Cycle, Letters, capture flows, data visualizations, or
Care activities in this batch. Pricing, subscription, entitlement, and
locked-premium surfaces are also deferred. They may appear only as inert
navigation destinations or placeholders needed to demonstrate the shell.

## Navigation contract

The bottom navigation order and meaning must remain unchanged:

1. Today
2. Cycle
3. Care
4. Letters
5. You

The production implementation is index-based in
`apps/mobile/lib/features/onboarding/presentation/privacy_center_screen.dart`.
Do not change route meaning, stack behavior, back behavior, or which actions
open sheets versus pages.

## Current visual tokens

Source: `apps/mobile/lib/design_system/letter_theme.dart`.

- canvas: `#FAF9F6`
- surface: `#FFFFFF`
- ink: `#252626`
- muted: `#687278`
- line: `#E3E4E1`
- teal: `#176D67`
- teal dark: `#155D59`
- teal soft: `#E4F2EF`
- safety red: `#B42318`
- semantic accents: coral, clinical blue, amber, violet
- display/ritual type: Newsreader
- control/body type: platform sans-serif
- spacing: 4, 8, 12, 16, 20, 28
- radii: 7px controls, 8px panels
- motion: 100ms instant, 180ms responsive, 500ms ritual
- elevation: one soft shadow, reserved for focal objects

The Lovable prototype's editorial paper-and-ink language may refine these
tokens, but semantic colors must retain their meaning. Observed, estimated,
severity, destructive, and safety states are never communicated by color alone.

## Existing reusable Flutter primitives

- `LetterBottomNavigation`
- `LetterEyebrow`
- `LetterSectionTitle`
- `LetterColors`
- `LetterSpacing`
- `LetterRadius`
- `LetterMotion`
- Material theme overrides for dialogs, date pickers, chips, switches,
  progress indicators, and app bars

The Lovable design should specify reusable equivalents rather than inventing
new cards, buttons, sheets, or section headers per screen.

## First-batch source screens

- `apps/mobile/lib/app/letter_app.dart`
- `apps/mobile/lib/features/onboarding/presentation/onboarding_flow.dart`
- `apps/mobile/lib/features/onboarding/presentation/privacy_center_screen.dart`
- `apps/mobile/lib/features/local_backup/presentation/local_backup_screen.dart`
- `apps/mobile/lib/features/summary_export/presentation/summary_export_screen.dart`
- `apps/mobile/lib/design_system/letter_bottom_navigation.dart`

Visual references:

- `apps/mobile/test/goldens/onboarding_privacy_390x844.png`
- `apps/mobile/test/goldens/summary_export_390x844.png`
- `apps/mobile/test/goldens/today_390x844.png` (shell reference only)

Pricing/entitlement references are intentionally excluded until the product
pricing and entitlement model is redesigned.

## Protected Care boundary

Care activities are already designed. Do not alter their core visuals,
animation, sound, haptics, timing, breathing interaction, safety copy, or exit
rules. In this first batch, Care is limited to its existing tab destination and
entry representation in the shared shell. Do not edit any file under
`apps/mobile/lib/features/care/` or any Care audio asset.

## Required responsive states

Each first-batch archetype must demonstrate:

- 390x844 baseline and 320px width
- default text and 200% text scaling
- light appearance
- reduced motion
- empty, loading, failure, disabled, and in-progress states where applicable
- keyboard/screen-reader labels and 44x44 minimum tap targets
- no horizontal page scrolling and no fixed-height text containers

## Acceptance gate

- No product behavior, navigation, validation, copy meaning, or data contract
  changes.
- No cloud persistence, authentication, analytics, or inferred health insight.
- No pricing, subscription, entitlement, purchase, or locked-premium changes;
  those are deferred to a separate product decision.
- One shared implementation for shell, buttons, cards, sheets, fields, tags,
  empty states, and safety notes.
- No hardcoded colors, radii, shadows, or typography in screen code.
- Care activity internals remain untouched.
- The result is a visual prototype and component specification suitable for
  deliberate porting into Flutter; generated Flutter is not merged directly
  into production.
