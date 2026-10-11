import 'package:drift/drift.dart';

@DataClassName('RecordProgrammeRow')
class RecordProgrammeRows extends Table {
  TextColumn get id => text()();
  IntColumn get startDay => integer()();
  IntColumn get endDay => integer().nullable()();

  /// One current programme, including a paused one. Historical rows use null.
  IntColumn get currentSlot => integer().nullable()();
  IntColumn get createdAtMillis => integer()();
  IntColumn get updatedAtMillis => integer()();
  @override
  Set<Column<Object>> get primaryKey => {id};
  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {currentSlot},
  ];
}

@DataClassName('RecordProgrammeConfigRow')
class RecordProgrammeConfigRows extends Table {
  TextColumn get id => text()();
  TextColumn get programmeId => text().references(RecordProgrammeRows, #id)();
  IntColumn get versionNumber => integer()();
  IntColumn get effectiveDay => integer()();

  /// Ordered canonical vocabulary IDs only, never ratings or display labels.
  TextColumn get symptomIds => text()();
  IntColumn get vocabularyVersion => integer()();
  @override
  Set<Column<Object>> get primaryKey => {id};
  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {programmeId, versionNumber},
  ];
}

@DataClassName('RecordProgrammePauseRow')
class RecordProgrammePauseRows extends Table {
  TextColumn get id => text()();
  TextColumn get programmeId => text().references(RecordProgrammeRows, #id)();
  IntColumn get sequenceNumber => integer()();
  IntColumn get startDay => integer()();

  /// Exclusive. Null remains an open pause bounded by programme end, if any.
  IntColumn get resumeDay => integer().nullable()();
  @override
  Set<Column<Object>> get primaryKey => {id};
  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {programmeId, sequenceNumber},
  ];
}
