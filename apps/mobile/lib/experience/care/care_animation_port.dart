import 'package:flutter/widgets.dart';

import '../../features/care/domain/care_mode.dart';

/// Stable presentation boundary for the professional Care animation pass.
///
/// The release framework can ship accessible Flutter fallbacks first. A later
/// Rive/character-animation implementation plugs in here without changing the
/// Care journey, persistence, safety route, or completion flow.
abstract interface class CareAnimationPort {
  Widget buildScene(
    BuildContext context, {
    required CareMode mode,
    required CareSceneMotionPreference motionPreference,
    required ValueChanged<CareSceneSignal> onSignal,
  });
}

enum CareSceneMotionPreference { full, reduced, staticFallback }

enum CareSceneSignal {
  ready,
  primaryInteraction,
  stepCompleted,
  sceneCompleted,
  sceneDismissed,
  requestedSafety,
  requestedExit,
}
