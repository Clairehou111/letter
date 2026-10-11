import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/local_export/domain/letter_local_export_store.dart';
import 'package:letter_mobile/features/summary_export/domain/local_file_share_adapter.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final status in ShareResultStatus.values) {
    test(
      'durable local file precedes native $status and its receipt stays accurate',
      () async {
        final dir = await Directory.systemTemp.createTemp(
          'record-native-export-',
        );
        addTearDown(() => dir.delete(recursive: true));
        var nativeCalls = 0;
        final adapter = SystemLocalFileShareAdapter(
          localStore: LetterLocalExportStore(documentsDirectory: dir),
          nativeShare: (params) async {
            nativeCalls++;
            expect(params.files, hasLength(1));
            expect(params.files!.single.mimeType, 'text/csv');
            expect(await File(params.files!.single.path).readAsBytes(), [
              65,
              66,
              67,
            ]);
            return ShareResult('', status);
          },
        );
        final result = await adapter.share(
          const LocalCsvFile(fileName: 'source.csv', bytes: [65, 66, 67]),
        );
        expect(nativeCalls, 1);
        expect(
          result.status,
          status == ShareResultStatus.success
              ? LocalFileShareStatus.shared
              : LocalFileShareStatus.savedOnly,
        );
        expect(await File(result.savedPath!).readAsBytes(), [65, 66, 67]);
        if (status == ShareResultStatus.unavailable) {
          expect(result.message, contains('could not confirm'));
        }
      },
    );
  }
  test(
    'failed local write never reaches the native sheet or reports success',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'record-export-failure-',
      );
      addTearDown(() => dir.delete(recursive: true));
      final blocker = File('${dir.path}/not-a-directory');
      await blocker.writeAsString('block');
      var called = false;
      final adapter = SystemLocalFileShareAdapter(
        localStore: LetterLocalExportStore(
          documentsDirectory: Directory(blocker.path),
        ),
        nativeShare: (_) async {
          called = true;
          return const ShareResult('', ShareResultStatus.success);
        },
      );
      final result = await adapter.share(
        const LocalPdfFile(fileName: 'report.pdf', bytes: [1]),
      );
      expect(result.status, LocalFileShareStatus.failed);
      expect(called, isFalse);
      expect(result.savedPath, isNull);
    },
  );
  test(
    'native failure preserves the durable file with saved-only feedback',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'record-share-failure-',
      );
      addTearDown(() => dir.delete(recursive: true));
      final adapter = SystemLocalFileShareAdapter(
        localStore: LetterLocalExportStore(documentsDirectory: dir),
        nativeShare: (_) async => throw StateError('native sheet unavailable'),
      );
      final result = await adapter.share(
        const LocalPdfFile(fileName: 'report.pdf', bytes: [1, 2, 3]),
      );
      expect(result.status, LocalFileShareStatus.savedOnly);
      expect(await File(result.savedPath!).readAsBytes(), [1, 2, 3]);
    },
  );
}
