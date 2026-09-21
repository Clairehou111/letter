import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/local_export/domain/letter_local_export_store.dart';
import 'package:path/path.dart' as path;

void main() {
  test('reports and backups share the dedicated letter folder', () async {
    final documents = await Directory.systemTemp.createTemp(
      'letter-local-export-',
    );
    addTearDown(() => documents.delete(recursive: true));
    final store = LetterLocalExportStore(documentsDirectory: documents);

    final reportPath = await store.save(
      fileName: 'letter-report.pdf',
      bytes: const [1, 2, 3],
    );
    final backupPath = await store.save(
      fileName: 'letter-backup.letter',
      bytes: const [4, 5, 6],
    );
    final expectedFolder = path.join(
      documents.path,
      letterLocalExportFolderName,
    );

    expect(letterLocalExportFolderName, 'letter');
    expect(path.dirname(reportPath), expectedFolder);
    expect(path.dirname(backupPath), expectedFolder);
    expect(await File(reportPath).readAsBytes(), const [1, 2, 3]);
    expect(await File(backupPath).readAsBytes(), const [4, 5, 6]);
  });
}
