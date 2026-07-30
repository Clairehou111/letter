import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/diary/data/in_memory_diary_repository.dart';
import 'package:letter_mobile/features/diary/domain/diary_enrollment.dart';
import 'package:letter_mobile/features/diary/domain/diary_repository.dart';

void main() {
  DateTime fakeClock() => DateTime.utc(2026, 9, 30, 12);

  /// Creates a synthetic two-cycle diary: enrollment on July 1, daily entries
  /// from July 1 through Sept 28 (90 days ≈ two median cycles), with some
  /// intentionally skipped days.
  Future<void> seedTwoCycles({
    required DiaryEnrollmentRepository enrollmentRepo,
    required DiaryEntryRepository entryRepo,
    int skipModulus = 7, // skip every Nth day
  }) async {
    final enrollment = await enrollmentRepo.create(
      DiaryEnrollmentDraft(startedAt: DateTime.utc(2026, 7, 1)),
    );

    var current = const LocalDate(2026, 7, 1);
    final end = const LocalDate(2026, 9, 28);
    var dayCount = 0;

    while (current.compareTo(end) <= 0) {
      dayCount++;
      // Intentionally skip some days (mimics real-world missed days).
      if (dayCount % skipModulus == 0) {
        current = current.addDays(1);
        continue;
      }

      // Vary symptom ratings in a plausible cyclic pattern.
      final cycleDay = dayCount % 29; // ~29-day cycle
      final irritability = cycleDay > 22 && cycleDay < 29 ? 4 : 1;
      final lowEnergy = cycleDay > 20 && cycleDay < 28 ? 3 : 1;
      final physicalSymptoms = cycleDay < 6 ? 4 : 1;

      await entryRepo.saveEntry(
        DiaryEntryDraft(
          enrollmentId: enrollment.id,
          experiencedDate: current,
          provenance: dayCount % 5 == 0
              ? DiaryEntryProvenance.laterRecall
              : DiaryEntryProvenance.prospective,
          symptoms: {
            'irritability': irritability,
            'lowEnergy': lowEnergy,
            'physicalSymptoms': physicalSymptoms,
          },
          functionalImpacts: cycleDay > 23 ? {'work': 3, 'social': 4} : {},
        ),
      );

      current = current.addDays(1);
    }
  }

  group('two-cycle diary validation', () {
    test('entries span at least two cycle-length windows', () async {
      final enrollmentRepo = InMemoryDiaryEnrollmentRepository(clock: fakeClock);
      final entryRepo = InMemoryDiaryEntryRepository(clock: fakeClock);

      await seedTwoCycles(enrollmentRepo: enrollmentRepo, entryRepo: entryRepo);

      final enrollment = await enrollmentRepo.getLatest();
      expect(enrollment, isNotNull);

      final entries = await entryRepo.getEntries(enrollment!.id);

      // At least 60 days of coverage across ~90 days (skipping 1/7).
      expect(entries.length, greaterThanOrEqualTo(60));

      final dates = entries.map((e) => e.experiencedDate).toSet();
      expect(
        dates.length,
        entries.length, // No duplicate dates
      );
    });

    test('missed days are absent, not zero-filled', () async {
      final enrollmentRepo = InMemoryDiaryEnrollmentRepository(clock: fakeClock);
      final entryRepo = InMemoryDiaryEntryRepository(clock: fakeClock);

      await seedTwoCycles(enrollmentRepo: enrollmentRepo, entryRepo: entryRepo);

      final enrollment = await enrollmentRepo.getLatest();
      final entries = await entryRepo.getEntries(enrollment!.id);

      // Verify no entry has all-zeros (would indicate backfill).
      for (final entry in entries) {
        expect(entry.isEmpty, isFalse,
            reason: 'Entry for ${entry.experiencedDate} should not be empty');
        expect(
          entry.symptoms.values.every((v) => v == 0),
          isFalse,
          reason: 'Entry should not have all-zero symptom ratings',
        );
      }
    });

    test('provenance marks laterRecall correctly', () async {
      final enrollmentRepo = InMemoryDiaryEnrollmentRepository(clock: fakeClock);
      final entryRepo = InMemoryDiaryEntryRepository(clock: fakeClock);

      await seedTwoCycles(enrollmentRepo: enrollmentRepo, entryRepo: entryRepo);

      final enrollment = await enrollmentRepo.getLatest();
      final entries = await entryRepo.getEntries(enrollment!.id);

      final laterRecallEntries = entries
          .where((e) => e.provenance == DiaryEntryProvenance.laterRecall)
          .toList();
      expect(laterRecallEntries, isNotEmpty,
          reason: 'Should have some later-recall entries mixed in');
    });

    test('date range query returns correct subset', () async {
      final enrollmentRepo = InMemoryDiaryEnrollmentRepository(clock: fakeClock);
      final entryRepo = InMemoryDiaryEntryRepository(clock: fakeClock);

      await seedTwoCycles(enrollmentRepo: enrollmentRepo, entryRepo: entryRepo);

      // Query just the first month.
      final julyEntries = await entryRepo.getEntriesInRange(
        const LocalDate(2026, 7, 1),
        const LocalDate(2026, 7, 31),
      );
      expect(julyEntries.length, greaterThanOrEqualTo(20));

      // No entry outside the range.
      for (final entry in julyEntries) {
        expect(
          entry.experiencedDate.compareTo(const LocalDate(2026, 7, 1)),
          greaterThanOrEqualTo(0),
        );
        expect(
          entry.experiencedDate.compareTo(const LocalDate(2026, 7, 31)),
          lessThanOrEqualTo(0),
        );
      }
    });

    test('pause and resume does not lose entries', () async {
      final enrollmentRepo = InMemoryDiaryEnrollmentRepository(clock: fakeClock);
      final entryRepo = InMemoryDiaryEntryRepository(clock: fakeClock);

      final enrollment = await enrollmentRepo.create(
        DiaryEnrollmentDraft(startedAt: DateTime.utc(2026, 8, 1)),
      );

      // Save some entries.
      await entryRepo.saveEntry(
        DiaryEntryDraft(
          enrollmentId: enrollment.id,
          experiencedDate: const LocalDate(2026, 8, 1),
          symptoms: {'irritability': 2},
        ),
      );
      await entryRepo.saveEntry(
        DiaryEntryDraft(
          enrollmentId: enrollment.id,
          experiencedDate: const LocalDate(2026, 8, 2),
          symptoms: {'lowEnergy': 3},
        ),
      );

      // Pause enrollment.
      await enrollmentRepo.update(
        enrollment.id,
        const DiaryEnrollmentUpdate(status: DiaryEnrollmentStatus.paused),
      );

      final afterPause = await entryRepo.getEntries(enrollment.id);
      expect(afterPause.length, 2); // Entries preserved during pause.
    });

    test('stop does not delete existing entries', () async {
      final enrollmentRepo = InMemoryDiaryEnrollmentRepository(clock: fakeClock);
      final entryRepo = InMemoryDiaryEntryRepository(clock: fakeClock);

      final enrollment = await enrollmentRepo.create(
        DiaryEnrollmentDraft(startedAt: DateTime.utc(2026, 8, 1)),
      );

      await entryRepo.saveEntry(
        DiaryEntryDraft(
          enrollmentId: enrollment.id,
          experiencedDate: const LocalDate(2026, 8, 1),
          symptoms: {'irritability': 2},
        ),
      );

      // Stop enrollment.
      await enrollmentRepo.update(
        enrollment.id,
        const DiaryEnrollmentUpdate(
          status: DiaryEnrollmentStatus.stopped,
          stoppedReason: 'Done',
        ),
      );

      final entries = await entryRepo.getEntries(enrollment.id);
      expect(entries.length, 1); // Entry survives stop.
    });
  });
}
