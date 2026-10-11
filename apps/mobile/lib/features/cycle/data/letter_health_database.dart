import 'package:drift/drift.dart';
import '../../record_hub/data/record_hub_tables.dart';
import '../../record_hub/data/record_interventions_tables.dart';
import '../../record_hub/data/record_programme_tables.dart';

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
  TextColumn get originalProvenance => text().nullable()();
  IntColumn get writeZoneOffsetMinutes => integer().nullable()();
  TextColumn get writeZoneName => text().nullable()();
  IntColumn get updatedZoneOffsetMinutes => integer().nullable()();
  TextColumn get updatedZoneName => text().nullable()();
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
  IntColumn get updatedAtMillis => integer().withDefault(const Constant(0))();
  BoolColumn get keepInComfortKit =>
      boolean().withDefault(const Constant(false))();

  /// Unknown legacy experienced dates remain undated; never infer from UTC.
  IntColumn get experiencedDay => integer().nullable()();
  TextColumn get provenance => text().nullable()();
  TextColumn get originalProvenance => text().nullable()();
  IntColumn get writeZoneOffsetMinutes => integer().nullable()();
  TextColumn get writeZoneName => text().nullable()();

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
  IntColumn get experiencedDay => integer().nullable()();
  TextColumn get provenance => text().nullable()();
  IntColumn get writeZoneOffsetMinutes => integer().nullable()();
  TextColumn get writeZoneName => text().nullable()();
  IntColumn get updatedAtMillis => integer().nullable()();
  TextColumn get originalProvenance => text().nullable()();
  IntColumn get updatedZoneOffsetMinutes => integer().nullable()();
  TextColumn get updatedZoneName => text().nullable()();

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

class ComfortKitOverrideRows extends Table {
  TextColumn get sourceId => text()();
  TextColumn get action => text()();
  TextColumn get sourceVersion => text().nullable()();
  IntColumn get updatedAtMillis => integer()();

  @override
  Set<Column<Object>> get primaryKey => {sourceId};
}

class ComfortReminderPreferenceRows extends Table {
  TextColumn get id => text()();
  BoolColumn get enabled => boolean().withDefault(const Constant(false))();
  IntColumn get leadDays => integer().withDefault(const Constant(2))();
  IntColumn get hour => integer().withDefault(const Constant(9))();
  IntColumn get minute => integer().withDefault(const Constant(0))();
  IntColumn get updatedAtMillis => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
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
    ComfortKitOverrideRows,
    ComfortReminderPreferenceRows,
    RecordHubImpactRows,
    RecordHubBleedingRows,
    RecordHubSleepRows,
    RecordHubAppetiteRows,
    RecordHubActivityRows,
    RecordHubEventRows,
    RecordHubTemperatureRows,
    RecordHubPinRows,
    RecordProductEpisodeRows,
    RecordProductVersionRows,
    RecordProductUseRows,
    RecordTriedActionRows,
    RecordTriedActionItemRows,
    RecordActionCheckbackRows,
    RecordProgrammeRows,
    RecordProgrammeConfigRows,
    RecordProgrammePauseRows,
  ],
)
class LetterHealthDatabase extends _$LetterHealthDatabase {
  LetterHealthDatabase(super.executor);

  /// Kept for legacy import adapters. Imported ranges retain their source IDs;
  /// adjacent ranges require user review through ConfirmablePeriodRepository.
  Future<void> normalizeContinuousPeriods() async {}

