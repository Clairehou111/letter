import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../features/entitlement/domain/entitlement.dart';
import '../../features/entitlement/domain/entitlement_repository.dart';
import '../../features/analytics/domain/analytics_service.dart' as analytics;
import '../../features/analytics/presentation/analytics_scope.dart';
import '../theme/experience_foundation.dart';

/// The intent a Reports boundary action carried into Plus.
///
/// Plus owns no report ranges and no report data; it only mirrors the exact
/// requested outcome back to the user and returns the same intent if access is
/// activated, so the caller can continue what the user originally asked for.
enum PlusOutcomeIntentKind { seeAllCycles, export }

class PlusOutcomeContext {
  const PlusOutcomeContext._({
    required this.headline,
    required this.kind,
    this.rangeId,
    this.opensDateRangePicker = false,
  });

  /// A locked range intent. [rangeId] is an opaque caller-owned identifier and
  /// must round-trip unchanged through [PlusCommitResult.activated].
  const factory PlusOutcomeContext.seeAllCycles({
    required String headline,
    required String rangeId,
    bool opensDateRangePicker,
  }) = PlusOutcomeContext._seeAllCycles;

  /// A locked export intent.
  const factory PlusOutcomeContext.export({required String headline}) =
      PlusOutcomeContext._export;

  const PlusOutcomeContext._seeAllCycles({
    required String headline,
    required String rangeId,
    bool opensDateRangePicker = false,
  }) : this._(
         headline: headline,
         kind: PlusOutcomeIntentKind.seeAllCycles,
         rangeId: rangeId,
         opensDateRangePicker: opensDateRangePicker,
       );

  const PlusOutcomeContext._export({required String headline})
    : this._(headline: headline, kind: PlusOutcomeIntentKind.export);

  /// The exact outcome line used as the commitment-sheet headline.
  final String headline;

  final PlusOutcomeIntentKind kind;

  /// Opaque range identity for [PlusOutcomeIntentKind.seeAllCycles].
  final String? rangeId;

  /// True when a fulfilled range intent should open the caller's date-range
  /// picker after returning.
  final bool opensDateRangePicker;
}

enum PlusCommitStatus { activated, dismissed, unchanged }

/// Result of the commitment sheet. Dismissal abandons nothing; activation
/// carries the original intent back to the caller.
class PlusCommitResult {
  const PlusCommitResult._(this.status, this.intent);

  const PlusCommitResult.activated(PlusOutcomeContext? intent)
    : this._(PlusCommitStatus.activated, intent);

  const PlusCommitResult.dismissed() : this._(PlusCommitStatus.dismissed, null);

  const PlusCommitResult.unchanged() : this._(PlusCommitStatus.unchanged, null);

  final PlusCommitStatus status;
  final PlusOutcomeContext? intent;

  bool get isActivated => status == PlusCommitStatus.activated;
}

/// Plus — a commitment slip, never a tab and never a cold sales page.
///
/// Reached only from a Reports boundary action with an outcome context, or
/// deliberately from Settings/Patterns without one. The sheet restates the
/// requested line, renders the real plan catalog from
/// [EntitlementRepository.loadPlans], keeps the store as pricing source of
/// truth, and treats pending, offlineUnknown, gracePeriod, cancelled, and
/// failed as first-class calm states.
///
/// Entitlement gates generation and refresh of premium depth — never
/// ownership. Existing local material stays readable after lapse.
class PlusExperience extends StatefulWidget {
  const PlusExperience({
    super.key,
    required this.entitlementRepository,
    this.outcomeContext,
    this.openLegalUrl,
    this.onOpenAccount,
  });

  final EntitlementRepository entitlementRepository;
  final Future<bool> Function(Uri url)? openLegalUrl;
  final VoidCallback? onOpenAccount;

  /// Additive outcome context. Null means a deliberate Settings/Patterns
  /// entry: the headline is the plain product name and no outcome is invented.
  final PlusOutcomeContext? outcomeContext;

  /// Single public entry. Existing call sites compile unchanged; callers that
  /// await the future now receive the commitment result, and scrim/drag/close
  /// dismissal resolves to [PlusCommitResult.dismissed].
  static Future<PlusCommitResult?> open(
    BuildContext context, {
    required EntitlementRepository entitlementRepository,
    PlusOutcomeContext? outcomeContext,
    VoidCallback? onOpenAccount,
  }) async {
    final result = await showExperienceSheet<PlusCommitResult>(
      context,
      child: PlusExperience(
        entitlementRepository: entitlementRepository,
        outcomeContext: outcomeContext,
        onOpenAccount: onOpenAccount,
      ),
    );
    return result ?? const PlusCommitResult.dismissed();
  }

  @override
  State<PlusExperience> createState() => _PlusExperienceState();
}

