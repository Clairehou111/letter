import 'package:flutter/material.dart';

import '../../features/care/domain/care_mode.dart';
import '../../features/care/presentation/care_motion_flow.dart';
import 'care_animation_port.dart';

/// Reuses Letter Within's original five native motion scenes inside the
/// current Care journey.
///
/// The original painter remains the visual and interaction authority. This
/// adapter only translates its exit and completion callbacks into the stable
/// [CareAnimationPort] signals owned by `CareExperience`. No gesture, timing,
/// haptic, sound, persistence, or recovery behavior lives here — every
/// mapping below is the shipped production semantics, documented so the
/// adapter and the journey can never drift apart.
///
/// Signal semantics (production):
///
/// * **Back tap → [CareSceneSignal.sceneDismissed].** A deliberate back tap
///   is an ordinary dismissal: a clean return to the Care landing with zero
///   persistence and no check-back. It is *not* treated as an interruption
///   and never arms the recovery state — only an actual app backgrounding
///   mid-scene does that, via the lifecycle observers in `CareExperience`.
///   (Owner decision: back = clean dismissal is preserved; routing exits
///   through recovery is a separate future decision, not this pass.)
/// * **Completion paths → [CareSceneSignal.sceneCompleted].** Natural
///   settle, "Enough for now", and the settled "Done for now" are all
///   deliberate completions. Because `usesExternalCompletionFlow` is true,
///   the scene hands off directly and the owning experience presents the
///   Better / Same / Worse check-back; completion is never conflated with
///   dismissal.
/// * **Safety → [CareSceneSignal.requestedSafety].** A pure passthrough;
///   the safety route stays reachable from every scene.
/// * **`onCheckedIn` outcome intentionally discarded.** The legacy
///   in-scene moment-check sheet is bypassed in this configuration, so the
///   callback is unreachable in production. The mapping is retained (the
///   parameter surface of [CareBreakFlow] is a preserved contract) and
///   defensively forwards to [CareSceneSignal.sceneCompleted]; the outcome
///   value itself is intentionally dropped because the external check-back
///   flow owns outcome recording.
///
/// Reduced-motion handling: when the requested [CareSceneMotionPreference]
/// is anything but [CareSceneMotionPreference.full], `disableAnimations` is
/// injected through a [MediaQuery] wrapper so still scenes stop their frame
/// loop, suppress sound, and keep chrome persistent — without touching any
/// scene internals.
final class OriginalCareAnimationPort implements CareAnimationPort {
  const OriginalCareAnimationPort();

  @override
  Widget buildScene(
    BuildContext context, {
    required CareMode mode,
    required CareSceneMotionPreference motionPreference,
    required ValueChanged<CareSceneSignal> onSignal,
  }) {
    Widget scene = CareBreakFlow(
      mode: mode,
      // Production configuration: the owning experience presents the
      // check-back, so the legacy moment-check sheet stays bypassed and the
      // scene hands off directly on completion.
      usesExternalCompletionFlow: true,
      // A deliberate back tap is an ordinary dismissal: clean landing exit,
      // zero persistence, no recovery state. Only an actual app
      // interruption (backgrounding mid-scene) should arm recovery in
      // CareExperience.
      onBack: () => onSignal(CareSceneSignal.sceneDismissed),
      onSafety: () => onSignal(CareSceneSignal.requestedSafety),
      onCompleted: () => onSignal(CareSceneSignal.sceneCompleted),
      // Unreachable while `usesExternalCompletionFlow` is true (the legacy
      // moment-check sheet never opens). Retained for the fallback
      // configuration; the outcome is intentionally discarded here because
      // the external check-back flow owns outcome recording.
      onCheckedIn: (_) => onSignal(CareSceneSignal.sceneCompleted),
      // `Done for now` is a deliberate completion: it enters the external
      // check-back like every other completion path. It is not a dismissal.
      onDone: () => onSignal(CareSceneSignal.sceneCompleted),
    );

    if (motionPreference != CareSceneMotionPreference.full) {
      final media = MediaQuery.maybeOf(context);
      if (media != null && !media.disableAnimations) {
        scene = MediaQuery(
          data: media.copyWith(disableAnimations: true),
          child: scene,
        );
      }
    }

    return scene;
  }
}
