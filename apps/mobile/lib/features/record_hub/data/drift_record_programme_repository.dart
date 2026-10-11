import 'dart:math';

import 'package:drift/drift.dart';

import '../../cycle/data/letter_health_database.dart';
import '../../cycle/domain/local_date.dart';
import '../../health_records/domain/health_record.dart';
import '../../health_records/domain/observation_catalog.dart';
import '../domain/record_programme.dart';

/// Strict read-only decoder for repository reads and atomic backup staging.
RecordProgramme decodeRecordProgramme(
  RecordProgrammeRow row,
  List<RecordProgrammeConfigRow> configurations,
  List<RecordProgrammePauseRow> pauses,
) {
  requireProgramme(
    row.currentSlot == null
        ? row.endDay != null
        : row.currentSlot == 1 && row.endDay == null,
    RecordProgrammeFailure.storageUnavailable,
  );
  final configs = [...configurations]
    ..sort((left, right) => left.versionNumber.compareTo(right.versionNumber));
  final orderedPauses = [
    ...pauses,
  ]..sort((left, right) => left.sequenceNumber.compareTo(right.sequenceNumber));
  requireProgramme(
    configs.every(
          (config) =>
              config.programmeId == row.id &&
              config.vocabularyVersion <= healthRecordVocabularyVersion,
        ) &&
        orderedPauses.every((pause) => pause.programmeId == row.id),
    RecordProgrammeFailure.storageUnavailable,
  );
  for (var index = 0; index < orderedPauses.length; index++) {
    requireProgramme(
      orderedPauses[index].sequenceNumber == index + 1,
      RecordProgrammeFailure.storageUnavailable,
    );
  }
  SymptomType decode(String id) {
    final definition = ObservationCatalog.byId(id);
    requireProgramme(
      definition != null,
      RecordProgrammeFailure.invalidSelection,
    );
    return definition!.symptom;
  }

  return RecordProgramme(
    id: row.id,
    startDate: LocalDate.fromEpochDay(row.startDay),
    endDate: row.endDay == null ? null : LocalDate.fromEpochDay(row.endDay!),
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      row.createdAtMillis,
      isUtc: true,
    ),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(
      row.updatedAtMillis,
      isUtc: true,
    ),
    configurations: [
      for (final config in configs)
        RecordProgrammeConfig(
          id: config.id,
          version: config.versionNumber,
          effectiveDate: LocalDate.fromEpochDay(config.effectiveDay),
          symptoms: [for (final id in config.symptomIds.split(',')) decode(id)],
          vocabularyVersion: config.vocabularyVersion,
        ),
    ],
    pauses: [
      for (final pause in orderedPauses)
        RecordProgrammePause(
          id: pause.id,
          startDate: LocalDate.fromEpochDay(pause.startDay),
          resumedDate: pause.resumeDay == null
              ? null
              : LocalDate.fromEpochDay(pause.resumeDay!),
        ),
    ],
  );
}

