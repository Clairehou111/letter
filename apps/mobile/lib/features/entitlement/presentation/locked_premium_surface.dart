import 'package:flutter/material.dart';

import '../../../experience/theme/experience_foundation.dart';

/// Honest locked state for premium surfaces (REQ-004): says what the surface
/// would contain and offers one calm upgrade action. Never fabricates
/// content, never uses urgency.
///
/// Quiet Dusk composition: a low-glare plum field, one restrained lock mark,
/// a short ember cue, compact caller-supplied copy, and a single ember
/// primary action. The shell owns surrounding chrome; this surface only keeps
/// itself inset-safe and readable.
class LockedPremiumSurface extends StatelessWidget {
  const LockedPremiumSurface({
    required this.title,
    required this.description,
    required this.onOpenPlans,
    super.key,
  });

  final String title;
  final String description;
  final VoidCallback onOpenPlans;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: ExperienceColors.canvas,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double topGap = constraints.maxHeight > 620 ? 64.0 : 32.0;

            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ExperienceSpacing.screenMargin,
                    vertical: ExperienceSpacing.lg,
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(height: topGap),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: ExperienceColors.surface,
                                  borderRadius: ExperienceRadius.cardRadius,
                                  border: Border.all(
                                    color: ExperienceColors.hairline,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.mail_lock_outlined,
                                  size: 26,
                                  color: ExperienceColors.ember,
                                ),
                              ),
                              const SizedBox(width: ExperienceSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 3,
                                      decoration: BoxDecoration(
                                        color: ExperienceColors.ember,
                                        borderRadius:
                                            ExperienceRadius.chipRadius,
                                      ),
                                    ),
                                    const SizedBox(
                                      height: ExperienceSpacing.xs,
                                    ),
                                    Text(
                                      title,
                                      style: ExperienceType.headline(
                                        ExperienceColors.ink,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: ExperienceSpacing.md),
                          Text(
                            description,
                            style: ExperienceType.bodySmall(
                              ExperienceColors.inkSoft,
                            ),
                          ),
                          const SizedBox(height: ExperienceSpacing.lg),
                          Semantics(
                            button: true,
                            label: 'See plans',
                            child: Material(
                              color: Colors.transparent,
                              child: Ink(
                                decoration: BoxDecoration(
                                  gradient:
                                      ExperienceColors.emberActionGradient,
                                  borderRadius: ExperienceRadius.chipRadius,
                                  boxShadow: ExperienceShadows.card,
                                ),
                                child: InkWell(
                                  key: const Key('locked-see-plans'),
                                  onTap: onOpenPlans,
                                  borderRadius: ExperienceRadius.chipRadius,
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      minHeight: 52,
                                    ),
                                    child: Center(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: ExperienceSpacing.sm,
                                          vertical: ExperienceSpacing.xs,
                                        ),
                                        child: Text(
                                          'See plans',
                                          textAlign: TextAlign.center,
                                          style: ExperienceType.label(
                                            ExperienceColors.onEmber,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: ExperienceSpacing.lg),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
