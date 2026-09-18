import 'package:flutter/material.dart';

import '../../../design_system/lovable/letter_theme.dart';
import '../domain/bleeding_flow.dart';
import '../domain/local_date.dart';

String _flowDescription(BleedingFlow flow) => switch (flow) {
  BleedingFlow.spotting =>
    'A few spots of blood, lighter than your usual flow.',
  BleedingFlow.light => 'Less than an ordinary day for you.',
  BleedingFlow.medium => 'An ordinary day for you.',
  BleedingFlow.heavy => 'More than an ordinary day for you.',
};

Color _flowCardColor(BleedingFlow flow) => switch (flow) {
  BleedingFlow.spotting => const Color(0xFFFFF0F2),
  BleedingFlow.light => const Color(0xFFFFE9EC),
  BleedingFlow.medium => const Color(0xFFFFDEE3),
  BleedingFlow.heavy => const Color(0xFFFFD2D9),
};

Color bleedingColorSwatch(BleedingColor color) => switch (color) {
  BleedingColor.pink => const Color(0xFFE997A4),
  BleedingColor.brightRed => const Color(0xFFC94854),
  BleedingColor.darkRed => const Color(0xFF7E2933),
  BleedingColor.brown => const Color(0xFF805347),
};

class FlowGlyph extends StatelessWidget {
  const FlowGlyph({required this.flow, super.key, this.emphasis = false});

  final BleedingFlow flow;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      excludeSemantics: true,
      child: CustomPaint(
        painter: _FlowGlyphPainter(flow: flow, emphasis: emphasis),
        child: SizedBox(width: emphasis ? 46 : 34, height: emphasis ? 34 : 25),
      ),
    );
  }
}

class _FlowGlyphPainter extends CustomPainter {
  const _FlowGlyphPainter({required this.flow, required this.emphasis});

  final BleedingFlow flow;
  final bool emphasis;

  @override
  void paint(Canvas canvas, Size size) {
    final outline = Paint()
      ..color = const Color(0xFFB77780).withValues(alpha: 0.42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = emphasis ? 1.7 : 1.3;
    final fill = Paint()..color = const Color(0xFFB64E5D);
    final pad = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * .22, 1, size.width * .56, size.height - 2),
      Radius.elliptical(size.width * .25, size.height * .28),
    );
    canvas.drawRRect(pad, outline);
    if (flow == BleedingFlow.spotting) {
      final radius = size.shortestSide * .055;
      for (final offset in const [
        Offset(.43, .42),
        Offset(.59, .57),
        Offset(.48, .7),
      ]) {
        canvas.drawCircle(
          Offset(size.width * offset.dx, size.height * offset.dy),
          radius,
          fill,
        );
      }
      return;
    }
    final factor = switch (flow) {
      BleedingFlow.light => .29,
      BleedingFlow.medium => .55,
      BleedingFlow.heavy => .82,
      BleedingFlow.spotting => 0,
    };
    final stain = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: size.width * (.22 + factor * .25),
        height: size.height * factor,
      ),
      Radius.circular(size.width * .16),
    );
    canvas.drawRRect(stain, fill);
  }

  @override
  bool shouldRepaint(covariant _FlowGlyphPainter oldDelegate) =>
      flow != oldDelegate.flow || emphasis != oldDelegate.emphasis;
}

class FlowChoiceTile extends StatelessWidget {
  const FlowChoiceTile({
    required this.flow,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final BleedingFlow flow;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${flow.label}. ${_flowDescription(flow)}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: LetterTokens.s8),
        child: InkWell(
          onTap: onTap,
          borderRadius: LetterTokens.brControl,
          child: AnimatedContainer(
            duration: context.lovableMotion(LetterTokens.durFast),
            curve: LetterTokens.ease,
            constraints: const BoxConstraints(
              minHeight: LetterTokens.tapTarget,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: LetterTokens.s12,
              vertical: LetterTokens.s12,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? _flowCardColor(flow)
                  : _flowCardColor(flow).withValues(alpha: 0.48),
              borderRadius: LetterTokens.brControl,
              border: Border.all(
                color: selected
                    ? const Color(0xFFB64E5D)
                    : const Color(0xFFE9C8CD),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  selected ? Icons.check_circle_outline : Icons.circle_outlined,
                  size: 18,
                  color: selected
                      ? const Color(0xFFB64E5D)
                      : const Color(0xFFA97A80),
                ),
                const SizedBox(width: LetterTokens.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: LetterTokens.s8,
                        runSpacing: LetterTokens.s4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            flow.label,
                            style: letterBody(
                              size: 14.5,
                              weight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: selected
                                  ? const Color(0xFF8D3441)
                                  : LetterTokens.ink,
                            ),
                          ),
                          FlowGlyph(flow: flow, emphasis: selected),
                        ],
                      ),
                      const SizedBox(height: LetterTokens.s4),
                      Text(
                        _flowDescription(flow),
                        style: letterHelper(size: 12.5),
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
}

class BleedingColorGlyph extends StatelessWidget {
  const BleedingColorGlyph({required this.color, super.key, this.size = 30});

  final BleedingColor color;
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _ColorDropPainter(bleedingColorSwatch(color)),
    child: SizedBox.square(dimension: size),
  );
}

class _ColorDropPainter extends CustomPainter {
  const _ColorDropPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * .5, size.height * .06)
      ..cubicTo(
        size.width * .38,
        size.height * .28,
        size.width * .17,
        size.height * .5,
        size.width * .17,
        size.height * .68,
      )
      ..cubicTo(
        size.width * .17,
        size.height * .91,
        size.width * .83,
        size.height * .91,
        size.width * .83,
        size.height * .68,
      )
      ..cubicTo(
        size.width * .83,
        size.height * .5,
        size.width * .62,
        size.height * .28,
        size.width * .5,
        size.height * .06,
      )
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: .28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant _ColorDropPainter oldDelegate) =>
      color != oldDelegate.color;
}

