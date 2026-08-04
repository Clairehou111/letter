import 'package:flutter/material.dart';

import '../../../design_system/letter_theme.dart';
import '../../cycle/domain/cycle_prediction.dart';
import '../domain/body_letter.dart';
import '../today_cycle_context.dart';

/// The first thing on Today: a short letter from the body, and one-tap ways to
/// answer it.
///
/// This is the "being seen" surface. It states nothing about causes or
/// conditions, asks no questions, and needs at most a single tap.
class BodyLetterHeader extends StatefulWidget {
  const BodyLetterHeader({
    required this.cycleContext,
    super.key,
    this.prediction,
    this.onOpenLowEffort,
  });

  final TodayCycleContext cycleContext;
  final CyclePrediction? prediction;

  /// Opens the no-energy surface in Stay. Optional.
  final VoidCallback? onOpenLowEffort;

  @override
  State<BodyLetterHeader> createState() => _BodyLetterHeaderState();
}

class _BodyLetterHeaderState extends State<BodyLetterHeader> {
  String? _answeredId;

  @override
  Widget build(BuildContext context) {
    final line = BodyLetter.forContext(
      widget.cycleContext,
      prediction: widget.prediction,
    );
    final answered = _answeredId == null
        ? null
        : BodyLetter.acknowledgements.firstWhere((r) => r.id == _answeredId);

    return Container(
      key: const Key('today-body-letter'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: LetterColors.tealSoft,
        borderRadius: BorderRadius.circular(LetterRadius.panel),
        border: Border.all(color: LetterColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            line.stamp.toUpperCase(),
            style: const TextStyle(
              color: LetterColors.tealDark,
              fontSize: 10,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: LetterSpacing.xs),
          Text(
            line.body,
            style: const TextStyle(
              color: LetterColors.ink,
              fontFamily: 'Newsreader',
              fontSize: 19,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: LetterSpacing.sm),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            child: answered == null
                ? Wrap(
                    key: const Key('today-body-letter-replies'),
                    spacing: LetterSpacing.xs,
                    runSpacing: LetterSpacing.xs,
                    children: [
                      for (final reply in BodyLetter.acknowledgements)
                        _ReplyChip(
                          reply: reply,
                          onPressed: () =>
                              setState(() => _answeredId = reply.id),
                        ),
                    ],
                  )
                : Text(
                    answered.reply,
                    key: const Key('today-body-letter-answered'),
                    style: const TextStyle(
                      color: LetterColors.muted,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
          ),
          if (widget.onOpenLowEffort != null) ...[
            const SizedBox(height: LetterSpacing.xxs),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('today-body-letter-low-effort'),
                onPressed: widget.onOpenLowEffort,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 36),
                  foregroundColor: LetterColors.tealDark,
                ),
                child: const Text('I have nothing left today'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReplyChip extends StatelessWidget {
  const _ReplyChip({required this.reply, required this.onPressed});

  final BodyLetterReply reply;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      key: Key('today-body-letter-reply-${reply.id}'),
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: LetterColors.tealDark,
        backgroundColor: LetterColors.surface,
        side: const BorderSide(color: LetterColors.line),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LetterRadius.control),
        ),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      child: Text(reply.label),
    );
  }
}