final class DriftRecordProgrammeRepository
    implements RecordProgrammeRepository {
  DriftRecordProgrammeRepository(
    this._database, {
    DateTime Function()? clock,
    String Function()? idGenerator,
  }) : _clock = clock ?? DateTime.now,
       _idGenerator = idGenerator ?? _randomId;
  final LetterHealthDatabase _database;
  final DateTime Function() _clock;
  final String Function() _idGenerator;

  @override
  Future<List<RecordProgramme>> getAll() => _guard(
    () => _database.transaction(() async {
      final rows =
          await (_database.select(_database.recordProgrammeRows)..orderBy([
                (row) => OrderingTerm.desc(row.startDay),
                (row) => OrderingTerm.asc(row.id),
              ]))
              .get();
      return [for (final row in rows) await _read(row)];
    }),
  );

  @override
  Future<RecordProgramme?> getCurrent() => _guard(
    () => _database.transaction(() async {
      final row = await (_database.select(
        _database.recordProgrammeRows,
      )..where((row) => row.currentSlot.equals(1))).getSingleOrNull();
      return row == null ? null : _read(row);
    }),
  );

  Future<RecordProgramme> _read(RecordProgrammeRow row) async {
    requireProgramme(
      row.currentSlot == null
          ? row.endDay != null
          : row.currentSlot == 1 && row.endDay == null,
      RecordProgrammeFailure.storageUnavailable,
    );
    final configRows =
        await (_database.select(_database.recordProgrammeConfigRows)
              ..where((config) => config.programmeId.equals(row.id))
              ..orderBy([(config) => OrderingTerm.asc(config.versionNumber)]))
            .get();
    final pauseRows =
        await (_database.select(_database.recordProgrammePauseRows)
              ..where((pause) => pause.programmeId.equals(row.id))
              ..orderBy([(pause) => OrderingTerm.asc(pause.sequenceNumber)]))
            .get();
    return decodeRecordProgramme(row, configRows, pauseRows);
  }

  DateTime _eligibleClock(LocalDate date) {
    final now = _clock().toLocal();
    requireProgramme(
      !date.isAfter(LocalDate.fromDateTime(now)),
      RecordProgrammeFailure.futureDate,
    );
    return now;
  }

  Future<RecordProgramme> _currentById(String id) async {
    final row = await (_database.select(
      _database.recordProgrammeRows,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    requireProgramme(row != null, RecordProgrammeFailure.notFound);
    final programme = await _read(row!);
    requireProgramme(!programme.isEnded, RecordProgrammeFailure.ended);
    return programme;
  }

  Future<void> _touch(String id, DateTime now) =>
      (_database.update(
        _database.recordProgrammeRows,
      )..where((row) => row.id.equals(id))).write(
        RecordProgrammeRowsCompanion(
          updatedAtMillis: Value(now.toUtc().millisecondsSinceEpoch),
        ),
      );

  Future<RecordProgramme> _readId(String id) async => _read(
    await (_database.select(
      _database.recordProgrammeRows,
    )..where((row) => row.id.equals(id))).getSingle(),
  );

  @override
  Future<RecordProgramme> enroll({
    required LocalDate startDate,
    required List<SymptomType> symptoms,
  }) => _guard(
    () => _database.transaction(() async {
      final now = _eligibleClock(startDate);
      final config = RecordProgrammeConfig(
        id: _idGenerator(),
        version: 1,
        effectiveDate: startDate,
        symptoms: symptoms,
      );
      final existing = await (_database.select(
        _database.recordProgrammeRows,
      )..where((row) => row.currentSlot.equals(1))).getSingleOrNull();
      requireProgramme(existing == null, RecordProgrammeFailure.alreadyCurrent);
      final id = _idGenerator();
      await _database
          .into(_database.recordProgrammeRows)
          .insert(
            RecordProgrammeRowsCompanion.insert(
              id: id,
              startDay: startDate.epochDay,
              currentSlot: const Value(1),
              createdAtMillis: now.toUtc().millisecondsSinceEpoch,
              updatedAtMillis: now.toUtc().millisecondsSinceEpoch,
            ),
          );
      await _insertConfig(id, config);
      return _readId(id);
    }),
  );

  Future<void> _insertConfig(String id, RecordProgrammeConfig config) =>
      _database
          .into(_database.recordProgrammeConfigRows)
          .insert(
            RecordProgrammeConfigRowsCompanion.insert(
              id: config.id,
              programmeId: id,
              versionNumber: config.version,
              effectiveDay: config.effectiveDate.epochDay,
              symptomIds: config.symptomIds.join(','),
              vocabularyVersion: config.vocabularyVersion,
            ),
          );

  @override
  Future<RecordProgramme> updateConfig(
    String id, {
    required LocalDate effectiveDate,
    required List<SymptomType> symptoms,
  }) => _guard(
    () => _database.transaction(() async {
      final now = _eligibleClock(effectiveDate);
      requireProgramme(
        effectiveDate == LocalDate.fromDateTime(now),
        RecordProgrammeFailure.historicalConfigChange,
      );
      final programme = await _currentById(id);
      final latest = programme.configurations.last;
      requireProgramme(
        !effectiveDate.isBefore(latest.effectiveDate),
        RecordProgrammeFailure.dateOutsideProgramme,
      );
      final config = RecordProgrammeConfig(
        id: _idGenerator(),
        version: latest.version + 1,
        effectiveDate: effectiveDate,
        symptoms: symptoms,
      );
      if (_sameSymptoms(latest.symptoms, config.symptoms)) return programme;
      await _insertConfig(id, config);
      await _touch(id, now);
      return _readId(id);
    }),
  );

  bool _sameSymptoms(List<SymptomType> left, List<SymptomType> right) =>
      left.length == right.length &&
      List.generate(
        left.length,
        (index) => left[index] == right[index],
      ).every((same) => same);

  @override
  Future<RecordProgramme> pause(String id, {required LocalDate date}) => _guard(
    () => _database.transaction(() async {
      final now = _eligibleClock(date);
      final programme = await _currentById(id);
      requireProgramme(
        !programme.isPaused,
        RecordProgrammeFailure.alreadyPaused,
      );
      requireProgramme(
        !date.isBefore(programme.startDate) &&
            (programme.pauses.isEmpty ||
                !date.isBefore(programme.pauses.last.resumedDate!)),
        RecordProgrammeFailure.dateOutsideProgramme,
      );
      await _database
          .into(_database.recordProgrammePauseRows)
          .insert(
            RecordProgrammePauseRowsCompanion.insert(
              id: _idGenerator(),
              programmeId: id,
              sequenceNumber: programme.pauses.length + 1,
              startDay: date.epochDay,
            ),
          );
      await _touch(id, now);
      return _readId(id);
    }),
  );

  @override
  Future<RecordProgramme> resume(String id, {required LocalDate date}) =>
      _guard(
        () => _database.transaction(() async {
          final now = _eligibleClock(date);
          final programme = await _currentById(id);
          requireProgramme(
            programme.isPaused,
            RecordProgrammeFailure.notPaused,
          );
          final pause = programme.pauses.last;
          requireProgramme(
            !date.isBefore(pause.startDate),
            RecordProgrammeFailure.dateOutsideProgramme,
          );
          await (_database.update(
            _database.recordProgrammePauseRows,
          )..where((row) => row.id.equals(pause.id))).write(
            RecordProgrammePauseRowsCompanion(resumeDay: Value(date.epochDay)),
          );
          await _touch(id, now);
          return _readId(id);
        }),
      );

  @override
  Future<RecordProgramme> end(String id, {required LocalDate date}) => _guard(
    () => _database.transaction(() async {
      final now = _eligibleClock(date);
      final programme = await _currentById(id);
      requireProgramme(
        !date.isBefore(programme.configurations.last.effectiveDate) &&
            (programme.pauses.isEmpty ||
                !date.isBefore(
                  programme.pauses.last.resumedDate ??
                      programme.pauses.last.startDate,
                )),
        RecordProgrammeFailure.dateOutsideProgramme,
      );
      await (_database.update(
        _database.recordProgrammeRows,
      )..where((row) => row.id.equals(id))).write(
        RecordProgrammeRowsCompanion(
          endDay: Value(date.epochDay),
          currentSlot: const Value(null),
          updatedAtMillis: Value(now.toUtc().millisecondsSinceEpoch),
        ),
      );
      return _readId(id);
    }),
  );

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on RecordProgrammeException {
      rethrow;
    } catch (_) {
      throw const RecordProgrammeException(
        RecordProgrammeFailure.storageUnavailable,
      );
    }
  }

  static String _randomId() =>
      'programme-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32).toRadixString(16)}';
}
