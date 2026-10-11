import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/capture/data/drift_capture_note_store.dart';
import 'package:letter_mobile/features/capture/domain/capture_models.dart';
import 'package:letter_mobile/features/cycle/data/letter_health_database.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';

void main() {
  test('Drift persists text capture notes and deletes by stable id', () async {
    final database = LetterHealthDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final store = DriftCaptureNoteStore(database, closeDatabase: false);
    final note = CaptureNote(
      id: 'note-1',
      text: 'I need a dark and quiet room.',
      source: CaptureSource.typed,
      createdAt: DateTime.utc(2026, 7, 28, 14),
    );

    await store.save(note);

    final loaded = (await store.getAll()).single;
    expect(loaded.id, 'note-1');
    expect(loaded.text, 'I need a dark and quiet room.');
    expect(loaded.source, CaptureSource.typed);
    expect(loaded.createdAt, DateTime.utc(2026, 7, 28, 14));

    await store.delete(loaded);
    expect(await store.getAll(), isEmpty);
  });
  test(
    'Kit choice survives dated correction, conditional delete and exact Undo',
    () async {
      final database = LetterHealthDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      var now = DateTime(2026, 10, 9, 12);
      final store = DriftCaptureNoteStore(
        database,
        closeDatabase: false,
        clock: () => now,
      );
      final saved = await store.save(
        CaptureNote(
          id: 'kept-dated',
          text: 'Original words',
          source: CaptureSource.typed,
          createdAt: now.toUtc(),
          experiencedDate: const LocalDate(2026, 10, 9),
          keepInComfortKit: true,
        ),
      );
      now = DateTime(2026, 10, 10, 12);
      final edited = await store.update(
        saved.copyWith(text: 'Corrected words'),
      );
      expect(edited.keepInComfortKit, isTrue);
      expect(edited.id, saved.id);
      expect(edited.createdAt, saved.createdAt);
      expect(edited.experiencedDate, saved.experiencedDate);
      expect(edited.provenance, HealthRecordProvenance.laterRecall);
      expect(
        edited.effectiveOriginalProvenance,
        HealthRecordProvenance.sameDay,
      );
      expect((await store.getAll()).single.keepInComfortKit, isTrue);
      await store.delete(edited, expectedCurrent: edited);
      await store.restore(edited);
      expect(
        sameCaptureNoteVersion((await store.getAll()).single, edited),
        isTrue,
      );
    },
  );
  test(
    'changing only Kit consent preserves the experienced-source timing',
    () async {
      final database = LetterHealthDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      var now = DateTime(2026, 10, 9, 12);
      final store = DriftCaptureNoteStore(
        database,
        closeDatabase: false,
        clock: () => now,
      );
      final saved = await store.save(
        CaptureNote(
          id: 'kit-only',
          text: 'Stable source words',
          source: CaptureSource.typed,
          createdAt: now.toUtc(),
          experiencedDate: const LocalDate(2026, 10, 9),
        ),
      );
      now = DateTime(2026, 10, 10, 12);
      final kept = await store.update(saved.copyWith(keepInComfortKit: true));
      expect(kept.keepInComfortKit, isTrue);
      expect(kept.provenance, saved.provenance);
      expect(
        kept.effectiveOriginalProvenance,
        saved.effectiveOriginalProvenance,
      );
      expect(kept.createdAt, saved.createdAt);
      expect(kept.experiencedDate, saved.experiencedDate);
      await expectLater(
        store.restore(saved, expectedCurrent: saved),
        throwsA(isA<CaptureNoteStorageException>()),
      );
      expect((await store.getAll()).single.keepInComfortKit, isTrue);
    },
  );
  test(
    'conditional Drift correction cannot overwrite a newer Kit or text revision',
    () async {
      final database = LetterHealthDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final store = DriftCaptureNoteStore(
        database,
        closeDatabase: false,
        clock: () => DateTime(2026, 10, 10, 12),
      );
      final original = await store.save(
        CaptureNote(
          id: 'conditional-note',
          text: 'Original undated words',
          source: CaptureSource.typed,
          createdAt: DateTime.utc(2026, 8, 15),
        ),
      );
      final newer = await store.updateIfUnchanged(
        original.copyWith(text: 'Newer words', keepInComfortKit: true),
        expectedCurrent: original,
      );
      await expectLater(
        store.updateIfUnchanged(
          original.copyWith(text: 'Stale edit'),
          expectedCurrent: original,
        ),
        throwsA(isA<CaptureNoteStorageException>()),
      );
      expect(
        sameCaptureNoteVersion((await store.getAll()).single, newer),
        isTrue,
      );
      expect(newer.experiencedDate, isNull);
      expect(newer.writeZoneOffsetMinutes, isNotNull);
      expect(newer.provenance, HealthRecordProvenance.timingUnknown);
    },
  );
}
