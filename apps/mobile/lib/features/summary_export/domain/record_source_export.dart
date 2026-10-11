import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'local_file_share_adapter.dart';
import 'record_report_selection.dart';

final class RecordReportPdfTextException implements Exception {
  const RecordReportPdfTextException();
}

/// The incumbent bundled print font must faithfully represent every selected
/// string. Never silently replace private source text with missing glyphs.
Future<bool> recordReportPdfCanRepresentText(
  RecordReportPreview preview,
) async {
  final font = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Newsreader.ttf'),
  );
  final actual = font.getFont(pw.Context(document: PdfDocument()));
  for (final row in preview.rows) {
    for (final text in [
      row.id,
      row.sourceType,
      ...row.fields.keys,
      ...row.fields.values,
    ]) {
      if (text.runes.any(
        (r) => r != 9 && r != 10 && r != 13 && !actual.isRuneSupported(r),
      )) {
        return false;
      }
    }
  }
  return true;
}

/// Source rows are long-form plaintext, including exact categorical durations.
/// Empty optional fields stay absent; no zero, date, or bucket midpoint is made.
LocalCsvFile buildRecordSourceCsv(RecordReportPreview preview) {
  final lines = <List<String>>[
    [
      'category',
      'source_type',
      'source_id',
      'experienced_date',
      'field',
      'value',
    ],
  ];
  for (final row in preview.rows) {
    final fields = row.fields.keys.toList()..sort();
    if (fields.isEmpty) {
      lines.add([
        row.category.name,
        row.sourceType,
        row.id,
        row.date?.toString() ?? 'Date unknown',
        '',
        '',
      ]);
    }
    for (final field in fields) {
      lines.add([
        row.category.name,
        row.sourceType,
        row.id,
        row.date?.toString() ?? 'Date unknown',
        field,
        row.fields[field]!,
      ]);
    }
  }
  String escape(String value) {
    final neutralized = RegExp(r'^[\x00-\x20]*[=+\-@]').hasMatch(value)
        ? "'$value"
        : value;
    return '"${neutralized.replaceAll('"', '""')}"';
  }

  final text =
      '${lines.map((line) => line.map(escape).join(',')).join('\r\n')}\r\n';
  return LocalCsvFile(
    fileName:
        'letter-source-records-${preview.selection.range.start}-${preview.selection.range.end}.csv',
    bytes: Uint8List.fromList(utf8.encode(text)),
  );
}

/// The factual Visit Summary uses the exact selected source projection.
/// Clinical comparisons remain in the existing independent PDF engine.
Future<LocalPdfFile> buildRecordVisitSummaryPdf(
  RecordReportPreview preview, {
  required String generatedAt,
}) async {
  if (!await recordReportPdfCanRepresentText(preview)) {
    throw const RecordReportPdfTextException();
  }
  final font = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Newsreader.ttf'),
  );
  final document = pw.Document(
    theme: pw.ThemeData.withFont(base: font, bold: font),
  );
  final body = pw.TextStyle(fontSize: 10, color: PdfColors.grey800);
  final small = pw.TextStyle(fontSize: 8, color: PdfColors.grey600);
  final categories = preview.selection.categories.toList()
    ..sort((a, b) => a.index.compareTo(b.index));
  document.addPage(
    pw.MultiPage(
      maxPages: 1000,
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(30),
      header: (context) =>
          pw.Text('Letter · factual Visit Summary', style: small),
      footer: (context) => pw.Text(
        'Generated $generatedAt · Page ${context.pageNumber} · Local source records',
        style: small,
      ),
      build: (context) => [
        pw.SizedBox(height: 12),
        pw.Text('Visit Summary', style: pw.TextStyle(fontSize: 22)),
        pw.Text(
          preview.selection.allRecords
              ? 'All saved source dates · frozen date labels retained'
              : preview.selection.range.label,
          style: body,
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Recorded observations and self-reported experiences. This summary does not diagnose conditions or establish cause and effect. Blank dates and fields mean no included observation; they do not mean absent symptoms.',
          style: body,
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          '${preview.rows.length} selected source entries. Episode and version rows describe a product schedule; only a use row records actual use. Date unknown preserves missing date evidence. An overlapping episode or version keeps its original start date.',
          style: small,
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Included categories: ${categories.map((c) => c.label).join(', ')}.',
          style: small,
        ),
        pw.Text(
          'Excluded categories: ${RecordReportCategory.values.where((c) => !preview.selection.categories.contains(c)).map((c) => c.label).join(', ')}. Drafts, audio, plan forms, forecasts and undeclared categories are excluded.',
          style: small,
        ),
        for (final category in categories) ...[
          pw.SizedBox(height: 12),
          pw.Text(category.label, style: pw.TextStyle(fontSize: 15)),
          pw.Text(
            'Included fields: ${(preview.selection.fieldsFor(category).toList()..sort()).join(', ')}',
            style: small,
          ),
          if (!preview.rows.any((r) => r.category == category))
            pw.Text('No selected source entries in this scope.', style: small),
          for (final row in preview.rows.where(
            (r) => r.category == category,
          )) ...[
            pw.SizedBox(height: 5),
            pw.Text(
              '${row.date ?? 'Date unknown'} · ${row.sourceType} · ${row.id}',
              style: body,
            ),
            for (final field in row.fields.keys.toList()..sort())
              pw.Text('$field: ${row.fields[field]}', style: small),
          ],
        ],
      ],
    ),
  );
  return LocalPdfFile(
    fileName:
        'letter-visit-summary-${preview.selection.range.start}-${preview.selection.range.end}.pdf',
    bytes: await document.save(),
  );
}
