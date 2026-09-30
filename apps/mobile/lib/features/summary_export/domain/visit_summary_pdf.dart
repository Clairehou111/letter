import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'cycle_care_summary.dart';
import 'local_file_share_adapter.dart';

/// Builds the paid factual handoff after the report port verifies live paid
/// entitlement. It intentionally excludes recurrence, ranking, Comfort Window
/// evidence, and any diagnostic interpretation.
Future<LocalPdfFile> buildVisitSummaryPdf({
  required CycleAndCareSummary summary,
  required String generatedAt,
}) async {
  final fontData = await rootBundle.load('assets/fonts/Newsreader.ttf');
  final reportFont = pw.Font.ttf(fontData);
  final document = pw.Document(
    theme: pw.ThemeData.withFont(base: reportFont, bold: reportFont),
  );
  final body = pw.TextStyle(fontSize: 9, color: PdfColors.grey800);
  final muted = pw.TextStyle(fontSize: 8, color: PdfColors.grey600);
  final heading = pw.TextStyle(
    fontSize: 14,
    fontWeight: pw.FontWeight.bold,
    color: PdfColors.black,
  );

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (context) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Letter Within · Visit Summary',
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text('Page ${context.pageNumber}', style: muted),
        ],
      ),
      footer: (_) => pw.Text(
        'Generated $generatedAt on this device · not a diagnosis',
        style: muted,
      ),
      build: (_) => [
        pw.SizedBox(height: 16),
        pw.Text('Visit Summary', style: heading),
        pw.SizedBox(height: 4),
        pw.Text(summary.range.label, style: body),
        pw.SizedBox(height: 10),
        _notice(CycleAndCareSummary.nonDiagnosticDisclosure),
        pw.SizedBox(height: 16),
        pw.Text('Recorded period days and flow', style: heading),
        pw.SizedBox(height: 6),
        _periodDays(summary, body),
        pw.SizedBox(height: 16),
        pw.Text('Confirmed symptoms', style: heading),
        pw.SizedBox(height: 6),
        _symptoms(summary, body),
        pw.SizedBox(height: 16),
        pw.Text('Selected notes', style: heading),
        pw.SizedBox(height: 6),
        if (summary.notes.isEmpty)
          pw.Text('No notes selected.', style: body)
        else
          for (final note in summary.notes)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Text(
                '${summaryDateLabel(note.date)} · ${note.label}: ${note.text}',
                style: body,
              ),
            ),
        pw.SizedBox(height: 16),
        pw.Text('Missing or not included', style: heading),
        pw.SizedBox(height: 6),
        if (summary.missingness.isEmpty)
          pw.Text('No missing sections in the selected range.', style: body)
        else
          for (final item in summary.missingness)
            pw.Text('• $item', style: body),
        pw.SizedBox(height: 12),
        pw.Text(CycleAndCareSummary.exclusionDisclosure, style: muted),
      ],
    ),
  );

  return LocalPdfFile(
    fileName:
        'letter-visit-summary-${summary.range.start}-${summary.range.end}.pdf',
    bytes: await document.save(),
  );
}

pw.Widget _notice(String text) => pw.Container(
  padding: const pw.EdgeInsets.all(8),
  decoration: pw.BoxDecoration(
    color: PdfColors.grey100,
    border: pw.Border(left: pw.BorderSide(color: PdfColors.grey500, width: 2)),
  ),
  child: pw.Text(text, style: const pw.TextStyle(fontSize: 8)),
);

pw.Widget _periodDays(CycleAndCareSummary summary, pw.TextStyle style) {
  final rows = [
    for (final day in summary.periodDays)
      [summaryDateLabel(day.date), day.flow?.label ?? 'Not recorded'],
  ];
  if (rows.isEmpty) rows.add(['No period days recorded', '']);
  return pw.TableHelper.fromTextArray(
    headers: const ['Date', 'Flow'],
    data: rows,
    headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
    cellStyle: style,
    headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
  );
}

pw.Widget _symptoms(CycleAndCareSummary summary, pw.TextStyle style) {
  final rows = [
    for (final row in summary.healthRows)
      [
        summaryDateLabel(row.date),
        summaryDateTimeLabel(row.recordedAt),
        row.provenance.label,
        row.symptom.label,
        '${row.severity.score}/5',
        row.functionalImpacts.isEmpty
            ? 'Not recorded'
            : row.functionalImpacts.map((item) => item.label).join('; '),
      ],
  ];
  if (rows.isEmpty) {
    rows.add(['No confirmed symptoms', '', '', '', '', '']);
  }
  return pw.TableHelper.fromTextArray(
    headers: const [
      'Experienced',
      'Recorded',
      'Provenance',
      'Symptom',
      'Severity',
      'Impact',
    ],
    data: rows,
    headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
    cellStyle: style,
    headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
  );
}
