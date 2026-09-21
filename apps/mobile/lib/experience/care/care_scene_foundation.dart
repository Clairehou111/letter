import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../features/care/domain/care_mode.dart';
import '../theme/experience_foundation.dart';
import 'care_animation_port.dart';

/// One paced step inside a Care scene.
///
/// Presentation-authored copy lives here, inside the existing mode contracts.
/// Steps are never advanced by punishing timers; progression is either the
/// scene's slow fade or the person's deliberate primary action.
class CareSceneStep {
  const CareSceneStep({
    required this.id,
    required this.text,
    required this.primaryActionLabel,
    this.title,
    this.onPrimaryAction,
    this.semanticsLabel,
    this.advances = true,
  });

  /// Stable identity used for focus, keys, and interruption recovery.
  final String id;

  /// Optional short step headline rendered above [text].
  final String? title;

  /// The current step text. Identical in full, reduced, and static scenes.
  final String text;

  /// The single visible primary action for this step.
  final String primaryActionLabel;

  /// Runs after [CareSceneSignal.primaryInteraction] is emitted.
  final VoidCallback? onPrimaryAction;

  /// Screen-reader override for the step text.
  final String? semanticsLabel;

  /// Whether pressing the primary action moves to the next step. Final steps
  /// set this to `false` and hand completion to their owner.
  final bool advances;
}

/// Shared Care scene runtime and the seam consumed by the five mode scenes,
/// the toolkit, and the completion flow.
///
/// **One ground-plane geometry for every Care surface.** The shell composes
/// each scene in three depth layers, in a fixed order that never varies by
/// mode, motion preference, or recovery state:
///
///  1. **Backfield** — the plum-dusk gradient filling the scene.
///  2. **Ground plane** — the ground line and the ember resting on it with
///     visible weight, laid out inside the stage region *above* the control
///     shelf. The ember is therefore structurally incapable of rendering
///     below the exit pill or the system navigation inset, in every scene,
///     every motion preference, and the interruption-recovery landing alike.
///  3. **Foreground control shelf** — pinned to the bottom foreground:
///     the single primary action, the quiet safety line, and the exit pill,
///     which is always the bottom-most persistent control. Scene copy lives
///     in a scrollable region between the title and the shelf, so 200% text
///     scrolls instead of pushing the exit pill off-screen.
///
/// The shell honors all three [CareSceneMotionPreference] values with
/// identical copy, steps, and controls; emits the shared [CareSceneSignal]s
/// through the same `ValueChanged<CareSceneSignal>` seam used by
/// [CareAnimationPort]; keeps exit persistent, high-contrast, and unlocked;
/// renders exactly one primary action at a time; excludes the breathing
/// ember from the accessibility tree; and moves focus to the new step text
/// exactly once per [CareSceneSignal.stepCompleted].
abstract final class CareSceneFoundation {
  /// Scene ground line, as a fraction of the stage region's height (the
  /// region between the header and the pinned control shelf). The ember
  /// rests on this line; the shelf always sits below it.
  static const double groundLineFraction = 0.72;

  /// Default calm exit copy. Owners may override for mode-specific landings.
  static const String defaultExitLabel = 'Leave for now';

  /// Quiet, persistent safety access line. Tapping routes to the
  /// deterministic safety surface owned by the Care experience.
  static const String defaultSafetyLine =
      'If this feels bigger than this moment, support is here.';

  /// Slow step fades, never bounces. Reduced motion keeps a crossfade;
  /// static fallback settles instantly with the same copy and controls.
  static Duration stepTransition(CareSceneMotionPreference motion) {
    return switch (motion) {
      CareSceneMotionPreference.full => const Duration(milliseconds: 450),
      CareSceneMotionPreference.reduced => const Duration(milliseconds: 250),
      CareSceneMotionPreference.staticFallback => Duration.zero,
    };
  }

