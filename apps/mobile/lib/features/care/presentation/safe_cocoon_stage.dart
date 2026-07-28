import 'package:flutter/material.dart';

import '../../../design_system/letter_theme.dart';

class SafeCocoonStage extends StatelessWidget {
  const SafeCocoonStage({
    required this.isClosed,
    required this.onClose,
    required this.onPrepareWords,
    required this.onNothingNow,
    super.key,
  });

  final bool isClosed;
  final VoidCallback onClose;
  final VoidCallback onPrepareWords;
  final VoidCallback onNothingNow;

  static const transitionDuration = Duration(milliseconds: 320);

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reduceMotion ? Duration.zero : transitionDuration;
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.45;

    return Column(
      key: const Key('safe-cocoon-stage'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LetterEyebrow(
          isClosed ? 'A QUIET ROOM' : 'A QUIETER SCREEN',
          color: isClosed ? LetterColors.teal : LetterColors.muted,
        ),
        const SizedBox(height: LetterSpacing.xs),
        AnimatedSwitcher(
          duration: duration,
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeOut,
          child: Text(
            isClosed
                ? 'The door is closed. You are allowed to be unavailable.'
                : 'Make a little room around you.',
            key: ValueKey(isClosed),
            style: TextStyle(
              color: LetterColors.ink,
              fontFamily: 'Newsreader',
              fontSize: largeText ? 23 : 29,
              height: 1.08,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        SizedBox(height: largeText ? LetterSpacing.md : LetterSpacing.xl),
        _CurtainControl(
          isClosed: isClosed,
          duration: duration,
          onClose: onClose,
        ),
        const SizedBox(height: LetterSpacing.md),
        AnimatedSwitcher(
          duration: duration,
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeOut,
          child: isClosed
              ? _ClosedActions(
                  key: const ValueKey('safe-cocoon-closed-actions'),
                  onPrepareWords: onPrepareWords,
                  onNothingNow: onNothingNow,
                )
              : const _PlatformBoundary(
                  key: ValueKey('safe-cocoon-platform-boundary'),
                ),
        ),
      ],
    );
  }
}

class _CurtainControl extends StatefulWidget {
  const _CurtainControl({
    required this.isClosed,
    required this.duration,
    required this.onClose,
  });

  final bool isClosed;
  final Duration duration;
  final VoidCallback onClose;

  @override
  State<_CurtainControl> createState() => _CurtainControlState();
}

class _CurtainControlState extends State<_CurtainControl> {
  static const _gestureDistance = 24.0;

  double _downwardDistance = 0;
  bool _didRequestClose = false;

  @override
  void didUpdateWidget(covariant _CurtainControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isClosed && !widget.isClosed) {
      _didRequestClose = false;
    }
  }

  void _requestClose() {
    if (widget.isClosed || _didRequestClose) {
      return;
    }
    _didRequestClose = true;
    widget.onClose();
  }

  void _startPointer(PointerDownEvent event) {
    _downwardDistance = 0;
  }

  void _updatePointer(PointerMoveEvent event) {
    _downwardDistance += event.delta.dy;
    if (_downwardDistance >= _gestureDistance) {
      _requestClose();
    }
  }

  void _endPointer(PointerEvent event) {
    _downwardDistance = 0;
  }

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.45;
    final label = widget.isClosed
        ? 'Curtain closed. This Letter screen is quiet.'
        : 'Close the curtain';

    return Semantics(
      key: const Key('safe-cocoon-curtain-semantics'),
      container: true,
      button: !widget.isClosed,
      enabled: !widget.isClosed,
      excludeSemantics: true,
      label: label,
      hint: widget.isClosed
          ? 'Nothing is required here.'
          : 'Tap or pull down a short distance.',
      onTap: widget.isClosed ? null : _requestClose,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: widget.isClosed ? null : _startPointer,
        onPointerMove: widget.isClosed ? null : _updatePointer,
        onPointerUp: widget.isClosed ? null : _endPointer,
        onPointerCancel: widget.isClosed ? null : _endPointer,
        child: GestureDetector(
          key: const Key('safe-cocoon-close'),
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: widget.isClosed ? null : _requestClose,
          child: SizedBox(
            height: largeText ? 272 : 218,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(LetterRadius.panel),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  TweenAnimationBuilder<double>(
                    key: const Key('safe-cocoon-curtain-animation'),
                    tween: Tween(end: widget.isClosed ? 1 : 0),
                    duration: widget.duration,
                    curve: Curves.easeOutCubic,
                    builder: (context, progress, child) {
                      return CustomPaint(
                        painter: _CurtainPainter(progress: progress),
                      );
                    },
                  ),
                  AnimatedSwitcher(
                    duration: widget.duration,
                    child: widget.isClosed
                        ? const _ClosedCurtainMark(
                            key: ValueKey('closed-curtain-mark'),
                          )
                        : const _OpenCurtainPrompt(
                            key: ValueKey('open-curtain-prompt'),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OpenCurtainPrompt extends StatelessWidget {
  const _OpenCurtainPrompt({super.key});

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.45;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: largeText ? 240 : 180),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFF7F5F0).withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(LetterRadius.control),
            border: Border.all(color: const Color(0xFFD8DEDA)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: LetterSpacing.md,
              vertical: LetterSpacing.sm,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!largeText) ...[
                  const Icon(
                    Icons.keyboard_arrow_down,
                    color: LetterColors.teal,
                    size: 28,
                  ),
                  const SizedBox(height: LetterSpacing.xxs),
                ],
                const Text(
                  'Close the curtain',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: LetterColors.ink,
                    fontSize: 15,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: LetterSpacing.xxs),
                const Text(
                  'Tap or pull down',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: LetterColors.muted,
                    fontSize: 12,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ClosedCurtainMark extends StatelessWidget {
  const _ClosedCurtainMark({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        excludeSemantics: true,
        child: const DecoratedBox(
          decoration: BoxDecoration(
            color: Color(0x24FFFFFF),
            shape: BoxShape.circle,
          ),
          child: SizedBox.square(
            dimension: 72,
            child: Icon(
              Icons.nights_stay_outlined,
              color: Color(0xFFE3ECE8),
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlatformBoundary extends StatelessWidget {
  const _PlatformBoundary({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Letter can quiet this screen. It cannot silence calls or other apps.',
      textAlign: TextAlign.center,
      style: TextStyle(color: LetterColors.muted, fontSize: 13, height: 1.4),
    );
  }
}

class _ClosedActions extends StatelessWidget {
  const _ClosedActions({
    required this.onPrepareWords,
    required this.onNothingNow,
    super.key,
  });

  final VoidCallback onPrepareWords;
  final VoidCallback onNothingNow;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      container: true,
      explicitChildNodes: true,
      label:
          'The curtain is closed. Nothing is required here. Optional choices follow.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Nothing is required here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: LetterColors.muted,
              fontSize: 15,
              height: 1.4,
            ),
          ),
          const SizedBox(height: LetterSpacing.xl),
          FilledButton(
            key: const Key('safe-cocoon-prepare-words'),
            onPressed: onPrepareWords,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              padding: const EdgeInsets.symmetric(
                horizontal: LetterSpacing.md,
                vertical: LetterSpacing.sm,
              ),
              backgroundColor: LetterColors.teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(LetterRadius.control),
              ),
            ),
            child: const Text('Prepare words', textAlign: TextAlign.center),
          ),
          const SizedBox(height: LetterSpacing.sm),
          OutlinedButton(
            key: const Key('safe-cocoon-nothing-now'),
            onPressed: onNothingNow,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              padding: const EdgeInsets.symmetric(
                horizontal: LetterSpacing.md,
                vertical: LetterSpacing.sm,
              ),
              foregroundColor: LetterColors.ink,
              backgroundColor: LetterColors.surface,
              side: const BorderSide(color: LetterColors.line),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(LetterRadius.control),
              ),
            ),
            child: const Text(
              'Nothing else right now',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _CurtainPainter extends CustomPainter {
  const _CurtainPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(bounds, Paint()..color = const Color(0xFFE8EFEC));

    final fabric = Paint()..color = const Color(0xFF315F5B);
    final fabricDark = Paint()..color = const Color(0xFF284F4C);
    final sideWidth = size.width * 0.19;

    canvas.drawRect(Rect.fromLTWH(0, 0, sideWidth, size.height), fabric);
    canvas.drawRect(
      Rect.fromLTWH(size.width - sideWidth, 0, sideWidth, size.height),
      fabric,
    );

    final loweredHeight = size.height * progress;
    if (loweredHeight > 0) {
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, loweredHeight), fabric);
    }

    final foldPaint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.08)
      ..strokeWidth = 1.5;
    for (var index = 1; index < 8; index += 1) {
      final x = size.width * index / 8;
      if (loweredHeight > 0) {
        canvas.drawLine(Offset(x, 0), Offset(x, loweredHeight), foldPaint);
      }
    }

    final sideFold = Paint()
      ..color = fabricDark.color.withValues(alpha: 0.54)
      ..strokeWidth = 7;
    canvas.drawLine(
      Offset(sideWidth * 0.55, 0),
      Offset(sideWidth * 0.72, size.height),
      sideFold,
    );
    canvas.drawLine(
      Offset(size.width - sideWidth * 0.55, 0),
      Offset(size.width - sideWidth * 0.72, size.height),
      sideFold,
    );

    if (progress < 1) {
      final lowerEdge = Paint()
        ..color = const Color(0xFFB8CBC6).withValues(alpha: 0.65)
        ..strokeWidth = 1;
      canvas.drawLine(
        Offset(0, loweredHeight),
        Offset(size.width, loweredHeight),
        lowerEdge,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CurtainPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
