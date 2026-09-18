import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/design_system/letter_theme.dart';
import 'package:letter_mobile/features/summary_export/domain/local_file_share_adapter.dart';
import 'package:letter_mobile/features/summary_export/domain/cycle_care_summary.dart';
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

final class _PendingSummaryRepository implements SummaryExportRepository {
  final completer = Completer<SummaryExportInput>();

  @override
  Future<SummaryExportInput> load() => completer.future;
}

final class _FailingSummaryRepository implements SummaryExportRepository {
  @override
  Future<SummaryExportInput> load() async => throw StateError('read failed');
}

Finder _verticalSummaryScroll() => find
    .byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    )
    .first;

Future<void> _reveal(WidgetTester tester, Finder content) async {
  final scrollable = _verticalSummaryScroll();
  for (var index = 0; index < 10 && content.evaluate().isEmpty; index++) {
    await tester.drag(scrollable, const Offset(0, -500), warnIfMissed: false);
    await tester.pump();
  }
  if (content.evaluate().isEmpty) return;
  await tester.scrollUntilVisible(content, 400, scrollable: scrollable);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('loading retains the Summary back action', (tester) async {
    final repository = _PendingSummaryRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: SummaryExportScreen(
          repository: repository,
          fileShareAdapter: RecordingShareAdapter(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('summary-export-back')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('read failure retains the Summary back action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SummaryExportScreen(
          repository: _FailingSummaryRepository(),
          fileShareAdapter: RecordingShareAdapter(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('summary-export-back')), findsOneWidget);
    expect(find.text('Your summary could not be opened'), findsOneWidget);
  });

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

    expect(find.byKey(const Key('twin-matrix-source-hint')), findsOneWidget);
    expect(
      find.byKey(const Key('twin-matrix-horizontal-scroll')),
      findsNothing,
    );
    expect(find.byKey(const Key('twin-matrix-mobile')), findsOneWidget);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/summary_export_390x844.png'),
    );

    expect(find.text('Review every included record'), findsOneWidget);
    expect(find.textContaining('does not diagnose PMS'), findsOneWidget);

    await _reveal(tester, find.textContaining('Cramps'));
    expect(find.textContaining('Cramps'), findsOneWidget);
    expect(find.textContaining('Anxiety'), findsNothing);

    await _reveal(tester, find.byKey(const Key('summary-note-note-1')));
    await tester.tap(find.byKey(const Key('summary-note-note-1')));
    await tester.pump();
    await _reveal(tester, find.byKey(const Key('summary-export-csv')));
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

    await _reveal(tester, find.byKey(const Key('summary-export-pdf')));
    await tester.tap(find.byKey(const Key('summary-export-pdf')));
    await tester.pumpAndSettle();

    expect(adapter.file, isA<LocalPdfFile>());
    expect(utf8.decode(adapter.file!.bytes.take(4).toList()), '%PDF');
  });

  testWidgets('matrix preview fits 320px at 200 percent text', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: LetterTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 900),
            textScaler: TextScaler.linear(2),
          ),
          child: SummaryExportScreen(
            repository: InMemorySummaryExportRepository(
              fixture.summaryExportInput(),
            ),
            fileShareAdapter: RecordingShareAdapter(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await _reveal(tester, find.byKey(const Key('twin-matrix-mobile')));
    expect(
      find.byKey(const Key('twin-matrix-horizontal-scroll')),
      findsNothing,
    );
    expect(find.byKey(const Key('twin-matrix-mobile')), findsOneWidget);
  });
}
