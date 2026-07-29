/// Deterministic, locale-aware safety content for Care boundary sheets.
///
/// Region selection is pure: a region/locale code maps to fixed content. No
/// network, no LLM, no randomness, no device permissions. US and CA matching
/// is explicit; every other or unknown region receives the honest fallback
/// and never an invented crisis number.
library;

enum CrisisRegion { unitedStates, canada, other }

/// One tappable, always-visible emergency contact line.
class SafetyContact {
  const SafetyContact({
    required this.label,
    required this.number,
    required this.detail,
  });

  /// Short action label, e.g. `Call or text 988`.
  final String label;

  /// Dialable digits, e.g. `988`.
  final String number;

  /// One supporting line, e.g. `988 Suicide & Crisis Lifeline (US)`.
  final String detail;
}

class CrisisSafetyContent {
  const CrisisSafetyContent({
    required this.region,
    required this.contacts,
    required this.fallbackLine,
  });

  final CrisisRegion region;

  /// Region-verified crisis contacts. Empty for the fallback region.
  final List<SafetyContact> contacts;

  /// Present only for the fallback region: directs to local emergency
  /// services without inventing numbers.
  final String? fallbackLine;
}

class MedicalBoundaryContent {
  const MedicalBoundaryContent({required this.urgent, required this.nonUrgent});

  /// Symptoms that need urgent medical care now.
  final List<String> urgent;

  /// Symptoms that need a booked medical assessment.
  final List<String> nonUrgent;
}

CrisisRegion crisisRegionForCode(String? regionCode) {
  switch (regionCode?.toUpperCase()) {
    case 'US':
      return CrisisRegion.unitedStates;
    case 'CA':
      return CrisisRegion.canada;
    default:
      return CrisisRegion.other;
  }
}

CrisisSafetyContent crisisSafetyContentForCode(String? regionCode) {
  switch (crisisRegionForCode(regionCode)) {
    case CrisisRegion.unitedStates:
      return const CrisisSafetyContent(
        region: CrisisRegion.unitedStates,
        contacts: [
          SafetyContact(
            label: 'Call or text 988',
            number: '988',
            detail: '988 Suicide & Crisis Lifeline — free, 24/7 (US)',
          ),
          SafetyContact(
            label: 'Call 911',
            number: '911',
            detail: 'If you are in immediate danger',
          ),
        ],
        fallbackLine: null,
      );
    case CrisisRegion.canada:
      return const CrisisSafetyContent(
        region: CrisisRegion.canada,
        contacts: [
          SafetyContact(
            label: 'Call or text 9-8-8',
            number: '988',
            detail: '9-8-8 Suicide Crisis Helpline — free, 24/7 (Canada)',
          ),
          SafetyContact(
            label: 'Call 911',
            number: '911',
            detail: 'If you are in immediate danger',
          ),
        ],
        fallbackLine: null,
      );
    case CrisisRegion.other:
      return const CrisisSafetyContent(
        region: CrisisRegion.other,
        contacts: [],
        fallbackLine:
            'Contact your local emergency services or go to the nearest '
            'emergency department now.',
      );
  }
}

const medicalBoundaryContent = MedicalBoundaryContent(
  urgent: [
    'Fainting, or feeling about to faint',
    'Chest pain or palpitations',
    'Pain that is sudden, severe, or unlike your usual pattern',
    'Heavy bleeding with weakness or dizziness',
  ],
  nonUrgent: [
    'A symptom that is new, unusual, or changing',
    'A symptom that limits work, school, or daily life',
    'Anything that worries you, even if it seems small',
  ],
);
