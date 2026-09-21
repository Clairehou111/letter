import 'package:flutter/material.dart';

import '../../features/care/domain/care_memory.dart';
import '../../features/care/domain/care_mode.dart';
import '../../features/patterns/domain/personal_pattern.dart';
import '../../features/preparation/domain/preparation_loop_state.dart';
import '../theme/experience_foundation.dart';
import 'care_animation_port.dart';
import 'care_scene_foundation.dart';

/// Everyday-care guided rituals for stable users.
///
/// The toolkit is deliberately not a list of advice cards: each ritual is a
/// paced, interruptible scene on the shared Care runtime. Finishing the final
/// step creates one deliberate [CareActionCompletion] and hands it to the
/// owner through [onRitualCompleted], which is where the shared completion
/// flow (soft landing, optional outcome, separately dismissible receipt
/// opt-in) takes over. Leaving a ritual early records nothing.
///
/// Remembered-help copy is rendered only through
/// [ExperienceFoundation.gateMemoryEvidence] and the foundation memory copy
/// helpers. Warmth rituals carry a concise burn-safety reminder; warm drinks
/// and soaks are framed as comfort rituals, never treatments.
final class CareToolkitExperience extends StatefulWidget {
  const CareToolkitExperience({
    super.key,
    required this.onRitualCompleted,
    this.onExit,
    this.onSafety,
    this.loopKind,
    this.memoryEvidence = const <SupportActionPattern>[],
    this.now,
  });

  /// Receives the deliberate completion record exactly once, when the person
  /// presses the ritual's final primary action. The owning Care experience
  /// routes this into the same completion flow used by the five modes.
  final Future<void> Function(CareActionCompletion completion)
  onRitualCompleted;

  /// Leaves the toolkit / Care world. Exit remains available and unlocked.
  final VoidCallback? onExit;

  /// Routes to the deterministic safety surface owned by the Care experience.
  final VoidCallback? onSafety;

  /// Evidence inputs for the single shared memory gate. The toolkit never
  /// composes remembered-help copy outside the foundation helpers.
  final PreparationLoopKind? loopKind;
  final List<SupportActionPattern> memoryEvidence;

  /// Injectable clock for deterministic completion timestamps.
  final DateTime Function()? now;

  @override
  State<CareToolkitExperience> createState() => _CareToolkitExperienceState();
}

class _CareToolkitExperienceState extends State<CareToolkitExperience> {
  _ToolkitRitual? _active;
  bool _memoryProposalDismissed = false;
  bool _completing = false;

  DateTime _now() => (widget.now ?? DateTime.now)();

  void _openRitual(_ToolkitRitual ritual) {
    ExperienceHaptics.pick();
    setState(() => _active = ritual);
  }

  void _leaveActiveScene() {
    // Interruption and exit are recoverable and record nothing. The deliberate
    // completion path is the only route that writes.
    if (!mounted) return;
    setState(() => _active = null);
  }

