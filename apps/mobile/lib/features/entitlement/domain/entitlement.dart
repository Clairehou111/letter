/// Paid-split domain model (spec: 2026-07-29-paid-split-and-paywall).
///
/// Pure data: no store SDK, no health data, no analytics. The acute
/// experience and local data access never depend on entitlement state.
library;

enum EntitlementStatus {
  /// Inside the paid `$0.99` first month.
  activeIntro,

  /// Paying subscriber (monthly, six-month, or yearly).
  activePaid,

  /// Had a subscription that expired or was cancelled.
  lapsed,

  /// Never subscribed, or store state unavailable offline. Treated like
  /// lapsed for capability checks but copy must not claim a past purchase.
  freeOrUnknown,
}

enum LetterCapability {
  // Free forever (REQ-001).
  acuteCareFlows,
  safetyRoutes,
  periodTracking,
  cyclePrediction,
  localBackupExport,
  localDataDelete,

  // Premium (REQ-002).
  futureSelfNotes,
  prepareSurface,
  personalPatterns,
  lettersArchiveDetail,
}

bool isPremiumCapability(LetterCapability capability) {
  return switch (capability) {
    LetterCapability.acuteCareFlows ||
    LetterCapability.safetyRoutes ||
    LetterCapability.periodTracking ||
    LetterCapability.cyclePrediction ||
    LetterCapability.localBackupExport ||
    LetterCapability.localDataDelete => false,
    LetterCapability.futureSelfNotes ||
    LetterCapability.prepareSurface ||
    LetterCapability.personalPatterns ||
    LetterCapability.lettersArchiveDetail => true,
  };
}

class EntitlementState {
  const EntitlementState({required this.status, this.planId});

  final EntitlementStatus status;

  /// Store product identifier when known (e.g. `letter_yearly`). Never
  /// contains health or personal data.
  final String? planId;

  bool get hasPremiumAccess =>
      status == EntitlementStatus.activeIntro ||
      status == EntitlementStatus.activePaid;

  /// Losing entitlement never removes local data access; premium memory
  /// pauses but is never deleted (REQ-003).
  bool canUse(LetterCapability capability) {
    if (!isPremiumCapability(capability)) return true;
    return hasPremiumAccess;
  }
}

/// Store-facing plan catalog. Prices are display copy only; the store remains
/// the source of truth at purchase time.
class LetterPlan {
  const LetterPlan({
    required this.id,
    required this.title,
    required this.priceLabel,
    required this.effectiveMonthlyLabel,
    this.highlight,
  });

  final String id;
  final String title;
  final String priceLabel;
  final String effectiveMonthlyLabel;
  final String? highlight;
}

const letterPlans = [
  LetterPlan(
    id: 'letter_monthly',
    title: 'Monthly',
    priceLabel: '\$8.99 / month',
    effectiveMonthlyLabel: '\$8.99 / mo',
  ),
  LetterPlan(
    id: 'letter_six_months',
    title: '6 months',
    priceLabel: '\$49.99 / 6 months',
    effectiveMonthlyLabel: '\$8.33 / mo',
  ),
  LetterPlan(
    id: 'letter_yearly',
    title: 'Yearly',
    priceLabel: '\$50.99 / year',
    effectiveMonthlyLabel: '\$4.25 / mo',
    highlight: 'Best for learning your pattern',
  ),
];

const introOfferLabel = '\$0.99 first month';
const introRenewalNote =
    'Then renews at the plan you choose. Cancel anytime. '
    'The first month is paid, not a free trial.';
const yearlyVsSixMonthsNote = 'Yearly costs only \$1 more than 6 months.';
