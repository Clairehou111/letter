import 'package:flutter/widgets.dart';

import '../../features/care/domain/care_mode.dart';
import 'care_animation_port.dart';
import 'care_scene_foundation.dart';

/// Immersive guided scene for [CareMode.racing] — "My mind won't stop".
///
/// A paced focusing action, not advice: the person arrives, lets thoughts
/// pass without holding them, chooses one thing that truly needs them next,
/// holds it gently, and lands softly. Presence without prescription; low
/// reading level; no timers that punish; the ember is the only warm light.
///
/// Journey guarantees carried by this scene:
///  * The scene identifies itself by the mode's own label
///    ([CareMode.racing.label]) — in the spoken semantics and the title.
///  * Nothing is recorded without deliberate completion. Pressing the final
///    step's primary action is the only path that invokes [onCompleted];
///    interruption, backgrounding, and exit never record anything.
///  * [CareSceneSignal.requestedExit] is honored immediately: the exit pill
///    is persistent, high-contrast, never locked, and routes straight to
///    [onExit] even mid-fade.
///  * Interruption lands on a named recoverable state: [stepIds] and
///    [stepTitles] give the owner stable identities for every step, and
///    [recoveryLandingLine] / [resumeHintFor] supply the recoverable copy.
///    Re-entering with [initialStepIndex] + [resumeHint] resumes on the
///    exact named step with identical copy and controls.
///
/// The scene honors all three [CareSceneMotionPreference] values through
/// [CareSceneFoundation.scene]: full (breathing ember, slow step fades),
/// reduced (crossfades replace travel/breathing), and staticFallback
/// (composed static with identical copy, steps, and controls).
class CareFocusScene extends StatelessWidget {
  const CareFocusScene({
    super.key,
    required this.motionPreference,
    required this.onSignal,
    required this.onCompleted,
    this.onExit,
    this.onSafety,
    this.exitLabel = CareSceneFoundation.defaultExitLabel,
    this.safetyLine = CareSceneFoundation.defaultSafetyLine,
    this.initialStepIndex = 0,
    this.resumeHint,
    this.emberSize = 132,
  });

  /// Resolved from the platform accessibility setting only (plus the
  /// sanctioned jank escape hatch), mapped by the owner.
  final CareSceneMotionPreference motionPreference;

  /// The shared scene-signal seam, identical to `CareAnimationPort`'s:
  /// `ready`, `primaryInteraction`, `stepCompleted`, `requestedExit`.
  final ValueChanged<CareSceneSignal> onSignal;

  /// Deliberate completion — invoked only by the final step's primary
  /// action. The owner turns this into a validated `CareActionCompletion`;
  /// reading, watching, or leaving a scene never records.
  final VoidCallback onCompleted;

  /// Called after [CareSceneSignal.requestedExit] is emitted. Exit is
  /// always available and never locked.
  final VoidCallback? onExit;

  /// Routes to the deterministic safety surface. Safety access stays
  /// visible as a calm, persistent line throughout the scene.
  final VoidCallback? onSafety;

  /// Calm exit copy; the pill semantics always add that exit is available.
  final String exitLabel;

  /// Quiet, persistent safety access line.
  final String safetyLine;

  /// Recovery entry point — a real step index into [stepIds]. A recovered
  /// scene lands directly on its named step; focus moves there once.
  final int initialStepIndex;

  /// Recoverable-state hint rendered above the resumed step text, e.g.
  /// from [resumeHintFor]. Identical across all motion preferences.
  final String? resumeHint;

  /// The held orb's resting size on the scene's ground line.
  final double emberSize;

  /// Stable step identities — the named recoverable states of this scene.
  /// Interruption recovery, focus restoration, and tests key off these.
  static const List<String> stepIds = <String>[
    'arrive',
    'let-pass',
    'choose-one',
    'hold-it',
    'land',
  ];

  /// Short step names used in recovery copy.
  static const List<String> stepTitles = <String>[
    'Arriving',
    'Letting thoughts pass',
    'Choosing one thing',
    'Holding it gently',
    'Soft landing',
  ];

