import 'package:flutter/material.dart';

import '../../../design_system/letter_theme.dart';
import '../domain/care_mode.dart';

class CareSafetyBoundarySheet extends StatelessWidget {
  const CareSafetyBoundarySheet({
    required this.kind,
    required this.onLeaveCare,
    super.key,
  });

  final CareSafetyKind kind;
  final VoidCallback onLeaveCare;

  @override
  Widget build(BuildContext context) {
    final physical = kind == CareSafetyKind.physical;
    return Container(
      decoration: const BoxDecoration(
        color: LetterColors.canvas,
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: SafeArea(
        top: false,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    physical
                        ? 'This needs medical attention, not more interaction.'
                        : 'Immediate safety comes first.',
                    style: const TextStyle(
                      fontFamily: 'Newsreader',
                      fontSize: 25,
                      height: 1.05,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Return to scene',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: LetterSpacing.md),
            Text(
              physical
                  ? 'New, unusual, severe, changing, or function-limiting pain '
                        'needs medical assessment. Letter cannot assess it here.'
                  : 'Letter cannot provide emergency help from this screen. '
                        'If you may harm yourself or someone else, leave Care '
                        'and contact local emergency services or a trusted '
                        'person now.',
              style: const TextStyle(
                color: LetterColors.muted,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: LetterSpacing.lg),
            FilledButton(
              key: const Key('leave-care-from-safety'),
              onPressed: onLeaveCare,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: LetterColors.teal,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(LetterRadius.control),
                ),
              ),
              child: const Text('Leave Care'),
            ),
            TextButton(
              key: const Key('return-to-care-scene'),
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: LetterColors.muted,
              ),
              child: const Text('Return to scene'),
            ),
          ],
        ),
      ),
    );
  }
}
