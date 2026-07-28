# Local Onboarding And Privacy Choices Validation

Status: validated with native plugin gate deferred

## Automated Requirement Coverage

| Requirement | Validation |
| --- | --- |
| REQ-001 | Widget tests cover unresolved loading, first launch, and returning launch |
| REQ-002 | Navigation tests cover progress, Back, Continue, 320 width, and 200% text |
| REQ-003, REQ-004 | Copy assertions verify product/privacy promises and prohibited claims |
| REQ-005 | Default-off and ask-each-time selection tests |
| REQ-006 | Zero, one, and multiple synthetic goal-selection tests |
| REQ-007 | Repository round-trip and serialized schema-version tests |
| REQ-008 | Load and save failure tests verify retry and no false completion |
| REQ-009 | Privacy-center update, confirmation, and reset tests |
| REQ-010 | Existing Today golden/behavior tests remain green; You navigation test |

## Required Commands

- [x] `dart format --output=none --set-exit-if-changed lib test`
- [x] `flutter analyze` - no issues
- [x] `flutter test` - 16 tests passed, including 9 onboarding tests
- [x] `flutter build web --release` - development smoke build passed
- [x] API tests - 6 tests passed
- [x] Ruff format/check and strict Pyright - passed
- [x] OpenAPI and generated-client drift checks - passed
- [x] foundation metadata and repository hygiene checks - passed

## Manual Review

Reviewed with widget constraints and golden coverage at representative phone
sizes:

- [x] promise is visible without marketing-style clutter
- [x] local-first privacy is understandable
- [x] cloud tools are off by default
- [x] no option resembles blanket cloud consent
- [x] goal choices are balanced and not diagnosis labels
- [x] controls remain reachable at 320-pixel width and 200% text scale
- [x] transition to Today has no wrong-screen flash or dead end
- [x] privacy center accurately reflects the saved preference

## Evidence And Limits

- `OnboardingProfileCodec` round-trips a versioned profile, including zero and
  multiple goals.
- Fake-repository tests cover unresolved loading, returning users, load/save
  failures, retries, updates, confirmation, and reset without platform channels.
- Production wiring uses `flutter_secure_storage`; Android backup is disabled
  and iOS Keychain entitlements are configured.
- The onboarding implementation has no API client dependency, network call, or
  health-value logging.
- Native Keychain/Keystore execution remains deferred until the release
  preparation gate because this environment does not have a complete iOS or
  Android toolchain. The web build is development smoke evidence only.

## Acceptance Gate

- [x] every locally available automated check passes
- [x] completion survives a repository reload in repository-backed tests
- [x] a failed save cannot enter the main app
- [x] no onboarding data is transmitted or logged
- [x] existing Today behavior and visual baseline remain intact
- [x] native plugin behavior is recorded in the deferred native release gate
- [x] no merge, push, or deployment occurred