  static const int stepCount = 5;

  /// The named recoverable landing line for an interrupted Focus scene,
  /// matching the system's interruption contract ("You were in the middle
  /// of …"). The owner renders this on the soft landing; nothing has been
  /// recorded, and the copy says so implicitly by offering to continue.
  static const String recoveryLandingLine =
      'You were in the middle of Focus. Continue, check in, '
      'or leave it here.';

  /// A per-step resume hint, honest about exactly where the scene paused.
  /// Returns null for an out-of-range index — the owner then lands on the
  /// scene's first step with no hint rather than naming a wrong state.
  static String? resumeHintFor(int stepIndex) {
    if (stepIndex <= 0 || stepIndex >= stepIds.length) return null;
    return 'You were in the middle of Focus — '
        '${stepTitles[stepIndex].toLowerCase()}. Continue, or leave it here.';
  }

  List<CareSceneStep> _steps() {
    return <CareSceneStep>[
      const CareSceneStep(
        id: 'arrive',
        title: 'Arriving',
        text:
            'Your thoughts are moving quickly. Nothing is wrong with you. '
            'We will not try to stop them — only to stand beside them for a '
            'little while.',
        semanticsLabel:
            'Arriving. Your thoughts are moving quickly. Nothing '
            'is wrong with you. We will not try to stop them, only stand '
            'beside them for a little while.',
        primaryActionLabel: "I'm here",
      ),
      const CareSceneStep(
        id: 'let-pass',
        title: 'Letting thoughts pass',
        text:
            'Let each thought cross your mind like a bird crossing the sky. '
            'You do not have to hold any of them. Watch one arrive, and let '
            'it keep going.',
        semanticsLabel:
            'Letting thoughts pass. Let each thought cross your '
            'mind like a bird crossing the sky. You do not have to hold any '
            'of them. Watch one arrive, and let it keep going.',
        primaryActionLabel: 'One passed by',
      ),
      const CareSceneStep(
        id: 'choose-one',
        title: 'Choosing one thing',
        text:
            'Of everything asking for you, pick one thing — just one — '
            'that truly needs you next. The rest can wait exactly where it '
            'is.',
        semanticsLabel:
            'Choosing one thing. Of everything asking for you, '
            'pick one thing, just one, that truly needs you next. The rest '
            'can wait exactly where it is.',
        primaryActionLabel: 'I picked one thing',
      ),
      const CareSceneStep(
        id: 'hold-it',
        title: 'Holding it gently',
        text:
            'Hold that one thing gently. You can say it quietly to '
            'yourself, or simply know it. That is enough for now.',
        semanticsLabel:
            'Holding it gently. Hold that one thing gently. You '
            'can say it quietly to yourself, or simply know it. That is '
            'enough for now.',
        primaryActionLabel: "I'm holding it",
      ),
      CareSceneStep(
        id: 'land',
        title: 'Soft landing',
        text:
            'The noise can stay where it is. You chose one thing, and the '
            'rest can wait. Nothing else is asked of you right now.',
        semanticsLabel:
            'Soft landing. The noise can stay where it is. You '
            'chose one thing, and the rest can wait. Nothing else is asked '
            'of you right now.',
        primaryActionLabel: 'This is enough',
        // Final step: does not advance. The deliberate press is handed to
        // the owner as completion — the only moment anything may record.
        advances: false,
        onPrimaryAction: onCompleted,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return CareSceneFoundation.scene(
      key: key,
      // The scene identifies itself by the mode's own label, spoken and
      // visible: "My mind won't stop".
      mode: CareMode.racing,
      eyebrow: 'One thing at a time',
      title: CareMode.racing.label,
      steps: _steps(),
      motionPreference: motionPreference,
      onSignal: onSignal,
      onExit: onExit,
      onSafety: onSafety,
      exitLabel: exitLabel,
      safetyLine: safetyLine,
      initialStepIndex: initialStepIndex,
      resumeHint: resumeHint,
      emberSize: emberSize,
    );
  }
}
