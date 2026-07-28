import 'package:flutter/material.dart';

import '../../../design_system/letter_theme.dart';
import '../domain/care_mode.dart';
import 'care_safety_boundary_sheet.dart';
import 'future_self_note_card.dart';

enum PhysicalPainPath { cramps, headache, nausea, body, depleted }

enum PhysicalPainStage { choose, comfort, practical, handoff }

@immutable
class PhysicalPainAction {
  const PhysicalPainAction({required this.actionId, required this.actionLabel});

  final String actionId;
  final String actionLabel;
}

class PhysicalPainFlow extends StatefulWidget {
  const PhysicalPainFlow({
    required this.onReturnToGate,
    required this.onExitCare,
    super.key,
    this.onActionCompleted,
    this.futureSelfNote,
  });

  final VoidCallback onReturnToGate;
  final VoidCallback onExitCare;
  final ValueChanged<PhysicalPainAction>? onActionCompleted;
  final String? futureSelfNote;

  @override
  State<PhysicalPainFlow> createState() => _PhysicalPainFlowState();
}

class _PhysicalPainFlowState extends State<PhysicalPainFlow> {
  PhysicalPainStage _stage = PhysicalPainStage.choose;
  PhysicalPainPath? _path;
  String? _completedActionLabel;
  double _gestureProgress = 0;

  bool get _isHeadache =>
      _path == PhysicalPainPath.headache && _stage != PhysicalPainStage.choose;

  void _selectPath(PhysicalPainPath path) {
    setState(() {
      _path = path;
      _gestureProgress = 0;
      _stage = PhysicalPainStage.comfort;
    });
  }

  void _addGestureProgress(DragUpdateDetails details) {
    if (_isHeadache || _stage != PhysicalPainStage.comfort) {
      return;
    }
    setState(() {
      _gestureProgress = (_gestureProgress + details.delta.distance / 180)
          .clamp(0, 1);
    });
  }

  void _finishGesture(DragEndDetails details) {
    _showPracticalActions();
  }

  void _showPracticalActions() {
    if (_stage != PhysicalPainStage.comfort) {
      return;
    }
    setState(() {
      _gestureProgress = 1;
      _stage = PhysicalPainStage.practical;
    });
  }

  void _completeAction(_ActionOption option) {
    widget.onActionCompleted?.call(
      PhysicalPainAction(actionId: option.actionId, actionLabel: option.label),
    );
    setState(() {
      _completedActionLabel = option.label;
      _stage = PhysicalPainStage.handoff;
    });
  }

  void _finishWithoutAction() {
    setState(() {
      _completedActionLabel = null;
      _stage = PhysicalPainStage.handoff;
    });
  }

