import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/check_in/domain/moment_check_in.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/cycle/domain/period_record.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';
import 'package:letter_mobile/features/patterns/domain/pattern_source.dart';
import 'package:letter_mobile/features/patterns/domain/patterns_experience_data.dart';

void main() {
  final occurrence = DateTime.utc(2026, 5, 1, 23, 30);
  final source = MomentCheckIn(
    id: 'fictional-travel-moment',
    state: MomentCheckInState.good,
    occurredAt: occurrence,
    createdAt: occurrence.add(const Duration(minutes: 1)),
    experiencedDate: const LocalDate(2026, 5, 2),
    provenance: HealthRecordProvenance.sameDay,
    writeZoneOffsetMinutes: 540,
    writeZoneName: 'Asia/Tokyo',
  );
  test(
    'Patterns keeps the frozen source day independently of the viewing zone',
    () {
      final data = const PatternsExperienceDataBuilder().build(
        PatternSourceSnapshot(
          momentCheckIns: [source],
          periods: [
            for (final (id, date) in [
              ('fictional-may', const LocalDate(2026, 5, 1)),
              ('fictional-june', const LocalDate(2026, 6, 1)),
            ])
              PeriodRecord(
                id: id,
                startDate: date,
                endDate: date.addDays(4),
                createdAt: occurrence,
                updatedAt: occurrence,
              ),
          ],
        ),
        today: const LocalDate(2026, 6, 4),
      );
      expect(data.moods.single.date, const LocalDate(2026, 5, 2));
    },
  );
  test(
    'a frozen day ahead after travel remains archived without changing today Patterns',
    () {
      final snapshot = PatternSourceSnapshot(momentCheckIns: [source]);
      expect(
        snapshot.through(const LocalDate(2026, 5, 1)).momentCheckIns,
        isEmpty,
      );
      expect(snapshot.momentCheckIns.single.id, source.id);
      expect(
        snapshot.through(const LocalDate(2026, 5, 2)).momentCheckIns.single.id,
        source.id,
      );
    },
  );
}
