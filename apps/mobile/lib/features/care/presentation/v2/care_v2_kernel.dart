import 'dart:math' as math;
import 'dart:ui' show Offset;

/// Shared Care V2 interaction kernel.
///
/// V2 keeps Care passive-first: the timeline always advances and always
/// reaches the settled state at 90 seconds, whether or not the screen is
/// touched. Touch is one optional gesture — rest a finger, gently drift,
/// release — and produces three things:
///
/// 1. immediate local yield in the material (painter-side, under the finger),
/// 2. a subtle acceleration of settling while the finger stays down,
/// 3. exactly one persistent qualitative trace after release.
///
/// There is no target, instruction, score, counter, streak, timer, or success
/// state anywhere in this kernel, and repeated contacts merge instead of
/// accumulating: at most [CareV2TraceField.maxTraces] soft traces exist.
enum CareV2Phase { active, landing, settled, extending }

/// Timing contract shared by every V2 scene, identical to V1.
abstract final class CareV2Timeline {
  /// Passive scene length.
  static const double sceneSeconds = 90;

  /// Quiet landing begins here instead of an abrupt ending.
  static const double landingSeconds = 75;

  /// "Stay another minute" extends the settled state by this much.
  static const double extensionSeconds = 60;

  /// Ceiling of the driving controller, in seconds.
  static const double controllerSeconds = 600;

  static CareV2Phase phaseFor({
    required double elapsed,
    required double sceneDuration,
    required bool extending,
  }) {
    if (extending) {
      return elapsed >= sceneDuration
          ? CareV2Phase.settled
          : CareV2Phase.extending;
    }
    if (elapsed >= sceneSeconds) return CareV2Phase.settled;
    if (elapsed >= landingSeconds) return CareV2Phase.landing;
    return CareV2Phase.active;
  }

  /// 0 → 1 over the landing window, used to decay motion and dim the field.
  static double landingProgress(double elapsed) {
    if (elapsed <= landingSeconds) return 0;
    return ((elapsed - landingSeconds) / (sceneSeconds - landingSeconds))
        .clamp(0.0, 1.0)
        .toDouble();
  }
}

/// One persistent qualitative consequence of a contact.
///
/// Traces are stored in unit space (0..1 of the canvas) so they survive
/// rotation and resize without recomputation.
class CareV2Trace {
  CareV2Trace({
    required this.position,
    required this.bornAt,
    this.weight = 0.5,
  });

  Offset position;
  double bornAt;

  /// 0..1 — how established the trace looks. Merged contacts deepen an
  /// existing trace instead of adding another mark.
  double weight;
}

/// Bounded trace store shared by all V2 scenes.
class CareV2TraceField {
  CareV2TraceField();

  /// Hard cap. Frantic tapping cannot produce a field of marks.
  static const int maxTraces = 4;

  /// Contacts landing within this unit distance of an existing trace merge
  /// into it.
  static const double mergeRadius = 0.22;

  final List<CareV2Trace> _traces = <CareV2Trace>[];

  List<CareV2Trace> get traces => List.unmodifiable(_traces);

  int get length => _traces.length;

  bool get isEmpty => _traces.isEmpty;

  void clear() => _traces.clear();

  /// Commits one contact. [held] is how long the finger rested, in seconds;
  /// a longer rest leaves a slightly more established trace.
  ///
  /// Returns the trace that now carries this contact.
  CareV2Trace commit(
    Offset unitPosition, {
    required double at,
    double held = 0,
  }) {
    final clamped = Offset(
      unitPosition.dx.clamp(0.0, 1.0).toDouble(),
      unitPosition.dy.clamp(0.0, 1.0).toDouble(),
    );
    final gain = (0.34 + held * 0.18).clamp(0.2, 0.55).toDouble();

    final nearest = _nearest(clamped);
    final mustMerge = _traces.length >= maxTraces;
    if (nearest != null &&
        (mustMerge || (nearest.position - clamped).distance <= mergeRadius)) {
      // Merge: drift the existing trace slightly toward the new contact and
      // deepen it. No new mark appears.
      final blend = mustMerge ? 0.18 : 0.34;
      nearest.position = Offset(
        nearest.position.dx + (clamped.dx - nearest.position.dx) * blend,
        nearest.position.dy + (clamped.dy - nearest.position.dy) * blend,
      );
      nearest.weight = math.min(1, nearest.weight + gain * 0.6);
      nearest.bornAt = math.min(nearest.bornAt, at);
      return nearest;
    }

    final trace = CareV2Trace(position: clamped, bornAt: at, weight: gain);
    _traces.add(trace);
    return trace;
  }

