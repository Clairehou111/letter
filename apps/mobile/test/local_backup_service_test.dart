import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/local_backup/application/local_backup_service.dart';
import 'package:letter_mobile/features/local_backup/data/in_memory_local_backup_store.dart';
import 'package:letter_mobile/features/local_backup/domain/local_backup_import.dart';
import 'package:letter_mobile/features/local_backup/domain/local_backup_models.dart';

void main() {
  final service = LocalBackupService();
  final snapshot = _snapshot(
    createdAt: DateTime.utc(2026, 7, 28),
    records: [
      _record('health-1', DateTime.utc(2026, 7, 20), {'symptom': 'Cramps'}),
    ],
  );

  test('encrypts an opaque, versioned package and decrypts it', () async {
    final bytes = await service.encryptSnapshot(
      snapshot: snapshot,
      passphrase: 'private backup password',
    );

    final readablePackage = utf8.decode(bytes);
    expect(readablePackage, contains('letter.local-backup'));
    expect(readablePackage, isNot(contains('Cramps')));
    expect(readablePackage, isNot(contains('health-1')));

    final restored = await service.decryptSnapshot(
      packageBytes: bytes,
      passphrase: 'private backup password',
    );
    expect(restored.collections.single.records.single.id, 'health-1');
    expect(
      restored.collections.single.records.single.data['symptom'],
      'Cramps',
    );
  });

  test('fails closed for a wrong password and tampered package', () async {
    final bytes = await service.encryptSnapshot(
      snapshot: snapshot,
      passphrase: 'private backup password',
    );
    await expectLater(
      service.decryptSnapshot(packageBytes: bytes, passphrase: 'incorrect'),
      throwsA(
        isA<LocalBackupException>().having(
          (error) => error.failure,
          'failure',
          LocalBackupFailure.integrityCheckFailed,
        ),
      ),
    );

    final decoded = jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
    final ciphertext = decoded['ciphertext']! as String;
    decoded['ciphertext'] =
        '${ciphertext.substring(0, ciphertext.length - 2)}AA';
    await expectLater(
      service.decryptSnapshot(
        packageBytes: utf8.encode(jsonEncode(decoded)),
        passphrase: 'private backup password',
      ),
      throwsA(
        isA<LocalBackupException>().having(
          (error) => error.failure,
          'failure',
          LocalBackupFailure.integrityCheckFailed,
        ),
      ),
    );
  });

  test('rejects incompatible package headers before deriving a key', () async {
    final bytes = await service.encryptSnapshot(
      snapshot: snapshot,
      passphrase: 'private backup password',
    );
    final decoded = jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
    final kdf = Map<String, Object?>.from(decoded['kdf']! as Map);
    kdf['memoryKiB'] = 999999;
    decoded['kdf'] = kdf;

    await expectLater(
      service.decryptSnapshot(
        packageBytes: utf8.encode(jsonEncode(decoded)),
        passphrase: 'private backup password',
      ),
      throwsA(
        isA<LocalBackupException>().having(
          (error) => error.failure,
          'failure',
          LocalBackupFailure.incompatibleCrypto,
        ),
      ),
    );
  });

  test('rejects an empty or whitespace-only passphrase', () async {
    await expectLater(
      service.encryptSnapshot(snapshot: snapshot, passphrase: ''),
      throwsA(
        isA<LocalBackupException>().having(
          (error) => error.failure,
          'failure',
          LocalBackupFailure.emptyPassphrase,
        ),
      ),
    );
    await expectLater(
      service.encryptSnapshot(snapshot: snapshot, passphrase: '   '),
      throwsA(
        isA<LocalBackupException>().having(
          (error) => error.failure,
          'failure',
          LocalBackupFailure.emptyPassphrase,
        ),
      ),
    );
  });

  test('rejects a corrupt or structurally invalid package', () async {
    await expectLater(
      service.decryptSnapshot(
        packageBytes: utf8.encode('not valid json at all'),
        passphrase: 'anything',
      ),
      throwsA(
        isA<LocalBackupException>().having(
          (error) => error.failure,
          'failure',
          LocalBackupFailure.invalidPackage,
        ),
      ),
    );

    await expectLater(
      service.decryptSnapshot(
        packageBytes: utf8.encode(jsonEncode({'format': 'wrong-format'})),
        passphrase: 'anything',
      ),
      throwsA(isA<LocalBackupException>()),
    );
  });

  test('rejects a valid JSON package with a malformed payload inside', () async {
    final bytes = await service.encryptSnapshot(
      snapshot: snapshot,
      passphrase: 'private backup password',
    );
    final decoded = jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
    decoded['ciphertext'] = 'AAAA';

    // With a drastically wrong ciphertext, integrity failure is expected.
    await expectLater(
      service.decryptSnapshot(
        packageBytes: utf8.encode(jsonEncode(decoded)),
        passphrase: 'private backup password',
      ),
      throwsA(
        isA<LocalBackupException>().having(
          (error) => error.failure,
          'failure',
          LocalBackupFailure.integrityCheckFailed,
        ),
      ),
    );
  });

  test('merge has deterministic stable-ID conflict rules', () {
    final destination = _snapshot(
      createdAt: DateTime.utc(2026, 7, 1),
      records: [
        _record('older-source-wins', DateTime.utc(2026, 7, 1), {
          'value': 'old',
        }),
        _record('equal-destination-wins', DateTime.utc(2026, 7, 4), {
          'value': 'keep',
        }),
        _record('destination-only', DateTime.utc(2026, 7, 2), {
          'value': 'stay',
        }),
      ],
    );
    final incoming = _snapshot(
      createdAt: DateTime.utc(2026, 7, 28),
      records: [
        _record('older-source-wins', DateTime.utc(2026, 7, 2), {
          'value': 'new',
        }),
        _record('equal-destination-wins', DateTime.utc(2026, 7, 4), {
          'value': 'ignored',
        }),
        _record('incoming-only', DateTime.utc(2026, 7, 3), {'value': 'add'}),
      ],
    );

    final plan = planLocalBackupImport(
      incoming: incoming,
      destination: destination,
      policy: LocalBackupImportPolicy.merge,
    );
    final records = {
      for (final record in plan.resultingSnapshot.collections.single.records)
        record.id: record,
    };
    expect(records['older-source-wins']!.data['value'], 'new');
    expect(records['equal-destination-wins']!.data['value'], 'keep');
    expect(records['destination-only']!.data['value'], 'stay');
    expect(records['incoming-only']!.data['value'], 'add');
    final preview = plan.preview.collections.single;
    expect(
      (preview.wouldAdd, preview.wouldReplace, preview.wouldKeepDestination),
      (1, 1, 2),
    );
  });

  test(
    'replace is exact and staging leaves data unchanged until commit',
    () async {
      final destination = _snapshot(
        createdAt: DateTime.utc(2026, 7, 1),
        records: [
          _record('destination-only', DateTime.utc(2026, 7, 2), {
            'value': 'stay',
          }),
        ],
      );
      final store = InMemoryLocalBackupStore(destination);
      final bytes = await service.encryptSnapshot(
        snapshot: snapshot,
        passphrase: 'private backup password',
      );

      final staged = await service.prepareImport(
        packageBytes: bytes,
        passphrase: 'private backup password',
        policy: LocalBackupImportPolicy.replace,
        destination: store,
        stager: store,
      );
      expect(
        (await store.captureSnapshot()).collections.single.records.single.id,
        'destination-only',
      );
      expect(staged.preview.collections.single.wouldRemove, 1);

      await staged.commit();
      expect(
        (await store.captureSnapshot()).collections.single.records.single.id,
        'health-1',
      );
    },
  );
}

LocalBackupSnapshot _snapshot({
  required DateTime createdAt,
  required List<LocalBackupRecord> records,
}) {
  return LocalBackupSnapshot(
    createdAt: createdAt,
    collections: [
      LocalBackupCollection(
        name: 'health_records',
        schemaVersion: 1,
        records: records,
      ),
    ],
  );
}

LocalBackupRecord _record(
  String id,
  DateTime updatedAt,
  Map<String, Object?> data,
) => LocalBackupRecord(id: id, updatedAt: updatedAt, data: data);
