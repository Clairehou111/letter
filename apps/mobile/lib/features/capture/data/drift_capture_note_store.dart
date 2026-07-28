import 'package:drift/drift.dart';

import '../../cycle/data/letter_health_database.dart';
import '../domain/capture_models.dart';

/// Stores only explicit text notes and their source. This store has no raw
/// audio input and is intentionally not used by reports or analytics.
final class DriftCaptureNoteStore implements CaptureNoteStore {
  DriftCaptureNoteStore(this._database, {this.closeDatabase = true});

  final LetterHealthDatabase _database;
  final bool closeDatabase;

  @override
  Future<CaptureNote> save(CaptureNote note) async {
    try {
      await _database
          .into(_database.captureNoteRows)
          .insert(
            CaptureNoteRowsCompanion.insert(
              id: note.id,
              content: note.text,
              source: note.source.name,
              createdAtMillis: note.createdAt.toUtc().millisecondsSinceEpoch,
            ),
          );
      return note;
    } on Object {
      throw const CaptureNoteStorageException();
    }
  }

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
  Future<void> delete(CaptureNote note) async {
    try {
      final deleted = await (_database.delete(
        _database.captureNoteRows,
      )..where((row) => row.id.equals(note.id))).go();
      if (deleted == 0) {
        throw const CaptureNoteStorageException();
      }
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
