import 'package:flutter/widgets.dart';

import '../../features/care/domain/care_mode.dart';
import '../theme/experience_foundation.dart';
import 'care_animation_port.dart';
import 'care_scene_foundation.dart';

/// The immersive, interruptible safe-release scene for [CareMode.explode] —
/// "I want to explode".
///
/// One paced guided action at a time, ending in a soft landing. The scene:
///  * identifies itself by the mode's own label,
///  * never records anything on its own — completion happens only when the
///    person deliberately presses the final step's action, which the owner
///    turns into a validated `CareActionCompletion`,
///  * honors [CareSceneSignal.requestedExit] immediately through the shared
///    scene shell (exit is persistent, high-contrast, and never locked),
///  * supports interruption recovery: the owner persists [stepIds] with the
///    active index and hands both back via [initialStepIndex]; the scene then
///    lands on the named recoverable step with [resumeHint].
///
/// Copy, steps, and controls are identical across all three
/// [CareSceneMotionPreference]s; only motion changes.
class CareReleaseScene extends StatelessWidget {
  const CareReleaseScene({
    super.key,
    required this.motionPreference,
    required this.onSignal,
    this.onExit,
    this.onSafety,
    this.onCompleted,
    this.initialStepIndex = 0,
    this.resumeHint,
  });

  /// Resolved from the platform accessibility setting only (or the jank
  /// escape hatch). See [ExperienceMotion.scenePreference].
  final CareSceneMotionPreference motionPreference;

  /// All shared scene signals surface here — the same seam the future
  /// [CareAnimationPort] implementation will use.
  final ValueChanged<CareSceneSignal> onSignal;

  /// Calm exit. Invoked immediately after `requestedExit` is signaled.
  final VoidCallback? onExit;

  /// Routes to the deterministic safety surface. Quiet, always reachable.
  final VoidCallback? onSafety;

  /// Deliberate completion. Runs only from the final landing step's primary
  /// action — never from reading, never from interruption. The owner records
  /// the validated `CareActionCompletion` here.
  final VoidCallback? onCompleted;

  /// Recovery entry point: the persisted step index the person was on when
  /// the scene was interrupted. Must be `< stepIds.length`.
  final int initialStepIndex;

  /// The named recoverable state shown after interruption, e.g.
  /// "You were in the middle of Release. Continue, check in, or leave it
  /// here." Composed by the owner from [stepIds].
  final String? resumeHint;

  /// Stable step identities, in order. Owners persist `stepIds[index]` with
  /// the index so an interrupted scene can be named and resumed — nothing is
  /// recorded without the deliberate completion on the final step.
  static const List<String> stepIds = <String>[
    'arrive',
    'locate',
    'breathe-out',
    'press-release',
    'landing',
  ];

  /// Default recovery line for an interrupted Release scene.
  static const String interruptionHint =
      'You were in the middle of Release. Continue, check in, or leave it '
      'here.';

  List<CareSceneStep> _steps() {
    return <CareSceneStep>[
      const CareSceneStep(
        id: 'arrive',
        title: 'Something wants out.',
        text:
            'Whatever built up, it is allowed to be here. You do not have '
            'to hold it nicely. We will let it move, one small piece at a '
            'time.',
        primaryActionLabel: "I'm here",
        semanticsLabel:
            'Something wants out. Whatever built up, it is '
            'allowed to be here. We will let it move, one small piece at a '
            'time.',
      ),
      const CareSceneStep(
        id: 'locate',
        title: 'Find where it sits.',
        text:
            'Notice where the pressure lives — jaw, chest, shoulders, '
            'hands. You do not need the right word for it. Just point your '
            'attention at it, the way you would rest a hand somewhere sore.',
        primaryActionLabel: 'I found it',
        semanticsLabel:
            'Find where it sits. Notice where the pressure '
            'lives. You do not need the right word for it.',
      ),
      const CareSceneStep(
        id: 'breathe-out',
        title: 'Let some of it leave.',
        text:
            'Breathe in slowly through your nose. Then open your mouth and '
            'let the breath out for as long as it wants to go — a sigh is '
            'fine, a sound is fine. Do it three times, at your own pace.',
        primaryActionLabel: 'I breathed it out',
        semanticsLabel:
            'Let some of it leave. Breathe in slowly, then let '
            'the breath out for as long as it wants, three times, at your '
            'own pace.',
      ),
      const CareSceneStep(
        id: 'press-release',
        title: 'Give it somewhere to go.',
        text:
            'Press your palms together only as firmly as feels comfortable, '
            'or squeeze a soft object, and count slowly to five. Then let go '
            'and notice the release. Stop if anything hurts.',
        primaryActionLabel: 'I pressed and released',
        semanticsLabel:
            'Give it somewhere to go. Press your palms together '
            'hard, count slowly to five, then let your hands drop. Repeat '
            'if your body asks.',
      ),
      CareSceneStep(
        id: 'landing',
        title: 'Rest a moment.',
        text:
            'It moved, or it did not — both are okay. You are still here, '
            'and nothing needs fixing yet. When you are ready, you can land '
            'softly.',
        primaryActionLabel: 'Land softly',
        semanticsLabel:
            'Rest a moment. It moved, or it did not — both are '
            'okay. Nothing needs fixing yet.',
        advances: false,
        onPrimaryAction: onCompleted,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return CareSceneFoundation.scene(
      key: key,
      mode: CareMode.explode,
      eyebrow: 'Let it go',
      title: CareMode.explode.label,
      steps: _steps(),
      motionPreference: motionPreference,
      onSignal: onSignal,
      onExit: onExit,
      onSafety: onSafety,
      exitLabel: 'Leave for now',
      initialStepIndex: initialStepIndex,
      resumeHint: resumeHint,
    );
  }
}
