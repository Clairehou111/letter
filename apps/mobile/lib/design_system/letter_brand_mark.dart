import 'package:flutter/material.dart';

import '../experience/theme/experience_foundation.dart';

/// Letter Within's compact folded-letter mark.
class LetterBrandMark extends StatelessWidget {
  const LetterBrandMark({super.key, this.size = 30});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Letter Within',
      child: ExcludeSemantics(
        child: ClipRRect(
          key: const Key('letter-brand-mark'),
          borderRadius: BorderRadius.circular(size * .22),
          child: Image.asset(
            'assets/images/letter-within-app-icon.png',
            width: size,
            height: size,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}

/// The folded-letter mark beside the "Letter Within" wordmark, set in the
/// daylight foundation's Georgia serif and plum ink — the same voice as the
/// Today screen's display type, so thresholds never leave the room.
class LetterBrandLockup extends StatelessWidget {
  const LetterBrandLockup({super.key, this.compact = false});

  final bool compact;

  static const double _gap = 10;

  @override
  Widget build(BuildContext context) {
    final double wordmarkSize = compact ? 16 : 18;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        LetterBrandMark(size: compact ? 27 : 30),
        const SizedBox(width: _gap),
        Flexible(
          child: Text(
            'Letter Within',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Georgia',
              fontFamilyFallback: const <String>['Times New Roman', 'serif'],
              fontSize: wordmarkSize,
              height: (wordmarkSize + 6) / wordmarkSize,
              fontWeight: FontWeight.w700,
              color: ExperienceColors.ink,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ],
    );
  }
}