  Future<void> _openSafetyBoundary() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      barrierColor: LetterColors.ink.withValues(alpha: 0.42),
      builder: (context) => CareSafetyBoundarySheet(
        kind: CareSafetyKind.physical,
        onLeaveCare: () {
          Navigator.of(context).pop();
          widget.onExitCare();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final background = _isHeadache
        ? const Color(0xFF1F2528)
        : const Color(0xFFF4F5F2);
    final foreground = _isHeadache ? const Color(0xFFF1F2EE) : LetterColors.ink;
    final muted = _isHeadache ? const Color(0xFFB8C0C2) : LetterColors.muted;

    return Scaffold(
      backgroundColor: background,
      bottomNavigationBar: SafeArea(
        top: false,
        child: ColoredBox(
          color: background,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
            child: OutlinedButton.icon(
              key: const Key('physical-safety'),
              onPressed: _openSafetyBoundary,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: foreground,
                backgroundColor: _isHeadache
                    ? const Color(0xFF293135)
                    : LetterColors.surface,
                side: BorderSide(
                  color: _isHeadache
                      ? const Color(0xFF596469)
                      : LetterColors.line,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(LetterRadius.control),
                ),
              ),
              icon: const Icon(Icons.medical_services_outlined),
              label: const Text('This is new, unusual, or severe'),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                  child: _PhysicalHeader(
                    foreground: foreground,
                    muted: muted,
                    onBack: widget.onReturnToGate,
                    onExit: widget.onExitCare,
                  ),
                ),
                const SizedBox(height: LetterSpacing.md),
                Expanded(
                  child: CustomScrollView(
                    key: const Key('physical-pain-scroll'),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
                        sliver: SliverList.list(
                          children: [
                            AnimatedSwitcher(
                              duration: reduceMotion || _isHeadache
                                  ? Duration.zero
                                  : const Duration(milliseconds: 220),
                              child: switch (_stage) {
                                PhysicalPainStage.choose => _buildChoices(),
                                PhysicalPainStage.comfort => _buildComfort(
                                  _path!,
                                  reduceMotion,
                                ),
                                PhysicalPainStage.practical => _buildPractical(
                                  _path!,
                                ),
                                PhysicalPainStage.handoff => _buildHandoff(),
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChoices() {
    return Column(
      key: const ValueKey('physical-choose'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const LetterEyebrow('Physical comfort'),
        const SizedBox(height: LetterSpacing.xs),
        const Text(
          'What feels closest right now?',
          style: TextStyle(
            color: LetterColors.ink,
            fontFamily: 'Newsreader',
            fontSize: 28,
            height: 1.08,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: LetterSpacing.sm),
        const Text(
          'Choose only if it helps. Letter will not turn this into a pain '
          'rating or health record.',
          style: TextStyle(
            color: LetterColors.muted,
            fontSize: 14,
            height: 1.45,
          ),
        ),
        const SizedBox(height: LetterSpacing.lg),
        for (final path in PhysicalPainPath.values) ...[
          _PathChoice(
            config: _pathConfig(path),
            onPressed: () => _selectPath(path),
          ),
          const SizedBox(height: LetterSpacing.sm),
        ],
      ],
    );
  }

  Widget _buildComfort(PhysicalPainPath path, bool reduceMotion) {
    final config = _pathConfig(path);
    return Column(
      key: ValueKey('physical-comfort-${config.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LetterEyebrow(config.eyebrow, color: config.accent),
        const SizedBox(height: LetterSpacing.xs),
        Text(
          config.sceneTitle,
          style: TextStyle(
            color: config.foreground,
            fontFamily: 'Newsreader',
            fontSize: 28,
            height: 1.08,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: LetterSpacing.sm),
        Semantics(
          liveRegion: true,
          child: Text(
            config.firstResponse,
            style: TextStyle(color: config.muted, fontSize: 14, height: 1.45),
          ),
        ),
        const SizedBox(height: LetterSpacing.lg),
        _ComfortSurface(
          config: config,
          progress: _gestureProgress,
          reduceMotion: reduceMotion,
          onTap: _showPracticalActions,
          onPanUpdate: _isHeadache ? null : _addGestureProgress,
          onPanEnd: _isHeadache ? null : _finishGesture,
        ),
        const SizedBox(height: LetterSpacing.md),
        Text(
          config.gestureHint,
          textAlign: TextAlign.center,
          style: TextStyle(color: config.muted, fontSize: 13, height: 1.35),
        ),
        const SizedBox(height: LetterSpacing.lg),
        FilledButton.icon(
          key: const Key('physical-auto-complete'),
          onPressed: _showPracticalActions,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: config.accent,
            foregroundColor: config.buttonForeground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(LetterRadius.control),
            ),
          ),
          icon: Icon(config.autoIcon),
          label: Text(config.autoLabel),
        ),
      ],
    );
  }

  Widget _buildPractical(PhysicalPainPath path) {
    final config = _pathConfig(path);
    return Column(
      key: ValueKey('physical-practical-${config.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(config.transformedIcon, size: 68, color: config.accent),
        const SizedBox(height: LetterSpacing.lg),
        LetterEyebrow('One familiar comfort', color: config.accent),
        const SizedBox(height: LetterSpacing.xs),
        Text(
          config.transformedLine,
          style: TextStyle(
            color: config.foreground,
            fontFamily: 'Newsreader',
            fontSize: 28,
            height: 1.08,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: LetterSpacing.sm),
        Text(
          'Comfort is personal. Choose only something already familiar to '
          'your body. Letter is not assessing or treating this pain.',
          style: TextStyle(color: config.muted, fontSize: 14, height: 1.45),
        ),
        const SizedBox(height: LetterSpacing.lg),
        for (final option in config.actions) ...[
          OutlinedButton.icon(
            key: Key('physical-action-${option.actionId}'),
            onPressed: () => _completeAction(option),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              alignment: Alignment.centerLeft,
              foregroundColor: config.foreground,
              backgroundColor: config.surface,
              side: BorderSide(color: config.line),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(LetterRadius.control),
              ),
            ),
            icon: Icon(option.icon, color: config.accent),
            label: Text(option.label),
          ),
          const SizedBox(height: LetterSpacing.sm),
        ],
        TextButton(
          key: const Key('physical-no-action'),
          onPressed: _finishWithoutAction,
          style: TextButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            foregroundColor: config.muted,
          ),
          child: const Text('Nothing else right now'),
        ),
      ],
    );
  }

  Widget _buildHandoff() {
    final config = _pathConfig(_path!);
    return Column(
      key: const ValueKey('physical-handoff'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: LetterSpacing.xl),
        Icon(Icons.nights_stay_outlined, size: 68, color: config.accent),
        const SizedBox(height: LetterSpacing.lg),
        LetterEyebrow('Enough for now', color: config.accent),
        const SizedBox(height: LetterSpacing.xs),
        Text(
          _completedActionLabel == null
              ? 'Nothing else is required.'
              : 'You chose one familiar comfort.',
          style: TextStyle(
            color: config.foreground,
            fontFamily: 'Newsreader',
            fontSize: 29,
            height: 1.08,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: LetterSpacing.sm),
        Text(
          _completedActionLabel == null
              ? 'Letter has not created a symptom or pain record.'
              : _completedActionLabel!,
          style: TextStyle(color: config.muted, fontSize: 15, height: 1.4),
        ),
        const SizedBox(height: LetterSpacing.xl),
        if (widget.futureSelfNote case final note?) ...[
          FutureSelfNoteCard(note: note),
          const SizedBox(height: LetterSpacing.lg),
        ],
        FilledButton.icon(
          key: const Key('physical-handoff-return'),
          onPressed: widget.onReturnToGate,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: config.accent,
            foregroundColor: config.buttonForeground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(LetterRadius.control),
            ),
          ),
          icon: const Icon(Icons.grid_view_outlined),
          label: const Text('Return to Care choices'),
        ),
        const SizedBox(height: LetterSpacing.sm),
        OutlinedButton.icon(
          key: const Key('physical-handoff-exit'),
          onPressed: widget.onExitCare,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            foregroundColor: config.foreground,
            backgroundColor: config.surface,
            side: BorderSide(color: config.line),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(LetterRadius.control),
            ),
          ),
          icon: const Icon(Icons.close),
          label: const Text('Leave Care'),
        ),
      ],
    );
  }
}

class _PhysicalHeader extends StatelessWidget {
  const _PhysicalHeader({
    required this.foreground,
    required this.muted,
    required this.onBack,
    required this.onExit,
  });

  final Color foreground;
  final Color muted;
  final VoidCallback onBack;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return IconTheme(
      data: IconThemeData(color: foreground),
      child: Row(
        children: [
          IconButton(
            key: const Key('physical-back-to-care'),
            tooltip: 'Back to Care choices',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back),
          ),
          Expanded(
            child: Text(
              'Physical comfort',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: muted,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            key: const Key('physical-exit-care'),
            tooltip: 'Leave Care',
            onPressed: onExit,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _PathChoice extends StatelessWidget {
  const _PathChoice({required this.config, required this.onPressed});

  final _PathConfig config;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      key: Key('physical-path-${config.id}'),
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(62),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        alignment: Alignment.centerLeft,
        foregroundColor: LetterColors.ink,
        backgroundColor: LetterColors.surface,
        side: const BorderSide(color: LetterColors.line),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LetterRadius.control),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: config.soft,
              borderRadius: BorderRadius.circular(LetterRadius.control),
            ),
            child: Icon(config.icon, color: config.accent, size: 22),
          ),
          const SizedBox(width: LetterSpacing.sm),
          Expanded(
            child: Text(
              config.label,
              style: const TextStyle(
                fontSize: 15,
                height: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: LetterSpacing.xs),
          const Icon(Icons.chevron_right, size: 22),
        ],
      ),
    );
  }
}

class _ComfortSurface extends StatelessWidget {
  const _ComfortSurface({
    required this.config,
    required this.progress,
    required this.reduceMotion,
    required this.onTap,
    required this.onPanUpdate,
    required this.onPanEnd,
  });

  final _PathConfig config;
  final double progress;
  final bool reduceMotion;
  final VoidCallback onTap;
  final GestureDragUpdateCallback? onPanUpdate;
  final GestureDragEndCallback? onPanEnd;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.45;
    return Semantics(
      button: true,
      label: config.surfaceSemantics,
      child: GestureDetector(
        key: Key('physical-comfort-surface-${config.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onPanUpdate: onPanUpdate,
        onPanEnd: onPanEnd,
        child: AnimatedContainer(
          duration: reduceMotion || config.path == PhysicalPainPath.headache
              ? Duration.zero
              : const Duration(milliseconds: 240),
          height: largeText ? 172 : 230,
          width: double.infinity,
          decoration: BoxDecoration(
            color: config.surface,
            borderRadius: BorderRadius.circular(LetterRadius.panel),
            border: Border.all(color: config.line),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (config.path == PhysicalPainPath.headache)
                const _HeadacheStillField()
              else
                _TransformField(config: config, progress: progress),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Text(
                  config.surfaceLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: config.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransformField extends StatelessWidget {
  const _TransformField({required this.config, required this.progress});

  final _PathConfig config;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final scale = 1 - (progress * 0.16);
    final turns = config.path == PhysicalPainPath.nausea
        ? progress * 0.08
        : 0.0;
    return Transform.rotate(
      angle: turns,
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: 112,
          height: 112,
          decoration: BoxDecoration(
            color: Color.lerp(config.soft, config.surface, progress),
            shape: config.path == PhysicalPainPath.depleted
                ? BoxShape.rectangle
                : BoxShape.circle,
            borderRadius: config.path == PhysicalPainPath.depleted
                ? BorderRadius.circular(8)
                : null,
            border: Border.all(color: config.accent, width: 2),
          ),
          alignment: Alignment.center,
          child: Icon(config.sceneIcon, size: 50, color: config.accent),
        ),
      ),
    );
  }
}

class _HeadacheStillField extends StatelessWidget {
  const _HeadacheStillField();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.brightness_2_outlined,
      size: 72,
      color: Color(0xFF9CAEB5),
    );
  }
}

@immutable
class _ActionOption {
  const _ActionOption(this.actionId, this.label, this.icon);

  final String actionId;
  final String label;
  final IconData icon;
}

@immutable
class _PathConfig {
  const _PathConfig({
    required this.path,
    required this.id,
    required this.label,
    required this.eyebrow,
    required this.sceneTitle,
    required this.firstResponse,
    required this.gestureHint,
    required this.surfaceLabel,
    required this.surfaceSemantics,
    required this.autoLabel,
    required this.transformedLine,
    required this.icon,
    required this.sceneIcon,
    required this.autoIcon,
    required this.transformedIcon,
    required this.accent,
    required this.soft,
    required this.surface,
    required this.line,
    required this.foreground,
    required this.muted,
    required this.buttonForeground,
    required this.actions,
  });

  final PhysicalPainPath path;
  final String id;
  final String label;
  final String eyebrow;
  final String sceneTitle;
  final String firstResponse;
  final String gestureHint;
  final String surfaceLabel;
  final String surfaceSemantics;
  final String autoLabel;
  final String transformedLine;
  final IconData icon;
  final IconData sceneIcon;
  final IconData autoIcon;
  final IconData transformedIcon;
  final Color accent;
  final Color soft;
  final Color surface;
  final Color line;
  final Color foreground;
  final Color muted;
  final Color buttonForeground;
  final List<_ActionOption> actions;
}

_PathConfig _pathConfig(PhysicalPainPath path) {
  return switch (path) {
    PhysicalPainPath.cramps => const _PathConfig(
      path: PhysicalPainPath.cramps,
      id: 'cramps',
      label: 'Cramps or back pain',
      eyebrow: 'Warm the edges',
      sceneTitle: 'Give the knot more room.',
      firstResponse:
          'The screen can soften around the pain without asking you to rate it.',
      gestureHint: 'Trace once to loosen the knot, or use the button below.',
      surfaceLabel: 'Trace or tap once',
      surfaceSemantics:
          'A warm knot. Trace or tap once to finish the visual comfort action.',
      autoLabel: 'Soften it for me',
      transformedLine: 'The knot has more room on this screen.',
      icon: Icons.blur_circular_outlined,
      sceneIcon: Icons.all_inclusive,
      autoIcon: Icons.wb_sunny_outlined,
      transformedIcon: Icons.spa_outlined,
      accent: Color(0xFF9B4F42),
      soft: Color(0xFFF6E4DF),
      surface: Color(0xFFFFFBF9),
      line: Color(0xFFE8C9C1),
      foreground: LetterColors.ink,
      muted: LetterColors.muted,
      buttonForeground: Colors.white,
      actions: [
        _ActionOption(
          'cramps_familiar_warmth',
          'Get familiar warmth',
          Icons.wb_sunny_outlined,
        ),
        _ActionOption(
          'cramps_change_position',
          'Change position',
          Icons.airline_seat_recline_normal,
        ),
      ],
    ),
    PhysicalPainPath.headache => const _PathConfig(
      path: PhysicalPainPath.headache,
      id: 'headache',
      label: 'Headache or migraine',
      eyebrow: 'Less input',
      sceneTitle: 'The screen is dark and still.',
      firstResponse:
          'No sound, haptics, flashing, pulsing, or decorative motion will start here.',
      gestureHint: 'No gesture is needed. Tap once or use the button below.',
      surfaceLabel: 'Tap once when ready',
      surfaceSemantics:
          'A dark still field. Tap once to continue without animation, sound, or haptics.',
      autoLabel: 'Keep it still',
      transformedLine: 'The screen will stay quiet.',
      icon: Icons.brightness_4_outlined,
      sceneIcon: Icons.brightness_2_outlined,
      autoIcon: Icons.visibility_off_outlined,
      transformedIcon: Icons.nights_stay_outlined,
      accent: Color(0xFF9CAEB5),
      soft: Color(0xFF313A3E),
      surface: Color(0xFF252D31),
      line: Color(0xFF596469),
      foreground: Color(0xFFF1F2EE),
      muted: Color(0xFFB8C0C2),
      buttonForeground: Color(0xFF1F2528),
      actions: [
        _ActionOption(
          'headache_dim_room',
          'Dim the room if that is familiar',
          Icons.light_mode_outlined,
        ),
        _ActionOption(
          'headache_rest_still',
          'Rest somewhere still',
          Icons.hotel_outlined,
        ),
      ],
    ),
    PhysicalPainPath.nausea => const _PathConfig(
      path: PhysicalPainPath.nausea,
      id: 'nausea',
      label: 'Nausea or bloating',
      eyebrow: 'Settle the surface',
      sceneTitle: 'Let the surface become steady.',
      firstResponse:
          'You do not need to explain the sensation or keep touching the screen.',
      gestureHint: 'Sweep once to settle the surface, or use the button below.',
      surfaceLabel: 'Sweep or tap once',
      surfaceSemantics:
          'A disturbed surface. Sweep or tap once to finish the visual comfort action.',
      autoLabel: 'Settle it for me',
      transformedLine: 'The surface is steady now.',
      icon: Icons.waves_outlined,
      sceneIcon: Icons.water_outlined,
      autoIcon: Icons.horizontal_rule,
      transformedIcon: Icons.water_drop_outlined,
      accent: Color(0xFF287078),
      soft: Color(0xFFDDEFF0),
      surface: Color(0xFFF8FCFC),
      line: Color(0xFFB8D8DA),
      foreground: LetterColors.ink,
      muted: LetterColors.muted,
      buttonForeground: Colors.white,
      actions: [
        _ActionOption(
          'nausea_change_position',
          'Change position',
          Icons.airline_seat_recline_normal,
        ),
        _ActionOption(
          'nausea_reduce_pressure',
          'Loosen familiar clothing or support',
          Icons.checkroom_outlined,
        ),
      ],
    ),
    PhysicalPainPath.body => const _PathConfig(
      path: PhysicalPainPath.body,
      id: 'body',
      label: 'Breast, muscle, or joint discomfort',
      eyebrow: 'Loosen one thread',
      sceneTitle: 'Nothing needs to be pulled tight.',
      firstResponse:
          'One small release is enough. The screen will not ask where or how much.',
      gestureHint: 'Draw once to loosen the thread, or use the button below.',
      surfaceLabel: 'Draw or tap once',
      surfaceSemantics:
          'A taut thread. Draw or tap once to finish the visual comfort action.',
      autoLabel: 'Loosen it for me',
      transformedLine: 'One thread is loose.',
      icon: Icons.gesture_outlined,
      sceneIcon: Icons.timeline_outlined,
      autoIcon: Icons.linear_scale,
      transformedIcon: Icons.air_outlined,
      accent: Color(0xFF6B5B88),
      soft: Color(0xFFEDE8F4),
      surface: Color(0xFFFCFAFE),
      line: Color(0xFFD7CDE4),
      foreground: LetterColors.ink,
      muted: LetterColors.muted,
      buttonForeground: Colors.white,
      actions: [
        _ActionOption(
          'body_familiar_support',
          'Use familiar physical support',
          Icons.back_hand_outlined,
        ),
        _ActionOption(
          'body_change_position',
          'Change position',
          Icons.accessibility_new,
        ),
      ],
    ),
    PhysicalPainPath.depleted => const _PathConfig(
      path: PhysicalPainPath.depleted,
      id: 'depleted',
      label: 'Completely drained',
      eyebrow: 'Close the extra noise',
      sceneTitle: 'Make the screen ask for less.',
      firstResponse:
          'No energy score is needed. This screen can become simpler now.',
      gestureHint: 'Sweep once to close the noise, or use the button below.',
      surfaceLabel: 'Sweep or tap once',
      surfaceSemantics:
          'A field of visual noise. Sweep or tap once to close the extra input.',
      autoLabel: 'Close it for me',
      transformedLine: 'The extra visual noise is closed.',
      icon: Icons.battery_1_bar_outlined,
      sceneIcon: Icons.filter_none_outlined,
      autoIcon: Icons.close_fullscreen_outlined,
      transformedIcon: Icons.do_not_disturb_on_outlined,
      accent: Color(0xFF526B57),
      soft: Color(0xFFE3ECE4),
      surface: Color(0xFFFAFCFA),
      line: Color(0xFFC9D8CB),
      foreground: LetterColors.ink,
      muted: LetterColors.muted,
      buttonForeground: Colors.white,
      actions: [
        _ActionOption(
          'depleted_reduce_demands',
          'Set one demand aside',
          Icons.remove_done_outlined,
        ),
        _ActionOption(
          'depleted_rest',
          'Rest without another task',
          Icons.hotel_outlined,
        ),
      ],
    ),
  };
}
