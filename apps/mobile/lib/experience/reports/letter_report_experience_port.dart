import '../../features/care/domain/care_memory.dart';
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
import '../../features/record_hub/domain/record_hub_facts.dart';
import '../../features/record_hub/domain/record_hub_repository.dart';
import '../../features/record_hub/domain/record_interventions.dart';
import '../../features/summary_export/domain/cycle_care_pdf.dart';
import '../../features/summary_export/domain/visit_summary_pdf.dart';
import '../../features/summary_export/domain/cycle_care_summary.dart';
import '../../features/summary_export/domain/local_file_share_adapter.dart';
import '../../features/summary_export/domain/record_report_selection.dart';
import '../../features/summary_export/domain/record_report_sources.dart';
import '../../features/summary_export/domain/record_source_export.dart';
import '../../features/summary_export/presentation/twin_matrix_summary_adapter.dart';
import '../experience_release_ports.dart';

/// Production adapter for the clinician-report route.
///
/// It builds both the on-screen summary and exported files from the same
/// local source records. Period dates deliberately come from [PeriodRecord]
/// rather than optional flow entries: a recorded period remains a recorded
/// period when the person chose not to describe its daily flow.
final class LetterReportExperiencePort
    implements SelectableReportExperiencePort {
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
    this.recordHubRepository,
    this.recordInterventionsRepository,
    this.hasPlus,
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
  final RecordHubRepository? recordHubRepository;
  final RecordInterventionsRepository? recordInterventionsRepository;

  /// Rechecked at the file action. A preview never grants paid access.
  final bool Function()? hasPlus;

  DateTime _now() => now?.call() ?? DateTime.now();

  /// File authority comes from the store, never the no-card in-app Preview.
  /// The optional live callback may further restrict that authority.
  Future<bool> _hasCurrentPaidAccess() async {
    try {
      final state = await entitlementRepository.refresh();
      return state.canUse(LetterCapability.clinicianReports) &&
          (hasPlus?.call() ?? true);
    } on Object {
      return false;
    }
  }

  bool _legacyExportRequiresPlus(
    SummaryDateRange range,
    ReportExportFormat format,
    LocalDate today,
  ) => switch (format) {
    ReportExportFormat.csv || ReportExportFormat.rawCsv => false,
    ReportExportFormat.pdf || ReportExportFormat.patternReportPdf => true,
    ReportExportFormat.visitSummaryPdf =>
      range.start.isBefore(recordReportMonthsBefore(today, 3)) ||
          range.end.isAfter(today),
  };

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
          .where((note) => note.experiencedDate != null)
          .map(
            (note) => SummarySelectableNote(
              id: note.id,
              date: note.experiencedDate!,
              label: 'A note to self',
              text: note.text,
              sourceLabel: 'Private note · local only',
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<RecordReportSnapshot> loadRecordSources() =>
      readTransaction.run(_loadRecordSources);

  Future<RecordReportSnapshot> _loadRecordSources() async {
    final input = await _load();
    final periods = await periodRepository.getAll();
    final notes = await captureNoteStore.getAll();
    final reflections = await careMemoryRepository.getReflections();
    final letters = await careMemoryRepository.getCycleReflections();
    final facts =
        await recordHubRepository?.getAllFacts() ?? <RecordHubDateFacts>[];
    final episodes =
        await recordInterventionsRepository?.getEpisodes(
          includeArchived: true,
        ) ??
        <ProductEpisode>[];
    final uses =
        await recordInterventionsRepository?.getUses() ?? <ProductUseRecord>[];
    final actions =
        await recordInterventionsRepository?.getActions() ??
        <TriedActionRecord>[];
    final checkbacks =
        await recordInterventionsRepository?.getCheckbacks() ??
        <ActionCheckbackRecord>[];
    return RecordReportSnapshot(
      summaryInput: input,
      sources: recordReportSources(
        today: LocalDate.fromDateTime(_now().toLocal()),
        periods: periods,
        health: input.healthRecords,
        moments: input.checkIns,
        care: input.careRecords,
        notes: notes,
        reflections: reflections,
        cycleLetters: letters,
        facts: facts,
        episodes: episodes,
        uses: uses,
        actions: actions,
        checkbacks: checkbacks,
      ),
    );
  }

  @override
  Future<ExperienceFileReceipt> exportSelected({
    required RecordReportPreview preview,
    required ReportExportFormat format,
    required bool hasPlus,
  }) async {
    try {
      final today = LocalDate.fromDateTime(_now().toLocal());
      final selection = preview.selection;
      if (selection.range.end.isAfter(today)) {
        return const ExperienceFileReceipt(
          outcome: ExperienceFileOutcome.failed,
          message: 'Choose a range ending today or earlier.',
        );
      }
      if (recordReportRequiresPlus(selection, format, today) &&
          !await _hasCurrentPaidAccess()) {
        return const ExperienceFileReceipt(
          outcome: ExperienceFileOutcome.failed,
          message:
              'This PDF needs Letter Within Plus. Source CSV and the recent three-month Visit Summary stay free.',
        );
      }
      final snapshot = await loadRecordSources();
      final actual = projectRecordReport(snapshot, selection);
      if (actual.contentEvidence != preview.contentEvidence) {
        return const ExperienceFileReceipt(
          outcome: ExperienceFileOutcome.failed,
          message:
              'Your selected records changed. Refresh the preview before exporting.',
        );
      }
      final LocalExportFile file;
      if (format != ReportExportFormat.csv &&
          format != ReportExportFormat.rawCsv &&
          !await recordReportPdfCanRepresentText(actual)) {
        return const ExperienceFileReceipt(
          outcome: ExperienceFileOutcome.failed,
          message:
              'The PDF font cannot show some selected text accurately. Export source CSV to preserve every character, or change the selected sources.',
        );
      }
      if (format == ReportExportFormat.csv ||
          format == ReportExportFormat.rawCsv) {
        file = buildRecordSourceCsv(actual);
      } else if (selection.kind == RecordReportKind.visitSummary &&
          format != ReportExportFormat.patternReportPdf) {
        file = await buildRecordVisitSummaryPdf(
          actual,
          generatedAt: _dateStamp(_now().toLocal()),
        );
      } else {
        // The clinical engine retains its algorithms. Only confirmed sources
        // selected in the reviewed projection can enter its existing input.
        if (selection.fields.isNotEmpty ||
            !recordReportClinicalCategories.containsAll(selection.categories)) {
          return const ExperienceFileReceipt(
            outcome: ExperienceFileOutcome.failed,
            message:
                'The Clinical PDF uses fixed clinical fields. Use the factual Visit Summary for selected source fields and additional categories.',
          );
        }
        final input = recordReportClinicalInput(snapshot, actual);
        final summary = buildCycleAndCareSummary(
          input: input,
          range: selection.range,
          selectedNoteIds: input.notes.map((n) => n.id).toSet(),
        );
        file = await buildCycleAndCarePdf(
          summary: summary,
          matrix: TwinMatrixSummaryAdapter.fromSummary(
            summary: summary,
            exportTimestamp: _dateStamp(_now().toLocal()),
          ),
          generatedAt: _dateStamp(_now().toLocal()),
          evidence: await _patternEvidence(
            selection.range,
            selectedInput: input,
          ),
        );
      }
      // Local font/file preparation can be asynchronous. Recheck the actual
      // clock and current paid state immediately before durable handoff.
      final saveToday = LocalDate.fromDateTime(_now().toLocal());
      if (selection.range.end.isAfter(saveToday) ||
          (recordReportRequiresPlus(selection, format, saveToday) &&
              !await _hasCurrentPaidAccess())) {
        return const ExperienceFileReceipt(
          outcome: ExperienceFileOutcome.failed,
          message:
              'The date or PDF access changed. Review the current scope before exporting. Source CSV stays free.',
        );
      }
      return _receiptFor(await fileShareAdapter.share(file));
    } on RecordReportPdfTextException {
      return const ExperienceFileReceipt(
        outcome: ExperienceFileOutcome.failed,
        message:
            'The PDF font cannot show some selected text accurately. Export source CSV to preserve every character, or change the selected sources.',
      );
    } catch (_) {
      return const ExperienceFileReceipt(
        outcome: ExperienceFileOutcome.failed,
        message:
            'The export did not finish. Your records are safe on this device.',
      );
    }
  }

  @override
  Future<ExperienceFileReceipt> export({
    required SummaryDateRange range,
    required Set<String> selectedNoteIds,
    required ReportExportFormat format,
  }) async {
    try {
      final today = LocalDate.fromDateTime(_now().toLocal());
      final needsPlus = _legacyExportRequiresPlus(range, format, today);
      if (range.end.isAfter(today) ||
          (needsPlus && !await _hasCurrentPaidAccess())) {
        return const ExperienceFileReceipt(
          outcome: ExperienceFileOutcome.failed,
          message:
              'A current paid Plus entitlement is required for this extended or Clinical PDF. Source CSV and the recent factual Visit Summary stay free.',
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
      // Recheck after asynchronous font preparation, immediately before a
      // new durable file handoff. A lapse never affects a previous file.
      final saveToday = LocalDate.fromDateTime(_now().toLocal());
      if (range.end.isAfter(saveToday) ||
          (_legacyExportRequiresPlus(range, format, saveToday) &&
              !await _hasCurrentPaidAccess())) {
        return const ExperienceFileReceipt(
          outcome: ExperienceFileOutcome.failed,
          message:
              'The date or PDF access changed. Review the scope before exporting. Source CSV stays free.',
        );
      }
      final share = await fileShareAdapter.share(file);
      return _receiptFor(share);
    } catch (_) {
      return const ExperienceFileReceipt(
        outcome: ExperienceFileOutcome.failed,
        message:
            'The export did not finish. Your records are safe on this device.',
      );
    }
  }

  Future<PatternReportEvidence> _patternEvidence(
    SummaryDateRange range, {
    SummaryExportInput? selectedInput,
  }) async {
    final allCare =
        selectedInput?.careRecords ?? await careMemoryRepository.getRecords();
    final care = allCare
        .where((record) {
          return range.contains(
            LocalDate.fromDateTime(record.occurredAt.toLocal()),
          );
        })
        .toList(growable: false);
    final careIds = care.map((record) => record.id).toSet();
    final snapshot = PatternSourceSnapshot(
      healthRecords:
          (selectedInput?.healthRecords ??
                  await healthRecordRepository.getAll())
              .where((record) => range.contains(record.experiencedDate))
              .toList(growable: false),
      careRecords: care,
      careReflections:
          (selectedInput == null
                  ? await careMemoryRepository.getReflections()
                  : const <CareReflection>[])
              .where((reflection) => careIds.contains(reflection.careRecordId))
              .toList(growable: false),
      periods: (await periodRepository.getAll())
          .where((period) {
            return (selectedInput == null ||
                    selectedInput.periodDays.isNotEmpty) &&
                !period.startDate.isAfter(range.end) &&
                (period.endDate == null ||
                    !period.endDate!.isBefore(range.start));
          })
          .toList(growable: false),
      flowDays: (await periodRepository.getAllFlowDays())
          .where((flow) => selectedInput == null && range.contains(flow.date))
          .toList(growable: false),
      momentCheckIns:
          (selectedInput?.checkIns ?? await momentCheckInRepository.getAll())
              .where((checkIn) {
                return range.contains(
                  checkIn.experiencedDate ??
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

ExperienceFileReceipt _receiptFor(
  LocalFileShareResult share,
) => switch (share.status) {
  LocalFileShareStatus.shared => ExperienceFileReceipt(
    outcome: ExperienceFileOutcome.shared,
    localPath: share.savedPath,
  ),
  LocalFileShareStatus.savedOnly => ExperienceFileReceipt(
    outcome: ExperienceFileOutcome.savedOnly,
    localPath: share.savedPath,
    message:
        share.message ?? 'Saved on this device. Sharing was not confirmed.',
  ),
  LocalFileShareStatus.unavailable => const ExperienceFileReceipt(
    outcome: ExperienceFileOutcome.failed,
    message:
        'This device could not open a local export destination. Your records are safe on this device.',
  ),
  LocalFileShareStatus.failed => const ExperienceFileReceipt(
    outcome: ExperienceFileOutcome.failed,
    message: 'The export did not finish. Your records are safe on this device.',
  ),
};

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
