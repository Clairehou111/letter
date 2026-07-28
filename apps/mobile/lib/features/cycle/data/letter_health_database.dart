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

@DriftDatabase(tables: [PeriodRows])
class LetterHealthDatabase extends _$LetterHealthDatabase {
  LetterHealthDatabase(super.executor);

  @override
  int get schemaVersion => 1;
}