  Future<void> _completeRitual(_ToolkitRitual ritual) async {
    if (_completing) return;
    setState(() => _completing = true);
    final completion = CareActionCompletion(
      mode: CareMode.physical,
      actionId: ritual.id,
      actionLabel: ritual.title,
      occurredAt: _now(),
    );
    try {
      await widget.onRitualCompleted(completion);
      if (!mounted) return;
      setState(() {
        _active = null;
        _memoryProposalDismissed = false;
      });
    } catch (_) {
      if (!mounted) return;
      // Errors are visual + textual only; never haptic. Persistence failures
      // and their ready-made recovery copy are owned by the completion flow,
      // so this stays deliberately plain and non-punishing.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'That completion could not be handed off just now. '
            'Nothing was lost.',
            style: ExperienceType.bodySmall(ExperienceColors.careInk),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _completing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final motion = ExperienceFoundation.motionPreference(context);
    final active = _active;

    return Theme(
      data: ExperienceFoundation.careTheme(),
      child: Scaffold(
        backgroundColor: ExperienceColors.careSkyBottom,
        body: active == null
            ? _ToolkitChooser(
                motion: motion,
                loopKind: widget.loopKind,
                memoryEvidence: widget.memoryEvidence,
                proposalDismissed: _memoryProposalDismissed,
                onDismissProposal: () {
                  setState(() => _memoryProposalDismissed = true);
                },
                onOpenRitual: _openRitual,
                onExit: widget.onExit,
                onSafety: widget.onSafety,
              )
            : _buildScene(active, motion),
      ),
    );
  }

  Widget _buildScene(_ToolkitRitual ritual, CareSceneMotionPreference motion) {
    final steps = <CareSceneStep>[
      for (final spec in ritual.steps)
        CareSceneStep(
          id: spec.id,
          title: spec.title,
          text: spec.text,
          primaryActionLabel: spec.isFinal
              ? ritual.completionLabel
              : spec.actionLabel,
          semanticsLabel: spec.semanticsLabel,
          advances: !spec.isFinal,
          onPrimaryAction: spec.isFinal
              ? () {
                  // Hand completion to the shared flow. The scene foundation
                  // has already emitted primaryInteraction; this final step
                  // intentionally does not auto-advance.
                  _completeRitual(ritual);
                }
              : null,
        ),
    ];

    return CareSceneFoundation.scene(
      key: ValueKey<String>('toolkit-${ritual.id}'),
      mode: CareMode.physical,
      eyebrow: ritual.eyebrow,
      title: ritual.title,
      steps: steps,
      motionPreference: motion,
      onSignal: _handleSceneSignal,
      onExit: _leaveActiveScene,
      onSafety: widget.onSafety,
      exitLabel: 'Back to everyday care',
      safetyLine: CareSceneFoundation.defaultSafetyLine,
    );
  }

  void _handleSceneSignal(CareSceneSignal signal) {
    // The scene foundation already owns haptics, focus movement, pacing, and
    // requestedExit dispatch. The toolkit keeps this seam open so the future
    // animation port can observe the same shared signals without a journey
    // change.
    switch (signal) {
      case CareSceneSignal.ready:
      case CareSceneSignal.primaryInteraction:
      case CareSceneSignal.stepCompleted:
      case CareSceneSignal.sceneCompleted:
      case CareSceneSignal.sceneDismissed:
      case CareSceneSignal.requestedSafety:
      case CareSceneSignal.requestedExit:
        break;
    }
  }
}

class _ToolkitChooser extends StatelessWidget {
  const _ToolkitChooser({
    required this.motion,
    required this.loopKind,
    required this.memoryEvidence,
    required this.proposalDismissed,
    required this.onDismissProposal,
    required this.onOpenRitual,
    required this.onExit,
    required this.onSafety,
  });

  final CareSceneMotionPreference motion;
  final PreparationLoopKind? loopKind;
  final List<SupportActionPattern> memoryEvidence;
  final bool proposalDismissed;
  final VoidCallback onDismissProposal;
  final ValueChanged<_ToolkitRitual> onOpenRitual;
  final VoidCallback? onExit;
  final VoidCallback? onSafety;

