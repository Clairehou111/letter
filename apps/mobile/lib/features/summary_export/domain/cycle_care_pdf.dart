import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';

import '../../clinical/presentation/twin_matrix_view_model.dart';
import 'cycle_care_summary.dart';
import 'local_file_share_adapter.dart';

/// Builds the human-readable report packet from the same snapshot used by the
/// on-screen preview. The separate CSV contains source records only.
Future<LocalPdfFile> buildCycleAndCarePdf({
  required CycleAndCareSummary summary,
  required TwinMatrixViewModel matrix,
  required String generatedAt,
}) async {
  final fontData = await rootBundle.load('assets/fonts/Newsreader.ttf');
  final reportFont = pw.Font.ttf(fontData);
  final document = pw.Document(
    theme: pw.ThemeData.withFont(base: reportFont, bold: reportFont),
  );
  final bodyStyle = pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800);
  final mutedStyle = pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600);
  final headingStyle = pw.TextStyle(
    fontSize: 14,
    fontWeight: pw.FontWeight.bold,
    color: PdfColors.black,
  );

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 30),
      header: (context) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Cyclical Symptom Summary - confirmed observations',
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text('Page ${context.pageNumber}', style: mutedStyle),
        ],
      ),
      footer: (context) => pw.Text(
        'Generated $generatedAt - local user-confirmed records - not a diagnosis',
        style: mutedStyle,
      ),
      build: (context) => [
        pw.SizedBox(height: 14),
        pw.Text('Cycle and Care Summary', style: headingStyle),
        pw.SizedBox(height: 4),
        pw.Text(
          '${summary.range.label} - ${matrix.totalObservations} confirmed ratings',
          style: bodyStyle,
        ),
        pw.SizedBox(height: 10),
        _notice(CycleAndCareSummary.nonDiagnosticDisclosure),
        pw.SizedBox(height: 5),
        _notice(CycleAndCareSummary.exclusionDisclosure),
        pw.SizedBox(height: 14),
        pw.Text('Cyclical symptom matrix', style: headingStyle),
        pw.SizedBox(height: 5),
        _matrixTable(matrix),
        pw.SizedBox(height: 5),
        pw.Text(
          'Blank cells mean no observation. Explicit zero ratings remain zero. '
          'Populated cells average observations within each cycle first, then '
          'average across cycles. The optional CSV contains source records only; derived matrix cells appear only in this PDF.',
          style: mutedStyle,
        ),
        pw.SizedBox(height: 14),
        pw.Text('Observed period and predictions', style: headingStyle),
        pw.SizedBox(height: 5),
        _periodTable(summary, bodyStyle),
        pw.SizedBox(height: 14),
        pw.Text('Confirmed health records', style: headingStyle),
        pw.SizedBox(height: 5),
        _healthTable(summary, bodyStyle),
        pw.SizedBox(height: 14),
        pw.Text('Care events and selected notes', style: headingStyle),
        pw.SizedBox(height: 5),
        _careTable(summary, bodyStyle),
        if (summary.notes.isNotEmpty) ...[
          pw.SizedBox(height: 7),
          pw.Text('Selected notes', style: pw.TextStyle(fontSize: 9)),
          for (final note in summary.notes)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 3),
              child: pw.Text(
                '${summaryDateLabel(note.date)} - ${note.label}: ${note.text}',
                style: bodyStyle,
              ),
            ),
        ],
        pw.SizedBox(height: 14),
        pw.Text('Missing or not included', style: headingStyle),
        pw.SizedBox(height: 5),
        if (summary.missingness.isEmpty)
          pw.Text(
            'No missing sections within the selected report range.',
            style: bodyStyle,
          )
        else
          for (final value in summary.missingness)
            pw.Text('- $value', style: bodyStyle),
      ],
    ),
  );

  return LocalPdfFile(
    fileName:
        'letter-cycle-care-summary-${summary.range.start}-${summary.range.end}.pdf',
    bytes: await document.save(),
  );
}