  CareV2Trace? _nearest(Offset unitPosition) {
    CareV2Trace? best;
    var bestDistance = double.infinity;
    for (final trace in _traces) {
      final distance = (trace.position - unitPosition).distance;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = trace;
      }
    }
    return best;
  }
}

/// Live contact state: one finger, optional, releasable at any time.
class CareV2Contact {
  const CareV2Contact({
    required this.position,
    required this.startedAt,
    required this.drift,
  });

  /// Unit-space position of the finger.
  final Offset position;
  final double startedAt;

  /// Accumulated unit-space travel, used only for a gentle drift response.
  final double drift;

  double heldFor(double now) => math.max(0, now - startedAt);

  CareV2Contact moveTo(Offset next) => CareV2Contact(
    position: next,
    startedAt: startedAt,
    drift: drift + (next - position).distance,
  );
}

/// Converts elapsed time plus optional contact into the material's settling
/// progress.
///
/// The timeline is untouched: [CareV2Timeline.phaseFor] still settles at 90
/// seconds. Contact only nudges how far the material has already travelled,
/// and the nudge is capped so holding a finger down can never turn the scene
/// into a task worth optimising.
class CareV2Settling {
  CareV2Settling();

  /// Seconds of settling granted per second of rest.
  static const double holdRate = 0.35;

  /// Ceiling on total granted seconds.
  static const double maxBoostSeconds = 8;

  double _boost = 0;

  double get boostSeconds => _boost;

  void absorbHold(double heldSeconds) {
    _boost = math.min(maxBoostSeconds, _boost + heldSeconds * holdRate);
  }

  void reset() => _boost = 0;

  /// 0 → 1 material progress. [activeHold] is the current, uncommitted rest.

  ///
  /// [span] lets a scene finish its material transformation before the quiet
  /// landing: Explode's seal closes and rests, then the landing dims it.
  double progress(
    double elapsed, {
    double activeHold = 0,
    double span = CareV2Timeline.sceneSeconds,
  }) {
    final boosted = math.min(maxBoostSeconds, _boost + activeHold * holdRate);
    return ((elapsed + boosted) / span).clamp(0.0, 1.0).toDouble();
  }
}

/// Deterministic rain state for Heavy V2.
///
/// V2 owns its own drops so the V1 [PrototypeSceneModel] stays untouched.
class CareV2Drop {
  CareV2Drop({
    required this.x,
    required this.y,
    required this.velocity,
    required this.length,
    required this.width,
  });

  double x;
  double y;
  final double velocity;
  final double length;
  final double width;
}

class CareV2RainModel {
  CareV2RainModel({math.Random? random, this.dropCount = 30})
    : _random = random ?? math.Random(20260811) {
    drops = List.generate(dropCount, (_) {
      return CareV2Drop(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        velocity: 0.45 + _random.nextDouble() * 0.75,
        length: 26 + _random.nextDouble() * 74,
        width: 1 + _random.nextDouble() * 1.6,
      );
    });
  }

  final math.Random _random;
  final int dropCount;
  late final List<CareV2Drop> drops;

  double _lastElapsed = 0;

  /// Fraction of drops still falling. Rain thins out on its own and stops.
  int activeDropCount(double progress) {
    final remaining = (1 - progress);
    final eased = remaining * remaining;
    return (drops.length * eased).floor().clamp(0, drops.length);
  }

  void advance({required double elapsed, required double progress}) {
    final rawDt = (elapsed - _lastElapsed).clamp(0.0, 0.05).toDouble();
    _lastElapsed = elapsed;
    if (rawDt <= 0) return;
    final flow = 1 - progress * 0.9;
    for (final drop in drops) {
      drop.y += drop.velocity * flow * rawDt;
      if (drop.y > 1.15) {
        drop.y = -0.15;
        drop.x = _random.nextDouble();
      }
    }
  }
}
