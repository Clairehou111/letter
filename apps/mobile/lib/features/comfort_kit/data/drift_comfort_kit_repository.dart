import 'package:drift/drift.dart';

import '../../cycle/data/letter_health_database.dart';
import '../domain/comfort_kit.dart';
import '../domain/comfort_kit_repository.dart';

final class DriftComfortKitRepository implements ComfortKitRepository {
  DriftComfortKitRepository(this._database);

  final LetterHealthDatabase _database;

  @override
  Future<List<ComfortKitItemOverride>> getOverrides() async {
    final rows = await _database.select(_database.comfortKitOverrideRows).get();
    return List.unmodifiable(
      rows.map(
        (row) => ComfortKitItemOverride(
          sourceId: row.sourceId,
          action: ComfortKitOverrideAction.values.byName(row.action),
          sourceVersion: row.sourceVersion,
          updatedAt: DateTime.fromMillisecondsSinceEpoch(
            row.updatedAtMillis,
            isUtc: true,
          ),
        ),
      ),
    );
  }

  @override
  Future<void> removeUntilChanged({
    required ComfortKitItem item,
    required DateTime updatedAt,
  }) => _upsert(
    sourceId: item.sourceId,
    action: ComfortKitOverrideAction.removeUntilChanged,
    sourceVersion: item.sourceVersion,
    updatedAt: updatedAt,
  );

  @override
  Future<void> dontShowAgain({
    required String sourceId,
    required DateTime updatedAt,
  }) => _upsert(
    sourceId: sourceId,
    action: ComfortKitOverrideAction.dontShowAgain,
    updatedAt: updatedAt,
  );

  Future<void> _upsert({
    required String sourceId,
    required ComfortKitOverrideAction action,
    required DateTime updatedAt,
    String? sourceVersion,
  }) => _database
      .into(_database.comfortKitOverrideRows)
      .insertOnConflictUpdate(
        ComfortKitOverrideRowsCompanion.insert(
          sourceId: sourceId,
          action: action.name,
          sourceVersion: Value(sourceVersion),
          updatedAtMillis: updatedAt.toUtc().millisecondsSinceEpoch,
        ),
      );

  @override
  Future<void> restore(String sourceId) async {
    await (_database.delete(
      _database.comfortKitOverrideRows,
    )..where((row) => row.sourceId.equals(sourceId))).go();
  }
}
