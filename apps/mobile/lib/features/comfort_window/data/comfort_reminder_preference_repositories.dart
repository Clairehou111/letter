import 'package:drift/drift.dart';

import '../../cycle/data/letter_health_database.dart';
import '../domain/comfort_reminder_preference.dart';

final class InMemoryComfortReminderPreferenceRepository
    implements ComfortReminderPreferenceRepository {
  ComfortReminderPreference value = const ComfortReminderPreference();

  @override
  Future<ComfortReminderPreference> load() async => value;

  @override
  Future<void> save(ComfortReminderPreference preference) async {
    value = preference;
  }
}

final class DriftComfortReminderPreferenceRepository
    implements ComfortReminderPreferenceRepository {
  DriftComfortReminderPreferenceRepository(this._database);

  final LetterHealthDatabase _database;

  @override
  Future<ComfortReminderPreference> load() async {
    final row =
        await (_database.select(_database.comfortReminderPreferenceRows)..where(
              (row) => row.id.equals(ComfortReminderPreference.activeId),
            ))
            .getSingleOrNull();
    if (row == null) return const ComfortReminderPreference();
    return ComfortReminderPreference(
      enabled: row.enabled,
      leadDays: row.leadDays,
      hour: row.hour,
      minute: row.minute,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        row.updatedAtMillis,
        isUtc: true,
      ),
    );
  }

  @override
  Future<void> save(ComfortReminderPreference preference) => _database
      .into(_database.comfortReminderPreferenceRows)
      .insertOnConflictUpdate(
        ComfortReminderPreferenceRowsCompanion.insert(
          id: ComfortReminderPreference.activeId,
          enabled: Value(preference.enabled),
          leadDays: Value(preference.leadDays),
          hour: Value(preference.hour),
          minute: Value(preference.minute),
          updatedAtMillis: (preference.updatedAt ?? DateTime.now())
              .toUtc()
              .millisecondsSinceEpoch,
        ),
      );
}
