enum CareSafetyKind { emotional, physical }

enum CareMode {
  explode(label: 'I want to explode', safetyKind: CareSafetyKind.emotional),
  heavy(label: 'I feel heavy', safetyKind: CareSafetyKind.emotional),
  racing(label: "My mind won't stop", safetyKind: CareSafetyKind.emotional),
  space(label: 'I need everyone away', safetyKind: CareSafetyKind.emotional),
  physical(label: 'My body needs care', safetyKind: CareSafetyKind.physical);

  const CareMode({required this.label, required this.safetyKind});

  final String label;
  final CareSafetyKind safetyKind;
}
