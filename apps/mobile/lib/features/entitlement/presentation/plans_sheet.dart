import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../design_system/letter_theme.dart';
import '../../../experience/plus/plus_experience.dart';
import '../../analytics/domain/analytics_service.dart' as analytics;
import '../../analytics/presentation/analytics_scope.dart';
import '../domain/entitlement.dart';
import '../domain/entitlement_repository.dart';

@visibleForTesting
final privacyPolicyUrl = Uri.parse('https://letterwithin.app/privacy');

@visibleForTesting
Uri termsOfUseUrlFor(TargetPlatform platform) => switch (platform) {
  TargetPlatform.iOS || TargetPlatform.macOS => Uri.parse(
    'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/',
  ),
  _ => Uri.parse('https://letterwithin.app/terms'),
};

@visibleForTesting
Uri? refundRequestUrlFor(TargetPlatform platform) => switch (platform) {
  TargetPlatform.iOS => Uri.parse('https://reportaproblem.apple.com/'),
  TargetPlatform.android => Uri.parse(
    'https://support.google.com/googleplay/workflow/9813244',
  ),
  _ => null,
};

@visibleForTesting
Uri? subscriptionManagementUrlFor(TargetPlatform platform) =>
    switch (platform) {
      TargetPlatform.iOS => Uri.parse(
        'https://apps.apple.com/account/subscriptions',
      ),
      TargetPlatform.android => Uri.parse(
        'https://play.google.com/store/account/subscriptions',
      ),
      _ => null,
    };

/// Store catalog and purchase surface. It never invents a successful purchase
/// when the store is unavailable or a user cancels.
class PlansSheet extends StatefulWidget {
  const PlansSheet({required this.repository, super.key});

  final EntitlementRepository repository;

  static Future<void> show(
    BuildContext context,
    EntitlementRepository repo,
  ) async {
    await PlusExperience.open(context, entitlementRepository: repo);
  }

  @override
  State<PlansSheet> createState() => _PlansSheetState();
}

