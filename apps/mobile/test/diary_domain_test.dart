import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/diary/data/in_memory_diary_repository.dart';
import 'package:letter_mobile/features/diary/domain/diary_enrollment.dart';
import 'package:letter_mobile/features/diary/domain/diary_repository.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';

void main() {
  DateTime fakeClock() => DateTime.utc(2026, 7, 30, 12);

  group('DiaryEnrollmentRepository', () {
    test('creates first enrollment as active', () async {
      final repo = InMemoryDiaryEnrollmentRepository(clock: fakeClock);
      final enrollment = await repo.create(const DiaryEnrollmentDraft());

      expect(enrollment.status, DiaryEnrollmentStatus.active);
      expect(enrollment.startedAt, fakeClock());
      expect(enrollment.isActive, isTrue);
    });

    test('rejects second active enrollment', () async {
      final repo = InMemoryDiaryEnrollmentRepository(clock: fakeClock);
      await repo.create(const DiaryEnrollmentDraft());

      await expectLater(
        repo.create(const DiaryEnrollmentDraft()),
        throwsA(
          isA<DiaryException>().having(
            (error) => error.failure,
            'failure',
            DiaryFailure.enrollmentAlreadyActive,
          ),
        ),
      );
    });

    test('pauses an active enrollment', () async {
      final repo = InMemoryDiaryEnrollmentRepository(clock: fakeClock);
      final enrollment = await repo.create(const DiaryEnrollmentDraft());

      final paused = await repo.update(
        enrollment.id,
        const DiaryEnrollmentUpdate(status: DiaryEnrollmentStatus.paused),
      );

      expect(paused.status, DiaryEnrollmentStatus.paused);
      expect(paused.isActive, isFalse);
    });

    test('stops an enrollment with reason', () async {
      final repo = InMemoryDiaryEnrollmentRepository(clock: fakeClock);
      final enrollment = await repo.create(const DiaryEnrollmentDraft());

      final stopped = await repo.update(
        enrollment.id,
        DiaryEnrollmentUpdate(
          status: DiaryEnrollmentStatus.stopped,
          stoppedReason: 'Not helpful right now',
        ),
      );

      expect(stopped.status, DiaryEnrollmentStatus.stopped);
      expect(stopped.stoppedReason, 'Not helpful right now');
      expect(stopped.stoppedAt, isNotNull);
    });

    test('updating non-existent enrollment throws', () async {
      final repo = InMemoryDiaryEnrollmentRepository(clock: fakeClock);

      await expectLater(
        repo.update('does-not-exist', const DiaryEnrollmentUpdate()),
        throwsA(
          isA<DiaryException>().having(
            (error) => error.failure,
            'failure',
            DiaryFailure.enrollmentNotFound,
          ),
        ),
      );
    });

    test('getLatest returns most recent enrollment', () async {
      final repo = InMemoryDiaryEnrollmentRepository(clock: fakeClock);
      final first = await repo.create(const DiaryEnrollmentDraft());
      await repo.update(
        first.id,
        const DiaryEnrollmentUpdate(
          status: DiaryEnrollmentStatus.stopped,
        ),
      );

      final second = await repo.create(
        DiaryEnrollmentDraft(startedAt: DateTime.utc(2026, 8, 1)),
      );

      final latest = await repo.getLatest();
      expect(latest!.id, second.id);
    });

    test('getLatest returns null with no enrollments', () async {
      final repo = InMemoryDiaryEnrollmentRepository(clock: fakeClock);
      expect(await repo.getLatest(), isNull);
    });
  });

  group('DiaryEntryRepository', () {
    test('saves and retrieves entries by enrollment', () async {
      final repo = InMemoryDiaryEntryRepository(clock: fakeClock);
      const enrollmentId = 'diary-enrollment-1';

      final entry = await repo.saveEntry(
        DiaryEntryDraft(
          enrollmentId: enrollmentId,
          experiencedDate: const LocalDate(2026, 7, 30),
          symptoms: {'irritability': 3, 'lowEnergy': 2},
          functionalImpacts: {'work': 2},
        ),
      );

      expect(entry.symptoms['irritability'], 3);
      expect(entry.symptoms['lowEnergy'], 2);
      expect(entry.functionalImpacts['work'], 2);
      expect(entry.provenance, DiaryEntryProvenance.prospective);

      final entries = await repo.getEntries(enrollmentId);
      expect(entries.single.id, entry.id);
    });

    test('overwrites existing entry for same date', () async {
      final repo = InMemoryDiaryEntryRepository(clock: fakeClock);
      const enrollmentId = 'diary-enrollment-1';

      final first = await repo.saveEntry(
        DiaryEntryDraft(
          enrollmentId: enrollmentId,
          experiencedDate: const LocalDate(2026, 7, 30),
          symptoms: {'irritability': 1},
        ),
      );

      final second = await repo.saveEntry(
        DiaryEntryDraft(
          enrollmentId: enrollmentId,
          experiencedDate: const LocalDate(2026, 7, 30),
          symptoms: {'irritability': 4, 'lowEnergy': 2},
        ),
      );

      expect(second.id, first.id); // Same id, overwritten
      expect(second.symptoms['irritability'], 4);
      final entries = await repo.getEntries(enrollmentId);
      expect(entries.length, 1);
    });

    test('deletes an entry', () async {
      final repo = InMemoryDiaryEntryRepository(clock: fakeClock);
      const enrollmentId = 'diary-enrollment-1';

      final entry = await repo.saveEntry(
        DiaryEntryDraft(
          enrollmentId: enrollmentId,
          experiencedDate: const LocalDate(2026, 7, 30),
          symptoms: {'irritability': 2},
        ),
      );

      expect((await repo.getEntries(enrollmentId)).length, 1);
      await repo.deleteEntry(entry.id);
      expect((await repo.getEntries(enrollmentId)).length, 0);
    });

    test('retrieves entries in date range', () async {
      final repo = InMemoryDiaryEntryRepository(clock: fakeClock);
      const enrollmentId = 'diary-enrollment-1';

      await repo.saveEntry(
        DiaryEntryDraft(
          enrollmentId: enrollmentId,
          experiencedDate: const LocalDate(2026, 7, 28),
          symptoms: {'lowEnergy': 1},
        ),
      );
      await repo.saveEntry(
        DiaryEntryDraft(
          enrollmentId: enrollmentId,
          experiencedDate: const LocalDate(2026, 7, 30),
          symptoms: {'irritability': 3},
        ),
      );
      await repo.saveEntry(
        DiaryEntryDraft(
          enrollmentId: enrollmentId,
          experiencedDate: const LocalDate(2026, 8, 2),
          symptoms: {'anxiety': 2},
        ),
      );

      final range = await repo.getEntriesInRange(
        const LocalDate(2026, 7, 29),
        const LocalDate(2026, 7, 31),
      );
      expect(range.length, 1);
      expect(range.single.experiencedDate, const LocalDate(2026, 7, 30));
    });

    test('rejects ratings outside 0–5', () async {
      final repo = InMemoryDiaryEntryRepository(clock: fakeClock);

      await expectLater(
        repo.saveEntry(
          DiaryEntryDraft(
            enrollmentId: 'x',
            experiencedDate: const LocalDate(2026, 7, 30),
            symptoms: {'irritability': 6},
          ),
        ),
        throwsA(
          isA<DiaryException>().having(
            (error) => error.failure,
            'failure',
            DiaryFailure.invalidRating,
          ),
        ),
      );

      await expectLater(
        repo.saveEntry(
          DiaryEntryDraft(
            enrollmentId: 'x',
            experiencedDate: const LocalDate(2026, 7, 30),
            symptoms: {'irritability': -1},
          ),
        ),
        throwsA(
          isA<DiaryException>().having(
            (error) => error.failure,
            'failure',
            DiaryFailure.invalidRating,
          ),
        ),
      );
    });

    test('allows laterRecall provenance', () async {
      final repo = InMemoryDiaryEntryRepository(clock: fakeClock);
      const enrollmentId = 'diary-enrollment-1';

      final entry = await repo.saveEntry(
        DiaryEntryDraft(
          enrollmentId: enrollmentId,
          experiencedDate: const LocalDate(2026, 7, 28),
          provenance: DiaryEntryProvenance.laterRecall,
          symptoms: {'lowEnergy': 2},
        ),
      );

      expect(entry.provenance, DiaryEntryProvenance.laterRecall);
    });

    test('missed days are simply absent, not zero-filled', () async {
      final repo = InMemoryDiaryEntryRepository(clock: fakeClock);
      const enrollmentId = 'diary-enrollment-1';

      await repo.saveEntry(
        DiaryEntryDraft(
          enrollmentId: enrollmentId,
          experiencedDate: const LocalDate(2026, 7, 28),
          symptoms: {'lowEnergy': 1},
        ),
      );
      // July 29: intentionally skipped (no entry)
      await repo.saveEntry(
        DiaryEntryDraft(
          enrollmentId: enrollmentId,
          experiencedDate: const LocalDate(2026, 7, 30),
          symptoms: {'irritability': 3},
        ),
      );

      final all = await repo.getEntries(enrollmentId);
      expect(all.length, 2);
      expect(all.any((entry) => entry.experiencedDate == const LocalDate(2026, 7, 29)), isFalse);
    });
  });

  group('DiaryEnrollment domain', () {
    test('DiaryReminder validates hours and minutes', () {
      expect(const DiaryReminder(hour: 8, minute: 30).isValid, isTrue);
      expect(const DiaryReminder(hour: 24, minute: 0).isValid, isFalse);
      expect(const DiaryReminder(hour: 0, minute: 60).isValid, isFalse);
      expect(const DiaryReminder(hour: -1, minute: 0).isValid, isFalse);
    });

    test('DiaryEntry.isEmpty works correctly', () {
      final empty = DiaryEntry(
        id: 'x',
        enrollmentId: 'e',
        experiencedDate: const LocalDate(2026, 7, 30),
        recordedAt: DateTime.utc(2026),
        provenance: DiaryEntryProvenance.prospective,
        symptoms: const {},
        functionalImpacts: const {},
      );
      final filled = DiaryEntry(
        id: 'y',
        enrollmentId: 'e',
        experiencedDate: const LocalDate(2026, 7, 30),
        recordedAt: DateTime.utc(2026),
        provenance: DiaryEntryProvenance.prospective,
        symptoms: const {'irritability': 2},
        functionalImpacts: const {},
      );
      expect(empty.isEmpty, isTrue);
      expect(filled.isEmpty, isFalse);
    });
  });
}
