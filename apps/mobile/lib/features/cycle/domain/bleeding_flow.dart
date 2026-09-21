import 'local_date.dart';

enum BleedingFlow {
  spotting,
  light,
  medium,
  heavy;

  String get label => switch (this) {
    BleedingFlow.spotting => 'Spotting',
    BleedingFlow.light => 'Light',
    BleedingFlow.medium => 'Medium',
    BleedingFlow.heavy => 'Heavy',
  };
}

/// A visual observation, recorded without interpretation.
///
/// The labels intentionally describe color only. They are not health states
/// and never feed cycle prediction or symptom algorithms.
enum BleedingColor {
  pink('Pink'),
  brightRed('Bright red'),
  darkRed('Dark red'),
  brown('Brown');

  const BleedingColor(this.label);

  final String label;
}

final class BleedingDayRecord {
  const BleedingDayRecord({
    required this.periodId,
    required this.date,
    required this.flow,
    this.color,
    required this.createdAt,
    required this.updatedAt,
  });

  final String periodId;
  final LocalDate date;
  final BleedingFlow flow;
  final BleedingColor? color;
  final DateTime createdAt;
  final DateTime updatedAt;
}
