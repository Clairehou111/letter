import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../features/entitlement/domain/entitlement.dart';
import '../../features/entitlement/domain/entitlement_repository.dart';
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
  });

  final EntitlementRepository entitlementRepository;

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
  }) async {
    final result = await showExperienceSheet<PlusCommitResult>(
      context,
      child: PlusExperience(
        entitlementRepository: entitlementRepository,
        outcomeContext: outcomeContext,
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
  String? _selectedPlanId;

  bool _purchaseInFlight = false;
  bool _restoreInFlight = false;
  bool _completing = false;

  /// One calm feedback line at a time — acknowledgments and honest failures.
  /// Errors are visual + textual only; errors never haptic.
  String? _feedbackLine;
  bool _feedbackIsError = false;

  Uri? _managementUrl;

  EntitlementRepository get _repository => widget.entitlementRepository;

  @override
  void initState() {
    super.initState();
    _entitlement = _repository.current;
    _entitlementSubscription = _repository.watch().listen((state) {
      if (!mounted) {
        return;
      }
      setState(() => _entitlement = state);
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
    setState(() {
      _plansLoading = true;
      _plansError = null;
    });
    try {
      final plans = await _repository.loadPlans();
      if (!mounted) {
        return;
      }
      setState(() {
        _plans = plans;
        _plansLoading = false;
        _selectedPlanId = _defaultSelection(plans);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _plans = null;
        _plansError = error;
        _plansLoading = false;
      });
    }
  }

  Future<void> _loadManagementUrl() async {
    try {
      final url = await _repository.managementUrl();
      if (!mounted) {
        return;
      }
      setState(() => _managementUrl = url);
    } catch (_) {
      // The management destination is optional; absence hides the row.
    }
  }

  String? _defaultSelection(List<LetterPlan> plans) {
    final available = plans.where((plan) => plan.available).toList();
    if (available.isEmpty) {
      return null;
    }
    final highlighted = available
        .where((plan) => plan.highlight != null)
        .toList();
    return (highlighted.isNotEmpty ? highlighted.first : available.first).id;
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
    if (planId == null || _purchaseInFlight) {
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
          await _completeActivated();
        case PurchaseOutcome.pending:
          _setFeedback(
            'The store is confirming your purchase. '
            'Nothing else is needed right now.',
            isError: false,
          );
        case PurchaseOutcome.cancelled:
          // Cancellation never becomes failure and never grants access.
          _setFeedback('No charge was made. Nothing changed.', isError: false);
        case PurchaseOutcome.failed:
          _setFeedback(
            result.message ??
                'The purchase could not be completed. '
                    'You have not been charged.',
            isError: true,
          );
        case PurchaseOutcome.unavailable:
          _setFeedback(
            result.message ??
                'This needs a connection. '
                    'Your records are already safe on this device.',
            isError: true,
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
              'No active subscription was found for this store account.',
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
      return;
    }
    await showExperienceSheet<void>(
      context,
      child: Builder(
        builder: (sheetContext) {
          return Padding(
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
                Text(
                  'Manage your subscription',
                  style: ExperienceType.headline(ExperienceColors.ink),
                ),
                const SizedBox(height: ExperienceSpacing.xs),
                Text(
                  'Cancellations and payment changes happen in the store. '
                  'Cancelled access continues until the period ends, and your '
                  'records stay readable either way.',
                  style: ExperienceType.bodySmall(ExperienceColors.inkSoft),
                ),
                const SizedBox(height: ExperienceSpacing.sm),
                SelectableText(
                  url.toString(),
                  style: ExperienceType.caption(ExperienceColors.inkSoft),
                ),
                const SizedBox(height: ExperienceSpacing.md),
                _PlusSecondaryButton(
                  label: 'Copy store link',
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: url.toString()),
                    );
                    if (!sheetContext.mounted) {
                      return;
                    }
                    Navigator.of(sheetContext).pop();
                    _setFeedback(
                      'Link copied — open it in your browser '
                      'to manage your subscription.',
                      isError: false,
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
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
          if (!hasPremium) ...<Widget>[
            const SizedBox(height: ExperienceSpacing.sm),
            Text(
              'Care, safety, tracking, prediction, and backup are free. '
              'Losing Plus never removes anything you recorded.',
              textAlign: TextAlign.center,
              style: ExperienceType.caption(ExperienceColors.inkSoft),
            ),
          ],
          const SizedBox(height: ExperienceSpacing.md),
          Text(
            yearlyVsLifetimeNote,
            style: ExperienceType.caption(ExperienceColors.inkSoft),
          ),
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
      EntitlementStatus.activeIntro => const _StatusCopy(
        title: 'Plus is active — introductory period',
        body: 'You are inside your introductory billing period.',
        tone: _StatusTone.positive,
      ),
      EntitlementStatus.activePaid => const _StatusCopy(
        title: 'Plus is active',
        body: 'Your full report history and export tools are available.',
        tone: _StatusTone.positive,
      ),
      EntitlementStatus.gracePeriod => const _StatusCopy(
        title: 'Plus continues for now',
        body:
            'The store is resolving a billing issue. Your access continues, '
            'and your records are untouched.',
        tone: _StatusTone.neutral,
      ),
      EntitlementStatus.pending => const _StatusCopy(
        title: 'A store request is in progress',
        body:
            'Nothing is settled yet. This page updates the moment the '
            'store confirms.',
        tone: _StatusTone.neutral,
      ),
      EntitlementStatus.lapsed => const _StatusCopy(
        title: 'Plus has ended',
        body:
            'Everything you recorded stays readable. Premium depth '
            'pauses — it is never deleted. You can restart any time below.',
        tone: _StatusTone.neutral,
      ),
      EntitlementStatus.offlineUnknown => const _StatusCopy(
        title: 'We could not check your subscription',
        body:
            'The store could not verify this build or connection. Premium '
            'depth pauses until verification succeeds; your records are '
            'fully available.',
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
        const SizedBox(height: ExperienceSpacing.md),
        _buildPurchaseButton(),
        const SizedBox(height: ExperienceSpacing.xs),
        Text(
          introRenewalNote,
          textAlign: TextAlign.center,
          style: ExperienceType.caption(ExperienceColors.inkSoft),
        ),
        const SizedBox(height: ExperienceSpacing.sm),
        _PlusSecondaryButton(
          label: _restoreInFlight
              ? 'Checking with the store…'
              : 'Restore a previous purchase',
          onPressed: _restoreInFlight ? null : _restorePurchases,
        ),
      ],
    );
  }

  Widget _buildPlansError() {
    final message = _plansError is EntitlementException
        ? (_plansError! as EntitlementException).message
        : '';
    final unsupportedBuild = message.contains('unavailable on this build');
    final setupIncomplete = message.contains('not configured for this build');
    final title = unsupportedBuild
        ? 'Plans are available in the mobile app'
        : setupIncomplete
        ? 'Plans are not ready in this build'
        : 'Plans could not be loaded';
    final body = unsupportedBuild
        ? 'Purchases are not offered by this desktop build. Use Letter '
              'Within on iPhone or Android to view plans; your records and '
              'free features remain available here.'
        : setupIncomplete
        ? 'The App Store products have not been connected to this build yet. '
              'Your records and every free feature keep working.'
        : 'The store could not return plans for this build. Your records '
              'are already safe on this device, and everything free keeps '
              'working.';
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
          Text(title, style: ExperienceType.bodyStrong(ExperienceColors.ink)),
          const SizedBox(height: ExperienceSpacing.xs),
          Text(body, style: ExperienceType.bodySmall(ExperienceColors.inkSoft)),
          if (!unsupportedBuild && !setupIncomplete) ...<Widget>[
            const SizedBox(height: ExperienceSpacing.sm),
            _PlusSecondaryButton(label: 'Try again', onPressed: _loadPlans),
          ],
        ],
      ),
    );
  }

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
    final enabled = selected != null && !_purchaseInFlight && !_plansLoading;
    final outcome = widget.outcomeContext?.headline ?? 'Start $introOfferLabel';
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
                    ? ExperienceColors.emberGradient
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
                                  style: ExperienceType.label(Colors.white),
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
                                        ? Colors.white
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
  // Active section — manage, restore, and an honest cancellation note.
  // Existing subscribers never see acquisition copy.
  // -------------------------------------------------------------------------

  Widget _buildActiveSection() {
    final plans = _plans ?? const <LetterPlan>[];
    final currentPlan = plans
        .where((plan) => plan.id == _entitlement.planId)
        .firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('Your plan', style: ExperienceType.headline(ExperienceColors.ink)),
        const SizedBox(height: ExperienceSpacing.xs),
        Text(
          currentPlan == null
              ? 'An active Plus plan is linked to this device.'
              : '${currentPlan.title} · ${currentPlan.priceLabel}',
          style: ExperienceType.body(ExperienceColors.ink),
        ),
        const SizedBox(height: ExperienceSpacing.xs),
        Text(
          'Manage or cancel any time in the store. Cancelled access '
          'continues until the period ends, and everything you '
          'recorded stays readable after that.',
          style: ExperienceType.bodySmall(ExperienceColors.inkSoft),
        ),
        if (_managementUrl != null) ...<Widget>[
          const SizedBox(height: ExperienceSpacing.sm),
          _PlusSecondaryButton(
            label: 'Manage subscription',
            onPressed: _openManagement,
          ),
        ],
        const SizedBox(height: ExperienceSpacing.sm),
        _PlusSecondaryButton(
          label: _restoreInFlight
              ? 'Checking with the store…'
              : 'Restore a previous purchase',
          onPressed: _restoreInFlight ? null : _restorePurchases,
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
                const SizedBox(height: 2),
                Text(
                  copy.body,
                  style: ExperienceType.bodySmall(ExperienceColors.inkSoft),
                ),
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
      button: true,
      selected: selected,
      enabled: tappable,
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: <Widget>[
                            Text(
                              plan.title,
                              style: ExperienceType.bodyStrong(
                                ExperienceColors.ink,
                              ),
                            ),
                            if (plan.highlight != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: ExperienceColors.emberSoft.withValues(
                                    alpha: 0.35,
                                  ),
                                  borderRadius: ExperienceRadius.chipRadius,
                                ),
                                child: Text(
                                  plan.highlight!,
                                  style: ExperienceType.caption(
                                    ExperienceColors.emberDeep,
                                  ),
                                ),
                              ),
                          ],
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
