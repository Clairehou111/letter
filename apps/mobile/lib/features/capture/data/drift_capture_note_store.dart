import 'package:drift/drift.dart';

import '../../cycle/data/letter_health_database.dart';
import '../../cycle/domain/local_date.dart';
import '../../health_records/domain/health_record.dart';
import '../domain/capture_models.dart';

/// Stores only explicit text notes and their source. This store has no raw
/// audio input and is intentionally not used by reports or analytics.
final class DriftCaptureNoteStore implements ConditionalCaptureNoteStore {
  DriftCaptureNoteStore(
    this._database, {
    this.closeDatabase = true,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;
  final DateTime Function() _clock;

  final LetterHealthDatabase _database;
  final bool closeDatabase;

  @override
  Future<CaptureNote> save(CaptureNote note) async {
    final saved = prepareCaptureNoteWrite(note, localNow: _clock().toLocal());
    return _insert(saved);
  }

  Future<CaptureNote> _insert(CaptureNote note) async {
    try {
      await _database.into(_database.captureNoteRows).insert(_toRow(note));
      return note;
    } on Object {
      throw const CaptureNoteStorageException();
    }
  }

  @override
  Future<CaptureNote> restore(
    CaptureNote note, {
    CaptureNote? expectedCurrent,
  }) async {
    try {
      return await _database.transaction(() async {
        final row = await (_database.select(
          _database.captureNoteRows,
        )..where((r) => r.id.equals(note.id))).getSingleOrNull();
        if (expectedCurrent == null
            ? row != null
            : row == null ||
                  !sameCaptureNoteVersion(_fromRow(row), expectedCurrent)) {
          throw const CaptureNoteStorageException();
        }
        if (row != null) {
          await (_database.delete(
            _database.captureNoteRows,
          )..where((r) => r.id.equals(note.id))).go();
        }
        return _insert(note);
      });
    } on Object {
      throw const CaptureNoteStorageException();
    }
  }

  @override
  Future<CaptureNote> update(CaptureNote note) => _update(note);

  @override
  Future<CaptureNote> updateIfUnchanged(
    CaptureNote note, {
    required CaptureNote expectedCurrent,
  }) => _update(note, expectedCurrent: expectedCurrent);

  Future<CaptureNote> _update(
    CaptureNote note, {
    CaptureNote? expectedCurrent,
  }) async {
    try {
      return await _database.transaction(() async {
        final row = await (_database.select(
          _database.captureNoteRows,
        )..where((r) => r.id.equals(note.id))).getSingleOrNull();
        if (row == null) throw const CaptureNoteStorageException();
        final previous = _fromRow(row);
        if (expectedCurrent != null &&
            !sameCaptureNoteVersion(previous, expectedCurrent)) {
          throw const CaptureNoteStorageException();
        }
        final saved = prepareCaptureNoteWrite(
          note,
          localNow: _clock().toLocal(),
          previous: previous,
        );
        if (!identical(saved, previous)) {
          await (_database.update(
            _database.captureNoteRows,
          )..where((r) => r.id.equals(note.id))).write(_toRow(saved));
        }
        return saved;
      });
    } on Object {
      throw const CaptureNoteStorageException();
    }
  }

  static CaptureNoteRowsCompanion _toRow(CaptureNote note) =>
      CaptureNoteRowsCompanion.insert(
        id: note.id,
        content: note.text,
        source: note.source.name,
        keepInComfortKit: Value(note.keepInComfortKit),
        createdAtMillis: note.createdAt.toUtc().millisecondsSinceEpoch,
        experiencedDay: Value(note.experiencedDate?.epochDay),
        updatedAtMillis: Value(note.updatedAt.toUtc().millisecondsSinceEpoch),
        provenance: Value(note.provenance.storageKey),
        originalProvenance: Value(note.effectiveOriginalProvenance.storageKey),
        writeZoneOffsetMinutes: Value(note.writeZoneOffsetMinutes),
        writeZoneName: Value(note.writeZoneName),
      );

  @override
  Future<List<CaptureNote>> getAll() async {
    try {
      final query = _database.select(_database.captureNoteRows)
        ..orderBy([(row) => OrderingTerm.desc(row.createdAtMillis)]);
      return (await query.get()).map(_fromRow).toList(growable: false);
    } on Object {
      throw const CaptureNoteStorageException();
    }
  }

  @override
  Future<void> delete(CaptureNote note, {CaptureNote? expectedCurrent}) async {
    try {
      await _database.transaction(() async {
        if (expectedCurrent != null) {
          final row = await (_database.select(
            _database.captureNoteRows,
          )..where((r) => r.id.equals(note.id))).getSingleOrNull();
          if (row == null ||
              !sameCaptureNoteVersion(_fromRow(row), expectedCurrent)) {
            throw const CaptureNoteStorageException();
          }
        }
        final deleted = await (_database.delete(
          _database.captureNoteRows,
        )..where((row) => row.id.equals(note.id))).go();
        if (deleted == 0) {
          throw const CaptureNoteStorageException();
        }
      });
    } on CaptureNoteStorageException {
      rethrow;
    } on Object {
      throw const CaptureNoteStorageException();
    }
  }

  Future<void> close() async {
    if (closeDatabase) {
      await _database.close();
    }
  }

  static CaptureNote _fromRow(CaptureNoteRow row) {
    try {
      return CaptureNote(
        id: row.id,
        text: row.content,
        source: CaptureSource.values.byName(row.source),
        experiencedDate: row.experiencedDay == null
            ? null
            : LocalDate.fromEpochDay(row.experiencedDay!),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          row.updatedAtMillis == 0 ? row.createdAtMillis : row.updatedAtMillis,
          isUtc: true,
        ),
        keepInComfortKit: row.keepInComfortKit,
        provenance: HealthRecordProvenance.fromStorageKey(row.provenance),
        originalProvenance: HealthRecordProvenance.fromStorageKey(
          row.originalProvenance ?? row.provenance,
        ),
        writeZoneOffsetMinutes: row.writeZoneOffsetMinutes,
        writeZoneName: row.writeZoneName,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          row.createdAtMillis,
          isUtc: true,
        ),
      );
    } on Object {
      throw const CaptureNoteStorageException();
    }
  }
}

final class CaptureNoteStorageException implements Exception {
  const CaptureNoteStorageException();
}