  /// Builds one immersive, interruptible Care scene.
  ///
  /// The same composition serves live scenes and the interruption-recovery
  /// landing (via [initialStepIndex] / [resumeHint]), so every Care surface
  /// shares one ground-plane geometry.
  static Widget scene({
    Key? key,
    required CareMode mode,
    required String eyebrow,
    required String title,
    required List<CareSceneStep> steps,
    required CareSceneMotionPreference motionPreference,
    required ValueChanged<CareSceneSignal> onSignal,
    VoidCallback? onExit,
    VoidCallback? onSafety,
    String exitLabel = defaultExitLabel,
    String safetyLine = defaultSafetyLine,
    int initialStepIndex = 0,
    String? resumeHint,
    double emberSize = 132,
  }) {
    assert(steps.isNotEmpty, 'A Care scene needs at least one paced step.');
    assert(
      initialStepIndex >= 0 && initialStepIndex < steps.length,
      'initialStepIndex must name a real step.',
    );
    return _CareSceneShell(
      key: key,
      mode: mode,
      eyebrow: eyebrow,
      title: title,
      steps: steps,
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

class _CareSceneShell extends StatefulWidget {
  const _CareSceneShell({
    super.key,
    required this.mode,
    required this.eyebrow,
    required this.title,
    required this.steps,
    required this.motionPreference,
    required this.onSignal,
    required this.onExit,
    required this.onSafety,
    required this.exitLabel,
    required this.safetyLine,
    required this.initialStepIndex,
    required this.resumeHint,
    required this.emberSize,
  });

  final CareMode mode;
  final String eyebrow;
  final String title;
  final List<CareSceneStep> steps;
  final CareSceneMotionPreference motionPreference;
  final ValueChanged<CareSceneSignal> onSignal;
  final VoidCallback? onExit;
  final VoidCallback? onSafety;
  final String exitLabel;
  final String safetyLine;
  final int initialStepIndex;
  final String? resumeHint;
  final double emberSize;

  @override
  State<_CareSceneShell> createState() => _CareSceneShellState();
}

class _CareSceneShellState extends State<_CareSceneShell> {
  late int _index = widget.initialStepIndex;
  late List<FocusNode> _stepFocusNodes = _createStepNodes();
  bool _readySent = false;

  List<FocusNode> _createStepNodes() {
    return List<FocusNode>.generate(
      widget.steps.length,
      (i) => FocusNode(debugLabel: 'care-step-${widget.steps[i].id}'),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _readySent) return;
      _readySent = true;
      widget.onSignal(CareSceneSignal.ready);
      if (_index != 0 || widget.resumeHint != null) {
        // A recovered scene lands directly on its named step; focus moves
        // there once so the journey is resumable without live-region noise.
        _stepFocusNodes[_index].requestFocus();
      }
    });
  }

  @override
  void didUpdateWidget(covariant _CareSceneShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.steps.length != widget.steps.length ||
        !_sameStepIds(oldWidget.steps, widget.steps)) {
      for (final node in _stepFocusNodes) {
        node.dispose();
      }
      _stepFocusNodes = _createStepNodes();
      if (_index >= widget.steps.length) {
        _index = widget.steps.length - 1;
      }
    }
  }

