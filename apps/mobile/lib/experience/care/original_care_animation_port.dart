import 'package:flutter/material.dart';

import '../../features/care/domain/care_mode.dart';
import '../../features/care/presentation/care_motion_flow.dart';
import 'care_animation_port.dart';

/// Reuses Letter Within's original five native motion scenes inside the
/// current Care journey.
///
/// The original painter remains the visual and interaction authority. This
/// adapter only translates its exit and completion callbacks into the stable
/// [CareAnimationPort] signals owned by [CareExperience].
///
/// Completion and dismissal are distinct signals: `Done for now` is a
/// deliberate completion that enters the external check-back
/// ([CareSceneSignal.sceneCompleted]); only a deliberate back tap is an
/// ordinary dismissal ([CareSceneSignal.sceneDismissed]) that returns to the
/// Care landing with zero persistence and no check-back.
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
      usesExternalCompletionFlow: true,
      // A deliberate back tap is an ordinary dismissal. Only an actual app
      // interruption should create a recovery state in CareExperience.
      onBack: () => onSignal(CareSceneSignal.sceneDismissed),
      onSafety: () => onSignal(CareSceneSignal.requestedSafety),
      onCompleted: () => onSignal(CareSceneSignal.sceneCompleted),
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