  @override
  int get schemaVersion => 18;

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
      await _upgradeLegacySchema(
        migrator,
        rebuildHealthRecords: from < 11,
        associateLegacyCycleReflections: from < 11,
      );
      await _upgradeRecordHubSchema(migrator);
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _upgradeRecordHubSchema(Migrator migrator) async {
    for (final table in <TableInfo<Table, Object?>>[
      recordHubImpactRows,
      recordHubBleedingRows,
      recordHubSleepRows,
      recordHubAppetiteRows,
      recordHubActivityRows,
      recordHubEventRows,
      recordHubTemperatureRows,
      recordHubPinRows,
      recordProductEpisodeRows,
      recordProductVersionRows,
      recordProductUseRows,
      recordTriedActionRows,
      recordTriedActionItemRows,
      recordActionCheckbackRows,
      recordProgrammeRows,
      recordProgrammeConfigRows,
      recordProgrammePauseRows,
    ]) {
      if (!await _tableExists(table.actualTableName)) {
        await migrator.createTable(table);
      }
    }
    for (final column in [
      recordTriedActionRows.completionOccurredAtMillis,
      recordTriedActionRows.completionUtcOffsetMinutes,
    ]) {
      if (!await _columnExists('record_tried_action_rows', column.$name)) {
        await migrator.addColumn(recordTriedActionRows, column);
      }
    }
    for (final column in [
      healthRecordRows.originalProvenance,
      healthRecordRows.writeZoneOffsetMinutes,
      healthRecordRows.writeZoneName,
      healthRecordRows.updatedZoneOffsetMinutes,
      healthRecordRows.updatedZoneName,
    ]) {
      if (!await _columnExists('health_record_rows', column.$name)) {
        await migrator.addColumn(healthRecordRows, column);
      }
    }
    await customStatement(
      'UPDATE health_record_rows SET original_provenance = provenance WHERE original_provenance IS NULL',
    );
    for (final column in [
      momentCheckInRows.experiencedDay,
      momentCheckInRows.provenance,
      momentCheckInRows.writeZoneOffsetMinutes,
      momentCheckInRows.writeZoneName,
      momentCheckInRows.updatedAtMillis,
      momentCheckInRows.originalProvenance,
      momentCheckInRows.updatedZoneOffsetMinutes,
      momentCheckInRows.updatedZoneName,
    ]) {
      if (!await _columnExists('moment_check_in_rows', column.$name)) {
        await migrator.addColumn(momentCheckInRows, column);
      }
    }
    for (final column in [
      captureNoteRows.experiencedDay,
      captureNoteRows.updatedAtMillis,
      captureNoteRows.provenance,
      captureNoteRows.originalProvenance,
      captureNoteRows.writeZoneOffsetMinutes,
      captureNoteRows.writeZoneName,
    ]) {
      if (!await _columnExists('capture_note_rows', column.$name)) {
        await migrator.addColumn(captureNoteRows, column);
      }
    }
    await customStatement(
      'UPDATE capture_note_rows SET updated_at_millis = created_at_millis WHERE updated_at_millis IS NULL OR updated_at_millis = 0',
    );
  }

  Future<void> _upgradeLegacySchema(
    Migrator migrator, {
    required bool rebuildHealthRecords,
    required bool associateLegacyCycleReflections,
  }) async {
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
    } else if (rebuildHealthRecords) {
      await _rebuildHealthRecordsWithoutDataLoss(migrator);
    }
    if (!await _tableExists('capture_note_rows')) {
      await migrator.createTable(captureNoteRows);
    } else {
      if (!await _columnExists('capture_note_rows', 'updated_at_millis')) {
        await migrator.addColumn(
          captureNoteRows,
          captureNoteRows.updatedAtMillis,
        );
        await customStatement('''
          UPDATE capture_note_rows
          SET updated_at_millis = created_at_millis
          WHERE updated_at_millis = 0
        ''');
      }
      if (!await _columnExists('capture_note_rows', 'keep_in_comfort_kit')) {
        await migrator.addColumn(
          captureNoteRows,
          captureNoteRows.keepInComfortKit,
        );
      }
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
    if (!await _tableExists('comfort_kit_override_rows')) {
      await migrator.createTable(comfortKitOverrideRows);
    }
    if (!await _tableExists('comfort_reminder_preference_rows')) {
      await migrator.createTable(comfortReminderPreferenceRows);
    }

    // Migration cannot obtain merge consent. Keep saved ranges and attached
    // source identities intact until the user reviews a runtime period edit.
    if (associateLegacyCycleReflections) {
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
    }
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
