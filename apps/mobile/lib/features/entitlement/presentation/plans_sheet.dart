import 'package:flutter/material.dart';

import '../../../design_system/letter_theme.dart';
import '../domain/entitlement.dart';
import '../domain/entitlement_repository.dart';

/// Purchase surface (spec: 2026-07-29-paid-split-and-paywall REQ-005/006).
///
/// Shown before any personal question, from locked premium surfaces, or from
/// You. Never inside an acute Care flow, safety route, or export flow.
class PlansSheet extends StatefulWidget {
  const PlansSheet({required this.repository, super.key});

  final EntitlementRepository repository;

  static Future<void> show(BuildContext context, EntitlementRepository repo) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PlansSheet(repository: repo),
    );
  }

  @override
  State<PlansSheet> createState() => _PlansSheetState();
}

class _PlansSheetState extends State<PlansSheet> {
  String? _selectedPlanId;
  bool _starting = false;

  Future<void> _start() async {
    final planId = _selectedPlanId;
    if (planId == null || _starting) return;
    setState(() => _starting = true);
    await widget.repository.startIntroMonth(planId);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
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
            const Text(
              'Choose your plan',
              style: TextStyle(
                fontFamily: 'Newsreader',
                fontSize: 25,
                height: 1.05,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: LetterSpacing.xs),
            const Text(
              'Your next difficult window, prepared.',
              style: TextStyle(
                color: LetterColors.muted,
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: LetterSpacing.md),
            Container(
              key: const Key('intro-offer-banner'),
              padding: const EdgeInsets.all(LetterSpacing.sm),
              decoration: BoxDecoration(
                color: LetterColors.tealSoft,
                borderRadius: BorderRadius.circular(LetterRadius.control),
              ),
              child: const Text(
                '$introOfferLabel — $introRenewalNote',
                style: TextStyle(
                  color: LetterColors.tealDark,
                  fontSize: 13.5,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: LetterSpacing.md),
            for (final plan in letterPlans)
              Padding(
                padding: const EdgeInsets.only(bottom: LetterSpacing.sm),
                child: _PlanTile(
                  plan: plan,
                  selected: _selectedPlanId == plan.id,
                  onTap: () => setState(() => _selectedPlanId = plan.id),
                ),
              ),
            const Text(
              yearlyVsSixMonthsNote,
              textAlign: TextAlign.center,
              style: TextStyle(color: LetterColors.muted, fontSize: 12.5),
            ),
            const SizedBox(height: LetterSpacing.md),
            FilledButton(
              key: const Key('plans-start-intro'),
              onPressed: _selectedPlanId == null || _starting ? null : _start,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: LetterColors.teal,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(LetterRadius.control),
                ),
              ),
              child: Text(
                _selectedPlanId == null
                    ? 'Select a plan'
                    : 'Start \$0.99 first month',
              ),
            ),
            const SizedBox(height: LetterSpacing.xs),
            const Text(
              'Acute Care, period tracking, and your data stay available even '
              'if you stop paying. Your health data never leaves this device '
              'for billing.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: LetterColors.muted,
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  final LetterPlan plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${plan.title}, ${plan.priceLabel}',
      child: InkWell(
        key: Key('plan-${plan.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(LetterRadius.control),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? LetterColors.tealSoft : LetterColors.surface,
            borderRadius: BorderRadius.circular(LetterRadius.control),
            border: Border.all(
              color: selected ? LetterColors.teal : LetterColors.line,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: LetterColors.ink,
                      ),
                    ),
                    if (plan.highlight != null)
                      Text(
                        plan.highlight!,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: LetterColors.tealDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    plan.priceLabel,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: LetterColors.ink,
                    ),
                  ),
                  Text(
                    plan.effectiveMonthlyLabel,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: LetterColors.muted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
