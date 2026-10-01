# Release 2.0 UI fix follow-up — 2026-10-01

## Scope and method

- Source: `letter-main` local `main`, current Simulator debug builds. No TestFlight or App Store build was created.
- Runtime: iOS 26.5 Simulator. iPhone 17 (1206 × 2622) and iPhone 17e (1170 × 2532) used system `large` content size, the default text category. iPhone 17 Pro Max (1320 × 2868) used `large`; iPhone SE (3rd generation) used `accessibility-large` for the Patterns stress check.
- All entered or seeded health, Care, and report data was synthetic. The iPhone 17 formal app retained the existing system-acceptance synthetic fixture. Standalone capture frames came from `apps/mobile/tool/manual_qa_app.dart` and render production screen widgets with in-memory fixtures. Their surrounding navigation is a test shell and must not be treated as the shipped app shell.
- The shared worktree advanced during verification. These images are visual and behavioral checks, not a pixel-exact comparison of one frozen binary across every device. The Pro Max Patterns before/after pair uses the same capture frame and data.

## Synthetic data and steps

1. On iPhone 17, launch `lib/main.dart` as a debug app. Check Today, tap the settings gear, inspect You and the Care companion helper, open Clinician reports, then tap the locked six-month range to inspect Plus. Return to Today, open **Add a symptom**, switch to Cycle, then open Care and **Your comfort kit**. The formal app has four tabs: Today, Cycle, Care, Patterns. The retained acceptance fixture includes synthetic periods and the authored Kit entries “Warmth and rest,” “Sweet & Space,” and “Synthetic future note 2026-09-30.”
2. On iPhone 17 and 17e, render the independent `report` frame with four synthetic cycle starts (June 20, July 19, August 16, September 15), synthetic symptom rows, one **Irritable** check-in, and one synthetic reflection. Check the shortened Reports introduction and range rows. This frame does not validate the formal app's navigation.
3. On iPhone 17e, render `care-memory` with two synthetic **better** records for “Rest into support” (September 20 and 22), and `tracker-cycle` with synthetic period starts May 23, June 20, July 19, August 16, and September 15. Check normal-size text and the ring. The first Cycle image taken about two seconds after launch had a transient square drawing artifact; a delayed relaunch image below did not. Lower Cycle actions extend below the captured viewport.
4. On iPhone 17 Pro Max, compare the Patterns capture frame before and after the large-text fix using the same four completed synthetic cycles. On SE at `accessibility-large`, check the compact header and horizontal tabs; the associated widget test also drags to the end of the header and switches tabs at 320 × 568 and 3.2× text.

## Screenshots

| Surface | Evidence |
| --- | --- |
| Formal iPhone 17 Today and four-tab shell | [Today](screenshots/normal-17-formal-shell.png) |
| Formal iPhone 17 Cycle and ring | [Cycle](screenshots/normal-17-formal-cycle.png) |
| Formal iPhone 17 Comfort Kit, authored entries visible | [Comfort Kit](screenshots/normal-17-formal-comfort-kit.png) |
| Formal iPhone 17 Plus sheet | [Plus](screenshots/normal-17-formal-plus.png) |
| Formal iPhone 17 You field and helper | [Settings](screenshots/normal-17-formal-settings-care-name.png) |
| Formal iPhone 17 symptom browser | [Symptom sheet](screenshots/normal-17-formal-symptom-picker.png) |
| Reports production widget in synthetic capture frame | [iPhone 17](screenshots/normal-17-report.png), [iPhone 17e](screenshots/normal-17e-report.png) |
| Care production widget in synthetic capture frame | [iPhone 17e](screenshots/normal-17e-care-memory.png) |
| Settled Cycle production widget in synthetic capture frame | [iPhone 17e](screenshots/normal-17e-tracker-cycle-settled.png) |
| Patterns before/after, same Pro Max frame and data | [Before](screenshots/promax-patterns.png), [After](screenshots/fixed-promax-patterns.png) |
| Patterns on SE with larger text | [SE](screenshots/fixed-se-large-patterns.png) |

## Result and limits

- No new normal-text truncation or overlap was found on the checked surfaces. The Pro Max Patterns content is visually unchanged apart from status-bar time. The iPhone 17e Cycle artifact did not persist after the screen settled.
- Reports' visual summary uses difficult Today check-ins. The raw CSV intentionally retains every check-in in the selected range; the synthetic Reports frame contains only one Irritable check-in.
- The Plus store-unavailable copy and legal-link behavior passed the 390 × 844 widget test, but this exact error state was not captured in a native Simulator screenshot. The native Plus screenshot shows the available-plans state. No purchase or restore transaction was attempted.
- `flutter analyze --no-pub`: no issues. `flutter test --no-pub --concurrency=4 -r compact`: 679 passed, one existing skip. `git diff --check`: clean.
- These checks finish the requested Simulator UI fix follow-up. Qualified clinical review, public privacy-policy/App Store declaration alignment, physical-device purchase/restore validation, and App Store submission remain separate release tasks.
