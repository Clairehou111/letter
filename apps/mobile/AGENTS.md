# Letter Mobile Instructions

Follow the repository `AGENTS.md` and the active feature specification.

## Stack

- Flutter stable with sound null safety
- Dart formatted with `dart format`
- Flutter analyzer with no ignored warnings
- Platform targets: iOS and Android
- Web is allowed only for development and visual validation; it is not the
  production product target.

## UI And Architecture

- Use a feature-first structure with separate presentation, domain, and data
  responsibilities when a feature contains meaningful logic.
- Keep product rules out of widgets.
- Use immutable models and explicit state transitions.
- Start with Flutter SDK capabilities; add packages only when they remove
  meaningful complexity.
- Define Letter design tokens for color, typography, spacing, dimensions,
  borders, and motion. Do not expose unthemed default Material widgets as the
  product design.
- Use platform-adaptive behavior for navigation, sheets, pickers, switches,
  text input, safe areas, scrolling, and haptics.
- Preserve accessibility semantics, dynamic text sizing, contrast, and a
  minimum 44 logical-pixel touch target.
- Prevent layout shifts and text overflow at supported phone widths.

## Privacy

- Store health records only in the encrypted local data layer.
- Never log health values or free text.
- Network transmission requires a purpose-specific consent boundary defined by
  the feature specification.

## Validation

- Run `flutter analyze`.
- Run `flutter test`.
- Add widget tests for behavior and semantics.
- Add golden tests for stable, representative screens.
- Capture screenshots at approved iPhone and Android viewport sizes.
- A browser screenshot does not count as native simulator validation.