  bool _sameStepIds(List<CareSceneStep> a, List<CareSceneStep> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  @override
  void dispose() {
    for (final node in _stepFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _handlePrimary(CareSceneStep step) {
    widget.onSignal(CareSceneSignal.primaryInteraction);
    step.onPrimaryAction?.call();
    if (!step.advances || _index >= widget.steps.length - 1) {
      return;
    }
    final next = _index + 1;
    setState(() => _index = next);
    ExperienceHaptics.careStepCompleted();
    widget.onSignal(CareSceneSignal.stepCompleted);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Each completed step moves focus to the new step text once. Ambient
      // ember motion never speaks and never steals focus.
      _stepFocusNodes[next].requestFocus();
    });
  }

  void _handleExit() {
    // Exit is persistent, high-contrast, and never locked — even mid-fade.
    widget.onSignal(CareSceneSignal.requestedExit);
    widget.onExit?.call();
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_index];
    final motion = widget.motionPreference;
    final transition = CareSceneFoundation.stepTransition(motion);

    return Semantics(
      container: true,
      label: 'Care: ${widget.mode.label}',
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // Layer 1 — backfield: plum dusk. Red never dominates; the ember
            // is the single warm light source.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: ExperienceColors.careBackdrop,
              ),
            ),
            // Layers 2 + 3 — the ground plane lives inside the stage region
            // *above* the pinned control shelf, so the ember can never sit
            // below the exit pill or the system navigation inset in any
            // scene, motion preference, or recovery composition.
            SafeArea(
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
                    FocusTraversalOrder(
                      order: const NumericFocusOrder(1),
                      child: Semantics(
                        header: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            Text(
                              widget.eyebrow.toUpperCase(),
                              style: ExperienceType.eyebrow(
                                ExperienceColors.careInkSoft,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: ExperienceSpacing.xs),
                            Text(
                              widget.title,
                              style: ExperienceType.headline(
                                ExperienceColors.careInk,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: ExperienceSpacing.sm),
                    // Layer 2 — stage: ground line + resting ember, with the
                    // scrollable step copy held above the ember so large text
                    // scrolls instead of displacing the pinned shelf.
                    Expanded(
                      child: _CareSceneStage(
                        step: step,
                        resumeHint: widget.resumeHint,
                        emberSize: widget.emberSize,
                        motion: motion,
                        transition: transition,
                        stepFocusNode: _stepFocusNodes[_index],
                      ),
                    ),
                    const SizedBox(height: ExperienceSpacing.md),
                    // Layer 3 — foreground control shelf, pinned to the
                    // bottom. Exactly one primary action is visible at a
                    // time; the exit pill is always the bottom-most control.
                    FocusTraversalOrder(
                      order: const NumericFocusOrder(3),
                      child: _CarePrimaryAction(
                        label: step.primaryActionLabel,
                        onPressed: () => _handlePrimary(step),
                      ),
                    ),
                    const SizedBox(height: ExperienceSpacing.sm),
                    FocusTraversalOrder(
                      order: const NumericFocusOrder(5),
                      child: _CareSafetyLine(
                        line: widget.safetyLine,
                        onTap: widget.onSafety,
                      ),
                    ),
                    const SizedBox(height: ExperienceSpacing.sm),
                    FocusTraversalOrder(
                      order: const NumericFocusOrder(4),
                      child: _CareExitPill(
                        label: widget.exitLabel,
                        onPressed: _handleExit,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The stage region between the header and the pinned control shelf.
///
/// Geometry contract, identical for every scene and the recovery landing:
/// the ember rests on the ground line at ~[CareSceneFoundation
/// .groundLineFraction] of the stage when space allows, clamped so its
/// bottom edge always stays inside the stage (never dipping into the shelf
/// or the navigation inset), and its size shrinks on short stages so the
/// composition survives small screens and 200% text. Step copy occupies the
/// region above the ember and scrolls within it.
class _CareSceneStage extends StatelessWidget {
  const _CareSceneStage({
    required this.step,
    required this.resumeHint,
    required this.emberSize,
    required this.motion,
    required this.transition,
    required this.stepFocusNode,
  });

  final CareSceneStep step;
  final String? resumeHint;
  final double emberSize;
  final CareSceneMotionPreference motion;
  final Duration transition;
  final FocusNode stepFocusNode;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stageHeight = constraints.maxHeight;
        // The ember never claims more than a calm share of the stage; on
        // short stages it shrinks rather than colliding with header or shelf.
        final ember = math.min(emberSize, math.max(72.0, stageHeight * 0.42));
        // Rest the ember on the ground line near the designed fraction,
        // clamped so the orb's bottom edge (32% of its size below the line,
        // plus its soft contact shadow) never leaves the stage.
        final idealGroundDy =
            stageHeight * CareSceneFoundation.groundLineFraction;
        final groundDy = math.min(idealGroundDy, stageHeight - ember * 0.34);
        final emberTop = math.max(0.0, groundDy - ember * 0.68);
        // Copy lives strictly above the ember and scrolls within its region,
        // so it can never paint over the orb or push the shelf off-screen.
        final copyHeight = math.max(0.0, emberTop - ExperienceSpacing.sm);

        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // Ground line + glow. The future companion enters along this
            // line; current scenes already honor it, so the animation pass
            // replaces rendering, never journey.
            ExcludeSemantics(
              child: CustomPaint(
                painter: _GroundLinePainter(groundDy: groundDy),
              ),
            ),
            Positioned(
              top: groundDy - 5,
              left: 0,
              right: 0,
              child: ExcludeSemantics(
                child: Center(
                  child: Container(
                    width: ember * 0.9,
                    height: 10,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: RadialGradient(
                        colors: <Color>[
                          Colors.black.withValues(alpha: 0.35),
                          Colors.black.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // The held ember, resting on the ground line with visible
            // weight. Decorative — excluded from the accessibility tree.
            Positioned(
              top: emberTop,
              left: 0,
              right: 0,
              child: Center(
                child: EmberOrb(size: ember, breathing: true, motion: motion),
              ),
            ),
            // Step copy: scrollable between the title and the shelf.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: copyHeight,
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: copyHeight),
                  child: AnimatedSwitcher(
                    duration: transition,
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: FocusTraversalOrder(
                      key: ValueKey<String>(step.id),
                      order: const NumericFocusOrder(2),
                      child: Focus(
                        focusNode: stepFocusNode,
                        child: Semantics(
                          focusable: true,
                          liveRegion: false,
                          label: step.semanticsLabel ?? step.text,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: <Widget>[
                              if (resumeHint != null) ...<Widget>[
                                Text(
                                  resumeHint!,
                                  style: ExperienceType.bodySmall(
                                    ExperienceColors.careInkSoft,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: ExperienceSpacing.sm),
                              ],
                              if (step.title != null) ...<Widget>[
                                Text(
                                  step.title!,
                                  style: ExperienceType.title(
                                    ExperienceColors.careInk,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: ExperienceSpacing.sm),
                              ],
                              Text(
                                step.text,
                                style: ExperienceType.body(
                                  ExperienceColors.careInk,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GroundLinePainter extends CustomPainter {
  const _GroundLinePainter({required this.groundDy});

  /// Absolute y of the ground line within the stage region.
  final double groundDy;

  @override
  void paint(Canvas canvas, Size size) {
    final y = groundDy;
    final line = Paint()
      ..strokeWidth = 1
      ..shader = LinearGradient(
        colors: <Color>[
          ExperienceColors.careGlassBorder.withValues(alpha: 0),
          ExperienceColors.careGlassBorder,
          ExperienceColors.careGlassBorder.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromLTWH(0, y, size.width, 1));
    canvas.drawLine(Offset(0, y), Offset(size.width, y), line);

    final glowRect = Rect.fromCenter(
      center: Offset(size.width / 2, y),
      width: size.width * 0.72,
      height: 56,
    );
    final glow = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          ExperienceColors.emberGlow.withValues(alpha: 0.5),
          ExperienceColors.emberGlow.withValues(alpha: 0),
        ],
      ).createShader(glowRect);
    canvas.drawRect(glowRect, glow);
  }

  @override
  bool shouldRepaint(_GroundLinePainter oldDelegate) {
    return oldDelegate.groundDy != groundDy;
  }
}

class _CarePrimaryAction extends StatelessWidget {
  const _CarePrimaryAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: ExperienceSpacing.degreeTarget,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: ExperienceColors.emberGradient,
            borderRadius: ExperienceRadius.heroRadius,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: ExperienceColors.emberGlow.withValues(alpha: 0.55),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: ExperienceRadius.heroRadius,
              onTap: onPressed,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: ExperienceSpacing.lg,
                  vertical: ExperienceSpacing.sm,
                ),
                child: Text(
                  label,
                  style: ExperienceType.label(Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CareExitPill extends StatelessWidget {
  const _CareExitPill({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label. Exit is always available.',
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
                label,
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

class _CareSafetyLine extends StatelessWidget {
  const _CareSafetyLine({required this.line, required this.onTap});

  final String line;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      line,
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
      label: line,
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
