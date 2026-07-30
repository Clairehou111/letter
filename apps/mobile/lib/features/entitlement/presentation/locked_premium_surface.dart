import 'package:flutter/material.dart';

import '../../../design_system/letter_theme.dart';
import 'plans_sheet.dart';
import 'entitlement_scope.dart';

/// Honest locked state for premium surfaces (REQ-004): says what the surface
/// would contain and offers one calm upgrade action. Never fabricates
/// content, never uses urgency.
class LockedPremiumSurface extends StatelessWidget {
  const LockedPremiumSurface({
    required this.title,
    required this.description,
    super.key,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(LetterSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.mail_lock_outlined,
              size: 40,
              color: LetterColors.moonMetal,
            ),
            const SizedBox(height: LetterSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Newsreader',
                fontSize: 20,
                height: 1.2,
                fontWeight: FontWeight.w700,
                color: LetterColors.ink,
              ),
            ),
            const SizedBox(height: LetterSpacing.sm),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: LetterColors.muted,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: LetterSpacing.lg),
            OutlinedButton(
              key: const Key('locked-see-plans'),
              onPressed: () {
                final repo = EntitlementScope.repositoryOf(context);
                if (repo != null) PlansSheet.show(context, repo);
              },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(160, 48),
                foregroundColor: LetterColors.teal,
                side: const BorderSide(color: LetterColors.teal),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(LetterRadius.control),
                ),
              ),
              child: const Text('See plans'),
            ),
          ],
        ),
      ),
    );
  }
}
