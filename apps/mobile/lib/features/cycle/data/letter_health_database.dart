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

class ImpulseDraftRows extends Table {
  TextColumn get id => text()();
  TextColumn get content => text()();
  IntColumn get createdAtMillis => integer()();
  IntColumn get updatedAtMillis => integer()();
  IntColumn get sealedAtMillis => integer().nullable()();
  IntColumn get unlockAtMillis => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
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
  TextColumn get careRecordId => text().unique()();
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

@DriftDatabase(
  tables: [PeriodRows, ImpulseDraftRows, CareRecordRows, CareReflectionRows],
)
class LetterHealthDatabase extends _$LetterHealthDatabase {
  LetterHealthDatabase(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(impulseDraftRows);
      }
      if (from < 3) {
        await migrator.createTable(careRecordRows);
        await migrator.createTable(careReflectionRows);
      }
    },
  );
}
