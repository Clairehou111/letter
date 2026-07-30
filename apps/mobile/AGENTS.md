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


## UI & Presentation Layer
- **Responsiveness**: Never hardcode static layouts. Always leverage `MediaQuery`, `LayoutBuilder`, or the `responsive_framework` package for fluid grid systems.
- **Theming**: Bind all colors, text styles, and component modifications to `Theme.of(context)`. Explicitly support dark and light theme variations.
- **Aesthetics**: Prioritize modern UI principles (smooth micro-interactions, explicit hover/focus states for desktop/web, clean card elevations, and custom `Sliver` animations for scroll views).
- **Optimization**: Proactively use the `const` constructor for widgets wherever possible to minimize unnecessary tree rebuilds.

## Dart & Code Quality
- **Type Safety**: Enforce strict type definitions for all methods, widget parameters, and callback arguments. Avoid using `dynamic`.
- **Formatting**: Always format trailing commas for nested widget arguments to ensure clean multi-line formatting.
- **State Management**: Structure presentation separation clearly. Use [Insert your choice: Riverpod / BLoC / Provider] for reactive bindings. Keep business logic completely outside of the view widgets.


## LLM Workspace Routing Strategy
- **DeepSeek V4 Pro**: Use exclusively for structural architecture, data mapping, local encrypted storage rules, state transition models, and writing widget/golden tests.
- **Kimi K3**: Use exclusively for building UI presentation widgets, styling design tokens, platform-adaptive behaviors, and visual micro-interactions.




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

