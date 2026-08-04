import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/design_system/letter_theme.dart';
import 'package:letter_mobile/features/summary_export/domain/local_file_share_adapter.dart';
import 'package:letter_mobile/features/summary_export/domain/summary_export_repository.dart';
import 'package:letter_mobile/features/summary_export/presentation/summary_export_screen.dart';

import 'summary_export_domain_test.dart' as fixture;

final class RecordingShareAdapter implements LocalFileShareAdapter {
  LocalExportFile? file;

  @override
  Future<LocalFileShareResult> share(LocalExportFile value) async {
    file = value;
    return const LocalFileShareResult.shared();
  }
}

void main() {
  testWidgets('previews confirmed facts and exports only the selected note', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final adapter = RecordingShareAdapter();
    await tester.pumpWidget(
      MaterialApp(
        theme: LetterTheme.light,
        home: SummaryExportScreen(
          repository: InMemorySummaryExportRepository(
            fixture.summaryExportInput(),
          ),
          fileShareAdapter: adapter,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/summary_export_390x844.png'),
    );

    expect(find.text('Review every included record'), findsOneWidget);
    expect(find.textContaining('does not diagnose PMS'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.textContaining('Cramps'),
      400,
      scrollable: find.byType(Scrollable),
    );
    expect(find.textContaining('Cramps'), findsOneWidget);
    expect(find.textContaining('Anxiety'), findsNothing);

    await tester.scrollUntilVisible(
      find.byKey(const Key('summary-note-note-1')),
      400,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.byKey(const Key('summary-note-note-1')));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const Key('summary-export-csv')),
      400,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.byKey(const Key('summary-export-csv')));
    await tester.pumpAndSettle();

    expect(adapter.file, isNotNull);
    final text = utf8.decode(adapter.file!.bytes);
    expect(text, contains('A quiet room helped.'));
    expect(
      find.text('CSV sent to the local share destination.'),
      findsOneWidget,
    );
  });

  testWidgets('exports the complete clinician PDF packet', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final adapter = RecordingShareAdapter();
    await tester.pumpWidget(
      MaterialApp(
        theme: LetterTheme.light,
        home: SummaryExportScreen(
          repository: InMemorySummaryExportRepository(
            fixture.summaryExportInput(),
          ),
          fileShareAdapter: adapter,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('summary-export-pdf')),
      500,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.byKey(const Key('summary-export-pdf')));
    await tester.pumpAndSettle();

    expect(adapter.file, isA<LocalPdfFile>());
    expect(utf8.decode(adapter.file!.bytes.take(4).toList()), '%PDF');
  });
}
