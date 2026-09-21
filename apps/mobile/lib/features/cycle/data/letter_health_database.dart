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

  @override
  int get schemaVersion => 5;

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
      if (from < 2) {
        await migrator.addColumn(periodFlowRows, periodFlowRows.color);
      }
      if (from < 3) {
        // This is a pre-release schema reset. The removed 0-10 pain scale and
        // separate pain locations duplicated the five-level symptom record.
        await migrator.deleteTable('health_record_rows');
        await migrator.createTable(healthRecordRows);
      }
      if (from < 5) {
        // Pre-release cleanup: mood, flow, colour, and notes each have a
        // dedicated source of truth. Old aggregate rows are intentionally
        // discarded instead of being migrated into those newer records.
        await customStatement('DROP TABLE IF EXISTS daily_record_rows');
      }
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
