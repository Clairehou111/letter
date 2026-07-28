import 'package:flutter/material.dart';

import '../../../design_system/letter_theme.dart';

class FutureSelfNoteCard extends StatelessWidget {
  const FutureSelfNoteCard({required this.note, super.key});

  final String note;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: LetterColors.surface,
        border: Border.all(color: LetterColors.line),
        borderRadius: BorderRadius.circular(LetterRadius.panel),
      ),
      child: Padding(
        padding: const EdgeInsets.all(LetterSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LetterEyebrow('A note from clearer you'),
            const SizedBox(height: LetterSpacing.xs),
            Text(note, style: const TextStyle(fontSize: 16, height: 1.4)),
          ],
        ),
      ),
    );
  }
}
