import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../care/domain/care_memory.dart';
import 'cycle_care_summary.dart';

sealed class LocalExportFile {
  const LocalExportFile({
    required this.fileName,
    required this.bytes,
    required this.mimeType,
  });

  final String fileName;
  final List<int> bytes;
  final String mimeType;
}

final class LocalCsvFile extends LocalExportFile {
  const LocalCsvFile({required super.fileName, required super.bytes})
    : super(mimeType: 'text/csv');
}

final class LocalPdfFile extends LocalExportFile {
  const LocalPdfFile({required super.fileName, required super.bytes})
    : super(mimeType: 'application/pdf');
}

enum LocalFileShareStatus { shared, unavailable, failed }

final class LocalFileShareResult {
  const LocalFileShareResult._(this.status, {this.savedPath});

  const LocalFileShareResult.shared({String? savedPath})
    : this._(LocalFileShareStatus.shared, savedPath: savedPath);
  const LocalFileShareResult.unavailable()
    : this._(LocalFileShareStatus.unavailable);
  const LocalFileShareResult.failed() : this._(LocalFileShareStatus.failed);

  final LocalFileShareStatus status;

  /// On desktop platforms, the absolute path where the file was saved.
  final String? savedPath;
}

/// Platform code owns the actual destination or operating-system share sheet.
/// This boundary deliberately has no network, analytics, or logging behavior.
abstract interface class LocalFileShareAdapter {
  Future<LocalFileShareResult> share(LocalExportFile file);
}

final class UnavailableLocalFileShareAdapter implements LocalFileShareAdapter {
  const UnavailableLocalFileShareAdapter();

  @override
  Future<LocalFileShareResult> share(LocalExportFile file) async =>
      const LocalFileShareResult.unavailable();
}

/// Saves files locally on desktop platforms and uses the operating-system
/// share sheet on iOS and Android.
final class SystemLocalFileShareAdapter implements LocalFileShareAdapter {
  const SystemLocalFileShareAdapter();

  @override
  Future<LocalFileShareResult> share(LocalExportFile file) async {
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        await Share.shareXFiles([
          XFile.fromData(
            Uint8List.fromList(file.bytes),
            name: file.fileName,
            mimeType: file.mimeType,
          ),
        ]);
        return const LocalFileShareResult.shared();
      } on Object {
        return const LocalFileShareResult.failed();
      }
    }
    if (!Platform.isMacOS && !Platform.isWindows && !Platform.isLinux) {
      return const LocalFileShareResult.unavailable();
    }
    try {
      final dir = await getApplicationDocumentsDirectory();
      final output = File('${dir.path}/${file.fileName}');
      await output.writeAsBytes(file.bytes);
      return LocalFileShareResult.shared(savedPath: output.path);
    } on Object {
      return const LocalFileShareResult.failed();
    }
  }
}

@Deprecated('Use SystemLocalFileShareAdapter instead.')
typedef DesktopLocalFileShareAdapter = SystemLocalFileShareAdapter;

LocalCsvFile buildCycleAndCareCsv(CycleAndCareSummary summary) {
  final rows = <List<String>>[
    [
      'section',
      'date',
      'recorded_at',
      'cycle_day',
      'item',
      'severity_score',
      'functional_impact',
      'care_outcome',
      'provenance',
      'source',
      'note',
      'missingness',
    ],
    [
      'Report',
      summary.range.label,
      '',
      '',
      'Cycle and Care Summary',
      '',
      '',
      '',
      '',
      '',
      CycleAndCareSummary.nonDiagnosticDisclosure,
      '',
    ],
    [
      'Report',
      summary.range.label,
      '',
      '',
      'Privacy boundary',
      '',
      '',
      '',
      '',
      '',
      CycleAndCareSummary.exclusionDisclosure,
      '',
    ],
    for (final range in observedPeriodRanges(summary.periodDays))
      [
        'Observed period',
        '${summaryDateLabel(range.start)} to ${summaryDateLabel(range.end)}',
        '',
        '',
        'Observed period dates (${range.dayCount} days)',
        '',
        '',
        '',
        'Observed period date',
        'Saved local period date',
        '',
        '',
      ],
    for (final prediction in summary.predictions)
      [
        'Prediction range',
        '${summaryDateLabel(prediction.start)} to ${summaryDateLabel(prediction.end)}',
        '',
        '',
        'Cycle prediction range',
        '',
        '',
        '',
        'Prediction estimate',
        prediction.sourceLabel,
        '',
        '',
      ],
    for (final row in summary.healthRows)
      [
        'Confirmed health record',
        summaryDateLabel(row.date),
        summaryDateTimeLabel(row.recordedAt),
        row.cycleDay?.toString() ?? 'Not available',
        row.symptom.label,
        '${row.severity.score}/6',
        _labels(row.functionalImpacts.map((item) => item.label)),
        '',
        row.provenance.label,
        row.sourceLabel,
        '',
        '',
      ],
    for (final row in summary.careRows)
      [
        'Care event',
        summaryDateLabel(row.date),
        '',
        row.cycleDay?.toString() ?? 'Not available',
        row.actionLabel,
        '',
        '',
        _outcomeLabel(row.outcome),
        row.provenance.label,
        row.sourceLabel,
        '',
        '',
      ],
    for (final note in summary.notes)
      [
        'User-selected note',
        summaryDateLabel(note.date),
        '',
        '',
        note.label,
        '',
        '',
        '',
        'User-selected note',
        note.sourceLabel,
        note.text,
        '',
      ],
    for (final missing in summary.missingness)
      ['Missingness', '', '', '', '', '', '', '', '', '', '', missing],
  ];
  final text = '${rows.map(_encodeCsvRow).join('\r\n')}\r\n';
  return LocalCsvFile(
    fileName:
        'letter-cycle-care-summary-${summary.range.start}-${summary.range.end}.csv',
    bytes: utf8.encode(text),
  );
}

String _encodeCsvRow(List<String> fields) => fields.map(_escapeCsv).join(',');

String _escapeCsv(String value) {
  final escaped = value.replaceAll('"', '""');
  return '"$escaped"';
}

String _labels(Iterable<String> labels) {
  final values = labels.toList()..sort();
  return values.isEmpty ? 'Not recorded' : values.join('; ');
}

String _outcomeLabel(CareOutcome outcome) => switch (outcome) {
  CareOutcome.better => 'Better',
  CareOutcome.same => 'Same',
  CareOutcome.worse => 'Worse',
};
