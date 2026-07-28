# Flutter UI Fidelity Spike Validation

## Automated

| Requirement | Validation |
| --- | --- |
| REQ-001, REQ-008 | Widget tests at 320, 390, and 412 logical-pixel widths |
| REQ-002 | State selector contains balanced options and supports selection |
| REQ-003 | Symptom and severity selection behavior test |
| REQ-004 | Pain selection exposes and selects multiple locations |
| REQ-005 | Navigation order and centered Today semantics test |
| REQ-006 | Care sheet opens, offers actions, and dismisses |
| REQ-007, REQ-010 | Analyzer passes and UI uses shared Letter components/tokens |
| REQ-008 | 200% text-scale overflow test |
| REQ-009 | Semantics labels and minimum touch dimensions test |

Required commands:

- `dart format --output=none --set-exit-if-changed lib test`
- `flutter analyze`
- `flutter test`

## Visual

Capture:

- React reference at 390x844
- Flutter rendering at 390x844
- Flutter rendering at 412x915
- Flutter narrow-width rendering at 320x700

Review:

- typography hierarchy
- spacing rhythm and alignment
- modern, coherent controls
- state and severity clarity
- bottom-navigation stability
- sheet composition and supportive tone
- clipping, overlap, overflow, or blank regions

## Merge Gate

The spike is accepted because:

- all automated checks pass
- required screenshots contain no overflow or overlap
- Flutter is visually comparable to the React reference
- reusable components do not require disproportionate custom rendering
- the user approved Flutter after reviewing the result

Native iOS and Android simulator validation remains required during production
foundation work because the current machine lacks both native SDKs.

## Validation Result

Status: validated; Flutter approved by the user

Tooling:

- Flutter 3.44.8
- Dart 3.12.2
- Chrome release-web rendering for visual comparison
- Xcode installation incomplete
- Android SDK unavailable

Automated results:

- `dart format --output=none --set-exit-if-changed lib test`: passed
- `flutter analyze`: passed with no issues
- `flutter test`: 6 tests passed
- `flutter build web --release`: passed
- 320 logical-pixel width at 200% text scale: passed without overflow

Visual results:

- 390x844 release rendering: passed
- 412x915 release rendering: passed
- 320x700 release rendering: passed
- Care sheet composition: passed
- multiple pain locations and severity state: passed
- no clipping, overlap, or blank release-rendering regions observed

The Flutter debug web module loader stalled before mounting at 320px in one
headless capture. The release build rendered correctly at the same viewport,
and widget tests passed. This is recorded as a debug-tooling limitation rather
than a product-layout pass-through.

Comparison:

- Flutter reproduces the React reference's editorial hierarchy, deep-teal cycle
  card, compact care controls, balanced state palette, and stable navigation.
- Bundled Newsreader typography removes platform-dependent serif substitution.
- The implementation uses one small custom painter for the cycle ring; the rest
  uses maintainable Flutter composition without a large UI package.

Recommendation:

> Accept Flutter as the mobile framework if the user approves the final
> screenshots. Require native iOS and Android simulator validation during
> production workspace foundation before merging the first product feature.

Evidence is stored locally under `artifacts/ui-fidelity/`, including:

- `react-today-390x844.png`
- `flutter-final-390x844.png`
- `flutter-final-412x915.png`
- `flutter-final-320x700.png`
- `flutter-final-care-390x844.png`
- `flutter-final-pain-390x844.png`
