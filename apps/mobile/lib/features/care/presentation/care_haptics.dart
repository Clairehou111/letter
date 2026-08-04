import 'package:flutter/services.dart';

/// Haptic guidance mirroring the prototype's per-scene vibration personalities.
///
/// Flutter's built-in [HapticFeedback] only supports pre-defined impact styles,
/// not custom duration patterns like the web's `navigator.vibrate`. We map each
/// prototype pattern to the closest available impact:
/// - Short buzzes → lightImpact
/// - Medium buzzes → mediumImpact
/// - Long/heavy buzzes → heavyImpact
/// - Rhythmic patterns → sequenced impacts via [burst]
///
/// Everything is best-effort: haptics never gate visuals or captions.
class CareHaptics {
  CareHaptics._();

  static bool _armed = false;

  /// Haptics are inert until the user makes a gesture on the scene canvas.
  static void arm() {
    _armed = true;
  }

  /// Explode: rising stutter while holding. Maps to light taps that speed up.
  static void charge(double press, double intensity) {
    if (!_armed) return;
    if (intensity <= 0.05) return;
    final scaled = 0.25 + intensity * 0.75;
    if (scaled < 0.15) return;
    HapticFeedback.lightImpact();
  }

  /// Explode: one longer jolt on release.
  static void burst(double intensity) {
    if (!_armed) return;
    final scaled = 0.25 + intensity * 0.75;
    if (scaled < 0.2) {
      HapticFeedback.lightImpact();
    } else if (scaled < 0.6) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
    }
  }

  /// Heavy: slow heavy pulse falling with the rain.
  static void fall(double intensity) {
    if (!_armed) return;
    final scaled = (0.25 + intensity * 0.75) * 0.7;
    if (scaled < 0.15) return;
    HapticFeedback.mediumImpact();
  }

  /// Racing: quiet tick as strands are combed.
  static void tick(double intensity) {
    if (!_armed) return;
    final scaled = (0.25 + intensity * 0.75) * 0.5;
    if (scaled < 0.1) return;
    HapticFeedback.lightImpact();
  }

  /// Racing: longer settle when strands go calm.
  static void settle(double intensity) {
    if (!_armed) return;
    final scaled = (0.25 + intensity * 0.75) * 0.7;
    if (scaled < 0.15) return;
    HapticFeedback.mediumImpact();
  }

  /// Away: walls closing — a firm, slow press.
  static void enclose(double intensity) {
    if (!_armed) return;
    final scaled = (0.25 + intensity * 0.75) * 0.8;
    if (scaled < 0.2) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.mediumImpact();
    }
  }

  /// Away: slow heartbeat while held behind the closed door.
  static void heartbeat(double intensity) {
    if (!_armed) return;
    final scaled = (0.25 + intensity * 0.75) * 0.6;
    if (scaled < 0.12) return;
    HapticFeedback.lightImpact();
  }

  /// Care: warmth wave low in the body.
  static void warmth(double intensity) {
    if (!_armed) return;
    final scaled = (0.25 + intensity * 0.75) * 0.7;
    if (scaled < 0.15) return;
    HapticFeedback.mediumImpact();
  }

  /// Stop any ongoing vibration.
  static void stop() {
    // Flutter doesn't expose a "cancel vibration" API; this is a no-op
    // on the platform side. Included for API parity with the prototype.
  }
}
