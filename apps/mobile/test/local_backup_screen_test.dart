import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/local_backup/data/in_memory_local_backup_store.dart';
import 'package:letter_mobile/features/local_backup/domain/local_backup_file_port.dart';
import 'package:letter_mobile/features/local_backup/domain/local_backup_models.dart';
import 'package:letter_mobile/features/local_backup/presentation/local_backup_screen.dart';

void main() {
  testWidgets('renders explicit encrypted export and import preview actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LocalBackupScreen(
          store: InMemoryLocalBackupStore(_emptySnapshot()),
          filePort: const _FakeBackupFilePort(),
        ),
      ),
    );

    expect(find.byKey(const Key('local-backup-export')), findsOneWidget);
    expect(find.byKey(const Key('local-backup-import-merge')), findsOneWidget);
    expect(
      find.byKey(const Key('local-backup-import-replace')),
      findsOneWidget,
    );
    expect(find.textContaining('Sealed impulse letters'), findsOneWidget);
  });
}

LocalBackupSnapshot _emptySnapshot() => LocalBackupSnapshot(
  createdAt: DateTime.utc(2026, 7, 28),
  collections: [
    for (final name in const [
      'periods',
      'care_records',
      'care_reflections',
      'health_records',
      'capture_notes',
    ])
      LocalBackupCollection(name: name, schemaVersion: 1, records: const []),
  ],
);

final class _FakeBackupFilePort implements LocalBackupFilePort {
  const _FakeBackupFilePort();

  @override
  Future<Uint8List?> pickEncryptedBackup() async => null;

  @override
  Future<void> shareEncryptedBackup(Uint8List bytes) async {}
}
