import 'dart:convert';

import '../../care/domain/care_memory.dart';
import 'cycle_care_summary.dart';

final class LocalCsvFile {
  const LocalCsvFile({required this.fileName, required this.bytes});

  final String fileName;
  final List<int> bytes;
}

enum LocalFileShareStatus { shared, unavailable, failed }

final class LocalFileShareResult {
  const LocalFileShareResult._(this.status);

  const LocalFileShareResult.shared() : this._(LocalFileShareStatus.shared);
  const LocalFileShareResult.unavailable()
    : this._(LocalFileShareStatus.unavailable);
  const LocalFileShareResult.failed() : this._(LocalFileShareStatus.failed);

  final LocalFileShareStatus status;
}

/// Platform code owns the actual destination or operating-system share sheet.
/// This boundary deliberately has no network, analytics, or logging behavior.
abstract interface class LocalFileShareAdapter {
  Future<LocalFileShareResult> share(LocalCsvFile file);
}

final class UnavailableLocalFileShareAdapter implements LocalFileShareAdapter {
  const UnavailableLocalFileShareAdapter();

  @override
  Future<LocalFileShareResult> share(LocalCsvFile file) async =>
      const LocalFileShareResult.unavailable();
}

LocalCsvFile buildCycleAndCareCsv(CycleAndCareSummary summary) {
  final rows = <List<String>>[
    [
      'section',
      'date',
      'cycle_day',
      'item',
      'severity_score',
      'pain_rating',
      'pain_locations',
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
      'Cycle and Care Summary',
      '',
      '',
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
      'Privacy boundary',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      CycleAndCareSummary.exclusionDisclosure,
      '',
    ],
    for (final day in summary.periodDays)
      [
        'Observed period day',
        summaryDateLabel(day.date),
        '',
        'Period day',
        '',
        '',
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
        'Cycle prediction range',
        '',
        '',
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
        row.cycleDay?.toString() ?? 'Not available',
        row.symptom.label,
        '${row.severity.score}/6',
        row.painRating?.toString() ?? 'Not recorded',
        _labels(row.painLocations.map((item) => item.label)),
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
        row.cycleDay?.toString() ?? 'Not available',
        row.actionLabel,
        '',
        '',
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
        note.label,
        '',
        '',
        '',
        '',
        '',
        'User-selected note',
        note.sourceLabel,
        note.text,
        '',
      ],
    for (final missing in summary.missingness)
      ['Missingness', '', '', '', '', '', '', '', '', '', '', '', missing],
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
