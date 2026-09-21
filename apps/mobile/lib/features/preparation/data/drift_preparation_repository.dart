import 'dart:convert';

import 'package:drift/drift.dart';

import '../../care/domain/care_mode.dart';
import '../../cycle/data/letter_health_database.dart';
import '../domain/preparation_plan.dart';

final class DriftPreparationRepository implements PreparationRepository {
  const DriftPreparationRepository(this._database);

  final LetterHealthDatabase _database;

  @override
  Future<PreparationPlan?> getActivePlan() async {
    final query = _database.select(_database.preparationPlanRows)
      ..where((row) => row.id.equals(PreparationPlan.activeId));
    final row = await query.getSingleOrNull();
    if (row == null) return null;
    try {
      final ids = (jsonDecode(row.sourceRecordIdsJson) as List<Object?>)
          .cast<String>();
      return PreparationPlan(
        id: row.id,
        status: PreparationPlanStatus.values.byName(row.status),
        evidenceFingerprint: row.evidenceFingerprint,
        sourceRecordIds: ids,
        includeCare: row.includeCare,
        careActionId: row.careActionId,
        careActionLabel: row.careActionLabel,
        careMode: CareMode.values.byName(row.careMode),
        betterCount: row.betterCount,
        sameCount: row.sameCount,
        worseCount: row.worseCount,
        noteText: row.noteText,
        personalText: row.personalText,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          row.createdAtMillis,
          isUtc: true,
        ),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          row.updatedAtMillis,
          isUtc: true,
        ),
      );
    } on Object {
      throw const FormatException('Invalid saved preparation');
    }
  }

  @override
  Future<void> savePlan(PreparationPlan plan) => _database
      .into(_database.preparationPlanRows)
      .insertOnConflictUpdate(
        PreparationPlanRowsCompanion.insert(
          id: plan.id,
          status: plan.status.name,
          evidenceFingerprint: plan.evidenceFingerprint,
          sourceRecordIdsJson: jsonEncode(plan.sourceRecordIds),
          includeCare: plan.includeCare,
          careActionId: plan.careActionId,
          careActionLabel: plan.careActionLabel,
          careMode: plan.careMode.name,
          betterCount: plan.betterCount,
          sameCount: plan.sameCount,
          worseCount: plan.worseCount,
          noteText: Value(plan.noteText),
          personalText: Value(plan.personalText),
          createdAtMillis: plan.createdAt.toUtc().millisecondsSinceEpoch,
          updatedAtMillis: plan.updatedAt.toUtc().millisecondsSinceEpoch,
        ),
      );

  @override
  Future<void> removeActivePlan() async {
    await (_database.delete(
      _database.preparationPlanRows,
    )..where((row) => row.id.equals(PreparationPlan.activeId))).go();
  }

  @override
  Future<List<PreparationDismissal>> getDismissals() async {
    final query = _database.select(_database.preparationDismissalRows)
      ..orderBy([(row) => OrderingTerm.desc(row.dismissedAtMillis)]);
    return (await query.get())
        .map(
          (row) => PreparationDismissal(
            fingerprint: row.fingerprint,
            evidenceLine: row.evidenceLine,
            dismissedAt: DateTime.fromMillisecondsSinceEpoch(
              row.dismissedAtMillis,
              isUtc: true,
            ),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> dismiss(PreparationDismissal dismissal) => _database
      .into(_database.preparationDismissalRows)
      .insertOnConflictUpdate(
        PreparationDismissalRowsCompanion.insert(
          fingerprint: dismissal.fingerprint,
          evidenceLine: dismissal.evidenceLine,
          dismissedAtMillis: dismissal.dismissedAt
              .toUtc()
              .millisecondsSinceEpoch,
        ),
      );

  @override
  Future<void> restoreDismissal(String fingerprint) async {
    await (_database.delete(
      _database.preparationDismissalRows,
    )..where((row) => row.fingerprint.equals(fingerprint))).go();
  }
}
