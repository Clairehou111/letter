import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/cycle/data/drift_period_repository.dart';
import 'package:letter_mobile/features/cycle/data/letter_health_database.dart';
import 'package:letter_mobile/features/cycle/domain/bleeding_flow.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/cycle/domain/period_record.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';
import 'package:letter_mobile/features/record_hub/data/drift_record_hub_repository.dart';
import 'package:letter_mobile/features/record_hub/domain/record_hub_facts.dart';

void main() {
  late LetterHealthDatabase database;
  late DriftPeriodRepository periods;
  late DriftRecordHubRepository facts;
  late DateTime now;
  const date = LocalDate(2026, 10, 8);
  setUp(() {
    now = DateTime(2026, 10, 8, 12);
    database = LetterHealthDatabase(NativeDatabase.memory());
    periods = DriftPeriodRepository(database, clock: () => now, closeDatabase: false);
    facts = DriftRecordHubRepository(database, clock: () => now);
  });
  tearDown(() => database.close());
  Future<PeriodRecord> seed() => periods.create(PeriodDraft(startDate: date, endDate: date), today: date);

  test('legacy flow is read-only until deliberate edit; no-op retains timestamps and unknown timing', () async {
    final period = await seed();
    final flow = await periods.setFlow(period.id, date, BleedingFlow.light, today: date);
    await periods.setBleedingColor(period.id, date, BleedingColor.brown);
    final old = (await facts.getDateFacts(date)).bleeding!;
    expect(old.id, '${period.id}:${date.epochDay}');
    expect(old.metadata.provenance, HealthRecordProvenance.timingUnknown);
    expect(await database.select(database.recordHubBleedingRows).get(), isEmpty);
    now = DateTime(2026, 10, 9, 1);
    final unchanged = await facts.upsertBleeding(old.value);
    expect(unchanged.id, old.id);
    expect(unchanged.metadata.updatedAt, old.metadata.updatedAt);
    expect(await database.select(database.recordHubBleedingRows).get(), isEmpty);
    final changed = await facts.upsertBleeding(BleedingFactDraft(experiencedDate: date,
      periodId: period.id, flow: BleedingFlow.medium, color: BleedingColor.brown, clots: ClotObservation.notSure));
    expect(changed.id, old.id);
    expect(changed.metadata.recordedAt.millisecondsSinceEpoch, flow.createdAt.millisecondsSinceEpoch);
    expect(changed.metadata.originalProvenance, HealthRecordProvenance.timingUnknown);
    expect(changed.metadata.provenance, HealthRecordProvenance.laterRecall);
    expect(await database.select(database.periodFlowRows).get(), isEmpty);
    expect((await periods.getAllFlowDays()).single.flow, BleedingFlow.medium);
  });
  test('withdrawal through Record does not resurrect legacy flow in Cycle', () async {
    final period = await seed();
    await periods.setFlow(period.id, date, BleedingFlow.spotting, today: date);
    await facts.clearBleeding(date);
    expect((await facts.getDateFacts(date)).bleeding, isNull);
    expect(await periods.getAllFlowDays(), isEmpty);
    expect(await periods.getAll(), hasLength(1));
  });
  test('Cycle edits promoted source without mirrored copy or loss of clots', () async {
    final period = await seed();
    final source = await facts.upsertBleeding(BleedingFactDraft(experiencedDate: date,
      periodId: period.id, flow: BleedingFlow.light, color: BleedingColor.pink, clots: ClotObservation.present));
    now = DateTime(2026, 10, 9, 2);
    await periods.setFlow(period.id, date, BleedingFlow.heavy, today: LocalDate.fromDateTime(now));
    await periods.setBleedingColor(period.id, date, BleedingColor.darkRed);
    final changed = (await facts.getDateFacts(date)).bleeding!;
    expect(changed.id, source.id);
    expect(changed.value.clots, ClotObservation.present);
    expect(changed.value.flow, BleedingFlow.heavy);
    expect(changed.value.color, BleedingColor.darkRed);
    expect(changed.metadata.provenance, HealthRecordProvenance.laterRecall);
    expect(await database.select(database.periodFlowRows).get(), isEmpty);
  });
  test('nonperiod spotting and explicit no-bleeding never manufacture period anchors', () async {
    await facts.upsertBleeding(BleedingFactDraft(experiencedDate: date, flow: BleedingFlow.spotting));
    expect(await periods.getAll(), isEmpty);
    expect((await facts.getDateFacts(date)).bleeding!.value.periodId, isNull);
    await facts.upsertBleeding(BleedingFactDraft(experiencedDate: date, flow: null));
    expect((await facts.getDateFacts(date)).bleeding!.value.noBleeding, isTrue);
    expect(await periods.getAll(), isEmpty);
    await facts.clearBleeding(date);
    expect((await facts.getDateFacts(date)).bleeding, isNull);
  });
}