class _PlusExperienceState extends State<PlusExperience> {
  late EntitlementState _entitlement;
  StreamSubscription<EntitlementState>? _entitlementSubscription;

  List<LetterPlan>? _plans;
  Object? _plansError;
  bool _plansLoading = true;
  int _plansLoadGeneration = 0;
  String? _selectedPlanId;

  bool _purchaseInFlight = false;
  bool _restoreInFlight = false;
  bool _completing = false;
  bool _trackedView = false;
  bool _showPlanChoices = false;

  /// One calm feedback line at a time — acknowledgments and honest failures.
  /// Errors are visual + textual only; errors never haptic.
  String? _feedbackLine;
  bool _feedbackIsError = false;

  Uri? _managementUrl;
  int _managementUrlLoadGeneration = 0;

  EntitlementRepository get _repository => widget.entitlementRepository;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_trackedView) return;
    _trackedView = true;
    _track(
      analytics.PaywallViewedEvent(switch (widget.outcomeContext?.kind) {
        PlusOutcomeIntentKind.export => analytics.PaywallContext.patternReport,
        PlusOutcomeIntentKind.seeAllCycles =>
          analytics.PaywallContext.patternReport,
        null => analytics.PaywallContext.settings,
      }),
    );
  }

  void _track(analytics.AnalyticsEvent event) {
    final service = AnalyticsScope.maybeOf(context);
    if (service == null) return;
    unawaited(
      service
          .track(
            analytics.AnalyticsPayload(
              event: event,
              timestamp: DateTime.now().toUtc(),
            ),
          )
          .catchError((Object _) {}),
    );
  }

  analytics.PurchaseOffer _offerFor(String planId) => switch (planId) {
    'letter_monthly' => analytics.PurchaseOffer.monthly,
    'letter_lifetime' => analytics.PurchaseOffer.lifetime,
    _ => analytics.PurchaseOffer.annual,
  };

  void _trackPurchase(String planId, analytics.PurchaseOutcome outcome) {
    _track(
      analytics.PurchaseFlowOutcomeEvent(
        offer: _offerFor(planId),
        outcome: outcome,
      ),
    );
  }

  analytics.PlanCatalogFailureReason _planLoadReason(Object error) {
    if (error is! EntitlementException) {
      return analytics.PlanCatalogFailureReason.unknown;
    }
    return switch (error.planLoadFailureCode) {
      PlanLoadFailureCode.accountNotReady =>
        analytics.PlanCatalogFailureReason.accountNotReady,
      PlanLoadFailureCode.storeNotSelected =>
        analytics.PlanCatalogFailureReason.storeNotSelected,
      PlanLoadFailureCode.apiKeyMissing =>
        analytics.PlanCatalogFailureReason.apiKeyMissing,
      PlanLoadFailureCode.storeSetupFailed =>
        analytics.PlanCatalogFailureReason.storeSetupFailed,
      PlanLoadFailureCode.storeConfigurationError =>
        analytics.PlanCatalogFailureReason.storeConfigurationError,
      PlanLoadFailureCode.offeringRequestFailed =>
        analytics.PlanCatalogFailureReason.offeringRequestFailed,
      PlanLoadFailureCode.emptyOffering =>
        analytics.PlanCatalogFailureReason.emptyOffering,
      null => analytics.PlanCatalogFailureReason.unknown,
    };
  }

  @override
  void initState() {
    super.initState();
    _entitlement = _repository.current;
    _entitlementSubscription = _repository.watch().listen((state) {
      if (!mounted) {
        return;
      }
      final waitingForAccount =
          _plansError is EntitlementException &&
          (_plansError! as EntitlementException).planLoadFailureCode ==
              PlanLoadFailureCode.accountNotReady;
      setState(() => _entitlement = state);
      unawaited(_loadManagementUrl());
      // The app can open its shell while account-bound store reconciliation
      // finishes. If plans were requested before the user ID reached the store
      // adapter, retry once that unavailable state clears.
      if (waitingForAccount &&
          !_plansLoading &&
          state.message !=
              'Connect an account to view plans and restore purchases.') {
        unawaited(_loadPlans());
      }
    });
    _loadPlans();
    _loadManagementUrl();
  }

  @override
  void dispose() {
    _entitlementSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadPlans() async {
    final generation = ++_plansLoadGeneration;
    setState(() {
      _plansLoading = true;
      _plansError = null;
    });
    try {
      final plans = await _repository.loadPlans();
      if (!mounted || generation != _plansLoadGeneration) {
        return;
      }
      setState(() {
        _plans = plans;
        _plansLoading = false;
        _selectedPlanId = _showPlanChoices
            ? _alternativeSubscriptionId(plans)
            : _defaultSelection(plans);
      });
      _track(const analytics.PlanCatalogLoadEvent.loaded());
    } catch (error) {
      if (!mounted || generation != _plansLoadGeneration) {
        return;
      }
      setState(() {
        _plans = null;
        _plansError = error;
        _plansLoading = false;
      });
      final reason = _planLoadReason(error);
      developer.log('plan_catalog_load failed: ${reason.name}', name: 'plus');
      _track(analytics.PlanCatalogLoadEvent.failed(reason));
    }
  }

  Future<void> _loadManagementUrl() async {
    final generation = ++_managementUrlLoadGeneration;
    try {
      final url = await _repository.managementUrl();
      if (!mounted || generation != _managementUrlLoadGeneration) {
        return;
      }
      setState(() => _managementUrl = url);
    } catch (_) {
      // The action remains visible and explains when this store has no link.
    }
  }

  String? _defaultSelection(List<LetterPlan> plans) {
    final available = plans.where((plan) => plan.available).toList();
    if (available.isEmpty) {
      return null;
    }
    return available.first.id;
  }

  String? _alternativeSubscriptionId(List<LetterPlan> plans) {
    final otherId = _entitlement.planId == 'letter_monthly'
        ? 'letter_yearly'
        : 'letter_monthly';
    return plans.any((plan) => plan.id == otherId && plan.available)
        ? otherId
        : null;
  }

  void _setFeedback(String line, {required bool isError}) {
    setState(() {
      _feedbackLine = line;
      _feedbackIsError = isError;
    });
  }

  void _clearFeedback() {
    if (_feedbackLine == null) {
      return;
    }
    setState(() {
      _feedbackLine = null;
      _feedbackIsError = false;
    });
  }

  Future<void> _completeActivated() async {
    if (_completing) {
      return;
    }
    _completing = true;
    await ExperienceHaptics.saved();
    if (!mounted) {
      return;
    }
    Navigator.of(
      context,
    ).pop(PlusCommitResult.activated(widget.outcomeContext));
  }

  Future<void> _purchaseSelected() async {
    final planId = _selectedPlanId;
    if (planId == null ||
        _purchaseInFlight ||
        (_entitlement.hasPremiumAccess && planId == _entitlement.planId)) {
      return;
    }
    _clearFeedback();
    setState(() => _purchaseInFlight = true);
    try {
      final result = await _repository.purchase(planId);
      if (!mounted) {
        return;
      }
      setState(() => _entitlement = result.state);
      switch (result.outcome) {
        case PurchaseOutcome.activated:
          _trackPurchase(planId, analytics.PurchaseOutcome.completed);
          final hasOverlappingPlans =
              result.state.activeSubscriptions
                  .map((subscription) => subscription.productId)
                  .toSet()
                  .length >
              1;
          if (_showPlanChoices &&
              (result.state.planId != planId || hasOverlappingPlans)) {
            _setFeedback(
              hasOverlappingPlans
                  ? 'Both plans are active in this store.'
                  : 'The store still shows your current plan. Check again '
                        'after its next renewal.',
              isError: false,
            );
          } else {
            await _completeActivated();
          }
        case PurchaseOutcome.pending:
          _trackPurchase(planId, analytics.PurchaseOutcome.pending);
          _setFeedback(
            'Waiting for the store to confirm your purchase.',
            isError: false,
          );
        case PurchaseOutcome.cancelled:
          _trackPurchase(planId, analytics.PurchaseOutcome.cancelled);
          // Cancellation never becomes failure and never grants access.
          _setFeedback('Purchase canceled.', isError: false);
        case PurchaseOutcome.failed:
          _trackPurchase(planId, analytics.PurchaseOutcome.failed);
          _setFeedback(
            result.message ??
                'The purchase could not be completed. '
                    'You have not been charged.',
            isError: true,
          );
        case PurchaseOutcome.unavailable:
          _trackPurchase(planId, analytics.PurchaseOutcome.failed);
          _setFeedback(
            result.message ??
                'This needs a connection. '
                    'Your records are already safe on this device.',
            isError: true,
          );
      }
    } on EntitlementException catch (error) {
      _trackPurchase(planId, analytics.PurchaseOutcome.failed);
      if (!mounted) {
        return;
      }
      _setFeedback(error.message, isError: true);
    } catch (_) {
      _trackPurchase(planId, analytics.PurchaseOutcome.failed);
      if (!mounted) {
        return;
      }
      _setFeedback(
        'This needs a connection. '
        'Your records are already safe on this device.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _purchaseInFlight = false);
      }
    }
  }

  Future<void> _restorePurchases() async {
    if (_restoreInFlight) {
      return;
    }
    _clearFeedback();
    setState(() => _restoreInFlight = true);
    try {
      final state = await _repository.restorePurchases();
      if (!mounted) {
        return;
      }
      setState(() => _entitlement = state);
      if (state.hasPremiumAccess) {
        await _completeActivated();
      } else {
        _setFeedback(
          state.message ??
              'No active Plus purchase was found for this store account.',
          isError: false,
        );
      }
    } on EntitlementException catch (error) {
      if (!mounted) {
        return;
      }
      _setFeedback(error.message, isError: true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _setFeedback(
        'This needs a connection. '
        'Your records are already safe on this device.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _restoreInFlight = false);
      }
    }
  }

  Future<void> _openManagement() async {
    final url = _managementUrl;
    if (url == null) {
      _setFeedback(
        'Subscription settings are unavailable in this store.',
        isError: false,
      );
      return;
    }
    await _openExternalLink(url);
  }

  void _togglePlanChoices() {
    setState(() {
      _showPlanChoices = !_showPlanChoices;
      _selectedPlanId = _showPlanChoices
          ? _alternativeSubscriptionId(_plans ?? const <LetterPlan>[])
          : _defaultSelection(_plans ?? const <LetterPlan>[]);
      _feedbackLine = null;
    });
  }

  Future<void> _openExternalLink(Uri url) async {
    try {
      final opener =
          widget.openLegalUrl ??
          (Uri destination) =>
              launchUrl(destination, mode: LaunchMode.externalApplication);
      final opened = await opener(url);
      if (!opened && mounted) {
        _setFeedback(
          'The link could not be opened. Please try again.',
          isError: true,
        );
      }
    } on Object {
      if (mounted) {
        _setFeedback(
          'The link could not be opened. Please try again.',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPremium = _entitlement.hasPremiumAccess;
    final statusCopy = _statusCopy();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        ExperienceSpacing.screenMargin,
        0,
        ExperienceSpacing.screenMargin,
        ExperienceSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildOutcomeHeadline(),
          if (statusCopy != null) ...<Widget>[
            const SizedBox(height: ExperienceSpacing.sm),
            _StatusBanner(
              copy: statusCopy,
              trailingMessage: _entitlement.message,
            ),
          ],
          if (hasPremium) ...<Widget>[
            const SizedBox(height: ExperienceSpacing.md),
            _buildActiveSection(),
          ] else ...<Widget>[
            const SizedBox(height: ExperienceSpacing.sm),
            _buildPurchaseSection(),
          ],
          const SizedBox(height: ExperienceSpacing.sm),
          _buildFeedback(),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Outcome context line — the sheet says back what was asked for.
  // -------------------------------------------------------------------------

  Widget _buildOutcomeHeadline() {
    final contextOutcome = widget.outcomeContext;
    return Semantics(
      header: true,
      child: Text(
        contextOutcome?.headline ?? introOfferLabel,
        textAlign: TextAlign.center,
        style: ExperienceType.title(ExperienceColors.ink),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Status banner — pending, offlineUnknown, gracePeriod, lapsed are
  // first-class states with calm, exact copy.
  // -------------------------------------------------------------------------

  _StatusCopy? _statusCopy() {
    return switch (_entitlement.status) {
      EntitlementStatus.activeIntro || EntitlementStatus.activePaid => null,
      EntitlementStatus.gracePeriod => const _StatusCopy(
        title: 'Plus continues for now',
        body: 'The store is resolving a billing issue.',
        tone: _StatusTone.neutral,
      ),
      EntitlementStatus.pending => const _StatusCopy(
        title: 'A store request is in progress',
        body: '',
        tone: _StatusTone.neutral,
      ),
      EntitlementStatus.lapsed => const _StatusCopy(
        title: 'Plus has ended',
        body: 'Your records are still here. Choose a plan to restart Plus.',
        tone: _StatusTone.neutral,
      ),
      EntitlementStatus.offlineUnknown => const _StatusCopy(
        title: 'We could not check your subscription',
        body: 'Please try again when the store is available.',
        tone: _StatusTone.caution,
      ),
      // Never subscribed, or store unavailable offline. Copy must not claim
      // a past purchase — the standard commitment below carries this state.
      EntitlementStatus.freeOrUnknown => null,
    };
  }

  // -------------------------------------------------------------------------
  // Purchase section — real plan labels from loadPlans.
  // -------------------------------------------------------------------------

  Widget _buildPurchaseSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (_plansLoading)
          const _PlansSkeleton()
        else if (_plansError != null)
          _buildPlansError()
        else
          _buildPlanList(),
        if (!_accountRequired) ...<Widget>[
          const SizedBox(height: ExperienceSpacing.md),
          _buildPurchaseButton(),
          const SizedBox(height: ExperienceSpacing.xs),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: ExperienceSpacing.sm,
            children: <Widget>[
              Semantics(
                link: true,
                child: TextButton(
                  onPressed: () => _openExternalLink(
                    Uri.parse('https://letterwithin.app/privacy'),
                  ),
                  child: const Text('Privacy Policy'),
                ),
              ),
              Semantics(
                link: true,
                child: TextButton(
                  onPressed: () => _openExternalLink(
                    Uri.parse(
                      'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/',
                    ),
                  ),
                  child: const Text('Terms of Use'),
                ),
              ),
            ],
          ),
          const SizedBox(height: ExperienceSpacing.sm),
          _PlusSecondaryButton(
            label: _restoreInFlight
                ? 'Checking with the store…'
                : 'Restore a previous purchase',
            onPressed: _restoreInFlight ? null : _restorePurchases,
          ),
        ],
      ],
    );
  }

  Widget _buildPlansError() {
    final accountRequired = _accountRequired;
    final storeUnavailable =
        _plansError is EntitlementException &&
        (_plansError! as EntitlementException).message ==
            'Purchases are unavailable on this build.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ExperienceSpacing.sm),
      decoration: BoxDecoration(
        color: ExperienceColors.surfaceWarm,
        borderRadius: ExperienceRadius.cardRadius,
        border: Border.all(color: ExperienceColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            accountRequired
                ? 'Connect an account for Plus'
                : storeUnavailable
                ? 'Plans are unavailable'
                : 'Plans could not be loaded',
            style: ExperienceType.bodyStrong(ExperienceColors.ink),
          ),
          const SizedBox(height: ExperienceSpacing.xs),
          Text(
            accountRequired
                ? 'Create or connect an account to view plans and restore purchases.'
                : storeUnavailable
                ? 'Please try again after an app update.'
                : 'Please try again.',
            style: ExperienceType.bodySmall(ExperienceColors.inkSoft),
          ),
          const SizedBox(height: ExperienceSpacing.sm),
          if (accountRequired && widget.onOpenAccount != null)
            _PlusSecondaryButton(
              label: 'Open account settings',
              onPressed: () {
                final onOpenAccount = widget.onOpenAccount!;
                Navigator.of(context).pop(const PlusCommitResult.unchanged());
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  onOpenAccount();
                });
              },
            )
          else if (!accountRequired)
            _PlusSecondaryButton(label: 'Try again', onPressed: _loadPlans),
        ],
      ),
    );
  }

  bool get _accountRequired =>
      _plansError is EntitlementException &&
      (_plansError! as EntitlementException).planLoadFailureCode ==
          PlanLoadFailureCode.accountNotReady;

  Widget _buildPlanList() {
    final plans = _plans ?? const <LetterPlan>[];
    if (plans.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(ExperienceSpacing.sm),
        decoration: BoxDecoration(
          color: ExperienceColors.surfaceWarm,
          borderRadius: ExperienceRadius.cardRadius,
          border: Border.all(color: ExperienceColors.hairline),
        ),
        child: Text(
          'No plans are available right now. Please try again later.',
          style: ExperienceType.bodySmall(ExperienceColors.inkSoft),
        ),
      );
    }
    final ordered = [...plans]
      ..sort((left, right) {
        int rank(LetterPlan plan) => switch (plan.id) {
          'letter_yearly' => 0,
          'letter_monthly' => 1,
          'letter_lifetime' => 2,
          _ => 3,
        };
        return rank(left).compareTo(rank(right));
      });
    return Column(
      children: <Widget>[
        for (final plan in ordered) ...<Widget>[
          _PlanCard(
            plan: plan,
            selected: plan.id == _selectedPlanId,
            enabled: !_purchaseInFlight && !_restoreInFlight,
            onSelected: plan.available
                ? () {
                    ExperienceHaptics.pick();
                    setState(() => _selectedPlanId = plan.id);
                  }
                : null,
          ),
          const SizedBox(height: ExperienceSpacing.sm),
        ],
      ],
    );
  }

  Widget _buildPurchaseButton() {
    final plans = _plans ?? const <LetterPlan>[];
    final selected = plans
        .where((plan) => plan.id == _selectedPlanId && plan.available)
        .firstOrNull;
    final enabled =
        selected != null &&
        !_purchaseInFlight &&
        !_plansLoading &&
        (!_entitlement.hasPremiumAccess || selected.id != _entitlement.planId);
    final outcome = _showPlanChoices && _entitlement.hasPremiumAccess
        ? 'Continue with ${selected?.title ?? 'a plan'}'
        : widget.outcomeContext?.headline ?? 'Start $introOfferLabel';
    final label = _purchaseInFlight
        ? 'Talking to the store…'
        : selected == null
        ? 'Choose a plan'
        : outcome;
    final price = selected?.priceLabel;
    return Semantics(
      button: true,
      enabled: enabled,
      label: selected == null ? label : '$label, $price',
      child: Opacity(
        opacity: enabled || _purchaseInFlight ? 1 : 0.5,
        child: Material(
          color: Colors.transparent,
          borderRadius: ExperienceRadius.chipRadius,
          child: InkWell(
            borderRadius: ExperienceRadius.chipRadius,
            onTap: enabled ? _purchaseSelected : null,
            child: Ink(
              decoration: BoxDecoration(
                gradient: enabled || _purchaseInFlight
                    ? ExperienceColors.emberActionGradient
                    : null,
                color: enabled || _purchaseInFlight
                    ? null
                    : ExperienceColors.surfaceWarm,
                borderRadius: ExperienceRadius.chipRadius,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 54),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  child: Center(
                    child: _purchaseInFlight
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const EmberLoadingIndicator(
                                size: 22,
                                semanticLabel: 'Purchase in progress',
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Text(
                                  label,
                                  textAlign: TextAlign.center,
                                  style: ExperienceType.label(
                                    ExperienceColors.onEmber,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Text.rich(
                            TextSpan(
                              children: <InlineSpan>[
                                TextSpan(
                                  text: label,
                                  style: ExperienceType.label(
                                    enabled
                                        ? ExperienceColors.onEmber
                                        : ExperienceColors.inkSoft,
                                  ),
                                ),
                                if (price != null)
                                  TextSpan(
                                    text: ' — $price',
                                    style: ExperienceType.data(
                                      enabled
                                          ? Colors.white.withValues(alpha: 0.92)
                                          : ExperienceColors.inkSoft,
                                      size: 13,
                                      weight: FontWeight.w500,
                                    ),
                                  ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Active section — current access and actions.
  // Existing subscribers never see acquisition copy.
  // -------------------------------------------------------------------------

  Widget _buildActiveSection() {
    final plans = _plans ?? const <LetterPlan>[];
    final isLifetime = _entitlement.planId == 'letter_lifetime';
    final subscriptions = _entitlement.activeSubscriptions;
    final hasOverlappingPlans =
        subscriptions
            .map((subscription) => subscription.productId)
            .toSet()
            .length >
        1;
    ActivePlanPeriod? latestSubscription;
    for (final subscription in subscriptions) {
      if (latestSubscription == null ||
          (subscription.purchasedAt != null &&
              (latestSubscription.purchasedAt == null ||
                  subscription.purchasedAt!.isAfter(
                    latestSubscription.purchasedAt!,
                  )))) {
        latestSubscription = subscription;
      }
    }
    DateTime? accessThrough;
    for (final endsAt in <DateTime?>[
      _entitlement.expiresAt,
      for (final subscription in subscriptions) subscription.expiresAt,
    ]) {
      if (endsAt != null &&
          (accessThrough == null || endsAt.isAfter(accessThrough))) {
        accessThrough = endsAt;
      }
    }
    final periodLabel = _currentPeriodLabel();
    final displayedPlanId = hasOverlappingPlans
        ? latestSubscription?.productId
        : _entitlement.planId;
    final currentPlan =
        plans.where((plan) => plan.id == displayedPlanId).firstOrNull ??
        letterPlans.where((plan) => plan.id == displayedPlanId).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (_entitlement.status != EntitlementStatus.gracePeriod) ...<Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.check_circle_rounded,
                size: 18,
                color: ExperienceColors.phaseOvulation,
              ),
              const SizedBox(width: ExperienceSpacing.xs),
              Expanded(
                child: Text(
                  'Plus is active',
                  style: ExperienceType.bodySmall(ExperienceColors.inkSoft),
                ),
              ),
            ],
          ),
          const SizedBox(height: ExperienceSpacing.xs),
        ],
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: ExperienceSpacing.sm,
          children: <Widget>[
            Text(
              currentPlan?.title ?? 'Plus',
              style: ExperienceType.headline(ExperienceColors.ink),
            ),
            if (!isLifetime && !hasOverlappingPlans)
              TextButton(
                onPressed: _togglePlanChoices,
                child: Text(_showPlanChoices ? 'Done' : 'Change plan'),
              ),
          ],
        ),
        if (_entitlement.status == EntitlementStatus.activeIntro)
          Text(
            'Introductory period',
            style: ExperienceType.bodySmall(ExperienceColors.inkSoft),
          ),
        if (hasOverlappingPlans) ...<Widget>[
          const SizedBox(height: ExperienceSpacing.xs),
          if (accessThrough != null)
            Text(
              accessThrough.isAfter(DateTime.now().toUtc())
                  ? 'Current Plus access through at least ${_displayDate(accessThrough)}'
                  : 'Last reported Plus period ended ${_displayDate(accessThrough)}',
              style: ExperienceType.bodySmall(ExperienceColors.inkSoft),
            ),
          Text(
            'Another subscription is also active in the store.',
            style: ExperienceType.caption(ExperienceColors.inkSoft),
          ),
        ] else if (periodLabel != null) ...<Widget>[
          const SizedBox(height: ExperienceSpacing.xs),
          Text(
            periodLabel,
            style: ExperienceType.bodySmall(ExperienceColors.inkSoft),
          ),
        ],
        if (_managementUrl != null && !isLifetime)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _openManagement,
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('Manage subscription'),
            ),
          ),
        if (!isLifetime && !hasOverlappingPlans) ...<Widget>[
          if (_showPlanChoices) ...<Widget>[
            const SizedBox(height: ExperienceSpacing.sm),
            const Divider(height: 1, color: ExperienceColors.hairline),
            const SizedBox(height: ExperienceSpacing.sm),
            _buildPlanChangeSection(),
          ],
        ],
      ],
    );
  }

  String? _currentPeriodLabel() {
    if (_entitlement.planId == 'letter_lifetime' ||
        _entitlement.status == EntitlementStatus.gracePeriod) {
      return null;
    }
    return _periodLabel(_entitlement.expiresAt, _entitlement.willRenew);
  }

  String? _periodLabel(DateTime? endsAt, bool? willRenew) {
    if (endsAt == null) {
      return null;
    }
    final dateAndTime = _displayDate(endsAt);
    if (!endsAt.isAfter(DateTime.now().toUtc())) {
      return 'Last reported period ended $dateAndTime';
    }
    return switch (willRenew) {
      true => 'Renews on $dateAndTime',
      false => 'Access until $dateAndTime',
      null => 'Current period ends $dateAndTime',
    };
  }

  String _displayDate(DateTime endsAt) {
    final localDate = endsAt.toLocal();
    final localizations = MaterialLocalizations.of(context);
    final date =
        '${localizations.formatMediumDate(localDate)}, '
        '${localizations.formatYear(localDate)}';
    final hoursUntil = endsAt.difference(DateTime.now().toUtc()).inHours;
    return hoursUntil > -24 && hoursUntil < 24
        ? '$date at ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(localDate))}'
        : date;
  }

  Widget _buildPlanChangeSection() {
    final alternative = (_plans ?? const <LetterPlan>[])
        .where((plan) => plan.id == _selectedPlanId && plan.available)
        .firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (_plansLoading)
          const _PlansSkeleton()
        else if (_plansError != null)
          _buildPlansError()
        else if (alternative == null)
          Text(
            'No other subscription is available right now.',
            style: ExperienceType.bodySmall(ExperienceColors.inkSoft),
          )
        else
          Semantics(
            button: true,
            enabled: !_purchaseInFlight,
            label:
                'Switch to ${alternative.title}, ${alternative.priceLabel}, '
                '${alternative.effectiveMonthlyLabel}',
            child: Material(
              color: ExperienceColors.surfaceWarm,
              borderRadius: ExperienceRadius.cardRadius,
              child: InkWell(
                borderRadius: ExperienceRadius.cardRadius,
                onTap: _purchaseInFlight ? null : _purchaseSelected,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 76),
                  padding: const EdgeInsets.all(ExperienceSpacing.sm),
                  decoration: BoxDecoration(
                    borderRadius: ExperienceRadius.cardRadius,
                    border: Border.all(color: ExperienceColors.hairline),
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              _purchaseInFlight
                                  ? 'Opening store…'
                                  : 'Switch to ${alternative.title}',
                              style: ExperienceType.bodyStrong(
                                ExperienceColors.ink,
                              ),
                            ),
                            const SizedBox(height: ExperienceSpacing.xs),
                            Text(
                              '${alternative.priceLabel} · '
                              '${alternative.effectiveMonthlyLabel}',
                              style: ExperienceType.bodySmall(
                                ExperienceColors.inkSoft,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: ExperienceSpacing.sm),
                      if (_purchaseInFlight)
                        const EmberLoadingIndicator(
                          size: 20,
                          semanticLabel: 'Purchase in progress',
                        )
                      else
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: ExperienceColors.ember,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Feedback line — acknowledgment or honest failure. Errors never haptic.
  // -------------------------------------------------------------------------

  Widget _buildFeedback() {
    final line = _feedbackLine;
    if (line == null) {
      return const SizedBox.shrink();
    }
    if (_feedbackIsError) {
      return Semantics(
        liveRegion: true,
        child: Text(
          line,
          textAlign: TextAlign.center,
          style: ExperienceType.bodySmall(ExperienceColors.error),
        ),
      );
    }
    return SavedRhythmAckLine(line: line);
  }
}

// ---------------------------------------------------------------------------
// Private presentation pieces
// ---------------------------------------------------------------------------

enum _StatusTone { positive, neutral, caution }

final class _StatusCopy {
  const _StatusCopy({
    required this.title,
    required this.body,
    required this.tone,
  });

  final String title;
  final String body;
  final _StatusTone tone;
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.copy, this.trailingMessage});

  final _StatusCopy copy;
  final String? trailingMessage;

  @override
  Widget build(BuildContext context) {
    final accent = switch (copy.tone) {
      _StatusTone.positive => ExperienceColors.phaseOvulation,
      _StatusTone.neutral => ExperienceColors.inkSoft,
      _StatusTone.caution => ExperienceColors.accentGravity,
    };
    return Container(
      padding: const EdgeInsets.all(ExperienceSpacing.sm),
      decoration: BoxDecoration(
        color: ExperienceColors.surface,
        borderRadius: ExperienceRadius.cardRadius,
        border: Border.all(color: ExperienceColors.hairline),
        boxShadow: ExperienceShadows.card,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 4,
            height: 56,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  copy.title,
                  style: ExperienceType.bodyStrong(ExperienceColors.ink),
                ),
                if (copy.body.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    copy.body,
                    style: ExperienceType.bodySmall(ExperienceColors.inkSoft),
                  ),
                ],
                if (trailingMessage != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    trailingMessage!,
                    style: ExperienceType.caption(ExperienceColors.inkSoft),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.enabled,
    this.onSelected,
  });

  final LetterPlan plan;
  final bool selected;
  final bool enabled;
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    final tappable = enabled && plan.available && onSelected != null;
    final selectionDuration = ExperienceMotion.reducedMotion(context)
        ? Duration.zero
        : ExperienceMotion.chipSelect;
    return Semantics(
      button: onSelected != null,
      selected: onSelected == null ? null : selected,
      enabled: onSelected == null ? null : tappable,
      label: plan.available
          ? '${plan.title}, ${plan.priceLabel}'
          : '${plan.title}, not available right now',
      child: Opacity(
        opacity: plan.available ? 1 : 0.55,
        child: Material(
          color: Colors.transparent,
          borderRadius: ExperienceRadius.cardRadius,
          child: InkWell(
            borderRadius: ExperienceRadius.cardRadius,
            onTap: tappable ? onSelected : null,
            child: AnimatedContainer(
              duration: selectionDuration,
              padding: const EdgeInsets.all(ExperienceSpacing.sm),
              constraints: const BoxConstraints(
                minHeight: ExperienceSpacing.degreeTarget,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? ExperienceColors.surfaceWarm
                    : ExperienceColors.surface,
                borderRadius: ExperienceRadius.cardRadius,
                border: Border.all(
                  color: selected
                      ? ExperienceColors.ember
                      : ExperienceColors.hairline,
                  width: selected ? 1.6 : 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (onSelected != null) ...<Widget>[
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected
                                ? ExperienceColors.ember
                                : ExperienceColors.inkFaint,
                            width: 2,
                          ),
                          gradient: selected
                              ? ExperienceColors.emberGradient
                              : null,
                        ),
                        child: selected
                            ? const Icon(
                                Icons.check,
                                size: 13,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          plan.title,
                          style: ExperienceType.bodyStrong(
                            ExperienceColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          plan.priceLabel,
                          style: ExperienceType.data(
                            ExperienceColors.ink,
                            size: 15,
                          ),
                        ),
                        Text(
                          plan.available
                              ? plan.effectiveMonthlyLabel
                              : 'Not available right now',
                          style: ExperienceType.caption(
                            ExperienceColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Plan list skeleton — quiet rows while the store answers, never a bare
/// spinner over white. Rows grow with text scale instead of clipping.
class _PlansSkeleton extends StatelessWidget {
  const _PlansSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading plans',
      child: Column(
        children: <Widget>[
          for (var i = 0; i < 3; i++) ...<Widget>[
            Container(
              constraints: const BoxConstraints(minHeight: 76),
              decoration: BoxDecoration(
                color: ExperienceColors.surfaceWarm.withValues(alpha: 0.6),
                borderRadius: ExperienceRadius.cardRadius,
                border: Border.all(color: ExperienceColors.hairline),
              ),
            ),
            const SizedBox(height: ExperienceSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _PlusSecondaryButton extends StatelessWidget {
  const _PlusSecondaryButton({required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: ExperienceColors.ink,
        side: const BorderSide(color: ExperienceColors.hairline),
        shape: const RoundedRectangleBorder(
          borderRadius: ExperienceRadius.chipRadius,
        ),
        minimumSize: const Size.fromHeight(ExperienceSpacing.degreeTarget),
        textStyle: ExperienceType.label(ExperienceColors.ink),
      ),
      child: Text(label, textAlign: TextAlign.center),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
