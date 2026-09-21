import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/experience/experience_release_ports.dart';
import 'package:letter_mobile/experience/reports/letter_report_experience_port.dart';
import 'package:letter_mobile/features/care/data/in_memory_care_memory_repository.dart';
import 'package:letter_mobile/features/care/domain/care_memory.dart';
import 'package:letter_mobile/features/care/domain/care_mode.dart';
import 'package:letter_mobile/features/capture/domain/capture_models.dart';
import 'package:letter_mobile/features/check_in/data/in_memory_moment_check_in_repository.dart';
import 'package:letter_mobile/features/check_in/domain/moment_check_in.dart';
import 'package:letter_mobile/features/cycle/data/in_memory_period_repository.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/cycle/domain/period_record.dart';
import 'package:letter_mobile/features/health_records/data/in_memory_health_record_repository.dart';
import 'package:letter_mobile/features/summary_export/domain/cycle_care_summary.dart';
import 'package:letter_mobile/features/summary_export/domain/cycle_care_pdf.dart';
import 'package:letter_mobile/features/summary_export/domain/local_file_share_adapter.dart';
import 'package:letter_mobile/features/summary_export/presentation/twin_matrix_summary_adapter.dart';

final class _RecordingShareAdapter implements LocalFileShareAdapter {
  LocalExportFile? file;

  @override
  Future<LocalFileShareResult> share(LocalExportFile value) async {
    file = value;
    return const LocalFileShareResult.shared(savedPath: '/Letter/report');
  }
}

PeriodRecord _period(String id, LocalDate start, {LocalDate? end}) =>
    PeriodRecord(
      id: id,
      startDate: start,
      endDate: end,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 7, 30, 12);

  LetterReportExperiencePort port(_RecordingShareAdapter share) =>
      LetterReportExperiencePort(
        periodRepository: InMemoryPeriodRepository(
          seed: [
            _period(
              'closed',
              const LocalDate(2026, 7, 1),
              end: const LocalDate(2026, 7, 5),
            ),
            _period('open', const LocalDate(2026, 7, 29)),
          ],
        ),
        careMemoryRepository: InMemoryCareMemoryRepository(
          records: [
            CareRecord(
              id: 'warmth-before-period',
              mode: CareMode.physical,
              actionId: 'warmth',
              actionLabel: 'Apply warmth',
              outcome: CareOutcome.better,
              occurredAt: DateTime.utc(2026, 7, 28, 10),
              createdAt: DateTime.utc(2026, 7, 28, 10),
              updatedAt: DateTime.utc(2026, 7, 28, 10),
              pinned: false,
            ),
          ],
        ),
        healthRecordRepository: InMemoryHealthRecordRepository(),
        momentCheckInRepository: InMemoryMomentCheckInRepository(
          seed: [
            MomentCheckIn(
              id: 'anxious-before-period',
              state: MomentCheckInState.anxious,
              occurredAt: DateTime.utc(2026, 7, 28, 9),
              createdAt: DateTime.utc(2026, 7, 28, 9),
            ),
            MomentCheckIn(
              id: 'calm-during-period',
              state: MomentCheckInState.calm,
              occurredAt: DateTime.utc(2026, 7, 30, 9),
              createdAt: DateTime.utc(2026, 7, 30, 9),
            ),
          ],
        ),
        captureNoteStore: InMemoryCaptureNoteStore(),
        fileShareAdapter: share,
        now: () => now,
      );

  test(
    'uses recorded period ranges even when no daily flow was entered',
    () async {
      final input = await port(_RecordingShareAdapter()).load();

      expect(input.periodDays.map((day) => day.date), const [
        LocalDate(2026, 7, 1),
        LocalDate(2026, 7, 2),
        LocalDate(2026, 7, 3),
        LocalDate(2026, 7, 4),
        LocalDate(2026, 7, 5),
        LocalDate(2026, 7, 29),
        LocalDate(2026, 7, 30),
      ]);
      expect(input.checkIns, hasLength(2));
    },
  );

  test('creates real CSV and Twin Matrix PDF exports', () async {
    final csvShare = _RecordingShareAdapter();
    final csvReceipt = await port(csvShare).export(
      range: const SummaryDateRange(
        start: LocalDate(2026, 7, 1),
        end: LocalDate(2026, 7, 30),
      ),
      selectedNoteIds: const {},
      format: ReportExportFormat.csv,
    );
    expect(csvReceipt.outcome, ExperienceFileOutcome.shared);
    expect(csvReceipt.localPath, '/Letter/report');
    expect(csvShare.file, isA<LocalCsvFile>());
    expect(
      utf8.decode(csvShare.file!.bytes),
      contains('Observed period dates (5 days)'),
    );
    expect(utf8.decode(csvShare.file!.bytes), contains('Today check-in'));
    expect(utf8.decode(csvShare.file!.bytes), contains('Anxious'));
    expect(utf8.decode(csvShare.file!.bytes), contains('Apply warmth'));
    expect(utf8.decode(csvShare.file!.bytes), contains('Better'));

    final input = await port(_RecordingShareAdapter()).load();
    final summary = buildCycleAndCareSummary(
      input: input,
      range: const SummaryDateRange(
        start: LocalDate(2026, 7, 1),
        end: LocalDate(2026, 7, 30),
      ),
      selectedNoteIds: const {},
    );
    final directPdf = await buildCycleAndCarePdf(
      summary: summary,
      matrix: TwinMatrixSummaryAdapter.fromSummary(
        summary: summary,
        exportTimestamp: '2026-07-30',
      ),
      generatedAt: '2026-07-30',
    );
    expect(utf8.decode(directPdf.bytes.take(4).toList()), '%PDF');
    final matrix = TwinMatrixSummaryAdapter.fromSummary(
      summary: summary,
      exportTimestamp: '2026-07-30',
    );
    expect(matrix.totalObservations, 0);
    expect(matrix.qualitativeCheckIns, hasLength(1));
    expect(matrix.qualitativeCheckIns.single.state, MomentCheckInState.anxious);
    expect(matrix.careOutcomes, hasLength(1));
    expect(matrix.careOutcomes.single.outcome, CareOutcome.better);
    expect(matrix.careOutcomes.single.daysBeforeMenses, -1);

    final pdfShare = _RecordingShareAdapter();
    final pdfReceipt = await port(pdfShare).export(
      range: const SummaryDateRange(
        start: LocalDate(2026, 7, 1),
        end: LocalDate(2026, 7, 30),
      ),
      selectedNoteIds: const {},
      format: ReportExportFormat.pdf,
    );
    expect(pdfReceipt.outcome, ExperienceFileOutcome.shared);
    expect(pdfShare.file, isA<LocalPdfFile>());
    expect(utf8.decode(pdfShare.file!.bytes.take(4).toList()), '%PDF');
  });
}
