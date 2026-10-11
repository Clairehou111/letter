import 'package:drift/drift.dart';

mixin RecordHubMetadataColumns on Table {
  TextColumn get id => text()();
  IntColumn get experiencedDay => integer()();
  IntColumn get recordedAtMillis => integer()();
  IntColumn get updatedAtMillis => integer()();
  TextColumn get originalProvenance => text()();
  TextColumn get provenance => text()();
  TextColumn get originalWriteZoneId => text().nullable()();
  TextColumn get writeZoneId => text().nullable()();
  IntColumn get originalUtcOffsetMinutes => integer().nullable()();
  IntColumn get utcOffsetMinutes => integer().nullable()();
  IntColumn get vocabularyVersion => integer().withDefault(const Constant(1))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

mixin RecordHubDurationColumns on Table {
  TextColumn get durationBucket => text().nullable()();
  TextColumn get durationLabel => text().nullable()();
  IntColumn get durationCatalogVersion => integer().nullable()();
  IntColumn get exactMinutes => integer().nullable()();
}

@DataClassName('RecordHubImpactRow')
class RecordHubImpactRows extends Table with RecordHubMetadataColumns {
  IntColumn get overall => integer()();
  BoolColumn get workOrSchool => boolean().withDefault(const Constant(false))();
  BoolColumn get homeResponsibilities =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get relationships =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get socialActivity =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get sleep => boolean().withDefault(const Constant(false))();
  BoolColumn get hobbiesOrInterests =>
      boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {experiencedDay},
  ];
}

@DataClassName('RecordHubBleedingRow')
class RecordHubBleedingRows extends Table with RecordHubMetadataColumns {
  TextColumn get flow => text().nullable()();
  TextColumn get periodId => text().nullable()();
  TextColumn get color => text().nullable()();
  TextColumn get clots => text().nullable()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {experiencedDay},
  ];
}

@DataClassName('RecordHubSleepRow')
class RecordHubSleepRows extends Table
    with RecordHubMetadataColumns, RecordHubDurationColumns {
  IntColumn get quality => integer().nullable()();
  BoolColumn get troubleFallingAsleep =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get wakingDuringNight =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get muchMoreThanUsual =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get muchLessThanUsual =>
      boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {experiencedDay},
  ];
}

@DataClassName('RecordHubAppetiteRow')
class RecordHubAppetiteRows extends Table with RecordHubMetadataColumns {
  TextColumn get appetite => text().nullable()();
  IntColumn get cravingScore => integer().nullable()();
  TextColumn get cravingType => text().nullable()();
  TextColumn get customCraving => text().nullable()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {experiencedDay},
  ];
}

@DataClassName('RecordHubActivityRow')
class RecordHubActivityRows extends Table
    with RecordHubMetadataColumns, RecordHubDurationColumns {
  TextColumn get type => text()();
  TextColumn get intensity => text().nullable()();
  TextColumn get customName => text().nullable()();
}

@DataClassName('RecordHubEventRow')
class RecordHubEventRows extends Table with RecordHubMetadataColumns {
  TextColumn get type => text()();
  TextColumn get intensity => text().nullable()();
  TextColumn get customName => text().nullable()();
  TextColumn get note => text().nullable()();
}

@DataClassName('RecordHubTemperatureRow')
class RecordHubTemperatureRows extends Table with RecordHubMetadataColumns {
  RealColumn get enteredValue => real()();
  TextColumn get unit => text()();
  TextColumn get method => text()();
  IntColumn get measuredHour => integer().nullable()();
  IntColumn get measuredMinute => integer().nullable()();
  BoolColumn get feverOrIllness =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get poorSleep => boolean().withDefault(const Constant(false))();
  BoolColumn get alcohol => boolean().withDefault(const Constant(false))();
  BoolColumn get travelOrTimeZoneChange =>
      boolean().withDefault(const Constant(false))();
}

@DataClassName('RecordHubPinRow')
class RecordHubPinRows extends Table {
  TextColumn get symptom => text()();
  IntColumn get position => integer()();

  @override
  Set<Column<Object>> get primaryKey => {symptom};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {position},
  ];
}
