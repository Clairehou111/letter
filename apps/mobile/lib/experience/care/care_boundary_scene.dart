import 'package:flutter/material.dart';

import '../../features/care/domain/care_mode.dart';
import 'care_animation_port.dart';
import 'care_scene_foundation.dart';

/// The immersive guided personal-boundary scene for [CareMode.space] —
/// "I need everyone away".
///
/// One quiet action at a time on the shared ground-plane scene shell: the
/// ember rests with visible weight, copy is paced in slow fades, and the
/// scene always permits exit. The scene identifies itself by the mode's own
/// label; interruption (app backgrounded, call, exit tap) surfaces a named
/// recoverable state through [onInterrupted] and [interruptionRecoveryLine];
/// and nothing is ever recorded here — only the final step's deliberate
/// completion action invokes [onCompleted]. `requestedExit` is honored
/// immediately by the scene shell, mid-fade if needed.
///
/// For [CareMode.space], `suggestedSymptomForCare` returns null, so the
/// downstream completion flow offers the receipt signal list rather than the
/// symptom catalog — this scene stays deliberately light.
class CareBoundaryScene extends StatefulWidget {
  const CareBoundaryScene({
    super.key,
    required this.motionPreference,
    required this.onSignal,
    this.onExit,
    this.onSafety,
    this.onCompleted,
    this.onInterrupted,
    this.initialStepIndex = 0,
    this.resumeHint,
  });

  /// The motion resolution for this scene — full, reduced (crossfades
  /// replace travel/breathing), or static fallback. Identical copy, steps,
  /// and controls in all three.
  final CareSceneMotionPreference motionPreference;

  /// The single scene-signal seam, compatible with [CareAnimationPort]:
  /// ready, primaryInteraction, stepCompleted, requestedExit.
  final ValueChanged<CareSceneSignal> onSignal;

  /// Persistent, never-locked exit. Invoked immediately after the
  /// `requestedExit` signal; leaving records nothing.
  final VoidCallback? onExit;

  /// Routes to the deterministic safety surface owned by the Care
  /// experience. The safety line stays visible and calm throughout.
  final VoidCallback? onSafety;

  /// The deliberate completion — the only path by which this moment can be
  /// recorded. Fired solely by the final step's primary action; reading,
  /// pausing, or leaving never completes.
  final VoidCallback? onCompleted;

  /// Interruption hook: when the app is backgrounded mid-scene, the current
  /// step index is reported so the owner can land on the named recoverable
  /// state ("Continue, check in, or leave it here") with nothing recorded.
  final ValueChanged<int>? onInterrupted;

  /// Recovery entry point — a previously interrupted scene resumes on its
  /// named step instead of restarting.
  final int initialStepIndex;

  /// Recovery copy shown above the resumed step, typically
  /// [interruptionRecoveryLine].
  final String? resumeHint;

  /// The mode this scene serves. Fixed by contract.
  static const CareMode mode = CareMode.space;

  /// Stable step identities, in order. Used for focus, keys, and
  /// interruption recovery — a saved index plus these ids fully names the
  /// recoverable state.
  static const List<String> stepIds = <String>[
    'arrive',
    'edge',
    'stay',
    'landing',
  ];

  /// The named recoverable state for an interrupted boundary scene. Nothing
  /// is recorded by reaching or leaving this state.
  static const String interruptionRecoveryLine =
      'You were in the middle of making some space. '
      'Continue, check in, or leave it here.';

  /// Names a step for recovery; out-of-range indexes clamp to a real step so
  /// a stale saved position can never crash a returning user.
  static String stepIdAt(int index) {
    if (index < 0) return stepIds.first;
    if (index >= stepIds.length) return stepIds.last;
    return stepIds[index];
  }

  /// Resolves a persisted step position into a valid shell index.
  static int clampStepIndex(int index) {
    if (index < 0) return 0;
    if (index >= stepIds.length) return stepIds.length - 1;
    return index;
  }

  @override
  State<CareBoundaryScene> createState() => _CareBoundarySceneState();
}

class _CareBoundarySceneState extends State<CareBoundaryScene>
    with WidgetsBindingObserver {
  late int _currentStepIndex = CareBoundaryScene.clampStepIndex(
    widget.initialStepIndex,
  );
  bool _interruptionReported = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Interruption lands on a named recoverable state: the owner is told
    // exactly where the scene paused so it can offer "Continue, check in,
    // or leave it here." Backgrounding itself records nothing.
    if (state == AppLifecycleState.paused) {
      if (!_interruptionReported) {
        _interruptionReported = true;
        widget.onInterrupted?.call(_currentStepIndex);
      }
    } else if (state == AppLifecycleState.resumed) {
      _interruptionReported = false;
    }
  }

  void _handleSignal(CareSceneSignal signal) {
    if (signal == CareSceneSignal.stepCompleted &&
        _currentStepIndex < CareBoundaryScene.stepIds.length - 1) {
      _currentStepIndex += 1;
    }
    widget.onSignal(signal);
  }

  List<CareSceneStep> _steps() {
    return <CareSceneStep>[
      const CareSceneStep(
        id: 'arrive',
        title: 'You can stop answering.',
        text:
            'For these next minutes, nothing gets a piece of you. No replies, '
            'no explanations, no being reachable. The world can wait outside.',
        primaryActionLabel: 'Let it go quiet',
        semanticsLabel:
            'Step one. You can stop answering. For these next minutes, '
            'nothing gets a piece of you. The world can wait outside.',
      ),
      const CareSceneStep(
        id: 'edge',
        title: 'A soft edge around you',
        text:
            'Picture a slow circle of space, like the warm light resting '
            'below. Everyone you love is fine outside it. Wanting them at a '
            'distance is not unkind — it is how you come back to yourself.',
        primaryActionLabel: 'Hold the circle',
        semanticsLabel:
            'Step two. A soft edge around you. Everyone you love is fine '
            'outside the circle. Wanting distance is not unkind.',
      ),
      const CareSceneStep(
        id: 'stay',
        title: 'Stay in the middle',
        text:
            'Rest at the center of your own space. If a "should" knocks, let '
            'it land outside the circle. It will keep until you want it.',
        primaryActionLabel: "I'm staying here",
        semanticsLabel:
            'Step three. Stay in the middle. Rest at the center of your own '
            'space. Anything that knocks can wait outside the circle.',
      ),
      CareSceneStep(
        id: 'landing',
        title: 'Soft landing',
        text:
            'You made room for yourself, and nothing fell apart. If you like, '
            'mark this moment complete — or simply leave. Both are enough.',
        primaryActionLabel: 'This moment is complete',
        advances: false,
        // The only recording path in the scene: a deliberate, unambiguous
        // completion action. Reading this step, pausing on it, or exiting
        // from it records nothing.
        onPrimaryAction: widget.onCompleted,
        semanticsLabel:
            'Final step. Soft landing. You made room for yourself, and '
            'nothing fell apart. Mark the moment complete, or simply leave.',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return CareSceneFoundation.scene(
      mode: CareBoundaryScene.mode,
      // The scene identifies itself by the mode's own words.
      eyebrow: 'Room to yourself',
      title: CareBoundaryScene.mode.label,
      steps: _steps(),
      motionPreference: widget.motionPreference,
      onSignal: _handleSignal,
      onExit: widget.onExit,
      onSafety: widget.onSafety,
      initialStepIndex: CareBoundaryScene.clampStepIndex(
        widget.initialStepIndex,
      ),
      resumeHint: widget.resumeHint,
    );
  }
}
