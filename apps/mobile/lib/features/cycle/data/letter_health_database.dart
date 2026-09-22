import 'package:drift/drift.dart';

part 'letter_health_database.g.dart';

class PeriodRows extends Table {
  TextColumn get id => text()();
  IntColumn get startDay => integer()();
  IntColumn get endDay => integer().nullable()();
  IntColumn get createdAtMillis => integer()();
  IntColumn get updatedAtMillis => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class PeriodFlowRows extends Table {
  TextColumn get periodId =>
      text().references(PeriodRows, #id, onDelete: KeyAction.cascade)();
  IntColumn get day => integer()();
  TextColumn get flow => text()();
  TextColumn get color => text().nullable()();
  IntColumn get createdAtMillis => integer()();
  IntColumn get updatedAtMillis => integer()();

  @override
  Set<Column<Object>> get primaryKey => {periodId, day};
}

class CareRecordRows extends Table {
  TextColumn get id => text()();
  TextColumn get mode => text()();
  TextColumn get actionId => text()();
  TextColumn get actionLabel => text()();
  TextColumn get outcome => text()();
  IntColumn get occurredAtMillis => integer()();
  IntColumn get createdAtMillis => integer()();
  IntColumn get updatedAtMillis => integer()();
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class CareReflectionRows extends Table {
  TextColumn get id => text()();
  TextColumn get careRecordId => text().unique().references(
    CareRecordRows,
    #id,
    onDelete: KeyAction.cascade,
  )();
  TextColumn get mode => text()();
  TextColumn get observation => text().nullable()();
  TextColumn get need => text().nullable()();
  TextColumn get whatHelped => text().nullable()();
  TextColumn get futureSelfNote => text().nullable()();
  IntColumn get createdAtMillis => integer()();
  IntColumn get updatedAtMillis => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class CycleReflectionRows extends Table {
  TextColumn get id => text()();
  TextColumn get startingPeriodId => text().nullable().references(
    PeriodRows,
    #id,
    onDelete: KeyAction.setNull,
  )();
  IntColumn get cycleStartDay => integer().unique()();
  TextColumn get observation => text().nullable()();
  TextColumn get need => text().nullable()();
  TextColumn get whatHelped => text().nullable()();
  TextColumn get futureSelfNote => text().nullable()();
  IntColumn get createdAtMillis => integer()();
  IntColumn get updatedAtMillis => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class HealthRecordRows extends Table {
  TextColumn get id => text()();
  TextColumn get symptom => text()();
  IntColumn get severity => integer()();
  TextColumn get functionalImpactsJson => text()();
  IntColumn get experiencedDay => integer()();
  IntColumn get recordedAtMillis => integer()();
  IntColumn get updatedAtMillis => integer()();
  TextColumn get provenance => text()();
  BoolColumn get userConfirmed => boolean()();
  IntColumn get vocabularyVersion => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {symptom, experiencedDay},
  ];
}

/// Private, user-authored note text only. There is deliberately no audio,
/// analysis, clinical, or analytics field on this table.
class CaptureNoteRows extends Table {
  TextColumn get id => text()();
  TextColumn get content => text()();
  TextColumn get source => text()();
  IntColumn get createdAtMillis => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Timestamped, non-clinical current-state check-ins. They can contribute to
/// personal Patterns as an explicitly saved feeling, but never acquire a
/// symptom severity or become a clinical symptom record.
class MomentCheckInRows extends Table {
  TextColumn get id => text()();
  TextColumn get state => text()();
  IntColumn get occurredAtMillis => integer()();
  IntColumn get createdAtMillis => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// One explicit, user-confirmed preparation memory. Timing is deliberately
/// absent: Gravity Horizon remains the sole owner of cycle estimates.
class PreparationPlanRows extends Table {
  TextColumn get id => text()();
  TextColumn get status => text()();
  TextColumn get evidenceFingerprint => text()();
  TextColumn get sourceRecordIdsJson => text()();
  BoolColumn get includeCare => boolean()();
  TextColumn get careActionId => text()();
  TextColumn get careActionLabel => text()();
  TextColumn get careMode => text()();
  IntColumn get betterCount => integer()();
  IntColumn get sameCount => integer()();
  IntColumn get worseCount => integer()();
  TextColumn get noteText => text().nullable()();
  TextColumn get personalText => text().nullable()();
  IntColumn get createdAtMillis => integer()();
  IntColumn get updatedAtMillis => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Dismissal is scoped to an exact evidence fingerprint. New or corrected
/// evidence therefore produces a new proposal without erasing this history.
class PreparationDismissalRows extends Table {
  TextColumn get fingerprint => text()();
  TextColumn get evidenceLine => text()();
  IntColumn get dismissedAtMillis => integer()();

  @override
  Set<Column<Object>> get primaryKey => {fingerprint};
}

@DriftDatabase(
  tables: [
    PeriodRows,
    PeriodFlowRows,
    CareRecordRows,
    CareReflectionRows,
    CycleReflectionRows,
    HealthRecordRows,
    CaptureNoteRows,
    MomentCheckInRows,
    PreparationPlanRows,
    PreparationDismissalRows,
  ],
)
class LetterHealthDatabase extends _$LetterHealthDatabase {
  LetterHealthDatabase(super.executor);

  /// Repairs legacy or imported period rows so every continuous run has one
  /// stable database record. Repository writes enforce the same invariant.
  Future<void> normalizeContinuousPeriods() => _mergeContinuousPeriodRows();

  @override
  int get schemaVersion => 11;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await customStatement('''
        CREATE UNIQUE INDEX cycle_reflection_starting_period_id
        ON cycle_reflection_rows (starting_period_id)
      ''');
    },
    onUpgrade: (migrator, from, to) async {
      await _upgradeLegacySchema(migrator);
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _upgradeLegacySchema(Migrator migrator) async {
    if (!await _tableExists('period_rows')) {
      await migrator.createTable(periodRows);
    }
    if (!await _tableExists('period_flow_rows')) {
      await migrator.createTable(periodFlowRows);
    } else if (!await _columnExists('period_flow_rows', 'color')) {
      await migrator.addColumn(periodFlowRows, periodFlowRows.color);
    }
    if (!await _tableExists('care_record_rows')) {
      await migrator.createTable(careRecordRows);
    }
    if (!await _tableExists('care_reflection_rows')) {
      await migrator.createTable(careReflectionRows);
    }
    if (!await _tableExists('cycle_reflection_rows')) {
      await migrator.createTable(cycleReflectionRows);
    } else if (!await _columnExists(
      'cycle_reflection_rows',
      'starting_period_id',
    )) {
      await migrator.addColumn(
        cycleReflectionRows,
        cycleReflectionRows.startingPeriodId,
      );
    }
    if (!await _tableExists('health_record_rows')) {
      await migrator.createTable(healthRecordRows);
    } else {
      await _rebuildHealthRecordsWithoutDataLoss(migrator);
    }
    if (!await _tableExists('capture_note_rows')) {
      await migrator.createTable(captureNoteRows);
    }
    if (!await _tableExists('moment_check_in_rows')) {
      await migrator.createTable(momentCheckInRows);
    }
    if (!await _tableExists('preparation_plan_rows')) {
      await migrator.createTable(preparationPlanRows);
    }
    if (!await _tableExists('preparation_dismissal_rows')) {
      await migrator.createTable(preparationDismissalRows);
    }

    await _mergeContinuousPeriodRows();
    await customStatement('''
      UPDATE cycle_reflection_rows
      SET starting_period_id = (
        SELECT period_rows.id
        FROM period_rows
        WHERE period_rows.start_day = cycle_reflection_rows.cycle_start_day
        ORDER BY period_rows.updated_at_millis DESC, period_rows.id ASC
        LIMIT 1
      )
      WHERE starting_period_id IS NULL
    ''');
    await customStatement('''
      CREATE UNIQUE INDEX IF NOT EXISTS cycle_reflection_starting_period_id
      ON cycle_reflection_rows (starting_period_id)
    ''');
  }

  Future<void> _rebuildHealthRecordsWithoutDataLoss(Migrator migrator) async {
    const legacyTable = 'health_record_rows_before_v11';
    await customStatement('DROP TABLE IF EXISTS $legacyTable');
    await customStatement(
      'ALTER TABLE health_record_rows RENAME TO $legacyTable',
    );
    await migrator.createTable(healthRecordRows);
    await customStatement('''
      INSERT INTO health_record_rows (
        id,
        symptom,
        severity,
        functional_impacts_json,
        experienced_day,
        recorded_at_millis,
        updated_at_millis,
        provenance,
        user_confirmed,
        vocabulary_version
      )
      SELECT
        candidate.id,
        candidate.symptom,
        candidate.severity,
        candidate.functional_impacts_json,
        candidate.experienced_day,
        candidate.recorded_at_millis,
        candidate.updated_at_millis,
        candidate.provenance,
        candidate.user_confirmed,
        candidate.vocabulary_version
      FROM $legacyTable AS candidate
      WHERE candidate.rowid = (
        SELECT newest.rowid
        FROM $legacyTable AS newest
        WHERE newest.symptom = candidate.symptom
          AND newest.experienced_day = candidate.experienced_day
        ORDER BY
          newest.updated_at_millis DESC,
          newest.recorded_at_millis DESC,
          newest.id DESC
        LIMIT 1
      )
    ''');
    await customStatement('DROP TABLE $legacyTable');
  }

  Future<void> _mergeContinuousPeriodRows() async {
    final rows =
        await (select(periodRows)..orderBy([
              (row) => OrderingTerm.asc(row.startDay),
              (row) => OrderingTerm.desc(row.updatedAtMillis),
              (row) => OrderingTerm.asc(row.id),
            ]))
            .get();
    if (rows.length < 2) return;

    final groups = <List<PeriodRow>>[];
    var current = <PeriodRow>[rows.first];
    var coveredThrough = rows.first.endDay ?? rows.first.startDay;
    for (final row in rows.skip(1)) {
      if (row.startDay <= coveredThrough + 1) {
        current.add(row);
        final rowEnd = row.endDay ?? row.startDay;
        if (rowEnd > coveredThrough) coveredThrough = rowEnd;
      } else {
        groups.add(current);
        current = <PeriodRow>[row];
        coveredThrough = row.endDay ?? row.startDay;
      }
    }
    groups.add(current);

    for (final group in groups.where((group) => group.length > 1)) {
      final survivor = group.first;
      final sourceIds = group.map((row) => row.id).toSet();
      final mergedEnd = group.any((row) => row.endDay == null)
          ? null
          : group
                .map((row) => row.endDay!)
                .reduce((left, right) => left > right ? left : right);
      final latestUpdate = group
          .map((row) => row.updatedAtMillis)
          .reduce((left, right) => left > right ? left : right);
      final flows = await (select(
        periodFlowRows,
      )..where((row) => row.periodId.isIn(sourceIds))).get();
      flows.sort((left, right) {
        final byUpdated = left.updatedAtMillis.compareTo(right.updatedAtMillis);
        return byUpdated != 0
            ? byUpdated
            : left.periodId.compareTo(right.periodId);
      });
      for (final flow in flows.where((row) => row.periodId != survivor.id)) {
        await into(periodFlowRows).insert(
          PeriodFlowRowsCompanion.insert(
            periodId: survivor.id,
            day: flow.day,
            flow: flow.flow,
            color: Value(flow.color),
            createdAtMillis: flow.createdAtMillis,
            updatedAtMillis: flow.updatedAtMillis,
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
      await (update(
        periodRows,
      )..where((row) => row.id.equals(survivor.id))).write(
        PeriodRowsCompanion(
          endDay: Value(mergedEnd),
          updatedAtMillis: Value(latestUpdate),
        ),
      );
      for (final absorbed in group.skip(1)) {
        await (delete(
          periodFlowRows,
        )..where((row) => row.periodId.equals(absorbed.id))).go();
        await (update(
          cycleReflectionRows,
        )..where((row) => row.startingPeriodId.equals(absorbed.id))).write(
          const CycleReflectionRowsCompanion(startingPeriodId: Value(null)),
        );
        await (delete(
          periodRows,
        )..where((row) => row.id.equals(absorbed.id))).go();
      }
    }
  }

  Future<bool> _tableExists(String name) async {
    final result = await customSelect(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1",
      variables: [Variable<String>(name)],
    ).getSingleOrNull();
    return result != null;
  }

  Future<bool> _columnExists(String table, String column) async {
    final rows = await customSelect('PRAGMA table_info($table)').get();
    return rows.any((row) => row.read<String>('name') == column);
  }
}
