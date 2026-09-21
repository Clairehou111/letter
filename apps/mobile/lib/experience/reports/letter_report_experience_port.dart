import '../../features/care/domain/care_memory_repository.dart';
import '../../features/capture/domain/capture_models.dart';
import '../../features/check_in/domain/moment_check_in_repository.dart';
import '../../features/cycle/domain/cycle_prediction.dart';
import '../../features/cycle/domain/local_date.dart';
import '../../features/cycle/domain/period_record.dart';
import '../../features/cycle/domain/period_repository.dart';
import '../../features/health_records/domain/health_record_repository.dart';
import '../../features/summary_export/domain/cycle_care_pdf.dart';
import '../../features/summary_export/domain/cycle_care_summary.dart';
import '../../features/summary_export/domain/local_file_share_adapter.dart';
import '../../features/summary_export/presentation/twin_matrix_summary_adapter.dart';
import '../experience_release_ports.dart';

/// Production adapter for the clinician-report route.
///
/// It builds both the on-screen summary and exported files from the same
/// local source records. Period dates deliberately come from [PeriodRecord]
/// rather than optional flow entries: a recorded period remains a recorded
/// period when the person chose not to describe its daily flow.
final class LetterReportExperiencePort implements ReportExperiencePort {
  const LetterReportExperiencePort({
    required this.periodRepository,
    required this.careMemoryRepository,
    required this.healthRecordRepository,
    required this.momentCheckInRepository,
    required this.captureNoteStore,
    this.fileShareAdapter = const SystemLocalFileShareAdapter(),
    this.now,
  });

  final PeriodRepository periodRepository;
  final CareMemoryRepository careMemoryRepository;
  final HealthRecordRepository healthRecordRepository;
  final MomentCheckInRepository momentCheckInRepository;
  final CaptureNoteStore captureNoteStore;
  final LocalFileShareAdapter fileShareAdapter;
  final DateTime Function()? now;

  DateTime _now() => now?.call() ?? DateTime.now();

  @override
  Future<SummaryExportInput> load() async {
    final today = LocalDate.fromDateTime(_now().toLocal());
    final periods = await periodRepository.getAll();
    final healthRecords = await healthRecordRepository.getAll();
    final checkIns = await momentCheckInRepository.getAll();
    final careRecords = await careMemoryRepository.getRecords();
    final notes = await captureNoteStore.getAll();
    final prediction = CyclePredictionEngine.calculate(
      CyclePredictionEngine.recordsThrough(periods, today),
    );
    return SummaryExportInput(
      periodDays: _periodDays(periods, through: today),
      predictions: prediction == null
          ? const <SummaryPredictionRange>[]
          : <SummaryPredictionRange>[
              SummaryPredictionRange(
                start: prediction.predictedMensesStart,
                end: prediction.predictedMensesEnd,
                sourceLabel:
                    'Calendar estimate · ${prediction.confidence.label.toLowerCase()} confidence',
              ),
            ],
      healthRecords: healthRecords,
      checkIns: checkIns,
      careRecords: careRecords,
      notes: notes
          .map(
            (note) => SummarySelectableNote(
              id: note.id,
              date: LocalDate.fromDateTime(note.createdAt.toLocal()),
              label: 'A note to self',
              text: note.text,
              sourceLabel: 'Private note · local only',
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<ExperienceFileReceipt> export({
    required SummaryDateRange range,
    required Set<String> selectedNoteIds,
    required ReportExportFormat format,
  }) async {
    try {
      final summary = buildCycleAndCareSummary(
        input: await load(),
        range: range,
        selectedNoteIds: selectedNoteIds,
      );
      final file = switch (format) {
        ReportExportFormat.csv => buildCycleAndCareCsv(summary),
        ReportExportFormat.pdf => await buildCycleAndCarePdf(
          summary: summary,
          matrix: TwinMatrixSummaryAdapter.fromSummary(
            summary: summary,
            exportTimestamp: _dateStamp(_now().toLocal()),
          ),
          generatedAt: _dateStamp(_now().toLocal()),
        ),
      };
      final share = await fileShareAdapter.share(file);
      return switch (share.status) {
        LocalFileShareStatus.shared => ExperienceFileReceipt(
          outcome: ExperienceFileOutcome.shared,
          localPath: share.savedPath,
        ),
        LocalFileShareStatus.unavailable => const ExperienceFileReceipt(
          outcome: ExperienceFileOutcome.failed,
          message:
              'This device could not open a local export destination. Your records are safe on this device.',
        ),
        LocalFileShareStatus.failed => const ExperienceFileReceipt(
          outcome: ExperienceFileOutcome.failed,
          message:
              'The export did not finish. Your records are safe on this device.',
        ),
      };
    } catch (_) {
      return const ExperienceFileReceipt(
        outcome: ExperienceFileOutcome.failed,
        message:
            'The export did not finish. Your records are safe on this device.',
      );
    }
  }
}

List<SummaryPeriodDay> _periodDays(
  Iterable<PeriodRecord> records, {
  required LocalDate through,
}) {
  final byDay = <int, SummaryPeriodDay>{};
  for (final period in records) {
    if (period.startDate.isAfter(through)) continue;
    final end = period.endDate == null || period.endDate!.isAfter(through)
        ? through
        : period.endDate!;
    for (
      var epochDay = period.startDate.epochDay;
      epochDay <= end.epochDay;
      epochDay += 1
    ) {
      final date = period.startDate.addDays(
        epochDay - period.startDate.epochDay,
      );
      byDay[epochDay] = SummaryPeriodDay(date);
    }
  }
  final days = byDay.values.toList()
    ..sort((left, right) => left.date.compareTo(right.date));
  return List.unmodifiable(days);
}

String _dateStamp(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
