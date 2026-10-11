import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/experience/experience_release_ports.dart';
import 'package:letter_mobile/experience/reports/letter_report_experience_port.dart';
import 'package:letter_mobile/features/entitlement/data/local_entitlement_repository.dart';
import 'package:letter_mobile/features/entitlement/domain/entitlement.dart';
import 'package:letter_mobile/features/care/data/in_memory_care_memory_repository.dart';
import 'package:letter_mobile/features/capture/domain/capture_models.dart';
import 'package:letter_mobile/features/check_in/data/in_memory_moment_check_in_repository.dart';
import 'package:letter_mobile/features/check_in/domain/moment_check_in.dart';
import 'package:letter_mobile/features/cycle/data/in_memory_period_repository.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/health_records/data/in_memory_health_record_repository.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';
import 'package:letter_mobile/features/summary_export/domain/cycle_care_summary.dart';
import 'package:letter_mobile/features/summary_export/domain/local_file_share_adapter.dart';
import 'package:letter_mobile/features/summary_export/domain/record_report_selection.dart';
import 'package:letter_mobile/features/summary_export/domain/record_report_sources.dart';
import 'package:letter_mobile/features/summary_export/domain/record_source_export.dart';

const _day = LocalDate(2026, 10, 8);
const _today = LocalDate(2026, 10, 9);
final _created = DateTime.utc(2026, 10, 8, 12);
final _updated = DateTime.utc(2026, 10, 9, 12);
const _range = SummaryDateRange(start: _day, end: _today);
const _emptyInput = SummaryExportInput(
  periodDays: [],
  predictions: [],
  healthRecords: [],
  checkIns: [],
  careRecords: [],
  notes: [],
);

MomentCheckIn _moment({bool legacy = false}) => MomentCheckIn(
  id: 'fictional-moment',
  state: MomentCheckInState.calm,
  occurredAt: _created,
  createdAt: _created,
  experiencedDate: legacy ? null : _day,
  provenance: legacy
      ? HealthRecordProvenance.timingUnknown
      : HealthRecordProvenance.sameDay,
  writeZoneOffsetMinutes: legacy ? null : 120,
  writeZoneName: legacy ? null : 'Europe/Berlin',
);

RecordReportSnapshot _snapshot(MomentCheckIn moment) => RecordReportSnapshot(
  summaryInput: _emptyInput,
  sources: recordReportSources(
    today: _today,
    periods: const [],
    health: const [],
    moments: [moment],
    care: const [],
    notes: const [],
    reflections: const [],
    cycleLetters: const [],
  ),
);

void main() {
  test(
    'corrected Moment exports active timing and zone separately from original metadata',
    () {
      final corrected = MomentCheckIn(
        id: 'fictional-moment',
        state: MomentCheckInState.low,
        occurredAt: _created,
        createdAt: _created,
        updatedAt: _updated,
        experiencedDate: _day,
        provenance: HealthRecordProvenance.laterRecall,
        originalProvenance: HealthRecordProvenance.sameDay,
        writeZoneOffsetMinutes: 120,
        writeZoneName: 'Europe/Berlin',
        updatedZoneOffsetMinutes: -420,
        updatedZoneName: 'America/Los_Angeles',
      );
      final preview = projectRecordReport(
        _snapshot(corrected),
        RecordReportSelection(range: _range),
      );
      final row = preview.rows.single;
      expect(row.id, 'fictional-moment');
      expect(row.date, _day);
      expect(row.fields['state'], 'low');
      expect(row.fields['recorded_at_utc'], _created.toIso8601String());
      expect(row.fields['occurred_at_utc'], _created.toIso8601String());
      expect(row.fields['updated_at_utc'], _updated.toIso8601String());
      expect(row.fields['timing'], 'later_recall');
      expect(row.fields['original_timing'], 'same_day');
      expect(row.fields['write_zone'], 'America/Los_Angeles');
      expect(row.fields['utc_offset_minutes'], '-420');
      expect(row.fields['original_write_zone'], 'Europe/Berlin');
      expect(row.fields['original_utc_offset_minutes'], '120');
      final csv = utf8.decode(buildRecordSourceCsv(preview).bytes);
      expect(csv, contains('America/Los_Angeles'));
      expect(csv, contains('Europe/Berlin'));
    },
  );

  test(
    'legacy correction retains date unknown and never fabricates original write zone',
    () async {
      final repository = InMemoryMomentCheckInRepository(
        seed: [_moment(legacy: true)],
        clock: () => _updated,
      );
      final corrected = await repository.update(
        'fictional-moment',
        MomentCheckInState.low,
      );
      final snapshot = _snapshot(corrected);
      expect(
        projectRecordReport(
          snapshot,
          RecordReportSelection(range: _range),
        ).rows,
        isEmpty,
      );
      final all = projectRecordReport(
        snapshot,
        RecordReportSelection(range: _range, allRecords: true),
      );
      final row = all.rows.single;
      expect(row.date, isNull);
      expect(row.fields['timing'], 'timing_unknown');
      expect(row.fields['original_timing'], 'timing_unknown');
      expect(row.fields['updated_at_utc'], _updated.toIso8601String());
      expect(row.fields['write_zone'], corrected.updatedZoneName);
      expect(row.fields, isNot(contains('original_write_zone')));
      expect(row.fields, isNot(contains('original_utc_offset_minutes')));
    },
  );

  test(
    'same-ID Moment correction invalidates the reviewed native export before file handoff',
    () async {
      final repository = InMemoryMomentCheckInRepository(
        seed: [_moment()],
        clock: () => _updated,
      );
      final share = _Share();
      final port = LetterReportExperiencePort(
        periodRepository: InMemoryPeriodRepository(),
        careMemoryRepository: InMemoryCareMemoryRepository(),
        healthRecordRepository: InMemoryHealthRecordRepository(),
        momentCheckInRepository: repository,
        captureNoteStore: InMemoryCaptureNoteStore(),
        entitlementRepository: LocalEntitlementRepository(
          initial: const EntitlementState(status: EntitlementStatus.activePaid),
        ),
        fileShareAdapter: share,
        now: () => _updated,
        hasPlus: () => false,
      );
      final reviewed = projectRecordReport(
        await port.loadRecordSources(),
        RecordReportSelection(range: _range),
      );
      await repository.update('fictional-moment', MomentCheckInState.low);
      final refreshed = projectRecordReport(
        await port.loadRecordSources(),
        reviewed.selection,
      );
      expect(refreshed.rows.single.id, reviewed.rows.single.id);
      expect(refreshed.contentEvidence, isNot(reviewed.contentEvidence));
      final stale = await port.exportSelected(
        preview: reviewed,
        format: ReportExportFormat.csv,
        hasPlus: false,
      );
      expect(stale.outcome, ExperienceFileOutcome.failed);
      expect(stale.message, contains('Refresh the preview'));
      expect(share.files, isEmpty);
      final fresh = await port.exportSelected(
        preview: refreshed,
        format: ReportExportFormat.csv,
        hasPlus: false,
      );
      expect(fresh.outcome, ExperienceFileOutcome.shared);
      expect(share.files, hasLength(1));
      expect(utf8.decode(share.files.single.bytes), contains('later_recall'));
    },
  );
}

final class _Share implements LocalFileShareAdapter {
  final files = <LocalExportFile>[];
  @override
  Future<LocalFileShareResult> share(LocalExportFile file) async {
    files.add(file);
    return const LocalFileShareResult.shared(
      savedPath: '/fictional/report.csv',
    );
  }
}
