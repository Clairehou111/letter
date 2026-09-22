import 'package:flutter/material.dart';

import '../../../experience/theme/experience_foundation.dart';

class PrivacyExplainerSheet extends StatelessWidget {
  const PrivacyExplainerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showExperienceSheet<void>(
      context,
      child: const PrivacyExplainerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      key: const Key('privacy-explainer-sheet'),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          ExperienceSpacing.screenMargin,
          ExperienceSpacing.xs,
          ExperienceSpacing.screenMargin,
          ExperienceSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Privacy, in plain language',
              style: ExperienceType.eyebrow(ExperienceColors.inkSoft),
            ),
            const SizedBox(height: ExperienceSpacing.xs),
            Text(
              'How privacy works',
              style: ExperienceType.title(ExperienceColors.ink),
            ),
            const SizedBox(height: ExperienceSpacing.xs),
            Text(
              'Letter Within is designed to keep intimate records under your '
              'control.',
              style: ExperienceType.bodySmall(ExperienceColors.inkSoft),
            ),
            const SizedBox(height: ExperienceSpacing.lg),
            const _PrivacyExplanation(
              icon: Icons.account_circle_outlined,
              title: 'Your account is separate',
              body:
                  'Your Letter Within account connects access, purchases, and '
                  'approved product activity. Period dates, symptoms, '
                  'Letters, and Care records are not stored in your account.',
            ),
            const _PrivacyExplanation(
              icon: Icons.phone_android_outlined,
              title: 'Your records stay here',
              body:
                  'Period dates, symptoms, notes, and Care records are stored '
                  'on this device. Letter Within does not upload them to our '
                  'servers. If a different account signs in, existing records '
                  'stay closed—not deleted—until the account that created '
                  'them signs in again.',
            ),
            const _PrivacyExplanation(
              icon: Icons.move_to_inbox_outlined,
              title: 'You choose when records move',
              body:
                  'Encrypted backup, restore, and export happen only when you '
                  'start them. Signing in does not move your health records '
                  'to another device.',
            ),
            const _PrivacyExplanation(
              icon: Icons.tune_outlined,
              title: 'You stay in control',
              body:
                  'You can change privacy choices, make an encrypted backup, '
                  'export records, or delete them from the You tab.',
            ),
            const SizedBox(height: ExperienceSpacing.xs),
            Semantics(
              button: true,
              label: 'Done',
              child: Material(
                color: Colors.transparent,
                child: Ink(
                  decoration: const BoxDecoration(
                    gradient: ExperienceColors.emberGradient,
                    borderRadius: ExperienceRadius.chipRadius,
                  ),
                  child: InkWell(
                    key: const Key('privacy-explainer-close'),
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: ExperienceRadius.chipRadius,
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(minHeight: 52),
                      alignment: Alignment.center,
                      child: Text(
                        'Done',
                        style: ExperienceType.label(Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyExplanation extends StatelessWidget {
  const _PrivacyExplanation({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ExperienceSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: ExperienceSpacing.minTouchTarget,
            height: ExperienceSpacing.minTouchTarget,
            decoration: BoxDecoration(
              color: ExperienceColors.surfaceWarm,
              borderRadius: ExperienceRadius.chipRadius,
              border: Border.all(color: ExperienceColors.hairline),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 22, color: ExperienceColors.emberDeep),
          ),
          const SizedBox(width: ExperienceSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: ExperienceType.bodyStrong(ExperienceColors.ink),
                ),
                const SizedBox(height: ExperienceSpacing.xs),
                Text(
                  body,
                  style: ExperienceType.bodySmall(ExperienceColors.inkSoft),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
