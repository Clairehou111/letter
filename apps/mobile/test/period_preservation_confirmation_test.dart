import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/care/data/drift_care_memory_repository.dart';
import 'package:letter_mobile/features/care/domain/care_memory.dart';
import 'package:letter_mobile/features/cycle/data/drift_period_repository.dart';
import 'package:letter_mobile/features/cycle/data/in_memory_period_repository.dart';
import 'package:letter_mobile/features/cycle/data/letter_health_database.dart';
import 'package:letter_mobile/features/cycle/domain/bleeding_flow.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/cycle/domain/period_record.dart';
import 'package:letter_mobile/features/cycle/domain/period_repository.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';
import 'package:letter_mobile/features/record_hub/data/drift_record_hub_repository.dart';
import 'package:letter_mobile/features/record_hub/domain/record_hub_facts.dart';

const _today = LocalDate(2026, 8, 15);
LocalDate _day(int day) => LocalDate(2026, 8, day);
PeriodDraft _draft(int start, int end) =>
    PeriodDraft(startDate: _day(start), endDate: _day(end));
Matcher _failure(PeriodWriteFailure failure) => isA<PeriodWriteException>()
    .having((error) => error.failure, 'failure', failure);

void main() {
  for (final drift in [false, true]) {
    group(drift ? 'Drift reviewed writes' : 'InMemory reviewed writes', () {
      late ConfirmablePeriodRepository repository;
      LetterHealthDatabase? database;
      setUp(() {
        var next = 0;
        if (drift) {
          database = LetterHealthDatabase(NativeDatabase.memory());
          repository = DriftPeriodRepository(
            database!,
            clock: () => DateTime.utc(2026, 8, 15, 12),
            idGenerator: () => 'period-${next++}',
            closeDatabase: false,
          );
        } else {
          repository = InMemoryPeriodRepository(
            clock: () => DateTime.utc(2026, 8, 15, 12),
            idGenerator: () => 'period-${next++}',
          );
        }
      });
      tearDown(() async => database?.close());

      test(
        'adjacent create and edit require confirmation before any mutation',
        () async {
          final first = await repository.create(_draft(1, 3), today: _today);
          final later = await repository.create(_draft(8, 10), today: _today);
          await expectLater(
            repository.create(_draft(4, 7), today: _today),
            throwsA(_failure(PeriodWriteFailure.confirmationRequired)),
          );
          await expectLater(
            repository.update(later.id, _draft(4, 10), today: _today),
            throwsA(_failure(PeriodWriteFailure.confirmationRequired)),
          );
          final preview = await repository.previewWrite(
            _draft(4, 7),
            today: _today,
          );
          expect(preview.requiresConfirmation, isTrue);
          expect(preview.adjacentPeriods.map((period) => period.id).toSet(), {
            first.id,
            later.id,
          });
          expect(await repository.getAll(), hasLength(2)); // Cancel: no write.
          expect((await repository.getAll()).first.startDate, _day(8));
          final saved = await repository.confirmWrite(preview, today: _today);
          expect(saved.id, first.id);
          expect(saved.startDate, _day(1));
          expect(saved.endDate, _day(10));
          expect(await repository.getAll(), hasLength(1));
          await expectLater(
            repository.confirmWrite(preview, today: _today),
            throwsA(_failure(PeriodWriteFailure.staleConfirmation)),
          );
        },
      );

      test(
        'flow change after review invalidates confirmation without losing sources',
        () async {
          final first = await repository.create(_draft(1, 3), today: _today);
          final preview = await repository.previewWrite(
            _draft(4, 5),
            today: _today,
          );
          await repository.setFlow(
            first.id,
            _day(2),
            BleedingFlow.heavy,
            today: _today,
          );
          await expectLater(
            repository.confirmWrite(preview, today: _today),
            throwsA(_failure(PeriodWriteFailure.staleConfirmation)),
          );
          expect((await repository.getAll()).single.endDate, _day(3));
          expect(
            (await repository.getAllFlowDays()).single.flow,
            BleedingFlow.heavy,
          );
          final refreshed = await repository.previewWrite(
            _draft(4, 5),
            today: _today,
          );
          await repository.confirmWrite(refreshed, today: _today);
          expect(
            (await repository.getAllFlowDays()).single.createdAt,
            DateTime.utc(2026, 8, 15, 12),
          );
        },
      );

      test(
        'confirmed update merges while retaining the earliest source identity',
        () async {
          final first = await repository.create(_draft(1, 3), today: _today);
          final later = await repository.create(_draft(8, 10), today: _today);
          final preview = await repository.previewWrite(
            _draft(4, 10),
            today: _today,
            editingId: later.id,
          );
          final merged = await repository.confirmWrite(preview, today: _today);
          expect(merged.id, first.id);
          expect(merged.createdAt, first.createdAt);
          expect(merged.endDate, _day(10));
          expect(await repository.getAll(), hasLength(1));
        },
      );
    });
  }

  group('durable source preservation', () {
    late LetterHealthDatabase database;
    late DriftPeriodRepository periods;
    late DriftRecordHubRepository hub;
    late DriftCareMemoryRepository care;
    late DateTime now;
    setUp(() {
      var next = 0;
      now = DateTime.utc(2026, 8, 15, 10);
      database = LetterHealthDatabase(NativeDatabase.memory());
      periods = DriftPeriodRepository(
        database,
        clock: () => now,
        idGenerator: () => 'p-${next++}',
        closeDatabase: false,
      );
      hub = DriftRecordHubRepository(database, clock: () => now);
      care = DriftCareMemoryRepository(
        database,
        clock: () => now,
        idGenerator: () => 'letter-${next++}',
        closeDatabase: false,
      );
    });
    tearDown(() => database.close());

    test(
      'shrink and delete promote legacy flow with stable IDs and original metadata',
      () async {
        final period = await periods.create(_draft(1, 5), today: _today);
        await periods.setFlow(
          period.id,
          _day(1),
          BleedingFlow.spotting,
          today: _today,
        );
        await periods.setBleedingColor(
          period.id,
          _day(1),
          BleedingColor.darkRed,
        );
        await periods.setFlow(
          period.id,
          _day(3),
          BleedingFlow.medium,
          today: _today,
        );
        final original = (await hub.getDateFacts(_day(1))).bleeding!;
        now = now.add(const Duration(hours: 1));
        await expectLater(
          periods.update(period.id, _draft(2, 4), today: _today),
          throwsA(_failure(PeriodWriteFailure.confirmationRequired)),
        );
        final shrinkReview = await periods.previewWrite(
          _draft(2, 4),
          today: _today,
          editingId: period.id,
        );
        expect(shrinkReview.requiresConfirmation, isTrue);
        expect(shrinkReview.detachedBleedingCount, 1);
        await periods.confirmWrite(shrinkReview, today: _today);
        final retained = (await hub.getDateFacts(_day(1))).bleeding!;
        expect(retained.metadata.id, original.metadata.id);
        expect(retained.metadata.recordedAt, original.metadata.recordedAt);
        expect(retained.metadata.updatedAt, original.metadata.updatedAt);
        expect(
          retained.metadata.provenance,
          HealthRecordProvenance.timingUnknown,
        );
        expect(
          retained.metadata.originalProvenance,
          HealthRecordProvenance.timingUnknown,
        );
        expect(retained.metadata.utcOffsetMinutes, isNull);
        expect(retained.value.periodId, isNull);
        expect(retained.value.flow, BleedingFlow.spotting);
        expect(retained.value.color, BleedingColor.darkRed);
        final inside = (await hub.getDateFacts(_day(3))).bleeding!;
        await periods.delete(period.id);
        final detached = (await hub.getDateFacts(_day(3))).bleeding!;
        expect(detached.metadata.id, inside.metadata.id);
        expect(detached.metadata.updatedAt, inside.metadata.updatedAt);
        expect(detached.value.periodId, isNull);
        expect(await periods.getAllFlowDays(), isEmpty);
        expect(await hub.getAllFacts(), hasLength(2));
        // Reopening a repository reads durable facts, not a process cache.
        expect(
          (await DriftRecordHubRepository(
            database,
          ).getDateFacts(_day(1))).bleeding!.metadata.id,
          original.metadata.id,
        );
      },
    );

    test(
      'range change detaches typed bleeding without rewriting its provenance or clots',
      () async {
        final period = await periods.create(_draft(1, 5), today: _today);
        final original = await hub.upsertBleeding(
          BleedingFactDraft(
            experiencedDate: _day(1),
            periodId: period.id,
            flow: BleedingFlow.light,
            clots: ClotObservation.present,
          ),
        );
        now = now.add(const Duration(hours: 1));
        final preview = await periods.previewWrite(
          _draft(2, 5),
          today: _today,
          editingId: period.id,
        );
        expect(preview.detachedBleedingCount, 1);
        await periods.confirmWrite(preview, today: _today);
        final retained = (await hub.getDateFacts(_day(1))).bleeding!;
        expect(retained.metadata.id, original.metadata.id);
        expect(retained.metadata.recordedAt, original.metadata.recordedAt);
        expect(retained.metadata.updatedAt, original.metadata.updatedAt);
        expect(retained.metadata.provenance, original.metadata.provenance);
        expect(
          retained.metadata.originalProvenance,
          original.metadata.originalProvenance,
        );
        expect(
          retained.metadata.utcOffsetMinutes,
          original.metadata.utcOffsetMinutes,
        );
        expect(retained.value.clots, original.value.clots);
        expect(retained.value.periodId, isNull);
      },
    );

    test(
      'merge preserves both legacy flow IDs and every saved reflection unchanged',
      () async {
        final first = await periods.create(_draft(1, 3), today: _today);
        final later = await periods.create(_draft(7, 9), today: _today);
        await periods.setFlow(
          first.id,
          _day(2),
          BleedingFlow.light,
          today: _today,
        );
        await periods.setFlow(
          later.id,
          _day(8),
          BleedingFlow.heavy,
          today: _today,
        );
        final firstLetter = await care.saveCycleReflection(
          _day(1).epochDay,
          const CycleReflectionDraft(observation: 'Original first letter'),
          startingPeriodId: first.id,
        );
        final laterLetter = await care.saveCycleReflection(
          _day(7).epochDay,
          const CycleReflectionDraft(whatHelped: 'Original later letter'),
          startingPeriodId: later.id,
        );
        final oldFlow = (await hub.getDateFacts(_day(8))).bleeding!;
        final preview = await periods.previewWrite(_draft(4, 6), today: _today);
        expect(preview.detachedReflectionCount, 1);
        now = now.add(const Duration(hours: 1));
        final merged = await periods.confirmWrite(preview, today: _today);
        final flow = (await hub.getDateFacts(_day(8))).bleeding!;
        expect(flow.metadata.id, oldFlow.metadata.id);
        expect(flow.metadata.updatedAt, oldFlow.metadata.updatedAt);
        expect(flow.value.periodId, merged.id);
        final letters = await care.getCycleReflections();
        expect(letters, hasLength(2));
        for (final source in [firstLetter, laterLetter]) {
          final letter = letters.singleWhere(
            (letter) => letter.id == source.id,
          );
          expect(letter.cycleStartDay, source.cycleStartDay);
          expect(letter.createdAt, source.createdAt);
          expect(letter.updatedAt, source.updatedAt);
          expect(letter.observation, source.observation);
          expect(letter.whatHelped, source.whatHelped);
        }
        expect(
          letters
              .singleWhere((letter) => letter.id == laterLetter.id)
              .startingPeriodId,
          isNull,
        );
        expect(
          (await care.getCycleReflection(
            _day(1).epochDay,
            startingPeriodId: merged.id,
          ))!.id,
          firstLetter.id,
        );
        await periods.delete(merged.id);
        expect(
          (await hub.getDateFacts(_day(8))).bleeding!.metadata.id,
          oldFlow.metadata.id,
        );
        expect(await care.getCycleReflections(), hasLength(2));
      },
    );

    test(
      'a reflection edit after preview blocks the merge atomically',
      () async {
        final period = await periods.create(_draft(3, 5), today: _today);
        final preview = await periods.previewWrite(_draft(1, 2), today: _today);
        await care.saveCycleReflection(
          _day(3).epochDay,
          const CycleReflectionDraft(observation: 'Saved while reviewing'),
          startingPeriodId: period.id,
        );
        await expectLater(
          periods.confirmWrite(preview, today: _today),
          throwsA(_failure(PeriodWriteFailure.staleConfirmation)),
        );
        expect((await periods.getAll()).single.startDate, _day(3));
        expect(
          (await care.getCycleReflections()).single.observation,
          'Saved while reviewing',
        );
      },
    );

    test(
      'a range edit displacing only a saved letter requires review',
      () async {
        final period = await periods.create(_draft(1, 5), today: _today);
        final source = await care.saveCycleReflection(
          _day(1).epochDay,
          const CycleReflectionDraft(observation: 'Saved original date'),
          startingPeriodId: period.id,
        );
        await expectLater(
          periods.update(period.id, _draft(2, 5), today: _today),
          throwsA(_failure(PeriodWriteFailure.confirmationRequired)),
        );
        final preview = await periods.previewWrite(
          _draft(2, 5),
          today: _today,
          editingId: period.id,
        );
        expect(preview.requiresConfirmation, isTrue);
        expect(preview.adjacentPeriods, isEmpty);
        expect(preview.detachedBleedingCount, 0);
        expect(preview.detachedReflectionCount, 1);
        await periods.confirmWrite(preview, today: _today);
        final retained = (await care.getCycleReflections()).single;
        expect(retained.id, source.id);
        expect(retained.cycleStartDay, source.cycleStartDay);
        expect(retained.updatedAt, source.updatedAt);
      },
    );

    test(
      'editing the primary letter after prepend preserves its anchor and another original letter',
      () async {
        final period = await periods.create(_draft(3, 5), today: _today);
        final primary = await care.saveCycleReflection(
          _day(3).epochDay,
          const CycleReflectionDraft(observation: 'Original primary'),
          startingPeriodId: period.id,
        );
        final detached = await care.saveCycleReflection(
          _day(1).epochDay,
          const CycleReflectionDraft(observation: 'Original detached'),
        );
        final preview = await periods.previewWrite(_draft(1, 2), today: _today);
        await periods.confirmWrite(preview, today: _today);
        final edited = await care.saveCycleReflection(
          _day(1).epochDay,
          const CycleReflectionDraft(observation: 'Explicit primary edit'),
          startingPeriodId: period.id,
        );
        expect(edited.id, primary.id);
        expect(edited.cycleStartDay, primary.cycleStartDay);
        expect(edited.createdAt, primary.createdAt);
        expect(
          (await care.getCycleReflections())
              .singleWhere((source) => source.id == detached.id)
              .observation,
          detached.observation,
        );
      },
    );

    test(
      'explicit withdrawal clears flow rather than creating a retained fact',
      () async {
        final period = await periods.create(_draft(1, 3), today: _today);
        await periods.setFlow(
          period.id,
          _day(2),
          BleedingFlow.light,
          today: _today,
        );
        await periods.clearFlow(period.id, _day(2));
        await periods.delete(period.id);
        expect((await hub.getDateFacts(_day(2))).bleeding, isNull);
      },
    );

    test(
      'distinct same-date sources fail closed instead of discarding the legacy ID',
      () async {
        final period = await periods.create(_draft(1, 3), today: _today);
        await periods.setFlow(
          period.id,
          _day(2),
          BleedingFlow.light,
          today: _today,
        );
        await database
            .into(database.recordHubBleedingRows)
            .insert(
              RecordHubBleedingRowsCompanion.insert(
                id: 'separate-existing-source',
                experiencedDay: _day(2).epochDay,
                recordedAtMillis: 1,
                updatedAtMillis: 1,
                provenance: 'timing_unknown',
                originalProvenance: 'timing_unknown',
                flow: const Value('heavy'),
              ),
            );
        await expectLater(
          periods.delete(period.id),
          throwsA(_failure(PeriodWriteFailure.storageUnavailable)),
        );
        expect(await periods.getAll(), hasLength(1));
        expect(
          await database.select(database.periodFlowRows).get(),
          hasLength(1),
        );
        expect(
          (await hub.getDateFacts(_day(2))).bleeding!.metadata.id,
          'separate-existing-source',
        );
      },
    );
  });

  test(
    'InMemory optional reflection source participates in consequential review and stale detection',
    () async {
      final savedAt = DateTime.utc(2026, 8, 15, 12);
      final letters = <CycleReflection>[];
      final repository = InMemoryPeriodRepository(
        clock: () => savedAt,
        idGenerator: () => 'memory-period',
        cycleReflectionSourceReader: () => letters,
      );
      final period = await repository.create(_draft(1, 5), today: _today);
      CycleReflection letter(String text) => CycleReflection(
        id: 'memory-letter',
        startingPeriodId: period.id,
        cycleStartDay: _day(1).epochDay,
        observation: text,
        need: null,
        whatHelped: null,
        futureSelfNote: null,
        createdAt: savedAt,
        updatedAt: savedAt,
      );
      letters.add(letter('Original reflection'));
      await expectLater(
        repository.update(period.id, _draft(2, 5), today: _today),
        throwsA(_failure(PeriodWriteFailure.confirmationRequired)),
      );
      final preview = await repository.previewWrite(
        _draft(2, 5),
        today: _today,
        editingId: period.id,
      );
      expect(preview.detachedReflectionCount, 1);
      expect(preview.requiresConfirmation, isTrue);
      letters[0] = letter('Changed during review, same clock tick');
      await expectLater(
        repository.confirmWrite(preview, today: _today),
        throwsA(_failure(PeriodWriteFailure.staleConfirmation)),
      );
      expect((await repository.getAll()).single.startDate, _day(1));
      expect(
        letters.single.observation,
        'Changed during review, same clock tick',
      );
    },
  );

  test(
    'InMemory promoted flow preserves pre-merge ID after subsequent deletion',
    () async {
      var next = 0;
      final repository = InMemoryPeriodRepository(
        clock: () => DateTime.utc(2026, 8, 15, 12),
        idGenerator: () => 'memory-${next++}',
      );
      final first = await repository.create(_draft(1, 3), today: _today);
      final later = await repository.create(_draft(7, 9), today: _today);
      final original = await repository.setFlow(
        later.id,
        _day(8),
        BleedingFlow.medium,
        today: _today,
      );
      final preview = await repository.previewWrite(
        _draft(4, 6),
        today: _today,
      );
      await repository.confirmWrite(preview, today: _today);
      await repository.delete(first.id);
      final retained = repository.independentBleedingFacts.single;
      expect(retained.metadata.id, '${later.id}:${_day(8).epochDay}');
      expect(retained.metadata.recordedAt, original.createdAt);
      expect(retained.metadata.updatedAt, original.updatedAt);
      expect(retained.value.periodId, isNull);
      expect(
        retained.metadata.provenance,
        HealthRecordProvenance.timingUnknown,
      );
      final replacement = await repository.create(_draft(7, 9), today: _today);
      await repository.setFlow(
        replacement.id,
        _day(8),
        BleedingFlow.heavy,
        today: _today,
      );
      expect(repository.independentBleedingFacts, isEmpty);
      await repository.delete(replacement.id);
      final corrected = repository.independentBleedingFacts.single;
      expect(corrected.metadata.id, retained.metadata.id);
      expect(corrected.metadata.recordedAt, retained.metadata.recordedAt);
      expect(corrected.value.flow, BleedingFlow.heavy);
    },
  );
}
