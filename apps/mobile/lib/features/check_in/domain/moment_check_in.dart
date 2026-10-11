import '../../cycle/domain/local_date.dart';
import '../../health_records/domain/health_record.dart';

enum MomentCheckInState {
  good('Good'),
  steady('Steady'),
  calm('Calm'),
  energized('Energized'),
  hopeful('Hopeful'),
  tender('Tender'),
  low('Low'),
  irritable('Irritable'),
  anxious('Anxious'),
  overwhelmed('Overwhelmed'),
  exhausted('Exhausted'),
  physical('Physical');

  const MomentCheckInState(this.label);

  final String label;

  /// One shared interpretation for prediction, Patterns, and reports.
  /// "Tender" is intentionally included: Today presents it as a moment that
  /// may need extra gentleness, so it must not become positive evidence on a
  /// different surface.
  bool get isHarderDaySignal => switch (this) {
    good || steady || calm || energized || hopeful => false,
    tender ||
    low ||
    irritable ||
    anxious ||
    overwhelmed ||
    exhausted ||
    physical => true,
  };

  bool get isPositiveSignal => switch (this) {
    good || calm || energized || hopeful => true,
    _ => false,
  };
}

final class MomentCheckIn {
  const MomentCheckIn({
    required this.id,
    required this.state,
    required this.occurredAt,
    required this.createdAt,
    this.experiencedDate,
    this.provenance = HealthRecordProvenance.timingUnknown,
    this.writeZoneOffsetMinutes,
    this.writeZoneName,
    DateTime? updatedAt,
    HealthRecordProvenance? originalProvenance,
    this.updatedZoneOffsetMinutes,
    this.updatedZoneName,
  }) : updatedAt = updatedAt ?? createdAt,
       originalProvenance = originalProvenance ?? provenance;

  final String id;
  final MomentCheckInState state;
  final DateTime occurredAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final HealthRecordProvenance originalProvenance;
  final LocalDate? experiencedDate;
  final HealthRecordProvenance provenance;
  final int? writeZoneOffsetMinutes;
  final String? writeZoneName;
  final int? updatedZoneOffsetMinutes;
  final String? updatedZoneName;
}
