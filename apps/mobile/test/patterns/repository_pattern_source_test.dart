import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/care/data/in_memory_care_memory_repository.dart';
import 'package:letter_mobile/features/care/data/drift_care_memory_repository.dart';
import 'package:letter_mobile/features/check_in/data/in_memory_moment_check_in_repository.dart';
import 'package:letter_mobile/features/check_in/data/drift_moment_check_in_repository.dart';
import 'package:letter_mobile/features/check_in/domain/moment_check_in.dart';
import 'package:letter_mobile/features/cycle/data/drift_period_repository.dart';
import 'package:letter_mobile/features/cycle/data/in_memory_period_repository.dart';
import 'package:letter_mobile/features/cycle/data/letter_health_database.dart';
import 'package:letter_mobile/features/cycle/domain/bleeding_flow.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/cycle/domain/period_record.dart';
import 'package:letter_mobile/features/health_data/domain/local_health_read_transaction.dart';
import 'package:letter_mobile/features/health_records/data/drift_health_record_repository.dart';
import 'package:letter_mobile/features/health_records/data/in_memory_health_record_repository.dart';
import 'package:letter_mobile/features/patterns/data/repository_pattern_source.dart';

final class _DriftReadTransaction implements LocalHealthReadTransaction {
  const _DriftReadTransaction(this.database);

  final LetterHealthDatabase database;

  @override
  Future<T> run<T>(Future<T> Function() read) => database.transaction(read);
}

PeriodRecord _period(String id, LocalDate start) {
  final timestamp = DateTime.utc(start.year, start.month, start.day);
  return PeriodRecord(
    id: id,
    startDate: start,
    endDate: start.addDays(4),
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  test(
    'completes a production-shaped read inside one Drift transaction',
    () async {
      final database = LetterHealthDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final source = RepositoryPatternSource(
        healthRecords: DriftHealthRecordRepository(
          database,
          closeDatabase: false,
        ),
        careMemory: DriftCareMemoryRepository(database, closeDatabase: false),
        periods: DriftPeriodRepository(database, closeDatabase: false),
        momentCheckIns: DriftMomentCheckInRepository(
          database,
          closeDatabase: false,
        ),
        readTransaction: _DriftReadTransaction(database),
        now: () => DateTime(2026, 8, 16),
      );

      final snapshot = await source.read().timeout(const Duration(seconds: 2));

      expect(snapshot.periods, isEmpty);
      expect(snapshot.healthRecords, isEmpty);
      expect(snapshot.careRecords, isEmpty);
      expect(snapshot.momentCheckIns, isEmpty);
    },
  );

  test(
    'reads explicit bleeding flow and color with the other Pattern facts',
    () async {
      final periods = InMemoryPeriodRepository(
        seed: [
          _period('july', const LocalDate(2026, 7, 1)),
          _period('august', const LocalDate(2026, 7, 29)),
          _period('future', const LocalDate(2026, 10, 1)),
        ],
      );
      await periods.setFlow(
        'july',
        const LocalDate(2026, 7, 2),
        BleedingFlow.heavy,
        today: const LocalDate(2026, 8, 16),
      );
      await periods.setBleedingColor(
        'july',
        const LocalDate(2026, 7, 2),
        BleedingColor.darkRed,
      );
      final checkIns = InMemoryMomentCheckInRepository(
        seed: [
          MomentCheckIn(
            id: 'calm',
            state: MomentCheckInState.calm,
            occurredAt: DateTime.utc(2026, 7, 4, 12),
            createdAt: DateTime.utc(2026, 7, 4, 12),
          ),
          MomentCheckIn(
            id: 'future',
            state: MomentCheckInState.low,
            occurredAt: DateTime.utc(2026, 10, 4, 12),
            createdAt: DateTime.utc(2026, 10, 4, 12),
          ),
        ],
      );
      final source = RepositoryPatternSource(
        healthRecords: InMemoryHealthRecordRepository(),
        careMemory: InMemoryCareMemoryRepository(),
        periods: periods,
        momentCheckIns: checkIns,
        now: () => DateTime(2026, 8, 16, 12),
      );

      final snapshot = await source.read();

      expect(snapshot.periods, hasLength(2));
      expect(snapshot.flowDays, hasLength(1));
      expect(snapshot.flowDays.single.periodId, 'july');
      expect(snapshot.flowDays.single.flow, BleedingFlow.heavy);
      expect(snapshot.flowDays.single.color, BleedingColor.darkRed);
      expect(snapshot.momentCheckIns.single.state, MomentCheckInState.calm);
    },
  );
}
