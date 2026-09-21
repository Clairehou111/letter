/// Paid-split domain model (spec: 2026-07-29-paid-split-and-paywall).
///
/// Pure data: no store SDK, no health data, no analytics. The acute
/// experience and local data access never depend on entitlement state.
library;

enum EntitlementStatus {
  /// Inside a store-confirmed introductory billing period.
  activeIntro,

  /// Paying subscriber or lifetime purchaser.
  activePaid,

  /// Store-confirmed access continues while a billing issue is being resolved.
  gracePeriod,

  /// A store request is in progress or a purchase is awaiting confirmation.
  pending,

  /// Had a subscription that expired or was cancelled.
  lapsed,

  /// The last store check could not be verified while offline.
  offlineUnknown,

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
  futureSelfNoteResurfacing,
  prepareSurface,
  personalPatterns,
  longitudinalComparisons,
  clinicianReports,
}

bool isPremiumCapability(LetterCapability capability) {
  return switch (capability) {
    LetterCapability.acuteCareFlows ||
    LetterCapability.safetyRoutes ||
    LetterCapability.periodTracking ||
    LetterCapability.cyclePrediction ||
    LetterCapability.localBackupExport ||
    LetterCapability.localDataDelete => false,
    LetterCapability.futureSelfNoteResurfacing ||
    LetterCapability.prepareSurface ||
    LetterCapability.personalPatterns ||
    LetterCapability.longitudinalComparisons ||
    LetterCapability.clinicianReports => true,
  };
}

class EntitlementState {
  const EntitlementState({required this.status, this.planId, this.message});

  final EntitlementStatus status;

  /// Store product identifier when known (e.g. `letter_yearly`). Never
  /// contains health or personal data.
  final String? planId;

  /// Safe, non-health explanation for an unavailable or failed store state.
  final String? message;

  bool get hasPremiumAccess =>
      status == EntitlementStatus.activeIntro ||
      status == EntitlementStatus.activePaid ||
      status == EntitlementStatus.gracePeriod;

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
    required this.referencePriceLabel,
    this.available = true,
    this.highlight,
  });

  final String id;
  final String title;
  final String priceLabel;
  final String effectiveMonthlyLabel;
  final String referencePriceLabel;
  final bool available;
  final String? highlight;
}

const letterPlans = [
  LetterPlan(
    id: 'letter_yearly',
    title: 'Yearly',
    priceLabel: '\$29.99 / year',
    effectiveMonthlyLabel: '\$2.50 / mo',
    referencePriceLabel: '\$29.99 / year',
    highlight: 'Best for learning your pattern',
  ),
  LetterPlan(
    id: 'letter_monthly',
    title: 'Monthly',
    priceLabel: '\$6.99 / month',
    effectiveMonthlyLabel: '\$6.99 / mo',
    referencePriceLabel: '\$6.99 / month',
  ),
  LetterPlan(
    id: 'letter_lifetime',
    title: 'Lifetime',
    priceLabel: '\$79.99 once',
    effectiveMonthlyLabel: 'One payment',
    referencePriceLabel: '\$79.99 once',
    highlight: 'One payment, keeps working offline',
  ),
];

const introOfferLabel = 'Letter Within Plus';
const introRenewalNote =
    'Store pricing and renewal terms are shown before purchase.';
const yearlyVsLifetimeNote =
    'Prices are localized by the App Store or Google Play.';
