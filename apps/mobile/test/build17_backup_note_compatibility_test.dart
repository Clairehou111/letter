import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/cycle/data/letter_health_database.dart';
import 'package:letter_mobile/features/local_backup/data/drift_local_backup_store.dart';
import 'package:letter_mobile/features/local_backup/domain/local_backup_import.dart';
import 'package:letter_mobile/features/local_backup/domain/local_backup_models.dart';

void main() {
  late LetterHealthDatabase source;
  late LetterHealthDatabase target;
  late DriftLocalBackupStore backup;
  late DriftLocalBackupStore destination;
  setUp(() {
    source = LetterHealthDatabase(NativeDatabase.memory());
    target = LetterHealthDatabase(NativeDatabase.memory());
    backup = DriftLocalBackupStore(source);
    destination = DriftLocalBackupStore(target);
  });
  tearDown(() async {
    await source.close();
    await target.close();
  });
  Future<void> restore(LocalBackupSnapshot snapshot) async {
    final plan = planLocalBackupImport(
      incoming: snapshot,
      destination: await destination.captureSnapshot(),
      policy: LocalBackupImportPolicy.replace,
    );
    await (await destination.stage(plan)).commit();
  }

  Future<LocalBackupSnapshot> oldNote(
    int version,
    Map<String, Object?> data,
  ) async {
    final snapshot = await backup.captureSnapshot();
    return LocalBackupSnapshot(
      createdAt: snapshot.createdAt,
      collections: snapshot.collections.map(
        (c) => c.name == 'capture_notes'
            ? LocalBackupCollection(
                name: c.name,
                schemaVersion: version,
                records: [
                  LocalBackupRecord(
                    id: 'same-note',
                    updatedAt: DateTime.fromMillisecondsSinceEpoch(
                      data['updatedAtMillis'] as int? ?? 100,
                      isUtc: true,
                    ),
                    data: data,
                  ),
                ],
              )
            : c,
      ),
    );
  }

  const base = {
    'content': 'Keep these exact words',
    'source': 'typed',
    'createdAtMillis': 100,
  };
  const timing = {
    'experiencedDay': 20600,
    'updatedAtMillis': 200,
    'provenance': 'later_recall',
    'originalProvenance': 'same_day',
    'writeZoneOffsetMinutes': -240,
    'writeZoneName': 'EDT',
  };
  test(
    'merged v3 preserves explicit Kit choice and date metadata alongside Build17 durable tables',
    () async {
      await source
          .into(source.captureNoteRows)
          .insert(
            CaptureNoteRowsCompanion.insert(
              id: 'same-note',
              content: 'Keep these exact words',
              source: 'typed',
              createdAtMillis: 100,
              updatedAtMillis: const Value(200),
              keepInComfortKit: const Value(true),
              experiencedDay: const Value(20600),
              provenance: const Value('later_recall'),
              originalProvenance: const Value('same_day'),
              writeZoneOffsetMinutes: const Value(-240),
              writeZoneName: const Value('EDT'),
            ),
          );
      await source
          .into(source.comfortKitOverrideRows)
          .insert(
            ComfortKitOverrideRowsCompanion.insert(
              sourceId: 'care:kept',
              action: 'dontShowAgain',
              sourceVersion: const Value('version-a'),
              updatedAtMillis: 300,
            ),
          );
      await source
          .into(source.comfortReminderPreferenceRows)
          .insert(
            ComfortReminderPreferenceRowsCompanion.insert(
              id: 'active',
              enabled: const Value(true),
              leadDays: const Value(1),
              hour: const Value(10),
              minute: const Value(15),
              updatedAtMillis: 400,
            ),
          );
      final snapshot = await backup.captureSnapshot();
      expect(
        snapshot.collections
            .singleWhere((c) => c.name == 'capture_notes')
            .schemaVersion,
        3,
      );
      await restore(snapshot);
      expect(
        (await target.select(target.captureNoteRows).get()).single.toJson(),
        (await source.select(source.captureNoteRows).get()).single.toJson(),
      );
      expect(
        (await target.select(target.comfortKitOverrideRows).get()).single
            .toJson(),
        (await source.select(source.comfortKitOverrideRows).get()).single
            .toJson(),
      );
      expect(
        (await target.select(target.comfortReminderPreferenceRows).get()).single
            .toJson(),
        (await source.select(source.comfortReminderPreferenceRows).get()).single
            .toJson(),
      );
    },
  );
  test(
    'Build17 v2 retains kept note without inventing a date or zone',
    () async {
      await restore(
        await oldNote(2, {
          ...base,
          'updatedAtMillis': 200,
          'keepInComfortKit': true,
        }),
      );
      final note = (await target.select(target.captureNoteRows).get()).single;
      expect(note.keepInComfortKit, isTrue);
      expect(note.updatedAtMillis, 200);
      expect(note.experiencedDay, isNull);
      expect(note.provenance, isNull);
      expect(note.writeZoneName, isNull);
    },
  );
  test(
    'RH v2 retains experienced date and recall without inventing Kit consent',
    () async {
      await restore(await oldNote(2, {...base, ...timing}));
      final note = (await target.select(target.captureNoteRows).get()).single;
      expect(note.keepInComfortKit, isFalse);
      expect(note.experiencedDay, 20600);
      expect(note.provenance, 'later_recall');
      expect(note.originalProvenance, 'same_day');
      expect(note.writeZoneName, 'EDT');
      expect(note.updatedAtMillis, 200);
    },
  );
  test('v1 remains undated and unkept', () async {
    await restore(await oldNote(1, base));
    final note = (await target.select(target.captureNoteRows).get()).single;
    expect(note.keepInComfortKit, isFalse);
    expect(note.experiencedDay, isNull);
    expect(note.updatedAtMillis, 100);
  });
  test(
    'ambiguous combined v2 fails before changing destination data',
    () async {
      await target
          .into(target.captureNoteRows)
          .insert(
            CaptureNoteRowsCompanion.insert(
              id: 'already-there',
              content: 'Existing untouched',
              source: 'typed',
              createdAtMillis: 50,
            ),
          );
      final incoming = await oldNote(2, {
        ...base,
        ...timing,
        'keepInComfortKit': true,
      });
      await expectLater(
        restore(incoming),
        throwsA(
          isA<LocalBackupException>().having(
            (e) => e.failure,
            'failure',
            LocalBackupFailure.malformedPayload,
          ),
        ),
      );
      expect(
        (await target.select(target.captureNoteRows).get()).single.id,
        'already-there',
      );
    },
  );
}
