import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/experience/backup/letter_backup_experience_port.dart';
import 'package:letter_mobile/experience/experience_release_ports.dart';
import 'package:letter_mobile/features/local_backup/data/in_memory_local_backup_store.dart';
import 'package:letter_mobile/features/local_backup/domain/local_backup_file_port.dart';
import 'package:letter_mobile/features/local_backup/domain/local_backup_models.dart';

final class _FilePort implements LocalBackupFilePort {
  _FilePort({this.failShare = false});

  final bool failShare;
  Uint8List? saved;
  Uint8List? shared;

  @override
  String get exportLocationDescription => 'your Letter folder on this device';

  @override
  Future<Uint8List?> pickEncryptedBackup() async => null;

  @override
  Future<String> saveEncryptedBackupLocally(Uint8List bytes) async {
    saved = bytes;
    return '/Letter/backup.letter';
  }

  @override
  Future<String> shareEncryptedBackup(Uint8List bytes) async {
    if (failShare) throw StateError('share unavailable');
    shared = bytes;
    return 'backup.letter';
  }
}

LocalBackupSnapshot _snapshot() => LocalBackupSnapshot(
  createdAt: DateTime.utc(2026, 8, 17),
  collections: const [],
);

void main() {
  test('exposes a destination phrase that composes without duplicate copy', () {
    final port = LetterBackupExperiencePort(
      store: InMemoryLocalBackupStore(_snapshot()),
      filePort: _FilePort(),
    );

    expect(
      port.localDestinationDescription,
      'Letter Within’s dedicated letter folder on this device',
    );
    expect(port.localDestinationDescription, isNot(contains('saves')));
    expect(port.localDestinationDescription, isNot(contains('opens')));
  });

  test(
    'saves an encrypted Letter backup before opening native sharing',
    () async {
      final files = _FilePort();
      final port = LetterBackupExperiencePort(
        store: InMemoryLocalBackupStore(_snapshot()),
        filePort: files,
      );

      final receipt = await port.exportEncrypted(
        passphrase: 'kept by the user',
        rememberPassphrase: false,
      );

      expect(receipt.outcome, ExperienceFileOutcome.shared);
      expect(receipt.localPath, '/Letter/backup.letter');
      expect(files.saved, isNotNull);
      expect(files.shared, files.saved);
      expect(files.saved, isNot(contains('letter.local-backup.payload')));
    },
  );

  test('keeps the local copy when native sharing is unavailable', () async {
    final files = _FilePort(failShare: true);
    final port = LetterBackupExperiencePort(
      store: InMemoryLocalBackupStore(_snapshot()),
      filePort: files,
    );

    final receipt = await port.exportEncrypted(
      passphrase: 'kept by the user',
      rememberPassphrase: false,
    );

    expect(receipt.outcome, ExperienceFileOutcome.savedOnly);
    expect(receipt.localPath, '/Letter/backup.letter');
    expect(files.saved, isNotNull);
  });
}
