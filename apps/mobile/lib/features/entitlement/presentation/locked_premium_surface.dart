import 'package:flutter/material.dart';

import '../../../experience/theme/experience_foundation.dart';
import 'entitlement_scope.dart';
import 'plans_sheet.dart';

/// Honest locked state for premium surfaces (REQ-004): says what the surface
/// would contain and offers one calm upgrade action. Never fabricates
/// content, never uses urgency.
///
/// Visual system: the daylight Experience Foundation — warm paper canvas,
/// plum serif title, and a single filled ember primary ("See plans"). This
/// surface never renders urgency styling, error red, or fabricated preview
/// content; the title and description are rendered exactly as given.
class LockedPremiumSurface extends StatelessWidget {
  const LockedPremiumSurface({
    required this.title,
    required this.description,
    this.onOpenPlans,
    super.key,
  });

  final String title;
  final String description;
  final VoidCallback? onOpenPlans;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(ExperienceSpacing.screenMargin),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: ExperienceColors.surfaceWarm,
                            borderRadius: ExperienceRadius.cardRadius,
                            border: Border.all(
                              color: ExperienceColors.hairline,
                            ),
                          ),
                          child: const Icon(
                            Icons.mail_lock_outlined,
                            size: 30,
                            color: ExperienceColors.ember,
                          ),
                        ),
                      ),
                      const SizedBox(height: ExperienceSpacing.md),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: ExperienceType.headline(ExperienceColors.ink),
                      ),
                      const SizedBox(height: ExperienceSpacing.xs),
                      Text(
                        description,
                        textAlign: TextAlign.center,
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
                              gradient: ExperienceColors.emberGradient,
                              borderRadius: ExperienceRadius.chipRadius,
                              boxShadow: ExperienceShadows.card,
                            ),
                            child: InkWell(
                              key: const Key('locked-see-plans'),
                              onTap: () {
                                final callback = onOpenPlans;
                                if (callback != null) {
                                  callback();
                                  return;
                                }
                                final repo = EntitlementScope.repositoryOf(
                                  context,
                                );
                                if (repo != null) {
                                  PlansSheet.show(context, repo);
                                }
                              },
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
                                      style: ExperienceType.label(Colors.white),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
