import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/local_backup/domain/local_backup_file_port.dart';

void main() {
  test('exports use the dedicated letter folder and timestamped names', () {
    final name = localBackupExportFileName(
      DateTime(2026, 8, 4, 18, 49, 25, 123),
    );

    expect(localBackupExportFolderName, 'letter');
    expect(name, 'letter-backup-2026-08-04-18-49-25-123.letter');
    expect(name, isNot(contains('health')));
  });
}
