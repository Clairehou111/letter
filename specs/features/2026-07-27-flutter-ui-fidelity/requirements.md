# Flutter UI Fidelity Spike Requirements

Status: validated
Branch: `spike/flutter-ui-fidelity`

## Context

The existing React prototype establishes an accepted visual direction, while
the team's existing Flutter application creates concern that Flutter may look
generic or dated. This spike tests Letter's actual interface before the mobile
framework is locked.

## Goal

Determine whether Flutter can reproduce the visual quality and interaction
standard of the React prototype with maintainable, testable code.

## Scope

REQ-001: Render a responsive Letter Today screen at representative iPhone and
Android phone widths.

REQ-002: Present a balanced current-state selector containing positive,
neutral, emotional, and physical states.

REQ-003: Allow selection of one symptom and one severity level without causing
layout movement.

REQ-004: For pain, expose multiple selectable pain locations.

REQ-005: Provide stable bottom navigation with Today in the center.

REQ-006: Provide one interactive Care flow as a modal sheet with supportive,
low-effort actions.

REQ-007: Use a coherent Letter design system rather than unmodified default
Material styling.

REQ-008: Preserve readable layout at 320 logical pixels and at 200% text scale.

REQ-009: Expose meaningful accessibility labels, selected states, and touch
targets.

REQ-010: Keep the spike dependency-light and organize reusable UI as Letter
components.

## Decisions

- Target iOS and Android; use exact browser viewports for visual comparison
  until native SDKs are available.
- Use synthetic cycle day and symptom content.
- Use `Care` as the working label instead of `Rescue`.
- Reproduce the accepted visual direction, not every prototype screen.

## Non-Goals

- production cycle calculations
- persistence, authentication, subscriptions, analytics, or backend calls
- HealthKit or Health Connect integration
- production LLM behavior
- final brand illustration or animation system

## Known Environment Limitation

Xcode and Android SDKs are unavailable on this machine. Browser screenshots and
Flutter widget tests validate rendering and responsiveness, but native
simulator behavior remains an explicit follow-up validation.

