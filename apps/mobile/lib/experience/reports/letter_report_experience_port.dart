import '../../features/care/domain/care_memory_repository.dart';
import '../../features/capture/domain/capture_models.dart';
import '../../features/check_in/domain/moment_check_in_repository.dart';
import '../../features/cycle/domain/cycle_prediction.dart';
import '../../features/cycle/domain/bleeding_flow.dart';
import '../../features/cycle/domain/local_date.dart';
import '../../features/cycle/domain/period_record.dart';
import '../../features/cycle/domain/period_repository.dart';
import '../../features/comfort_window/domain/comfort_window_engine.dart';
import '../../features/entitlement/domain/entitlement.dart';
import '../../features/entitlement/domain/entitlement_repository.dart';
import '../../features/health_data/domain/local_health_read_transaction.dart';
import '../../features/health_records/domain/health_record_repository.dart';
import '../../features/patterns/domain/pattern_source.dart';
import '../../features/patterns/domain/personal_pattern_engine.dart';
import '../../features/summary_export/domain/cycle_care_pdf.dart';
import '../../features/summary_export/domain/visit_summary_pdf.dart';
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
    required this.entitlementRepository,
    this.fileShareAdapter = const SystemLocalFileShareAdapter(),
    this.readTransaction = const PassthroughLocalHealthReadTransaction(),
    this.now,
  });

  final PeriodRepository periodRepository;
  final CareMemoryRepository careMemoryRepository;
  final HealthRecordRepository healthRecordRepository;
  final MomentCheckInRepository momentCheckInRepository;
  final CaptureNoteStore captureNoteStore;
  final EntitlementRepository entitlementRepository;
  final LocalFileShareAdapter fileShareAdapter;
  final LocalHealthReadTransaction readTransaction;
  final DateTime Function()? now;

  DateTime _now() => now?.call() ?? DateTime.now();

  @override
  Future<SummaryExportInput> load() => readTransaction.run(_load);

  Future<SummaryExportInput> _load() async {
    final today = LocalDate.fromDateTime(_now().toLocal());
    final periods = await periodRepository.getAll();
    final flowDays = await periodRepository.getAllFlowDays();
    final healthRecords = await healthRecordRepository.getAll();
    final checkIns = await momentCheckInRepository.getAll();
    final careRecords = await careMemoryRepository.getRecords();
    final notes = await captureNoteStore.getAll();
    final prediction = CyclePredictionEngine.calculate(
      CyclePredictionEngine.recordsThrough(periods, today),
    );
    return SummaryExportInput(
      periodDays: _periodDays(periods, flowDays: flowDays, through: today),
      predictions: prediction == null
          ? const <SummaryPredictionRange>[]
          : <SummaryPredictionRange>[
              SummaryPredictionRange(
                start: prediction.predictedMensesStart,
                end: prediction.predictedMensesEnd,
                sourceLabel:
                    'Calendar estimate · ${prediction.intervalCount} recorded ${prediction.intervalCount == 1 ? 'cycle' : 'cycles'}',
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
              label: 'Quick note',
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
      // This is the authoritative generation boundary. Refresh immediately
      // before reading report data or building bytes so an entitlement that
      // lapses while Reports remains open cannot use an earlier UI snapshot.
      // A no-card Preview never reaches this repository-backed paid state.
      final entitlement = await entitlementRepository.refresh();
      if (!entitlement.canUse(LetterCapability.clinicianReports)) {
        return const ExperienceFileReceipt(
          outcome: ExperienceFileOutcome.failed,
          message:
              'A current paid Plus entitlement is required to generate report files.',
        );
      }
      final summary = buildCycleAndCareSummary(
        input: await load(),
        range: range,
        selectedNoteIds: selectedNoteIds,
      );
      final evidence =
          format == ReportExportFormat.patternReportPdf ||
              format == ReportExportFormat.pdf
          ? await _patternEvidence(range)
          : const PatternReportEvidence();
      final file = switch (format) {
        ReportExportFormat.csv ||
        ReportExportFormat.rawCsv => buildCycleAndCareCsv(summary),
        ReportExportFormat.visitSummaryPdf => await buildVisitSummaryPdf(
          summary: summary,
          generatedAt: _dateStamp(_now().toLocal()),
        ),
        ReportExportFormat.pdf ||
        ReportExportFormat.patternReportPdf => await buildCycleAndCarePdf(
          summary: summary,
          matrix: TwinMatrixSummaryAdapter.fromSummary(
            summary: summary,
            exportTimestamp: _dateStamp(_now().toLocal()),
          ),
          generatedAt: _dateStamp(_now().toLocal()),
          evidence: evidence,
        ),
      };
      final share = await fileShareAdapter.share(file);
      return switch (share.status) {
        LocalFileShareStatus.shared => ExperienceFileReceipt(
          outcome: ExperienceFileOutcome.shared,
          localPath: share.savedPath,
        ),
        LocalFileShareStatus.savedOnly => ExperienceFileReceipt(
          outcome: ExperienceFileOutcome.savedOnly,
          localPath: share.savedPath,
          message: 'Saved on this device. Sharing was not confirmed.',
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

  Future<PatternReportEvidence> _patternEvidence(SummaryDateRange range) async {
    final allCare = await careMemoryRepository.getRecords();
    final care = allCare
        .where((record) {
          return range.contains(
            LocalDate.fromDateTime(record.occurredAt.toLocal()),
          );
        })
        .toList(growable: false);
    final careIds = care.map((record) => record.id).toSet();
    final snapshot = PatternSourceSnapshot(
      healthRecords: (await healthRecordRepository.getAll())
          .where((record) => range.contains(record.experiencedDate))
          .toList(growable: false),
      careRecords: care,
      careReflections: (await careMemoryRepository.getReflections())
          .where((reflection) => careIds.contains(reflection.careRecordId))
          .toList(growable: false),
      periods: (await periodRepository.getAll())
          .where((period) {
            return !period.startDate.isAfter(range.end) &&
                (period.endDate == null ||
                    !period.endDate!.isBefore(range.start));
          })
          .toList(growable: false),
      flowDays: (await periodRepository.getAllFlowDays())
          .where((flow) => range.contains(flow.date))
          .toList(growable: false),
      momentCheckIns: (await momentCheckInRepository.getAll())
          .where((checkIn) {
            return range.contains(
              LocalDate.fromDateTime(checkIn.occurredAt.toLocal()),
            );
          })
          .toList(growable: false),
    ).through(range.end);
    final prediction = CyclePredictionEngine.calculate(
      CyclePredictionEngine.recordsThrough(snapshot.periods, range.end),
    );
    final comfort = const ComfortWindowEngine().calculate(
      source: snapshot,
      periodPrediction: prediction,
      today: range.end,
    );
    final analysis = const PersonalPatternEngine().analyze(snapshot);
    return PatternReportEvidence(
      comfortWindow: comfort,
      supportActions: analysis.supportActions,
    );
  }
}

List<SummaryPeriodDay> _periodDays(
  Iterable<PeriodRecord> records, {
  required Iterable<BleedingDayRecord> flowDays,
  required LocalDate through,
}) {
  final flowByDay = <int, BleedingFlow>{
    for (final flow in flowDays) flow.date.epochDay: flow.flow,
  };
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
      byDay[epochDay] = SummaryPeriodDay(date, flow: flowByDay[date.epochDay]);
    }
  }
  final days = byDay.values.toList()
    ..sort((left, right) => left.date.compareTo(right.date));
  return List.unmodifiable(days);
}

String _dateStamp(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