class _PlansSheetState extends State<PlansSheet> {
  String? _selectedPlanId;
  List<LetterPlan> _plans = const [];
  String? _error;
  String? _notice;
  bool _loading = true;
  bool _starting = false;
  bool _restoring = false;
  Uri? _managementUrl;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    try {
      final plans = await widget.repository.loadPlans();
      final managementUrl = await widget.repository.managementUrl();
      if (!mounted) return;
      setState(() {
        _plans = plans;
        _managementUrl = managementUrl;
        _loading = false;
        _error = plans.isEmpty ? 'Plans are temporarily unavailable.' : null;
      });
    } on EntitlementException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Plans are temporarily unavailable.';
      });
    }
  }

  Future<void> _manageSubscription() async {
    final url =
        _managementUrl ?? subscriptionManagementUrlFor(defaultTargetPlatform);
    if (url == null) return;
    final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      setState(() => _error = 'Subscription settings could not be opened.');
    }
  }

  Future<void> _requestRefund() async {
    final url = refundRequestUrlFor(defaultTargetPlatform);
    if (url == null) return;
    final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      setState(() => _error = 'The store refund page could not be opened.');
    }
  }

  Future<void> _openLegalUrl(Uri url, String label) async {
    final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      setState(() => _error = '$label could not be opened.');
    }
  }

  Future<void> _start() async {
    final planId = _selectedPlanId;
    if (planId == null || _starting) return;
    setState(() {
      _starting = true;
      _error = null;
      _notice = null;
    });
    final result = await widget.repository.purchase(planId);
    await _trackPurchase(planId, result.outcome);
    if (!mounted) return;
    switch (result.outcome) {
      case PurchaseOutcome.activated:
        Navigator.of(context).pop();
      case PurchaseOutcome.pending:
        setState(() {
          _starting = false;
          _notice = 'Purchase is pending store confirmation.';
        });
      case PurchaseOutcome.cancelled:
        setState(() {
          _starting = false;
          _notice = 'Purchase cancelled. No charge or access was added.';
        });
      case PurchaseOutcome.failed:
      case PurchaseOutcome.unavailable:
        setState(() {
          _starting = false;
          _error = result.message ?? 'The purchase could not be completed.';
        });
    }
  }

  Future<void> _trackPurchase(String planId, PurchaseOutcome outcome) async {
    final service = AnalyticsScope.maybeOf(context);
    if (service == null) return;
    final offer = switch (planId) {
      'letter_monthly' => analytics.PurchaseOffer.monthly,
      'letter_yearly' => analytics.PurchaseOffer.annual,
      'letter_lifetime' => analytics.PurchaseOffer.lifetime,
      _ => null,
    };
    if (offer == null) return;
    final analyticsOutcome = switch (outcome) {
      PurchaseOutcome.activated => analytics.PurchaseOutcome.completed,
      PurchaseOutcome.pending => analytics.PurchaseOutcome.pending,
      PurchaseOutcome.cancelled => analytics.PurchaseOutcome.cancelled,
      PurchaseOutcome.failed ||
      PurchaseOutcome.unavailable => analytics.PurchaseOutcome.failed,
    };
    try {
      await service.track(
        analytics.AnalyticsPayload(
          event: analytics.PurchaseFlowOutcomeEvent(
            appVersion: const String.fromEnvironment(
              'FLUTTER_BUILD_NAME',
              defaultValue: 'development',
            ),
            platform: kIsWeb
                ? analytics.AnalyticsPlatform.web
                : switch (defaultTargetPlatform) {
                    TargetPlatform.iOS ||
                    TargetPlatform.macOS => analytics.AnalyticsPlatform.ios,
                    _ => analytics.AnalyticsPlatform.android,
                  },
            offer: offer,
            outcome: analyticsOutcome,
          ),
          timestamp: DateTime.now().toUtc(),
        ),
      );
    } on Object {
      // Optional operational analytics never changes purchase behavior.
    }
  }

  Future<void> _restore() async {
    if (_restoring) return;
    setState(() {
      _restoring = true;
      _error = null;
      _notice = null;
    });
    final state = await widget.repository.restorePurchases();
    final managementUrl = await widget.repository.managementUrl();
    if (!mounted) return;
    setState(() {
      _restoring = false;
      _managementUrl = managementUrl;
      if (state.hasPremiumAccess) {
        _notice = 'Letter Within Plus restored.';
      } else if (state.status == EntitlementStatus.pending) {
        _notice = 'Restore is pending store confirmation.';
      } else if (state.status == EntitlementStatus.offlineUnknown) {
        _error = 'Letter Within could not verify purchases while offline.';
      } else if (state.message != null) {
        _error = state.message;
      } else {
        _notice = 'No Letter Within Plus purchase was found.';
      }
    });
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
              'Choose Letter Within Plus',
              style: TextStyle(
                fontFamily: 'Newsreader',
                fontSize: 25,
                height: 1.05,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: LetterSpacing.xs),
            const Text(
              'Continuing memory and preparation for the next difficult window.',
              style: TextStyle(
                color: LetterColors.muted,
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: LetterSpacing.md),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null && _plans.isEmpty)
              _MessageBox(
                key: const Key('plans-unavailable'),
                text: _error!,
                error: true,
              )
            else ...[
              Container(
                key: const Key('plans-store-price-note'),
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
              for (final plan in _plans)
                Padding(
                  padding: const EdgeInsets.only(bottom: LetterSpacing.sm),
                  child: _PlanTile(
                    plan: plan,
                    selected: _selectedPlanId == plan.id,
                    onTap: () => setState(() => _selectedPlanId = plan.id),
                  ),
                ),
              const Text(
                yearlyVsLifetimeNote,
                textAlign: TextAlign.center,
                style: TextStyle(color: LetterColors.muted, fontSize: 12.5),
              ),
              if (_error != null) ...[
                const SizedBox(height: LetterSpacing.sm),
                _MessageBox(text: _error!, error: true),
              ],
              if (_notice != null) ...[
                const SizedBox(height: LetterSpacing.sm),
                _MessageBox(text: _notice!, error: false),
              ],
              const SizedBox(height: LetterSpacing.md),
              FilledButton(
                key: const Key('plans-purchase'),
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
                      : 'Continue to purchase',
                ),
              ),
            ],
            const SizedBox(height: LetterSpacing.xs),
            TextButton(
              key: const Key('plans-restore'),
              onPressed: _restoring ? null : _restore,
              child: Text(_restoring ? 'Restoring…' : 'Restore Purchases'),
            ),
            if (_managementUrl != null ||
                subscriptionManagementUrlFor(defaultTargetPlatform) != null)
              TextButton(
                key: const Key('plans-manage-subscription'),
                onPressed: _manageSubscription,
                child: const Text('Manage Subscription'),
              ),
            if (refundRequestUrlFor(defaultTargetPlatform) != null)
              TextButton(
                key: const Key('plans-request-refund'),
                onPressed: _requestRefund,
                child: const Text('Request a Refund'),
              ),
            if (refundRequestUrlFor(defaultTargetPlatform) != null)
              const Padding(
                padding: EdgeInsets.only(bottom: LetterSpacing.xs),
                child: Text(
                  'The store reviews refunds. Cancelling only stops future renewals.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: LetterColors.muted,
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
              ),
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                TextButton(
                  key: const Key('plans-privacy-policy'),
                  onPressed: () =>
                      _openLegalUrl(privacyPolicyUrl, 'Privacy Policy'),
                  child: const Text('Privacy Policy'),
                ),
                TextButton(
                  key: const Key('plans-terms-of-use'),
                  onPressed: () => _openLegalUrl(
                    termsOfUseUrlFor(defaultTargetPlatform),
                    'Terms of Use',
                  ),
                  child: const Text('Terms of Use'),
                ),
              ],
            ),
            const Text(
              'Acute Care, period tracking, and your local data stay available '
              'even if Plus ends. Billing never receives health records.',
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

class _MessageBox extends StatelessWidget {
  const _MessageBox({required this.text, required this.error, super.key});

  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(LetterSpacing.sm),
    decoration: BoxDecoration(
      color: error ? Colors.red.shade50 : LetterColors.tealSoft,
      borderRadius: BorderRadius.circular(LetterRadius.control),
    ),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: error ? Colors.red.shade900 : LetterColors.tealDark,
      ),
    ),
  );
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
  Widget build(BuildContext context) => Semantics(
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
                  Text(
                    'Reference ${plan.referencePriceLabel}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: LetterColors.muted,
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
