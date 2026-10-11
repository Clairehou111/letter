import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../experience/theme/experience_foundation.dart';

/// A single working face, backed by two quiet surfaces. Each workspace keeps
/// its own element tree when the foreground changes; no health data is copied.
class RecordWorkspaceStage extends StatefulWidget {
  const RecordWorkspaceStage({
    super.key,
    required this.selectedIndex,
    required this.children,
  }) : assert(selectedIndex >= 0 && selectedIndex < children.length);

  final int selectedIndex;
  final List<Widget> children;

  @override
  State<RecordWorkspaceStage> createState() => _RecordWorkspaceStageState();
}

class _RecordWorkspaceStageState extends State<RecordWorkspaceStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _handoff;
  late List<_FacePose> _from, _to;
  bool _reduced = false;
  int? _outgoing;

  @override
  void initState() {
    super.initState();
    _handoff = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      value: 1,
    );
    _from = _restingPoses();
    _to = List.of(_from);
  }

  List<_FacePose> _restingPoses() => [
    for (var index = 0; index < widget.children.length; index++)
      index == widget.selectedIndex
          ? _FacePose.front
          : _FacePose.waiting(index > widget.selectedIndex ? 1 : -1),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = ExperienceMotion.reducedMotion(context);
    if (reduced && !_reduced) {
      _handoff.stop();
      _from = _restingPoses();
      _to = List.of(_from);
      _outgoing = null;
      _handoff.value = 1;
    }
    _reduced = reduced;
  }

  @override
  void didUpdateWidget(covariant RecordWorkspaceStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.children.length != widget.children.length) {
      _handoff.stop();
      _from = _restingPoses();
      _to = List.of(_from);
      _outgoing = null;
      _handoff.value = 1;
      return;
    }
    if (oldWidget.selectedIndex == widget.selectedIndex) return;
    final direction = widget.selectedIndex > oldWidget.selectedIndex ? 1 : -1;
    final current = [
      for (var index = 0; index < widget.children.length; index++)
        _pose(index, selectedIndex: oldWidget.selectedIndex),
    ];
    _handoff.stop();
    _outgoing = oldWidget.selectedIndex;
    _from = [
      for (var index = 0; index < current.length; index++)
        if (index == widget.selectedIndex)
          current[index].opacity < .001
              ? _FacePose.waiting(direction)
              : current[index]
        else if (index == _outgoing)
          current[index]
        else
          _FacePose.waiting(index > widget.selectedIndex ? 1 : -1),
    ];
    _to = [
      for (var index = 0; index < current.length; index++)
        if (index == widget.selectedIndex)
          _FacePose.front
        else if (index == _outgoing)
          _FacePose(x: -32.0 * direction, y: 6, scale: .97, opacity: 0)
        else
          _from[index],
    ];
    if (_reduced) {
      _from = List.of(_to);
      _outgoing = null;
      _handoff.value = 1;
    } else {
      _handoff.forward(from: 0);
    }
  }

  _FacePose _pose(int index, {int? selectedIndex}) {
    final progress = _handoff.value;
    final movement = Curves.easeOutCubic.transform(progress);
    final settling = Curves.easeOutBack.transform(progress);
    final incoming = index == (selectedIndex ?? widget.selectedIndex);
    final fadeProgress = incoming
        ? ((progress - .08) / .60).clamp(0.0, 1.0)
        : (progress / .38).clamp(0.0, 1.0);
    return _FacePose(
      x: _mix(_from[index].x, _to[index].x, movement),
      y: _mix(_from[index].y, _to[index].y, movement),
      scale: _mix(_from[index].scale, _to[index].scale, settling),
      opacity: _mix(
        _from[index].opacity,
        _to[index].opacity,
        Curves.easeOut.transform(fadeProgress),
      ).clamp(0.0, 1.0),
    );
  }

  @override
  void dispose() {
    _handoff.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rounding = BorderRadius.circular(26);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
      child: AnimatedBuilder(
        animation: _handoff,
        builder: (context, _) {
          final lift = _reduced ? 0.0 : math.sin(_handoff.value * math.pi) * 4;
          final paintOrder = [
            for (var i = 0; i < widget.children.length; i++)
              if (i != widget.selectedIndex) i,
            widget.selectedIndex,
          ];
          return ClipRect(
            child: Stack(
              key: const Key('record-workspace-stage'),
              fit: StackFit.expand,
              children: [
                Positioned(
                  top: 0,
                  left: 16 + lift,
                  right: 16 + lift,
                  bottom: 24,
                  child: _BackingSurface(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderColor: theme.colorScheme.outlineVariant,
                    radius: rounding,
                  ),
                ),
                Positioned(
                  top: 8 - lift / 2,
                  left: 8 + lift / 2,
                  right: 8 + lift / 2,
                  bottom: 12,
                  child: _BackingSurface(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderColor: theme.colorScheme.outlineVariant,
                    radius: rounding,
                  ),
                ),
                for (final index in paintOrder)
                  Positioned.fill(
                    key: ValueKey('record-stage-face-$index'),
                    top: 16,
                    child: _face(index, rounding, theme),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _face(int index, BorderRadius radius, ThemeData theme) {
    final pose = _pose(index);
    final active = index == widget.selectedIndex;
    return Offstage(
      offstage: !active && (!_handoff.isAnimating || index != _outgoing),
      child: ExcludeSemantics(
        excluding: !active,
        child: IgnorePointer(
          ignoring: !active,
          child: Transform.translate(
            offset: Offset(pose.x, pose.y),
            child: Transform.scale(
              scale: pose.scale,
              alignment: Alignment.topCenter,
              child: Opacity(
                opacity: pose.opacity,
                alwaysIncludeSemantics: active,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: radius,
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: .45,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: ExperienceColors.shadowWarm.withValues(
                          alpha: .16,
                        ),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: radius,
                    child: TickerMode(
                      enabled: active,
                      child: widget.children[index],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BackingSurface extends StatelessWidget {
  const _BackingSurface({
    required this.color,
    required this.borderColor,
    required this.radius,
  });
  final Color color, borderColor;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: radius,
          border: Border.all(color: borderColor.withValues(alpha: .35)),
        ),
      ),
    ),
  );
}

class _FacePose {
  const _FacePose({
    required this.x,
    required this.y,
    required this.scale,
    required this.opacity,
  });
  static const front = _FacePose(x: 0, y: 0, scale: 1, opacity: 1);
  factory _FacePose.waiting(int direction) =>
      _FacePose(x: 48.0 * direction, y: 12, scale: .96, opacity: 0);
  final double x, y, scale, opacity;
}

double _mix(double from, double to, double fraction) =>
    from + (to - from) * fraction;
