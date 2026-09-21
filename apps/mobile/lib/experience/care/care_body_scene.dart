import 'package:flutter/widgets.dart';

import '../../features/care/domain/care_mode.dart';
import '../../features/care/domain/safety_resources.dart';
import 'care_animation_port.dart';
import 'care_scene_foundation.dart';

abstract final class CareBodyScene {
  /// The mode this scene serves. The scene always introduces itself with
  /// `mode.label` ("My body needs care").
  static const CareMode mode = CareMode.physical;

  /// Quiet eyebrow above the scene title.
  static const String eyebrow = 'Care for the body';

  // -------------------------------------------------------------------------
  // Named steps — stable identities are what make interruption recoverable.
  // -------------------------------------------------------------------------

  static const String arriveStepId = 'body.arrive';
  static const String settleStepId = 'body.settle';
  static const String warmthStepId = 'body.warmth';
  static const String boundaryStepId = 'body.boundary';
  static const String landingStepId = 'body.landing';

  /// Ordered step ids, used to resolve [resumeStepId] to a step index.
  static const List<String> stepIds = <String>[
    arriveStepId,
    settleStepId,
    warmthStepId,
    boundaryStepId,
    landingStepId,
  ];

  /// The named recoverable state shown after an interruption. Adult, warm,
  /// exact: continue, or leave it here — nothing was recorded.
  static const String defaultResumeHint =
      'You were in the middle of caring for your body. '
      'Continue, or leave it here.';

  /// Resolves a persisted step id to its index for scene recovery. Unknown
  /// or null ids restart gently at the first step.
  static int stepIndexFor(String? stepId) {
    if (stepId == null) return 0;
    final index = stepIds.indexOf(stepId);
    return index < 0 ? 0 : index;
  }

  // -------------------------------------------------------------------------
  // Steps
  // -------------------------------------------------------------------------

  /// The paced steps of the body-care scene.
  ///
  /// [onCompleted] is attached to the final landing step only: it runs on
  /// the person's deliberate primary action and is where the owner records
  /// the validated `CareActionCompletion`. Reading steps, pausing, or
  /// leaving mid-scene never invokes it — nothing is recorded without the
  /// deliberate completion.
  static List<CareSceneStep> steps({VoidCallback? onCompleted}) {
    return <CareSceneStep>[
      const CareSceneStep(
        id: arriveStepId,
        title: 'Nothing is asked of you here',
        text:
            'Your body has been carrying you through this. For the next few '
            'minutes, it can set that down. There is nothing to fix and '
            'nowhere else to be.',
        primaryActionLabel: "I'm here",
        semanticsLabel:
            'Nothing is asked of you here. Your body has been carrying you '
            'through this. For the next few minutes, it can set that down. '
            'There is nothing to fix and nowhere else to be.',
      ),
      const CareSceneStep(
        id: settleStepId,
        title: 'Let your body choose the position',
        text:
            'Find the one position that asks the least of your body — '
            'curled on your side, stretched out, or propped against '
            'something soft. Loosen anything tight around your waist. Take '
            'as long as you need.',
        primaryActionLabel: "I'm settled",
      ),
      const CareSceneStep(
        id: warmthStepId,
        title: 'Warmth and a slow breath',
        text:
            'If warmth is near — a heating pad, a warm bottle, or your own '
            'hands — rest it low on your belly or back. Warm, never hot '
            'against skin. Then breathe out slowly, a little longer than '
            'you breathed in, and let the warmth do the work.',
        primaryActionLabel: "I've done that",
      ),
      CareSceneStep(
        id: boundaryStepId,
        title: 'When the body asks for more',
        text: _medicalBoundaryText(),
        primaryActionLabel: 'I understand',
        semanticsLabel: _medicalBoundaryText(),
      ),
      CareSceneStep(
        id: landingStepId,
        title: 'Rest as long as you like',
        text:
            'You can stay exactly here. When you are ready, you can say how '
            'your body feels now — or simply keep resting. Either is '
            'enough.',
        primaryActionLabel: "I'm done for now",
        advances: false,
        onPrimaryAction: onCompleted,
      ),
    ];
  }

  // -------------------------------------------------------------------------
  // Scene assembly
  // -------------------------------------------------------------------------

  /// Builds the immersive body-care scene on the shared scene foundation.
  ///
  /// The shell supplies the plum-dusk backfield, ground plane, breathing
  /// ember, persistent unlocked exit, quiet safety line, explicit focus
  /// order, and all three [CareSceneMotionPreference] treatments with
  /// identical copy and controls. All shared [CareSceneSignal]s flow through
  /// [onSignal] — the same seam the future animation pass plugs into via
  /// `CareAnimationPort` without changing this journey.
  ///
  /// Recovery: pass [resumeStepId] (one of [stepIds]) to land directly on
  /// the interrupted step with [resumeHint] — the named recoverable state.
  /// A fresh start passes null and shows no hint.
  ///
  /// Completion: [onCompleted] fires only from the landing step's
  /// deliberate primary action. Exit and interruption route through
  /// [onExit] / [CareSceneSignal.requestedExit] with nothing recorded.
  static Widget build({
    Key? key,
    required CareSceneMotionPreference motionPreference,
    required ValueChanged<CareSceneSignal> onSignal,
    VoidCallback? onExit,
    VoidCallback? onSafety,
    VoidCallback? onCompleted,
    String? resumeStepId,
    String resumeHint = defaultResumeHint,
  }) {
    final resumeIndex = stepIndexFor(resumeStepId);
    return CareSceneFoundation.scene(
      key: key,
      mode: mode,
      eyebrow: eyebrow,
      // The scene names itself in the mode's own words.
      title: mode.label,
      steps: steps(onCompleted: onCompleted),
      motionPreference: motionPreference,
      onSignal: onSignal,
      onExit: onExit,
      onSafety: onSafety,
      initialStepIndex: resumeIndex,
      resumeHint: resumeStepId == null ? null : resumeHint,
    );
  }

  // -------------------------------------------------------------------------
  // Fixed medical-boundary content — calm, verbatim, never alarm.
  // -------------------------------------------------------------------------

  /// Composes the deterministic [medicalBoundaryContent] into one quiet
  /// step. The lists render verbatim; only the framing copy is authored,
  /// and it states plainly that this scene is comfort, not medical care.
  static String _medicalBoundaryText() {
    final buffer = StringBuffer()
      ..writeln(
        'Most cycle pain is hard, not dangerous. Still, some signals mean '
        'your body deserves medical care — calmly, and without waiting.',
      )
      ..writeln()
      ..writeln('Seek urgent care now for:');
    for (final item in medicalBoundaryContent.urgent) {
      buffer.writeln('• $item');
    }
    buffer
      ..writeln()
      ..writeln('Book a medical assessment for:');
    for (final item in medicalBoundaryContent.nonUrgent) {
      buffer.writeln('• $item');
    }
    buffer
      ..writeln()
      ..write(
        'This scene is comfort, not medical care. Nothing here replaces '
        'either kind of help.',
      );
    return buffer.toString();
  }
}