class BleedingColorChoice extends StatelessWidget {
  const BleedingColorChoice({
    required this.color,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final BleedingColor color;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final swatch = bleedingColorSwatch(color);
    return Semantics(
      button: true,
      selected: selected,
      label: '${color.label} bleeding color',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: context.lovableMotion(LetterTokens.durFast),
          constraints: const BoxConstraints(minHeight: 82),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: swatch.withValues(alpha: selected ? .16 : .08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? swatch : swatch.withValues(alpha: .25),
              width: selected ? 1.8 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              BleedingColorGlyph(color: color, size: 24),
              const SizedBox(height: 3),
              ExcludeSemantics(
                child: Text(
                  color.label,
                  textAlign: TextAlign.center,
                  textScaler: TextScaler.noScaling,
                  style: letterBody(
                    size: 12,
                    weight: selected ? FontWeight.w700 : FontWeight.w500,
                    height: 1.15,
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

class FlowDateStrip extends StatefulWidget {
  const FlowDateStrip({
    required this.start,
    required this.end,
    required this.selected,
    required this.onSelect,
    required this.flowFor,
    super.key,
  });

  final LocalDate start;
  final LocalDate end;
  final LocalDate selected;
  final ValueChanged<LocalDate> onSelect;
  final BleedingFlow? Function(LocalDate date) flowFor;

  @override
  State<FlowDateStrip> createState() => _FlowDateStripState();
}

class _FlowDateStripState extends State<FlowDateStrip> {
  final ScrollController _scrollController = ScrollController();

  static const _cellWidth = 64.0;
  static const _cellGap = LetterTokens.s8;

  int get _dayCount => widget.end.epochDay - widget.start.epochDay + 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _reveal(animate: false),
    );
  }

  @override
  void didUpdateWidget(covariant FlowDateStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      _reveal(animate: true);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _reveal({required bool animate}) {
    if (!_scrollController.hasClients) return;
    final index = widget.selected.epochDay - widget.start.epochDay;
    final target = (index * (_cellWidth + _cellGap) - _cellWidth)
        .clamp(0.0, _scrollController.position.maxScrollExtent)
        .toDouble();
    if (!animate || context.reduceLovableMotion) {
      _scrollController.jumpTo(target);
    } else {
      _scrollController.animateTo(
        target,
        duration: LetterTokens.durBase,
        curve: LetterTokens.ease,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 82,
      child: ListView.separated(
        key: const Key('flow-date-strip'),
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: LetterTokens.gutter),
        itemCount: _dayCount,
        separatorBuilder: (_, _) => const SizedBox(width: _cellGap),
        itemBuilder: (context, index) {
          final date = widget.start.addDays(index);
          final flow = widget.flowFor(date);
          return _FlowDateCell(
            date: date,
            flow: flow,
            selected: date == widget.selected,
            onTap: () => widget.onSelect(date),
          );
        },
      ),
    );
  }
}

class _FlowDateCell extends StatelessWidget {
  const _FlowDateCell({
    required this.date,
    required this.flow,
    required this.selected,
    required this.onTap,
  });

  final LocalDate date;
  final BleedingFlow? flow;
  final bool selected;
  final VoidCallback onTap;

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final flow = this.flow;
    final spoken = flow == null
        ? '${_formatFullDate(context, date)}. No flow recorded.'
        : '${_formatFullDate(context, date)}. Flow ${flow.label}.';
    return Semantics(
      button: true,
      selected: selected,
      label: spoken,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: LetterTokens.brControl,
        child: AnimatedContainer(
          duration: context.lovableMotion(LetterTokens.durFast),
          curve: LetterTokens.ease,
          width: _FlowDateStripState._cellWidth,
          constraints: const BoxConstraints(minHeight: LetterTokens.tapTarget),
          padding: const EdgeInsets.symmetric(vertical: LetterTokens.s8),
          decoration: BoxDecoration(
            color: selected ? LetterTokens.tealSoft : LetterTokens.surface,
            borderRadius: LetterTokens.brControl,
            border: Border.all(
              color: selected ? LetterTokens.teal : LetterTokens.line,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _weekdays[date.asLocalDateTime.weekday - 1],
                textScaler: TextScaler.noScaling,
                style: letterEyebrow(
                  color: selected ? LetterTokens.teal : LetterTokens.muted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${date.day}',
                textScaler: TextScaler.noScaling,
                style: letterSerif(size: 18).copyWith(
                  color: selected ? LetterTokens.tealDark : LetterTokens.ink,
                ),
              ),
              const SizedBox(height: 3),
              if (flow != null)
                SizedBox(
                  width: 28,
                  height: 18,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: ExcludeSemantics(child: FlowGlyph(flow: flow)),
                  ),
                )
              else
                Text(
                  '—',
                  textScaler: TextScaler.noScaling,
                  style: letterHelper(size: 11),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatFullDate(BuildContext context, LocalDate date) =>
    MaterialLocalizations.of(context).formatFullDate(date.asLocalDateTime);