  @override
  Widget build(BuildContext context) {
    final memory = _resolveMemoryLine();

    return DecoratedBox(
      decoration: const BoxDecoration(gradient: ExperienceColors.careBackdrop),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            ExperienceSpacing.screenMargin,
            ExperienceSpacing.md,
            ExperienceSpacing.screenMargin,
            ExperienceSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Semantics(
                header: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'EVERYDAY CARE',
                      style: ExperienceType.eyebrow(
                        ExperienceColors.careInkSoft,
                      ),
                    ),
                    const SizedBox(height: ExperienceSpacing.xs),
                    Text(
                      'Small rituals for a steadier body',
                      style: ExperienceType.title(ExperienceColors.careInk),
                    ),
                    const SizedBox(height: ExperienceSpacing.sm),
                    Text(
                      'Pick one thing. It will guide you slowly, and you can '
                      'leave whenever you need to.',
                      style: ExperienceType.body(ExperienceColors.careInkSoft),
                    ),
                  ],
                ),
              ),
              if (memory != null) ...<Widget>[
                const SizedBox(height: ExperienceSpacing.md),
                memory,
              ],
              const SizedBox(height: ExperienceSpacing.lg),
              Expanded(
                child: ListView.separated(
                  physics: const ClampingScrollPhysics(),
                  itemCount: _ToolkitRitual.catalog.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: ExperienceSpacing.sm),
                  itemBuilder: (context, index) {
                    final ritual = _ToolkitRitual.catalog[index];
                    return _RitualCard(
                      ritual: ritual,
                      onTap: () => onOpenRitual(ritual),
                    );
                  },
                ),
              ),
              const SizedBox(height: ExperienceSpacing.sm),
              _ChooserSafetyLine(onTap: onSafety),
              if (onExit != null) ...<Widget>[
                const SizedBox(height: ExperienceSpacing.sm),
                _ChooserExitButton(onPressed: onExit!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget? _resolveMemoryLine() {
    final verdict = ExperienceFoundation.gateMemoryEvidence(
      loopKind: loopKind,
      evidence: memoryEvidence,
    );

    String? line;
    var dismissible = false;
    switch (verdict) {
      case MemoryEvidenceVerdict.remembered:
        // A loop may justify remembered copy while raw evidence is still
        // empty; never fabricate a line in that case.
        line = ExperienceMemoryGate.rememberedLine(memoryEvidence);
        break;
      case MemoryEvidenceVerdict.accumulating:
        line = ExperienceMemoryGate.accumulatingLine(memoryEvidence);
        break;
      case MemoryEvidenceVerdict.proposal:
        if (!proposalDismissed) {
          line = ExperienceMemoryGate.rememberedLine(memoryEvidence);
          dismissible = line != null;
        }
        break;
      case MemoryEvidenceVerdict.silent:
        line = null;
        break;
    }

    if (line == null) return null;
    return _ToolkitMemoryLine(
      line: line,
      dismissible: dismissible,
      onDismiss: onDismissProposal,
    );
  }
}

class _ToolkitMemoryLine extends StatelessWidget {
  const _ToolkitMemoryLine({
    required this.line,
    required this.dismissible,
    required this.onDismiss,
  });

  final String line;
  final bool dismissible;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: line,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: ExperienceColors.careGlass,
          borderRadius: ExperienceRadius.cardRadius,
          border: Border.all(color: ExperienceColors.careGlassBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ExperienceSpacing.md,
            vertical: ExperienceSpacing.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: EmberOrb(size: 18),
              ),
              const SizedBox(width: ExperienceSpacing.sm),
              Expanded(
                child: Text(
                  line,
                  style: ExperienceType.bodySmall(ExperienceColors.careInk),
                ),
              ),
              if (dismissible) ...<Widget>[
                const SizedBox(width: ExperienceSpacing.xs),
                Semantics(
                  button: true,
                  label: 'Dismiss remembered help',
                  child: InkWell(
                    borderRadius: ExperienceRadius.chipRadius,
                    onTap: onDismiss,
                    child: const Padding(
                      padding: EdgeInsets.all(ExperienceSpacing.xs),
                      child: Icon(
                        Icons.close,
                        size: 18,
                        color: ExperienceColors.careInkSoft,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RitualCard extends StatelessWidget {
  const _RitualCard({required this.ritual, required this.onTap});

  final _ToolkitRitual ritual;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${ritual.title}. ${ritual.intention}',
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: ExperienceSpacing.minTouchTarget,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: ExperienceColors.careGlass,
            borderRadius: ExperienceRadius.cardRadius,
            border: Border.all(color: ExperienceColors.careGlassBorder),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: ExperienceRadius.cardRadius,
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(ExperienceSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            ritual.title,
                            style: ExperienceType.label(
                              ExperienceColors.careInk,
                            ),
                          ),
                          const SizedBox(height: ExperienceSpacing.xs),
                          Text(
                            ritual.intention,
                            style: ExperienceType.bodySmall(
                              ExperienceColors.careInkSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: ExperienceSpacing.sm),
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.chevron_right,
                        color: ExperienceColors.careInkSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChooserSafetyLine extends StatelessWidget {
  const _ChooserSafetyLine({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      CareSceneFoundation.defaultSafetyLine,
      style: ExperienceType.caption(ExperienceColors.careInkSoft),
      textAlign: TextAlign.center,
    );
    if (onTap == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: ExperienceSpacing.xs),
        child: text,
      );
    }
    return Semantics(
      button: true,
      label: CareSceneFoundation.defaultSafetyLine,
      child: InkWell(
        borderRadius: ExperienceRadius.chipRadius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ExperienceSpacing.sm,
            vertical: ExperienceSpacing.xs,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.favorite_border,
                size: 14,
                color: ExperienceColors.careInkSoft,
              ),
              const SizedBox(width: ExperienceSpacing.xs),
              Flexible(child: text),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChooserExitButton extends StatelessWidget {
  const _ChooserExitButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Leave everyday care. Exit is always available.',
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: ExperienceSpacing.minTouchTarget,
        ),
        child: Material(
          color: ExperienceColors.careInk,
          borderRadius: ExperienceRadius.heroRadius,
          child: InkWell(
            borderRadius: ExperienceRadius.heroRadius,
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ExperienceSpacing.lg,
                vertical: ExperienceSpacing.sm,
              ),
              child: Text(
                'Leave for now',
                style: ExperienceType.label(ExperienceColors.careSkyBottom),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolkitStepSpec {
  const _ToolkitStepSpec({
    required this.id,
    required this.text,
    required this.actionLabel,
    this.title,
    this.semanticsLabel,
    this.isFinal = false,
  });

  final String id;
  final String? title;
  final String text;
  final String actionLabel;
  final String? semanticsLabel;
  final bool isFinal;
}

class _ToolkitRitual {
  const _ToolkitRitual({
    required this.id,
    required this.title,
    required this.intention,
    required this.eyebrow,
    required this.completionLabel,
    required this.steps,
  });

  final String id;
  final String title;
  final String intention;
  final String eyebrow;
  final String completionLabel;
  final List<_ToolkitStepSpec> steps;

  /// The everyday toolkit. Copy is presentation-authored inside existing mode
  /// contracts; every ritual is a guided sequence, not static advice.
  static const List<_ToolkitRitual> catalog = <_ToolkitRitual>[
    _ToolkitRitual(
      id: 'warmth',
      title: 'Warmth on the cramping place',
      intention: 'A heating pad or warm pack, placed with care.',
      eyebrow: 'EVERYDAY CARE · WARMTH',
      completionLabel: 'Complete warmth ritual',
      steps: <_ToolkitStepSpec>[
        _ToolkitStepSpec(
          id: 'settle',
          title: 'Settle first',
          text:
              'Find a position your body can keep for a few minutes. Loosen '
              'anything tight around your waist. Let your shoulders drop.',
          actionLabel: 'I am settled',
        ),
        _ToolkitStepSpec(
          id: 'warm-not-hot',
          title: 'Warm, not hot',
          text:
              'Use warmth you can keep a hand on comfortably. Put a thin '
              'cloth between heat and skin, and never use heat on numb skin '
              'or while you might fall asleep.',
          semanticsLabel:
              'Burn safety: warm, not hot. Use a cloth layer. Never on numb '
              'skin or while asleep.',
          actionLabel: 'Warmth is safe',
        ),
        _ToolkitStepSpec(
          id: 'place',
          title: 'Place it where it speaks',
          text:
              'Rest the warmth over your lower belly or lower back — '
              'whichever is asking louder. Let the weight be gentle.',
          actionLabel: 'It is in place',
        ),
        _ToolkitStepSpec(
          id: 'stay',
          title: 'Stay for three slow breaths',
          text:
              'Breathe out a little longer than you breathe in. Notice one '
              'small place that softens, even by a fraction.',
          actionLabel: 'I stayed with it',
        ),
        _ToolkitStepSpec(
          id: 'complete',
          title: 'Leave the warmth nearby',
          text:
              'When you are ready, set the heat somewhere safe and off. '
              'Completing this ritual is optional and only happens if you '
              'choose it now.',
          actionLabel: 'Complete warmth ritual',
          isFinal: true,
        ),
      ],
    ),
    _ToolkitRitual(
      id: 'warm-shower',
      title: 'A warm shower',
      intention: 'Let water carry some of the tension for a while.',
      eyebrow: 'EVERYDAY CARE · WARMTH',
      completionLabel: 'Complete shower ritual',
      steps: <_ToolkitStepSpec>[
        _ToolkitStepSpec(
          id: 'temperature',
          title: 'Warm, not scalding',
          text:
              'Choose water that feels kind on the inside of your wrist. If '
              'you feel lightheaded, sit down or step out and cool the water.',
          semanticsLabel:
              'Burn safety: warm, not scalding. Sit down or step out if '
              'lightheaded.',
          actionLabel: 'The water is kind',
        ),
        _ToolkitStepSpec(
          id: 'aim',
          title: 'Aim it at the loud places',
          text:
              'Let the water run over your lower back, neck, or shoulders. '
              'No need to scrub anything away — just let it land.',
          actionLabel: 'It is landing',
        ),
        _ToolkitStepSpec(
          id: 'hands',
          title: 'Add one steady hand',
          text:
              'Place a hand where the ache is strongest. Keep it still. '
              'Count four slow breaths, or as many as feel possible.',
          actionLabel: 'I counted a few',
        ),
        _ToolkitStepSpec(
          id: 'after',
          title: 'After the water',
          text:
              'Dry off before you get chilled. Put on the softest layer '
              'within reach. Completing is your choice.',
          actionLabel: 'Complete shower ritual',
          isFinal: true,
        ),
      ],
    ),
    _ToolkitRitual(
      id: 'lower-back-release',
      title: 'Lower-back release',
      intention: 'Small supported movement for a guarded back.',
      eyebrow: 'EVERYDAY CARE · BODY',
      completionLabel: 'Complete back release',
      steps: <_ToolkitStepSpec>[
        _ToolkitStepSpec(
          id: 'support',
          title: 'Give your back a floor',
          text:
              'Lie on your back on a bed or mat, knees bent, feet down. If '
              'the floor is too much today, stay seated and lean back into '
              'a cushion instead.',
          actionLabel: 'I am supported',
        ),
        _ToolkitStepSpec(
          id: 'tilt',
          title: 'A tiny pelvic tilt',
          text:
              'Gently flatten your lower back toward the surface, then let '
              'it go. Slow enough that it almost is not movement.',
          actionLabel: 'I tried the tilt',
        ),
        _ToolkitStepSpec(
          id: 'knees-side',
          title: 'Let the knees wander',
          text:
              'With feet planted, let both knees drift a little to one side, '
              'back to center, then the other side. Stay far inside any '
              'sharp edge.',
          actionLabel: 'They wandered',
        ),
        _ToolkitStepSpec(
          id: 'rest',
          title: 'Rest in the middle',
          text:
              'Come back to center. Let the surface hold the full weight of '
              'your back for three breaths. Complete only if you want to.',
          actionLabel: 'Complete back release',
          isFinal: true,
        ),
      ],
    ),
    _ToolkitRitual(
      id: 'knees-to-chest',
      title: 'Knees-to-chest rest',
      intention: 'A curled, held position for cramps and guarding.',
      eyebrow: 'EVERYDAY CARE · BODY',
      completionLabel: 'Complete knees-to-chest rest',
      steps: <_ToolkitStepSpec>[
        _ToolkitStepSpec(
          id: 'arrive',
          title: 'Arrive on your back',
          text:
              'Lie somewhere comfortable. Bring one knee toward your chest, '
              'then the other if it is welcome. One knee is enough.',
          actionLabel: 'I am here',
        ),
        _ToolkitStepSpec(
          id: 'hold-loosely',
          title: 'Hold loosely',
          text:
              'Rest your hands on your shins or behind your thighs. No '
              'pulling. Let your belly stay soft under your hands.',
          actionLabel: 'My hold is loose',
        ),
        _ToolkitStepSpec(
          id: 'rock',
          title: 'A barely-there rock',
          text:
              'If it feels good, rock an inch side to side. If stillness '
              'feels better, be still. Both count.',
          actionLabel: 'I chose one',
        ),
        _ToolkitStepSpec(
          id: 'release',
          title: 'Release slowly',
          text:
              'Lower one foot, then the other. Notice what changed and what '
              'did not. Completing the ritual is a choice, not a duty.',
          actionLabel: 'Complete knees-to-chest rest',
          isFinal: true,
        ),
      ],
    ),
    _ToolkitRitual(
      id: 'slow-hips',
      title: 'Slow hip and pelvic movement',
      intention: 'Gentle circles that remind the pelvis it can move.',
      eyebrow: 'EVERYDAY CARE · BODY',
      completionLabel: 'Complete hip circles',
      steps: <_ToolkitStepSpec>[
        _ToolkitStepSpec(
          id: 'stance',
          title: 'Find a steady stance',
          text:
              'Stand holding a chair or wall, or sit tall on the edge of a '
              'seat. Let your knees stay soft.',
          actionLabel: 'I am steady',
        ),
        _ToolkitStepSpec(
          id: 'circle-one',
          title: 'One slow circle',
          text:
              'Move your hips in the smallest circle you can find. Slow '
              'enough to feel each quarter of it.',
          actionLabel: 'I made one circle',
        ),
        _ToolkitStepSpec(
          id: 'circle-other',
          title: 'Change direction',
          text:
              'Reverse the circle. Keep it boring on purpose — small, '
              'quiet, and inside comfort.',
          actionLabel: 'I reversed it',
        ),
        _ToolkitStepSpec(
          id: 'pause',
          title: 'Pause and feel',
          text:
              'Stand or sit still. Let the movement echo for a breath. '
              'Complete only if this is where you want to stop.',
          actionLabel: 'Complete hip circles',
          isFinal: true,
        ),
      ],
    ),
    _ToolkitRitual(
      id: 'massage',
      title: 'Belly or back massage',
      intention: 'Your own hands, unhurried, over the tense places.',
      eyebrow: 'EVERYDAY CARE · BODY',
      completionLabel: 'Complete massage ritual',
      steps: <_ToolkitStepSpec>[
        _ToolkitStepSpec(
          id: 'warm-hands',
          title: 'Warm your hands',
          text:
              'Rub your palms together for a few seconds. Warm hands are '
              'kinder than efficient ones.',
          actionLabel: 'My hands are warm',
        ),
        _ToolkitStepSpec(
          id: 'choose-place',
          title: 'Choose one place',
          text:
              'Pick your lower belly or one side of your lower back. Just '
              'one. The rest can wait its turn.',
          actionLabel: 'I chose a place',
        ),
        _ToolkitStepSpec(
          id: 'slow-strokes',
          title: 'Slow strokes outward',
          text:
              'With gentle pressure, stroke from the center outward, like '
              'smoothing a blanket. Six slow strokes is plenty.',
          actionLabel: 'I smoothed it',
        ),
        _ToolkitStepSpec(
          id: 'press-and-breathe',
          title: 'Press and breathe out',
          text:
              'Rest one hand on the tender place. As you breathe out, let '
              'your hand get heavier. Stop before any sharp pain.',
          actionLabel: 'I breathed with it',
        ),
        _ToolkitStepSpec(
          id: 'finish',
          title: 'Finish with stillness',
          text:
              'Keep your hand where it is for one more breath. Completing '
              'is optional and only counts if you choose it.',
          actionLabel: 'Complete massage ritual',
          isFinal: true,
        ),
      ],
    ),
    _ToolkitRitual(
      id: 'rest',
      title: 'Deliberate rest',
      intention: 'Doing nothing on purpose, with a beginning and an end.',
      eyebrow: 'EVERYDAY CARE · REST',
      completionLabel: 'Complete rest ritual',
      steps: <_ToolkitStepSpec>[
        _ToolkitStepSpec(
          id: 'permission',
          title: 'Give it edges',
          text:
              'Decide only this: “I am resting until I choose to stop.” No '
              'timer needed. This is allowed to be unproductive.',
          actionLabel: 'Rest has edges',
        ),
        _ToolkitStepSpec(
          id: 'position',
          title: 'Arrange the soft things',
          text:
              'Pillow under knees, blanket over hips, phone face-down — '
              'whatever makes the next minutes easier to keep.',
          actionLabel: 'It is arranged',
        ),
        _ToolkitStepSpec(
          id: 'one-anchor',
          title: 'One anchor',
          text:
              'Pick one anchor: the weight of the blanket, the sound in the '
              'room, or your breath leaving. Return to it when you drift.',
          actionLabel: 'I have an anchor',
        ),
        _ToolkitStepSpec(
          id: 'end-gently',
          title: 'End gently',
          text:
              'Wiggle fingers and toes. Roll to one side before sitting up. '
              'Complete the rest only if you want it remembered.',
          actionLabel: 'Complete rest ritual',
          isFinal: true,
        ),
      ],
    ),
    _ToolkitRitual(
      id: 'warm-drink',
      title: 'A warm drink, slowly',
      intention: 'Comfort in a cup — a ritual, not a treatment.',
      eyebrow: 'EVERYDAY CARE · COMFORT',
      completionLabel: 'Complete warm drink ritual',
      steps: <_ToolkitStepSpec>[
        _ToolkitStepSpec(
          id: 'comfort-frame',
          title: 'Comfort, not a cure',
          text:
              'This will not fix a cycle and it does not have to. It is '
              'warmth you can hold. The same is true of a warm foot soak: '
              'comfort only, warm rather than hot.',
          semanticsLabel:
              'Framing: a warm drink or foot soak is a comfort ritual, not a '
              'treatment. Warm rather than hot.',
          actionLabel: 'Comfort is enough',
        ),
        _ToolkitStepSpec(
          id: 'safe-sip',
          title: 'Let it cool to kind',
          text:
              'Test it before the first real sip. If a soak is part of this '
              'moment, test the water with a wrist or elbow first.',
          actionLabel: 'It is safe to sip',
        ),
        _ToolkitStepSpec(
          id: 'both-hands',
          title: 'Both hands around the cup',
          text:
              'Wrap both hands around it. Take three slow sips, with a '
              'breath between each one.',
          actionLabel: 'I took three sips',
        ),
        _ToolkitStepSpec(
          id: 'finish-cup',
          title: 'Stop where you want',
          text:
              'You do not need to finish the cup. Completing this ritual '
              'is your choice and only happens from here.',
          actionLabel: 'Complete warm drink ritual',
          isFinal: true,
        ),
      ],
    ),
  ];
}
