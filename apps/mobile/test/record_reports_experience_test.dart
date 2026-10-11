import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/experience/experience_release_ports.dart';
import 'package:letter_mobile/experience/reports/reports_experience.dart';
import 'package:letter_mobile/experience/theme/experience_foundation.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/summary_export/domain/cycle_care_summary.dart';
import 'package:letter_mobile/features/summary_export/domain/record_report_selection.dart';

const empty = SummaryExportInput(
  periodDays: [],
  predictions: [],
  healthRecords: [],
  checkIns: [],
  careRecords: [],
  notes: [],
);

final class SourcePort implements SelectableReportExperiencePort {
  RecordReportPreview? exported;
  ReportExportFormat? format;
  final rows = <RecordReportSource>[];
  @override
  Future<SummaryExportInput> load() async => empty;
  @override
  Future<RecordReportSnapshot> loadRecordSources() async =>
      RecordReportSnapshot(summaryInput: empty, sources: rows);
  @override
  Future<ExperienceFileReceipt> exportSelected({
    required RecordReportPreview preview,
    required ReportExportFormat format,
    required bool hasPlus,
  }) async {
    exported = preview;
    this.format = format;
    return const ExperienceFileReceipt(
      outcome: ExperienceFileOutcome.shared,
      localPath: '/Letter/report',
    );
  }

  @override
  Future<ExperienceFileReceipt> export({
    required SummaryDateRange range,
    required Set<String> selectedNoteIds,
    required ReportExportFormat format,
  }) async {
    throw StateError(
      'Production source port must use the reviewed projection.',
    );
  }
}

Future<void> reveal(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SavedRhythm.resetSession();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );
  Future<void> pump(
    WidgetTester tester,
    SourcePort port, {
    VoidCallback? onPlus,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ExperienceFoundation.lightTheme(),
        home: ReportsExperience(
          port: port,
          now: () => DateTime(2026, 10, 9, 12),
          onOpenPlus: onPlus,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'zero-cycle reports allow freely selected ranges and export CSV without acquisition',
    (tester) async {
      final port = SourcePort();
      var plus = 0;
      await pump(tester, port, onPlus: () => plus++);
      expect(find.text('Last 6 months'), findsOneWidget);
      await tester.tap(find.text('Last 6 months'));
      await tester.pumpAndSettle();
      expect(plus, 0);
      await reveal(tester, find.text('Export CSV · Free'));
      await tester.tap(find.text('Export CSV · Free'));
      await tester.pumpAndSettle();
      expect(port.format, ReportExportFormat.csv);
      expect(port.exported!.selection.range.start, const LocalDate(2026, 4, 9));
      expect(plus, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'default Visit PDF is free with no cycles and exact calendar range',
    (tester) async {
      final port = SourcePort();
      var plus = 0;
      await pump(tester, port, onPlus: () => plus++);
      await reveal(tester, find.text('Export PDF'));
      await tester.tap(find.text('Export PDF'));
      await tester.pumpAndSettle();
      expect(port.format, ReportExportFormat.pdf);
      expect(port.exported!.selection.kind, RecordReportKind.visitSummary);
      expect(port.exported!.selection.range.start, const LocalDate(2026, 7, 9));
      expect(plus, 0);
    },
  );
  testWidgets(
    'trusted in-app Care completion suppresses acquisition even without a legacy checkback',
    (tester) async {
      final port = SourcePort()
        ..rows.add(
          RecordReportSource(
            id: 'completion',
            category: RecordReportCategory.careActions,
            sourceType: 'tried_action',
            date: const LocalDate(2026, 10, 9),
            fields: {
              'source': 'inAppCare',
              'completion_occurred_at_utc': DateTime(
                2026,
                10,
                9,
                11,
              ).toUtc().toIso8601String(),
            },
          ),
        );
      var plus = 0;
      await pump(tester, port, onPlus: () => plus++);
      await tester.tap(find.text('Last 6 months'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('PDF · Letter Within Plus'));
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'PDF · Letter Within Plus'),
      );
      expect(button.onPressed, isNull);
      expect(plus, 0);
      await tester.tap(find.text('Export CSV · Free'));
      await tester.pumpAndSettle();
      expect(port.format, ReportExportFormat.csv);
      expect(plus, 0);
    },
  );
  testWidgets(
    'sensitive saved sources start excluded and extended PDF gates only the file action',
    (tester) async {
      final port = SourcePort()
        ..rows.add(
          RecordReportSource(
            id: 'bbt-secret',
            category: RecordReportCategory.temperature,
            sourceType: 'manual_bbt',
            date: const LocalDate(2026, 10, 9),
            fields: {'entered_value': '98.6', 'unit': '°F'},
          ),
        );
      var plus = 0;
      await pump(tester, port, onPlus: () => plus++);
      await tester.tap(find.text('Last 6 months'));
      await tester.pumpAndSettle();
      expect(plus, 0);
      final bbt = find.widgetWithText(CheckboxListTile, 'Manual BBT');
      await reveal(tester, bbt);
      expect(tester.widget<CheckboxListTile>(bbt).value, isFalse);
      await reveal(tester, find.text('PDF · Letter Within Plus'));
      await tester.tap(find.text('PDF · Letter Within Plus'));
      await tester.pumpAndSettle();
      expect(plus, 1);
      expect(port.exported, isNull);
      await tester.tap(find.text('Export CSV · Free'));
      await tester.pumpAndSettle();
      expect(port.exported!.rows, isEmpty);
      expect(
        port.exported!.selection.categories.contains(
          RecordReportCategory.temperature,
        ),
        isFalse,
      );
    },
  );
}
