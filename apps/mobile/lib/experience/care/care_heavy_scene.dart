import 'package:flutter/widgets.dart';

import '../../features/care/domain/care_mode.dart';
import 'care_animation_port.dart';
import 'care_scene_foundation.dart';

/// Immersive guided scene for [CareMode.heavy].
///
/// The scene is deliberately slow and narrow: one thought, one action, and an
/// always-visible exit. It performs no persistence itself. [onComplete] is
/// called only from the final explicit completion action, so interruption,
/// recovery, or exit can never create a partial care record.
class CareHeavyScene extends StatelessWidget {
  const CareHeavyScene({
    super.key,
    required this.motionPreference,
    required this.onSignal,
    this.onComplete,
    this.onExit,
    this.onSafety,
    this.initialStepIndex = 0,
    this.resumeHint,
  }) : assert(
         initialStepIndex >= 0 && initialStepIndex < _stepCount,
         'initialStepIndex must name a Heavy scene step.',
       );

  /// The motion treatment resolved by the Care experience.
  final CareSceneMotionPreference motionPreference;

  /// Receives the shared scene lifecycle signals, including
  /// [CareSceneSignal.requestedExit].
  final ValueChanged<CareSceneSignal> onSignal;

  /// Called only by the final, deliberate completion action.
  final VoidCallback? onComplete;

  /// Called immediately after [CareSceneSignal.requestedExit] is emitted.
  final VoidCallback? onExit;

  /// Opens the deterministic safety route.
  final VoidCallback? onSafety;

  /// The step to restore after an interruption.
  final int initialStepIndex;

  /// Optional recovery copy shown above the restored step.
  final String? resumeHint;

  /// Named recoverable state used by the Care experience after interruption.
  static const String interruptionStateName = 'Heavy — interrupted';

  /// Recovery wording for a scene restored after interruption.
  static const String interruptionResumeHint =
      'You were in the middle of Heavy. Continue, check in, or leave it here.';

  static const int _stepCount = 4;

  List<CareSceneStep> _steps() {
    return <CareSceneStep>[
      const CareSceneStep(
        id: 'heavy-arrive',
        title: 'Make this moment smaller',
        text:
            'You do not have to lift yourself out of this. For one slow breath, let there be nothing else to do.',
        primaryActionLabel: 'Stay here',
      ),
      const CareSceneStep(
        id: 'heavy-name-the-weight',
        title: 'Let the weight be known',
        text:
            'Notice where the heaviness sits — shoulders, chest, legs, or nowhere you can name. You do not have to change it.',
        primaryActionLabel: 'Let it be heavy',
      ),
      const CareSceneStep(
        id: 'heavy-borrow-support',
        title: 'Borrow some support',
        text:
            'Feel the surface already holding you. Let it take a little of the weight, only as much as is available right now.',
        primaryActionLabel: 'Rest into that',
      ),
      CareSceneStep(
        id: 'heavy-soft-landing',
        title: 'A soft place to stop',
        text:
            'You stayed with this moment without turning it into a task. That is enough for now.',
        primaryActionLabel: 'Complete this moment',
        advances: false,
        onPrimaryAction: onComplete,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return CareSceneFoundation.scene(
      mode: CareMode.heavy,
      eyebrow: 'Care · Low energy',
      title: CareMode.heavy.label,
      steps: _steps(),
      motionPreference: motionPreference,
      onSignal: onSignal,
      onExit: onExit,
      onSafety: onSafety,
      initialStepIndex: initialStepIndex,
      resumeHint:
          resumeHint ?? (initialStepIndex > 0 ? interruptionResumeHint : null),
      emberSize: 148,
    );
  }
}