pw.Widget _notice(String text) => pw.Container(
  padding: const pw.EdgeInsets.all(8),
  decoration: pw.BoxDecoration(
    color: PdfColors.blue50,
    border: pw.Border(left: pw.BorderSide(color: PdfColors.blueGrey, width: 2)),
  ),
  child: pw.Text(
    text,
    style: pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
  ),
);

pw.Widget _matrixTable(TwinMatrixViewModel matrix) {
  final headers = <String>[
    'Group',
    ...[
      for (var day = -14; day <= -1; day++) '$day',
      for (var day = 1; day <= 14; day++) '$day',
    ],
  ];
  final rows = [
    for (final cluster in matrix.clusters)
      [
        cluster.label,
        ...[
          for (final cell in [...cluster.lutealCells, ...cluster.cycleCells])
            _cellText(cell),
        ],
      ],
  ];
  return pw.TableHelper.fromTextArray(
    headers: headers,
    data: rows,
    headerStyle: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold),
    cellStyle: const pw.TextStyle(fontSize: 6),
    headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
    cellAlignments: {
      for (var index = 0; index < headers.length; index++)
        index: index == 0 ? pw.Alignment.centerLeft : pw.Alignment.center,
    },
  );
}

String _cellText(TwinMatrixCell cell) {
  final value = cell.severity;
  if (value == null) return '';
  return value <= 0 ? '0' : value.toStringAsFixed(1);
}

pw.Widget _periodTable(CycleAndCareSummary summary, pw.TextStyle style) {
  final rows = <List<String>>[
    for (final range in observedPeriodRanges(summary.periodDays))
      [
        'Observed period',
        '${summaryDateLabel(range.start)} to ${summaryDateLabel(range.end)}',
        '${range.dayCount} days',
      ],
    for (final prediction in summary.predictions)
      [
        'Prediction range',
        '${summaryDateLabel(prediction.start)} to ${summaryDateLabel(prediction.end)}',
        prediction.sourceLabel,
      ],
  ];
  if (rows.isEmpty) rows.add(['None recorded', '', '']);
  return pw.TableHelper.fromTextArray(
    headers: const ['Type', 'Dates', 'Detail'],
    data: rows,
    headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
    cellStyle: style,
    headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
  );
}

pw.Widget _healthTable(CycleAndCareSummary summary, pw.TextStyle style) {
  final rows = [
    for (final row in summary.healthRows)
      [
        summaryDateLabel(row.date),
        row.symptom.label,
        '${row.severity.score}/6',
        row.cycleDay?.toString() ?? '-',
        _beforePeriodLabel(row.daysBeforeMenses),
        row.provenance.label,
        summaryDateTimeLabel(row.recordedAt),
        row.functionalImpacts.map((impact) => impact.label).join('; '),
      ],
  ];
  if (rows.isEmpty) rows.add(['None recorded', '', '', '', '', '', '', '']);
  return pw.TableHelper.fromTextArray(
    headers: const [
      'Date',
      'Symptom',
      'Score',
      'Cycle day',
      'Before next period',
      'Provenance',
      'Recorded',
      'Functional impact',
    ],
    data: rows,
    headerStyle: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
    cellStyle: style,
    headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
  );
}

String _beforePeriodLabel(int? days) {
  if (days == null) return '-';
  final count = days.abs();
  return '$count day${count == 1 ? '' : 's'} before';
}

pw.Widget _careTable(CycleAndCareSummary summary, pw.TextStyle style) {
  final rows = [
    for (final row in summary.careRows)
      [
        summaryDateLabel(row.date),
        row.actionLabel,
        row.cycleDay?.toString() ?? '-',
        row.outcome.name,
        row.provenance.label,
      ],
  ];
  if (rows.isEmpty) rows.add(['None recorded', '', '', '', '']);
  return pw.TableHelper.fromTextArray(
    headers: const ['Date', 'Action', 'Cycle day', 'Outcome', 'Source'],
    data: rows,
    headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
    cellStyle: style,
    headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
  );
}
