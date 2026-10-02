import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';

import 'package:letter_mobile/features/summary_export/domain/local_file_share_adapter.dart';

void main() {
  const savedPath = '/documents/letter/report.pdf';

  test('ordinary successful share reports shared local file', () async {
    final result = await shareSavedFileWithSystem(
      savedPath: savedPath,
      mimeType: 'application/pdf',
      share: (params) async {
        expect(params.files, hasLength(1));
        expect(params.files!.single.path, savedPath);
        return const ShareResult('activity', ShareResultStatus.success);
      },
    );

    expect(result.status, LocalFileShareStatus.shared);
    expect(result.savedPath, savedPath);
  });

  test('dismissed share keeps the saved file available', () async {
    final result = await shareSavedFileWithSystem(
      savedPath: savedPath,
      mimeType: 'application/pdf',
      share: (_) async => const ShareResult('', ShareResultStatus.dismissed),
    );

    expect(result.status, LocalFileShareStatus.savedOnly);
    expect(result.savedPath, savedPath);
  });

  test(
    'a slow successful share still reports success without a timeout',
    () async {
      final pending = Completer<ShareResult>();
      final resultFuture = shareSavedFileWithSystem(
        savedPath: savedPath,
        mimeType: 'application/pdf',
        share: (_) => pending.future,
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      pending.complete(
        const ShareResult('activity', ShareResultStatus.success),
      );

      final result = await resultFuture;
      expect(result.status, LocalFileShareStatus.shared);
      expect(result.savedPath, savedPath);
    },
  );

  test('unanswered native share completion cannot hold export open', () async {
    final pending = Completer<ShareResult>();
    final result = await shareSavedFileWithSystem(
      savedPath: savedPath,
      mimeType: 'application/pdf',
      share: (_) => pending.future,
      resultTimeout: const Duration(milliseconds: 10),
    );

    expect(result.status, LocalFileShareStatus.savedOnly);
    expect(result.savedPath, savedPath);
    pending.complete(const ShareResult('activity', ShareResultStatus.success));
  });
}
