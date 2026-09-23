# Local Onboarding And Privacy Choices Validation

Status: validated; shared native secure-storage availability is evidenced,
while onboarding-profile restart and manual release review remain separate.
Cloud-preference checks below are retained only as historical evidence of the
original validation run; they are superseded by the permanent no-AI
requirements and current no-cloud-preference implementation.

## Automated Requirement Coverage

| Requirement | Validation |
| --- | --- |
| REQ-001 | Widget tests cover unresolved loading, first launch, and returning launch |
| REQ-002 | Navigation tests cover progress, Back, Continue, 320 width, and 200% text |
| REQ-003, REQ-004 | Copy assertions verify product/privacy promises and prohibited claims |
| REQ-005 | Historical cloud-preference tests; superseded and removed on 2026-09-24 |
| REQ-006 | Zero, one, and multiple synthetic goal-selection tests |
| REQ-007 | Repository round-trip and serialized schema-version tests |
| REQ-008 | Load and save failure tests verify retry and no false completion |
| REQ-009 | Privacy-center update, confirmation, and reset tests |
| REQ-010 | Existing Today golden/behavior tests remain green; You navigation test |
| REQ-011 | Current widget test opens and closes the explanation and verifies the permanent on-device/no-AI copy |

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
- [x] historical cloud-tool control removed; no AI/cloud-processing preference remains
- [x] goal choices are balanced and not diagnosis labels
- [x] controls remain reachable at 320-pixel width and 200% text scale
- [x] transition to Today has no wrong-screen flash or dead end
- [x] privacy center accurately states encrypted on-device storage and no AI processing

## Evidence And Limits

- `OnboardingProfileCodec` round-trips a versioned profile, including zero and
  multiple goals.
- Fake-repository tests cover unresolved loading, returning users, load/save
  failures, retries, updates, confirmation, and reset without platform channels.
- Production wiring uses `flutter_secure_storage`; Android backup is disabled
  and iOS Keychain entitlements are configured.
- The onboarding implementation has no API client dependency, network call, or
  health-value logging.
- The shared `flutter_secure_storage` platform path is exercised by the native
  encrypted-database key acceptance test on Android API 37 and an iPhone 17
  iOS 26.5 simulator, including process-restart persistence. That is evidence
  that Keychain/Keystore integration is available, not a native restart test
  of the separate onboarding-profile key. The web build remains development
  smoke evidence only; onboarding-profile restart, manual screen-reader,
  accessibility, target-user, and release checks remain separate.

## Acceptance Gate

- [x] every locally available automated check passes
- [x] completion survives a repository reload in repository-backed tests
- [x] a failed save cannot enter the main app
- [x] no onboarding data is transmitted or logged
- [x] existing Today behavior and visual baseline remain intact
- [x] shared native secure-storage behavior is recorded without claiming a
      native onboarding-profile restart test; that manual check remains open
- [x] no merge, push, or deployment occurred

## Privacy Explanation Amendment — 2026-08-07

- `See how privacy works` is visible from the onboarding privacy promise.
- The original explanation covered account/health-record separation, on-device
  health records, optional tools, and user-controlled backup/export/delete.
- The optional-tools control and its preservation test were subsequently
  removed under the permanent no-AI constraint below.
- The explanation remains scrollable and reachable at 320 logical pixels and
  200% text scale.
- Privacy-step and privacy-explanation golden baselines were reviewed at
  390×844.
- `flutter analyze` passed with no issues.
- `flutter test` passed: 584 tests.

## No-AI Supersession — 2026-09-24

- The former `Off` / `Ask each time` cloud-tool choice was removed from the
  product model, persistence, onboarding, and privacy explanation.
- Legacy profile JSON containing `cloud_tools` still decodes, while new saves
  omit the retired field.
- The privacy explanation now states that health records remain on-device and
  are not sent to AI services.
- Current build-11 verification: `flutter analyze` passed; the full Flutter
  suite passed 553 tests with one intentional skip.
