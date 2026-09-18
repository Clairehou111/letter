import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../design_system/letter_theme.dart';
import '../domain/care_memory.dart';
import '../domain/care_mode.dart';

enum CareToolkitAction {
  warmth(
    'toolkit.warmth',
    'Apply warmth',
    'A wrapped heat pad, warm bottle, or warmer.',
    Icons.local_fire_department_outlined,
    Color(0xFFE7A35B),
  ),
  gentleMovement(
    'toolkit.gentle-movement',
    'Move gently',
    'Three small movements, at your own pace.',
    Icons.self_improvement_outlined,
    Color(0xFF7E72B2),
  ),
  warmShower(
    'toolkit.warm-shower',
    'Take a warm shower',
    'Let comfortable warmth surround your body.',
    Icons.shower_outlined,
    Color(0xFF5795AA),
  ),
  massage(
    'toolkit.massage',
    'Massage belly or back',
    'Gentle pressure only where it feels welcome.',
    Icons.pan_tool_alt_outlined,
    Color(0xFFB46E7B),
  ),
  rest(
    'toolkit.rest',
    'Rest in a comfortable position',
    'Support your knees, side, or lower back.',
    Icons.bedtime_outlined,
    Color(0xFF668A78),
  ),
  warmDrink(
    'toolkit.warm-drink',
    'Have a warm drink',
    'A comfort ritual, without a treatment claim.',
    Icons.emoji_food_beverage_outlined,
    Color(0xFFA77955),
  );

  const CareToolkitAction(
    this.id,
    this.label,
    this.detail,
    this.icon,
    this.color,
  );

  final String id;
  final String label;
  final String detail;
  final IconData icon;
  final Color color;
}

class CareToolkitScreen extends StatefulWidget {
  const CareToolkitScreen({
    required this.now,
    super.key,
    this.priorRecords = const [],
  });

  final DateTime Function() now;
  final List<CareRecord> priorRecords;

  @override
  State<CareToolkitScreen> createState() => _CareToolkitScreenState();
}

class _CareToolkitScreenState extends State<CareToolkitScreen> {
  CareToolkitAction? _active;
  int _movementIndex = 0;

  static const _movements = [
    (
      'Gentle lower-back release',
      'Sit or lie supported. Slowly soften your lower back.',
    ),
    (
      'Knees-to-chest rest',
      'Bring one or both knees closer only as far as comfortable.',
    ),
    (
      'Slow hip and pelvic movement',
      'Make a small, easy circle. Stop if it feels worse.',
    ),
  ];

  void _finish(CareToolkitAction action) {
    Navigator.of(context).pop(
      CareActionCompletion(
        mode: CareMode.physical,
        actionId: action.id,
        actionLabel: action.label,
        occurredAt: widget.now(),
      ),
    );
  }

  int _betterCount(CareToolkitAction action) => widget.priorRecords
      .where(
        (record) =>
            record.actionId == action.id &&
            record.outcome == CareOutcome.better,
      )
      .length;

