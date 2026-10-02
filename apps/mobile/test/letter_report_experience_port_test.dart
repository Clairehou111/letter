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
import 'package:letter_mobile/features/entitlement/data/local_entitlement_repository.dart';
import 'package:letter_mobile/features/entitlement/data/revenue_cat_entitlement_repository.dart';
import 'package:letter_mobile/features/entitlement/domain/entitlement.dart';
import 'package:letter_mobile/features/entitlement/domain/entitlement_repository.dart';
import 'package:letter_mobile/features/health_records/data/in_memory_health_record_repository.dart';
import 'package:letter_mobile/features/summary_export/domain/cycle_care_summary.dart';
import 'package:letter_mobile/features/summary_export/domain/cycle_care_pdf.dart';
import 'package:letter_mobile/features/summary_export/domain/local_file_share_adapter.dart';
import 'package:letter_mobile/features/summary_export/presentation/twin_matrix_summary_adapter.dart';

final class _RecordingShareAdapter implements LocalFileShareAdapter {
  _RecordingShareAdapter({
    this.result = const LocalFileShareResult.shared(
      savedPath: '/Letter/report',
    ),
  });

  final LocalFileShareResult result;
  LocalExportFile? file;

  @override
  Future<LocalFileShareResult> share(LocalExportFile value) async {
    file = value;
    return result;
  }
}

final class _OfflineRevenueCatClient implements RevenueCatClient {
  bool offline = false;
  bool active = true;

  @override
  Future<void> configure({
    required String apiKey,
    required String appUserId,
  }) async {}

  @override
  Future<void> clearUser() async {}

  @override
  Future<List<RevenueCatPlanOffer>> loadPlans() async => const [];

  @override
  Future<RevenueCatCustomerState> currentCustomerState() async {
    if (offline) throw StateError('offline');
    return RevenueCatCustomerState(
      hasActiveEntitlement: active,
      hasPurchasedLetterProduct: true,
      productId: 'letter_monthly',
    );
  }

  @override
  Future<RevenueCatCustomerState> purchase(String productId) =>
      currentCustomerState();

  @override
  Future<RevenueCatCustomerState> restore() => currentCustomerState();
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
  final paidEntitlement = LocalEntitlementRepository(
    initial: const EntitlementState(status: EntitlementStatus.activePaid),
  );
  tearDownAll(paidEntitlement.dispose);

  LetterReportExperiencePort port(
    _RecordingShareAdapter share, {
    EntitlementRepository? entitlementRepository,
  }) => LetterReportExperiencePort(
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
    entitlementRepository: entitlementRepository ?? paidEntitlement,
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

  test('paid Plus creates real CSV and Twin Matrix PDF exports', () async {
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

  test(
    'confirmed Plus can export offline, then respects a confirmed lapse',
    () async {
      final client = _OfflineRevenueCatClient();
      final entitlement = RevenueCatEntitlementRepository(
        appUserId: '2c1a7f42-2d87-4ad6-8d89-b6b68b429127',
        appleApiKey: 'apple-key',
        googleApiKey: '',
        store: RevenueCatStore.apple,
        client: client,
      );
      addTearDown(entitlement.dispose);
      await entitlement.refresh();
      client.offline = true;

      final offlineShare = _RecordingShareAdapter();
      final offlineReceipt =
          await port(offlineShare, entitlementRepository: entitlement).export(
            range: const SummaryDateRange(
              start: LocalDate(2026, 7, 1),
              end: LocalDate(2026, 7, 30),
            ),
            selectedNoteIds: const {},
            format: ReportExportFormat.rawCsv,
          );
      expect(offlineReceipt.outcome, ExperienceFileOutcome.shared);
      expect(offlineShare.file, isA<LocalCsvFile>());

      client.offline = false;
      client.active = false;
      final afterLapseShare = _RecordingShareAdapter();
      final afterLapseReceipt =
          await port(
            afterLapseShare,
            entitlementRepository: entitlement,
          ).export(
            range: const SummaryDateRange(
              start: LocalDate(2026, 7, 1),
              end: LocalDate(2026, 7, 30),
            ),
            selectedNoteIds: const {},
            format: ReportExportFormat.rawCsv,
          );
      expect(afterLapseReceipt.outcome, ExperienceFileOutcome.failed);
      expect(afterLapseShare.file, isNull);
    },
  );

  test(
    'preserves the local file across share dismissal and reports native failures honestly',
    () async {
      final cases = <(LocalFileShareResult, ExperienceFileOutcome, String?)>[
        (
          const LocalFileShareResult.savedOnly(
            savedPath: '/Letter/dismissed.csv',
          ),
          ExperienceFileOutcome.savedOnly,
          '/Letter/dismissed.csv',
        ),
        (
          const LocalFileShareResult.unavailable(),
          ExperienceFileOutcome.failed,
          null,
        ),
        (
          const LocalFileShareResult.failed(),
          ExperienceFileOutcome.failed,
          null,
        ),
      ];

      for (final entry in cases) {
        final share = _RecordingShareAdapter(result: entry.$1);
        final receipt = await port(share).export(
          range: const SummaryDateRange(
            start: LocalDate(2026, 7, 1),
            end: LocalDate(2026, 7, 30),
          ),
          selectedNoteIds: const {},
          format: ReportExportFormat.rawCsv,
        );

        expect(receipt.outcome, entry.$2);
        expect(receipt.localPath, entry.$3);
        expect(share.file, isA<LocalCsvFile>());
      }
    },
  );

  test(
    'every file format is blocked before generation without paid Plus',
    () async {
      final freeEntitlement = LocalEntitlementRepository();
      addTearDown(freeEntitlement.dispose);

      for (final format in ReportExportFormat.values) {
        final share = _RecordingShareAdapter();
        final receipt =
            await port(share, entitlementRepository: freeEntitlement).export(
              range: const SummaryDateRange(
                start: LocalDate(2026, 7, 1),
                end: LocalDate(2026, 7, 30),
              ),
              selectedNoteIds: const {},
              format: format,
            );

        expect(
          receipt.outcome,
          ExperienceFileOutcome.failed,
          reason: '$format',
        );
        expect(receipt.message, contains('paid Plus'), reason: '$format');
        expect(share.file, isNull, reason: '$format');
      }
    },
  );
}
