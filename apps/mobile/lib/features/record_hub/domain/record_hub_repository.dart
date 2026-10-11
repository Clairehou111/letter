import '../../cycle/domain/local_date.dart';
import 'record_hub_facts.dart';

/// Additional facts use the incumbent encrypted store. Symptom ratings remain
/// in HealthRecordRepository; period ranges remain in PeriodRepository.
abstract interface class RecordHubRepository {
  Future<RecordHubDateFacts> getDateFacts(LocalDate date);

  Future<List<RecordHubDateFacts>> getAllFacts();

  /// Null retains incumbent pin behavior until the user saves a configuration.
  Future<SymptomPins?> getPins();
  Future<void> setPins(SymptomPins pins);

  /// Singleton upserts preserve the source ID and initial metadata on edits.
  /// Implementations revalidate the actual local date at the durable write.
  Future<DailyImpactRecord> upsertImpact(DailyImpactDraft draft);
  Future<BleedingFactRecord> upsertBleeding(BleedingFactDraft draft);
  Future<SleepRecord> upsertSleep(SleepDraft draft);
  Future<AppetiteRecord> upsertAppetite(AppetiteDraft draft);

  Future<void> clearImpact(LocalDate date);
  Future<void> clearBleeding(LocalDate date);
  Future<void> clearSleep(LocalDate date);
  Future<void> clearAppetite(LocalDate date);

  /// No ID creates a distinct event; an ID updates that exact source.
  Future<ActivityRecord> saveActivity(ActivityDraft draft, {String? id});
  Future<ContextEventRecord> saveEvent(ContextEventDraft draft, {String? id});
  Future<TemperatureRecord> saveTemperature(
    TemperatureDraft draft, {
    String? id,
  });

  Future<void> deleteActivity(String id);
  Future<void> deleteEvent(String id);
  Future<void> deleteTemperature(String id);
}