  @override
  Widget build(BuildContext context) {
    final active = _active;
    return Scaffold(
      key: const Key('care-toolkit-screen'),
      backgroundColor: const Color(0xFFF8F3EE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        leading: IconButton(
          key: const Key('care-toolkit-back'),
          onPressed: () => active == null
              ? Navigator.of(context).pop()
              : setState(() => _active = null),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(
          active?.label ?? 'Body comfort toolkit',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        top: false,
        child: active == null ? _choices() : _activeAction(active),
      ),
    );
  }

  Widget _choices() => ListView(
    padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
    children: [
      const Text(
        'What might feel manageable?',
        style: TextStyle(
          fontFamily: 'Newsreader',
          fontSize: 29,
          height: 1.05,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'Choose one small action. You can stop at any time.',
        style: TextStyle(color: LetterColors.muted, height: 1.4),
      ),
      const SizedBox(height: 20),
      for (final action in CareToolkitAction.values)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Semantics(
            button: true,
            label: '${action.label}. ${action.detail}',
            excludeSemantics: true,
            child: Material(
              color: action.color.withValues(alpha: .11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: action.color.withValues(alpha: .28)),
              ),
              child: InkWell(
                key: Key('toolkit-${action.name}'),
                borderRadius: BorderRadius.circular(18),
                onTap: () => setState(() => _active = action),
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final largeText =
                          MediaQuery.textScalerOf(context).scale(1) > 1.45;
                      final betterCount = _betterCount(action);
                      final copy = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            action.label,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            action.detail,
                            style: const TextStyle(
                              color: LetterColors.muted,
                              fontSize: 12.5,
                            ),
                          ),
                          if (betterCount > 0) ...[
                            const SizedBox(height: 7),
                            Container(
                              key: Key('toolkit-memory-${action.name}'),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: action.color.withValues(alpha: .13),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                betterCount == 1
                                    ? 'Helped you once before'
                                    : 'Helped you $betterCount times before',
                                style: TextStyle(
                                  color: action.color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      );
                      final visual = Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: action.color.withValues(alpha: .17),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(action.icon, color: action.color),
                      );
                      if (largeText || constraints.maxWidth < 300) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                visual,
                                const Spacer(),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  color: action.color,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            copy,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          visual,
                          const SizedBox(width: 13),
                          Expanded(child: copy),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: action.color,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );

  Widget _activeAction(CareToolkitAction action) {
    final movement = _movements[_movementIndex];
    final isMovement = action == CareToolkitAction.gentleMovement;
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.45;
    final guidance = switch (action) {
      CareToolkitAction.warmth =>
        'Wrap the heat source. Keep it comfortably warm, never hot, and check your skin regularly.',
      CareToolkitAction.gentleMovement => movement.$2,
      CareToolkitAction.warmShower =>
        'Choose a comfortable temperature. Let the water do the work; there is nothing to achieve.',
      CareToolkitAction.massage =>
        'Use slow circles or still pressure. Lighter is enough. Stop if pain increases.',
      CareToolkitAction.rest =>
        'Try your side, knees supported, or a pillow beneath your knees. Choose what asks least of you.',
      CareToolkitAction.warmDrink =>
        'Choose any warm drink you already enjoy. This is for comfort, not a treatment.',
    };
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: [
        Center(
          child: isMovement
              ? _MovementGuideVisual(
                  key: ValueKey('movement-guide-$_movementIndex'),
                  movementIndex: _movementIndex,
                  color: action.color,
                )
              : Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    color: action.color.withValues(alpha: .15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(action.icon, size: 48, color: action.color),
                ),
        ),
        const SizedBox(height: 24),
        if (isMovement)
          Text(
            movement.$1,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Newsreader',
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          )
        else
          Text(
            action.label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Newsreader',
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
        const SizedBox(height: 10),
        Text(
          guidance,
          textAlign: TextAlign.center,
          style: const TextStyle(color: LetterColors.muted, height: 1.5),
        ),
        if (isMovement) ...[
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var index = 0; index < _movements.length; index++)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: index == _movementIndex ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: index == _movementIndex
                        ? action.color
                        : action.color.withValues(alpha: .25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          if (_movementIndex < _movements.length - 1)
            OutlinedButton(
              key: const Key('toolkit-next-movement'),
              onPressed: () => setState(() => _movementIndex += 1),
              child: Text(largeText ? 'Next' : 'Next gentle movement'),
            ),
        ],
        const SizedBox(height: 26),
        FilledButton(
          key: const Key('toolkit-finish'),
          onPressed: () => _finish(action),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: action.color,
          ),
          child: Text(largeText ? 'Check in' : 'I’m ready to check in'),
        ),
        TextButton(
          key: const Key('toolkit-stop'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(largeText ? 'Stop' : 'Stop for now'),
        ),
      ],
    );
  }
}

class _MovementGuideVisual extends StatelessWidget {
  const _MovementGuideVisual({
    required this.movementIndex,
    required this.color,
    super.key,
  });

  final int movementIndex;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: 'Gentle movement illustration',
      image: true,
      child: Container(
        key: const Key('toolkit-movement-visual'),
        width: 156,
        height: 118,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(28),
        ),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: reducedMotion
              ? Duration.zero
              : const Duration(milliseconds: 2600),
          curve: Curves.easeInOut,
          builder: (context, progress, _) => CustomPaint(
            painter: _MovementGuidePainter(
              movementIndex: movementIndex,
              progress: progress,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

class _MovementGuidePainter extends CustomPainter {
  const _MovementGuidePainter({
    required this.movementIndex,
    required this.progress,
    required this.color,
  });

  final int movementIndex;
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final wave = math.sin(progress * math.pi);
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final soft = Paint()
      ..color = color.withValues(alpha: .18)
      ..style = PaintingStyle.fill;
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, 38 + wave * 4, soft);

    switch (movementIndex) {
      case 0:
        final shift = wave * 7;
        canvas.drawCircle(Offset(center.dx - 22 + shift, 35), 8, line);
        final back = Path()
          ..moveTo(center.dx - 14 + shift, 43)
          ..quadraticBezierTo(
            center.dx + 5,
            center.dy + 2 + wave * 5,
            center.dx + 35,
            center.dy + 9,
          );
        canvas.drawPath(back, line);
        canvas.drawLine(
          Offset(center.dx + 13, center.dy + 2),
          Offset(center.dx + 40, center.dy - 16),
          line,
        );
        canvas.drawLine(
          Offset(center.dx + 33, center.dy + 9),
          Offset(center.dx + 49, center.dy + 28),
          line,
        );
      case 1:
        final tuck = wave * 9;
        canvas.drawCircle(Offset(center.dx - 30, center.dy - 21), 8, line);
        canvas.drawLine(
          Offset(center.dx - 21, center.dy - 14),
          Offset(center.dx + 16, center.dy + 12),
          line,
        );
        canvas.drawPath(
          Path()
            ..moveTo(center.dx + 16, center.dy + 12)
            ..quadraticBezierTo(
              center.dx + 5 - tuck,
              center.dy + 28,
              center.dx - 11 - tuck,
              center.dy + 9,
            ),
          line,
        );
        canvas.drawPath(
          Path()
            ..moveTo(center.dx + 20, center.dy + 8)
            ..quadraticBezierTo(
              center.dx + 8 - tuck,
              center.dy + 20,
              center.dx - 4 - tuck,
              center.dy + 2,
            ),
          line,
        );
      case 2:
        final sway = math.sin(progress * math.pi * 2) * 7;
        canvas.drawCircle(Offset(center.dx + sway, 30), 8, line);
        canvas.drawPath(
          Path()
            ..moveTo(center.dx + sway, 40)
            ..quadraticBezierTo(
              center.dx - sway,
              center.dy + 5,
              center.dx + sway,
              center.dy + 29,
            ),
          line,
        );
        canvas.drawLine(
          Offset(center.dx - 2, center.dy),
          Offset(center.dx - 28, center.dy + 14),
          line,
        );
        canvas.drawLine(
          Offset(center.dx + 2, center.dy),
          Offset(center.dx + 28, center.dy + 14),
          line,
        );
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(center.dx, center.dy + 25),
            width: 68,
            height: 22,
          ),
          .15,
          math.pi * .7,
          false,
          line..strokeWidth = 2.5,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _MovementGuidePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.movementIndex != movementIndex ||
      oldDelegate.color != color;
}
