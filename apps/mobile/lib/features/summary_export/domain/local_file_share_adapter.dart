import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../care/domain/care_memory.dart';
import '../../local_export/domain/letter_local_export_store.dart';
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

enum LocalFileShareStatus { shared, savedOnly, unavailable, failed }

final class LocalFileShareResult {
  const LocalFileShareResult._(this.status, {this.savedPath});

  const LocalFileShareResult.shared({String? savedPath})
    : this._(LocalFileShareStatus.shared, savedPath: savedPath);
  const LocalFileShareResult.savedOnly({required String savedPath})
    : this._(LocalFileShareStatus.savedOnly, savedPath: savedPath);
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
  const SystemLocalFileShareAdapter({
    this.localStore = const LetterLocalExportStore(),
  });

  final LetterLocalExportStore localStore;

  @override
  Future<LocalFileShareResult> share(LocalExportFile file) async {
    final isMobile = Platform.isAndroid || Platform.isIOS;
    final isDesktop =
        Platform.isMacOS || Platform.isWindows || Platform.isLinux;
    if (!isMobile && !isDesktop) {
      return const LocalFileShareResult.unavailable();
    }
    String? savedPath;
    try {
      savedPath = await localStore.save(
        fileName: file.fileName,
        bytes: file.bytes,
      );
      if (isMobile) {
        return shareSavedFileWithSystem(
          savedPath: savedPath,
          mimeType: file.mimeType,
          resultTimeout: await _isIOSAppOnMac()
              ? const Duration(seconds: 15)
              : null,
        );
      }
      return LocalFileShareResult.savedOnly(savedPath: savedPath);
    } on Object {
      if (savedPath != null) {
        return LocalFileShareResult.savedOnly(savedPath: savedPath);
      }
      return const LocalFileShareResult.failed();
    }
  }
}

const _platformChannel = MethodChannel('app.letterwithin/platform');

Future<bool> _isIOSAppOnMac() async {
  if (!Platform.isIOS) return false;
  try {
    return await _platformChannel.invokeMethod<bool>('isIOSAppOnMac') ?? false;
  } on Object {
    return false;
  }
}

/// The local copy is already safe when the system sheet opens. On iOS apps
/// running on a Mac, finishing or dismissing a native share action can leave
/// its completion unanswered. Bound that wait so Reports never stays in its export
/// loading state indefinitely; an unconfirmed result only claims local save.
Future<LocalFileShareResult> shareSavedFileWithSystem({
  required String savedPath,
  required String mimeType,
  Future<ShareResult> Function(ShareParams)? share,
  Duration? resultTimeout,
}) async {
  try {
    final sharing = (share ?? SharePlus.instance.share)(
      ShareParams(files: [XFile(savedPath, mimeType: mimeType)]),
    );
    final result = await (resultTimeout == null
        ? sharing
        : sharing.timeout(resultTimeout));
    return result.status == ShareResultStatus.success
        ? LocalFileShareResult.shared(savedPath: savedPath)
        : LocalFileShareResult.savedOnly(savedPath: savedPath);
  } on Object {
    return LocalFileShareResult.savedOnly(savedPath: savedPath);
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
        'Observed period dates (${_dayCount(range.dayCount)})',
        '',
        '',
        '',
        'Observed period date',
        'Saved local period date',
        '',
        '',
      ],
    for (final day in summary.periodDays.where((day) => day.flow != null))
      [
        'Bleeding flow',
        summaryDateLabel(day.date),
        '',
        '',
        day.flow!.label,
        '',
        '',
        '',
        'User-recorded flow',
        'Saved local period day',
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
        '${row.severity.score}/5',
        _labels(row.functionalImpacts.map((item) => item.label)),
        '',
        row.provenance.label,
        row.sourceLabel,
        '',
        '',
      ],
    for (final row in summary.checkInRows)
      [
        'Today check-in',
        summaryDateLabel(row.date),
        summaryDateTimeLabel(row.recordedAt),
        row.cycleDay?.toString() ?? 'Not available',
        row.state.label,
        '',
        '',
        '',
        'Today check-in',
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
  final neutralized = RegExp(r'^[\x00-\x20]*[=+\-@]').hasMatch(value)
      ? "'$value"
      : value;
  final escaped = neutralized.replaceAll('"', '""');
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

String _dayCount(int count) => '$count ${count == 1 ? 'day' : 'days'}';
