import 'package:drift/drift.dart';
import 'record_hub_tables.dart';

@DataClassName('RecordProductEpisodeRow')
class RecordProductEpisodeRows extends Table with RecordHubMetadataColumns {
  TextColumn get family => text()();
  IntColumn get startDay => integer()();
  IntColumn get endDay => integer().nullable()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
}

@DataClassName('RecordProductVersionRow')
class RecordProductVersionRows extends Table with RecordHubMetadataColumns {
  TextColumn get episodeId => text()();
  IntColumn get effectiveDay => integer()();
  IntColumn get versionNumber => integer()();
  TextColumn get exactName => text().nullable()();
  TextColumn get medicationType => text().nullable()();
  TextColumn get supplementType => text().nullable()();
  TextColumn get birthControlMethod => text().nullable()();
  TextColumn get dose => text().nullable()();
  TextColumn get unit => text().nullable()();
  TextColumn get customUnit => text().nullable()();
  TextColumn get route => text().nullable()();
  TextColumn get customRoute => text().nullable()();
  TextColumn get target => text().nullable()();
  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {episodeId, versionNumber},
  ];
}

@DataClassName('RecordProductUseRow')
class RecordProductUseRows extends Table with RecordHubMetadataColumns {
  TextColumn get episodeId => text()();
  TextColumn get versionId => text()();
  TextColumn get status => text()();
  TextColumn get dailyKey => text().nullable()();
  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {dailyKey},
  ];
}

@DataClassName('RecordTriedActionRow')
class RecordTriedActionRows extends Table
    with RecordHubMetadataColumns, RecordHubDurationColumns {
  BoolColumn get bundle => boolean()();
  TextColumn get status => text()();
  TextColumn get target => text().nullable()();
  TextColumn get source => text()();
  TextColumn get completionToken => text().nullable()();
  TextColumn get careSourceId => text().nullable()();
  IntColumn get completionOccurredAtMillis => integer().nullable()();
  IntColumn get completionUtcOffsetMinutes => integer().nullable()();
  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {completionToken},
  ];
}

@DataClassName('RecordTriedActionItemRow')
class RecordTriedActionItemRows extends Table {
  TextColumn get actionId => text()();
  IntColumn get position => integer()();
  TextColumn get kind => text()();
  TextColumn get customName => text().nullable()();
  @override
  Set<Column<Object>> get primaryKey => {actionId, position};
}

@DataClassName('RecordActionCheckbackRow')
class RecordActionCheckbackRows extends Table with RecordHubMetadataColumns {
  TextColumn get actionId => text()();
  TextColumn get outcome => text()();
  IntColumn get targetDegree => integer().nullable()();
  TextColumn get unexpected => text().nullable()();
  TextColumn get reflection => text().nullable()();
  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {actionId},
  ];
}
