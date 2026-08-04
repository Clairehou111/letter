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

    await tester.scrollUntilVisible(
      find.byKey(const Key('local-backup-export')),
      200,
      scrollable: find.byType(Scrollable),
    );
    expect(find.byKey(const Key('local-backup-export')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('local-backup-import-merge')),
      200,
      scrollable: find.byType(Scrollable),
    );
    expect(find.byKey(const Key('local-backup-import-merge')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('local-backup-import-replace')),
      200,
      scrollable: find.byType(Scrollable),
    );
    expect(
      find.byKey(const Key('local-backup-import-replace')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('local-backup-help')), findsOneWidget);
    expect(find.textContaining('Remember this password'), findsOneWidget);
    expect(find.textContaining('Sealed impulse letters'), findsOneWidget);
  });

  testWidgets('opens export and import help', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LocalBackupScreen(
          store: InMemoryLocalBackupStore(_emptySnapshot()),
          filePort: const _FakeBackupFilePort(),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('local-backup-help')));
    await tester.pumpAndSettle();

    expect(find.text('Export and import help'), findsOneWidget);
    expect(find.text('Is it safe to see salt and nonce?'), findsOneWidget);
    expect(find.textContaining('cannot recover'), findsOneWidget);
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
  Future<String> shareEncryptedBackup(Uint8List bytes) async =>
      'letter-backup.letter';

  @override
  Future<String> saveEncryptedBackupLocally(Uint8List bytes) async =>
      '/tmp/letter-backup.letter';

  @override
  String get exportLocationDescription =>
      'The backup file is saved in the app documents folder.';
}
