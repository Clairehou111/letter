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
import 'package:letter_mobile/features/health_data/domain/local_health_read_transaction.dart';
import 'package:letter_mobile/features/record_hub/domain/record_hub_facts.dart';
import 'package:letter_mobile/features/record_hub/domain/record_interventions.dart';
import 'package:letter_mobile/features/summary_export/domain/cycle_care_summary.dart';
import 'package:letter_mobile/features/summary_export/domain/local_file_share_adapter.dart';
import 'package:letter_mobile/features/summary_export/domain/record_report_selection.dart';
import 'package:letter_mobile/features/summary_export/domain/record_report_sources.dart';
import 'package:letter_mobile/features/summary_export/domain/record_source_export.dart';

const today = LocalDate(2026, 10, 9);
const recent = SummaryDateRange(start: LocalDate(2026, 7, 9), end: today);
RecordFactMetadata metadata(String id, LocalDate date) => RecordFactMetadata(
  id: id,
  experiencedDate: date,
  recordedAt: DateTime.utc(date.year, date.month, date.day, 12),
  updatedAt: DateTime.utc(date.year, date.month, date.day, 12),
  originalProvenance: HealthRecordProvenance.sameDay,
  provenance: HealthRecordProvenance.sameDay,
  originalUtcOffsetMinutes: 540,
  utcOffsetMinutes: 540,
  originalWriteZoneId: 'Asia/Tokyo',
  writeZoneId: 'Asia/Tokyo',
);
const emptySummary = SummaryExportInput(
  periodDays: [],
  predictions: [],
  healthRecords: [],
  checkIns: [],
  careRecords: [],
  notes: [],
);
RecordReportSnapshot snapshot(List<RecordReportSource> rows) =>
    RecordReportSnapshot(summaryInput: emptySummary, sources: rows);
List<RecordReportSource> sources({
  List<CaptureNote> notes = const [],
  List<RecordHubDateFacts> facts = const [],
  List<ProductEpisode> episodes = const [],
  List<ProductUseRecord> uses = const [],
  List<MomentCheckIn> moments = const [],
  List<HealthRecord> records = const [],
}) => recordReportSources(
  today: today,
  periods: const [],
  health: records,
  moments: moments,
  care: const [],
  notes: notes,
  reflections: const [],
  cycleLetters: const [],
  facts: facts,
  episodes: episodes,
  uses: uses,
);

final class RecordingShare implements LocalFileShareAdapter {
  final files = <LocalExportFile>[];
  @override
  Future<LocalFileShareResult> share(LocalExportFile file) async {
    files.add(file);
    return const LocalFileShareResult.shared(
      savedPath: '/Letter/selected-report',
    );
  }
}

final class AfterReadTransaction implements LocalHealthReadTransaction {
  AfterReadTransaction(this.afterRead);
  final void Function() afterRead;
  @override
  Future<T> run<T>(Future<T> Function() read) async {
    final value = await read();
    afterRead();
    return value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'free CSV survives every entitlement, PDFs use exact calendar months and custom/Clinical gates',
    () {
      for (final status in EntitlementStatus.values) {
        final state = EntitlementState(status: status);
        final all = RecordReportSelection(
          range: const SummaryDateRange(
            start: LocalDate(2020, 1, 1),
            end: today,
          ),
          allRecords: true,
        );
        expect(
          recordReportRequiresPlus(all, ReportExportFormat.csv, today),
          isFalse,
          reason: '$status',
        );
        expect(
          recordReportRequiresPlus(
            RecordReportSelection(range: recent),
            ReportExportFormat.pdf,
            today,
          ),
          isFalse,
        );
        expect(state.canUse(LetterCapability.acuteCareFlows), isTrue);
      }
      expect(
        recordReportMonthsBefore(const LocalDate(2026, 5, 31), 3),
        const LocalDate(2026, 2, 28),
      );
      expect(
        recordReportMonthsBefore(const LocalDate(2024, 5, 31), 3),
        const LocalDate(2024, 2, 29),
      );
      expect(
        recordReportRequiresPlus(
          RecordReportSelection(range: recent, customRange: true),
          ReportExportFormat.pdf,
          today,
        ),
        isTrue,
      );
      expect(
        recordReportRequiresPlus(
          RecordReportSelection(
            range: recent,
            kind: RecordReportKind.clinicalPattern,
          ),
          ReportExportFormat.pdf,
          today,
        ),
        isTrue,
      );
      expect(
        recordReportRequiresPlus(
          RecordReportSelection(
            range: const SummaryDateRange(
              start: LocalDate(2026, 7, 8),
              end: today,
            ),
          ),
          ReportExportFormat.pdf,
          today,
        ),
        isTrue,
      );
    },
  );

  test('undeclared health fields and selection fields fail closed', () {
    expect(
      () => RecordReportSource(
        id: 'x',
        category: RecordReportCategory.symptoms,
        sourceType: 'symptom_rating',
        date: today,
        fields: {'new_sensitive_payload': 'secret'},
      ),
      throwsFormatException,
    );
    expect(
      () => RecordReportSelection(
        range: recent,
        fields: {
          RecordReportCategory.symptoms: {'new_sensitive_payload'},
        },
      ),
      throwsFormatException,
    );
  });
  test(
    'All records retains saved frozen dates ahead after travel; explicit dated ranges exclude them',
    () {
      const ahead = LocalDate(2026, 10, 10);
      final historical = HealthRecord(
        id: 'travel-day',
        symptom: SymptomType.cramps,
        severity: SymptomSeverity.notPresent,
        functionalImpacts: const {},
        experiencedDate: ahead,
        recordedAt: DateTime.utc(2026, 10, 9, 16),
        updatedAt: DateTime.utc(2026, 10, 9, 16),
        provenance: HealthRecordProvenance.sameDay,
        userConfirmed: true,
        vocabularyVersion: healthRecordVocabularyVersion,
        writeZoneOffsetMinutes: 540,
        writeZoneName: 'Asia/Tokyo',
      );
      final s = snapshot(sources(records: [historical]));
      expect(
        projectRecordReport(s, RecordReportSelection(range: recent)).rows,
        isEmpty,
      );
      final all = projectRecordReport(
        s,
        RecordReportSelection(range: recent, allRecords: true),
      );
      expect(all.rows.single.date, ahead);
      expect(all.rows.single.fields['original_utc_offset_minutes'], '540');
      expect(
        utf8.decode(buildRecordSourceCsv(all).bytes),
        contains('2026-10-10'),
      );
      expect(
        recordReportRequiresPlus(all.selection, ReportExportFormat.csv, today),
        isFalse,
      );
    },
  );
  test(
    'newer vocabulary facts stay excluded until their report contracts are understood',
    () {
      final future = HealthRecord(
        id: 'future',
        symptom: SymptomType.cramps,
        severity: SymptomSeverity.extreme,
        functionalImpacts: const {},
        experiencedDate: today,
        recordedAt: DateTime.utc(2026, 10, 9),
        updatedAt: DateTime.utc(2026, 10, 9),
        provenance: HealthRecordProvenance.sameDay,
        userConfirmed: true,
        vocabularyVersion: healthRecordVocabularyVersion + 1,
      );
      expect(sources(records: [future]), isEmpty);
    },
  );

  test(
    'saved zero, categorical duration and original Fahrenheit BBT remain exact; sensitive defaults off',
    () {
      final rows = sources(
        facts: [
          RecordHubDateFacts(
            date: today,
            impact: DailyImpactRecord(
              metadata: metadata('impact', today),
              value: DailyImpactDraft(experiencedDate: today, overall: 0),
            ),
            bleeding: BleedingFactRecord(
              metadata: metadata('bleeding', today),
              value: BleedingFactDraft(experiencedDate: today, flow: null),
            ),
            sleep: SleepRecord(
              metadata: metadata('sleep', today),
              value: SleepDraft(
                experiencedDate: today,
                duration: RecordedDuration.bucket(
                  DurationBucket.sleep7To9Hours,
                ),
              ),
            ),
            temperatures: [
              TemperatureRecord(
                metadata: metadata('bbt', today),
                value: TemperatureDraft(
                  experiencedDate: today,
                  enteredValue: 98.6,
                  unit: TemperatureUnit.fahrenheit,
                  method: TemperatureMethod.manualOral,
                ),
              ),
            ],
          ),
        ],
      );
      final plain = projectRecordReport(
        snapshot(rows),
        RecordReportSelection(range: recent),
      );
      expect(plain.rows.map((r) => r.id), isNot(contains('bbt')));
      expect(
        plain.rows
            .singleWhere((r) => r.id == 'impact')
            .fields['overall_degree'],
        '0',
      );
      expect(
        plain.rows.singleWhere((r) => r.id == 'bleeding').fields['flow'],
        'none',
      );
      final sleep = plain.rows.singleWhere((r) => r.id == 'sleep');
      expect(sleep.fields['duration_label'], '7–9 h');
      expect(sleep.fields.containsKey('duration_exact_minutes'), isFalse);
      final selected = projectRecordReport(
        snapshot(rows),
        RecordReportSelection(
          range: recent,
          categories: {RecordReportCategory.temperature},
        ),
      );
      expect(selected.rows.single.fields['entered_value'], '98.6');
      expect(selected.rows.single.fields['unit'], '°F');
      expect(selected.rows.single.fields['method'], 'manualOral');
    },
  );

  test(
    'experienced note date wins over created time; undated text requires explicit source consent',
    () {
      final notes = [
        CaptureNote(
          id: 'past',
          text: 'experienced in June',
          source: CaptureSource.typed,
          createdAt: DateTime.utc(2026, 10, 8),
          experiencedDate: const LocalDate(2026, 6, 1),
        ),
        CaptureNote(
          id: 'unknown',
          text: 'unknown, "quoted"\nsecond line',
          source: CaptureSource.typed,
          createdAt: DateTime.utc(2026, 10, 8),
        ),
      ];
      final s = snapshot(sources(notes: notes));
      final none = projectRecordReport(
        s,
        RecordReportSelection(
          range: recent,
          categories: {RecordReportCategory.privateNotes},
        ),
      );
      expect(none.rows, isEmpty);
      final chosen = projectRecordReport(
        s,
        RecordReportSelection(
          range: recent,
          categories: {RecordReportCategory.privateNotes},
          selectedNoteIds: {
            'private:capture_note:past',
            'private:capture_note:unknown',
          },
        ),
      );
      expect(chosen.rows.map((r) => r.id), ['unknown']);
      expect(chosen.rows.single.date, isNull);
      final csv = utf8.decode(buildRecordSourceCsv(chosen).bytes);
      expect(csv, contains('"Date unknown"'));
      expect(csv, contains('"unknown, ""quoted""\nsecond line"'));
      expect(csv, contains('\r\n'));
      expect(csv, isNot(contains('experienced in June')));
    },
  );

  test(
    'sensitive context text requires both category permission and individual note selection',
    () {
      final r = ContextEventRecord(
        metadata: metadata('event', today),
        value: ContextEventDraft(
          experiencedDate: today,
          type: ContextEventType.trauma,
          note: 'private event words',
        ),
      );
      final s = snapshot(
        sources(
          facts: [
            RecordHubDateFacts(date: today, events: [r]),
          ],
        ),
      );
      final noteOnly = projectRecordReport(
        s,
        RecordReportSelection(
          range: recent,
          categories: {RecordReportCategory.privateNotes},
          selectedNoteIds: {'private:event_text:event'},
        ),
      );
      expect(noteOnly.rows, isEmpty);
      final eventOnly = projectRecordReport(
        s,
        RecordReportSelection(
          range: recent,
          categories: {RecordReportCategory.contextEvents},
        ),
      );
      expect(
        utf8.decode(buildRecordSourceCsv(eventOnly).bytes),
        isNot(contains('private event words')),
      );
      final selected = projectRecordReport(
        s,
        RecordReportSelection(
          range: recent,
          categories: {
            RecordReportCategory.contextEvents,
            RecordReportCategory.privateNotes,
          },
          selectedNoteIds: {'private:event_text:event'},
        ),
      );
      expect(
        utf8.decode(buildRecordSourceCsv(selected).bytes),
        contains('private event words'),
      );
    },
  );

  test(
    'archived product episodes do not imply use; dated versions preserve the old use dose',
    () {
      const start = LocalDate(2026, 10, 1),
          change = LocalDate(2026, 10, 5),
          useDate = LocalDate(2026, 10, 2);
      final old = ProductDetails(
        family: ProductFamily.medication,
        exactName: 'Exact product',
        dose: '1/2',
        unit: DoseUnit.tablet,
      );
      final newer = ProductDetails(
        family: ProductFamily.medication,
        exactName: 'Exact product',
        dose: '2',
        unit: DoseUnit.tablet,
      );
      final episode = ProductEpisode(
        metadata: metadata('episode', start),
        family: ProductFamily.medication,
        startDate: start,
        endDate: const LocalDate(2026, 10, 7),
        archived: true,
        versions: [
          ProductVersion(
            metadata: metadata('old', start),
            episodeId: 'episode',
            effectiveFrom: start,
            versionNumber: 1,
            details: old,
          ),
          ProductVersion(
            metadata: metadata('new', change),
            episodeId: 'episode',
            effectiveFrom: change,
            versionNumber: 2,
            details: newer,
          ),
        ],
      );
      final use = ProductUseRecord(
        metadata: metadata('use', useDate),
        value: ProductUseDraft(
          experiencedDate: useDate,
          episodeId: 'episode',
          status: ProductUseStatus.taken,
        ),
        versionId: 'old',
        dailyShortcut: true,
      );
      final s = snapshot(sources(episodes: [episode], uses: [use]));
      expect(
        projectRecordReport(s, RecordReportSelection(range: recent)).rows,
        isEmpty,
      );
      final p = projectRecordReport(
        s,
        RecordReportSelection(
          range: const SummaryDateRange(
            start: useDate,
            end: LocalDate(2026, 10, 3),
          ),
          categories: {RecordReportCategory.medication},
        ),
      );
      expect(p.rows.map((r) => r.sourceType).toSet(), {
        'product_episode',
        'product_version',
        'product_use',
      });
      expect(
        p.rows.singleWhere((r) => r.sourceType == 'product_use').fields['dose'],
        '1/2',
      );
      expect(
        p.rows
            .singleWhere((r) => r.sourceType == 'product_use')
            .fields['version_id'],
        'old',
      );
      expect(p.rows.any((r) => r.id == 'new'), isFalse);
      expect(
        p.rows
            .singleWhere((r) => r.sourceType == 'product_episode')
            .fields
            .containsKey('use_status'),
        isFalse,
      );
    },
  );

  test(
    'field omissions drive preview and CSV, selected content evidence notices actual edits',
    () {
      RecordReportSource row(String degree) => RecordReportSource(
        id: 's',
        category: RecordReportCategory.symptoms,
        sourceType: 'symptom_rating',
        date: today,
        fields: {
          'symptom': 'cramps',
          'degree': degree,
          'original_timing': 'same_day',
        },
      );
      final selection = RecordReportSelection(
        range: recent,
        categories: {RecordReportCategory.symptoms},
        fields: {
          RecordReportCategory.symptoms: {'degree'},
        },
      );
      final a = projectRecordReport(snapshot([row('0')]), selection);
      final b = projectRecordReport(snapshot([row('1')]), selection);
      expect(a.rows.single.fields, {'degree': '0'});
      expect(
        utf8.decode(buildRecordSourceCsv(a).bytes),
        isNot(contains('cramps')),
      );
      expect(a.contentEvidence, isNot(b.contentEvidence));
    },
  );

  test(
    'frozen Moment date stays separate from UTC timestamp and unknown legacy date',
    () {
      final r = MomentCheckIn(
        id: 'dated',
        state: MomentCheckInState.calm,
        occurredAt: DateTime.utc(2026, 10, 8, 16),
        createdAt: DateTime.utc(2026, 10, 8, 16),
        experiencedDate: today,
        provenance: HealthRecordProvenance.sameDay,
        writeZoneOffsetMinutes: 540,
        writeZoneName: 'Asia/Tokyo',
      );
      final legacy = MomentCheckIn(
        id: 'legacy',
        state: MomentCheckInState.low,
        occurredAt: DateTime.utc(2026, 10, 8),
        createdAt: DateTime.utc(2026, 10, 8),
      );
      final s = snapshot(sources(moments: [r, legacy]));
      final dated = projectRecordReport(
        s,
        RecordReportSelection(
          range: const SummaryDateRange(start: today, end: today),
        ),
      );
      expect(dated.rows.map((r) => r.id), ['dated']);
      expect(dated.rows.single.date, today);
      expect(
        dated.rows.single.fields['occurred_at_utc'],
        '2026-10-08T16:00:00.000Z',
      );
      final all = projectRecordReport(
        s,
        RecordReportSelection(range: recent, allRecords: true),
      );
      expect(all.rows.singleWhere((r) => r.id == 'legacy').date, isNull);
      expect(
        all.rows.singleWhere((r) => r.id == 'legacy').fields['timing'],
        'timing_unknown',
      );
    },
  );

  test(
    'selected source CSV neutralizes spreadsheet formulas while retaining source text',
    () {
      final notes = [
        for (final (index, value) in [
          '=SUM(1,2)',
          '+42',
          '-42',
          '@example',
          '  =1',
          'ordinary text',
        ].indexed)
          CaptureNote(
            id: 'formula-$index',
            text: value,
            source: CaptureSource.typed,
            createdAt: DateTime.utc(2026, 10, 9),
            experiencedDate: today,
          ),
      ];
      final p = projectRecordReport(
        snapshot(sources(notes: notes)),
        RecordReportSelection(
          range: recent,
          categories: {RecordReportCategory.privateNotes},
          selectedNoteIds: {
            for (final note in notes) 'private:capture_note:${note.id}',
          },
        ),
      );
      final csv = utf8.decode(buildRecordSourceCsv(p).bytes);
      for (final value in ['=SUM(1,2)', '+42', '-42', '@example', '  =1']) {
        expect(csv, contains('"\'$value"'));
      }
      expect(csv, contains('"ordinary text"'));
      expect(p.rows.first.fields['text'], '=SUM(1,2)');
    },
  );

  group('real native report port', () {
    late RecordingShare share;
    late InMemoryCaptureNoteStore notes;
    late InMemoryHealthRecordRepository health;
    late LetterReportExperiencePort port;
    var active = false;
    setUp(() {
      active = false;
      share = RecordingShare();
      notes = InMemoryCaptureNoteStore();
      health = InMemoryHealthRecordRepository(
        clock: () => DateTime(2026, 10, 9, 12),
      );
      port = LetterReportExperiencePort(
        periodRepository: InMemoryPeriodRepository(),
        careMemoryRepository: InMemoryCareMemoryRepository(),
        healthRecordRepository: health,
        momentCheckInRepository: InMemoryMomentCheckInRepository(),
        captureNoteStore: notes,
        entitlementRepository: LocalEntitlementRepository(
          initial: const EntitlementState(status: EntitlementStatus.activePaid),
        ),
        fileShareAdapter: share,
        now: () => DateTime(2026, 10, 9, 12),
        hasPlus: () => active,
      );
    });
    test(
      'all-record CSV creates a real local file without Plus and excludes notes by default',
      () async {
        notes.notes.add(
          CaptureNote(
            id: 'note',
            text: 'private secret',
            source: CaptureSource.typed,
            createdAt: DateTime.utc(2026, 10, 9),
          ),
        );
        final preview = projectRecordReport(
          await port.loadRecordSources(),
          RecordReportSelection(
            range: const SummaryDateRange(
              start: LocalDate(2020, 1, 1),
              end: today,
            ),
            allRecords: true,
          ),
        );
        final receipt = await port.exportSelected(
          preview: preview,
          format: ReportExportFormat.csv,
          hasPlus: false,
        );
        expect(receipt.outcome, ExperienceFileOutcome.shared);
        expect(share.files.single, isA<LocalCsvFile>());
        expect(
          utf8.decode(share.files.single.bytes),
          isNot(contains('private secret')),
        );
      },
    );
    test(
      'recent Visit creates native PDF for free; custom, old, and Clinical reject before sharing',
      () async {
        final s = await port.loadRecordSources();
        final free = projectRecordReport(
          s,
          RecordReportSelection(range: recent),
        );
        expect(
          (await port.exportSelected(
            preview: free,
            format: ReportExportFormat.pdf,
            hasPlus: false,
          )).outcome,
          ExperienceFileOutcome.shared,
        );
        expect(share.files.single, isA<LocalPdfFile>());
        expect(utf8.decode(share.files.single.bytes.take(4).toList()), '%PDF');
        for (final selection in [
          RecordReportSelection(range: recent, customRange: true),
          RecordReportSelection(
            range: recent,
            kind: RecordReportKind.clinicalPattern,
            categories: recordReportClinicalCategories,
          ),
          RecordReportSelection(
            range: const SummaryDateRange(
              start: LocalDate(2026, 7, 8),
              end: today,
            ),
          ),
        ]) {
          final result = await port.exportSelected(
            preview: projectRecordReport(s, selection),
            format: ReportExportFormat.pdf,
            hasPlus: true,
          );
          expect(result.outcome, ExperienceFileOutcome.failed);
        }
        expect(share.files, hasLength(1));
      },
    );
    test(
      'a caller or no-card Preview cannot replace store-backed paid PDF authority',
      () async {
        final free = LocalEntitlementRepository();
        addTearDown(free.dispose);
        final untrusted = LetterReportExperiencePort(
          periodRepository: port.periodRepository,
          careMemoryRepository: port.careMemoryRepository,
          healthRecordRepository: health,
          momentCheckInRepository: port.momentCheckInRepository,
          captureNoteStore: notes,
          entitlementRepository: free,
          fileShareAdapter: share,
          hasPlus: () => true,
          now: () => DateTime(2026, 10, 9, 12),
        );
        final p = projectRecordReport(
          await untrusted.loadRecordSources(),
          RecordReportSelection(range: recent, customRange: true),
        );
        final receipt = await untrusted.exportSelected(
          preview: p,
          format: ReportExportFormat.pdf,
          hasPlus: true,
        );
        expect(receipt.outcome, ExperienceFileOutcome.failed);
        expect(share.files, isEmpty);
      },
    );

    test(
      'lapse keeps previous file and CSV while blocking a newly requested extended PDF',
      () async {
        active = true;
        final p = projectRecordReport(
          await port.loadRecordSources(),
          RecordReportSelection(range: recent, customRange: true),
        );
        expect(
          (await port.exportSelected(
            preview: p,
            format: ReportExportFormat.pdf,
            hasPlus: true,
          )).outcome,
          ExperienceFileOutcome.shared,
        );
        final previous = share.files.single;
        active = false;
        expect(
          (await port.exportSelected(
            preview: p,
            format: ReportExportFormat.pdf,
            hasPlus: true,
          )).outcome,
          ExperienceFileOutcome.failed,
        );
        expect(share.files.single, same(previous));
        expect(
          (await port.exportSelected(
            preview: p,
            format: ReportExportFormat.csv,
            hasPlus: false,
          )).outcome,
          ExperienceFileOutcome.shared,
        );
        expect(share.files, hasLength(2));
      },
    );
    test(
      'changed or deleted selected records invalidate reviewed preview before native file handoff',
      () async {
        final record = await health.create(
          const HealthRecordDraft(
            symptom: SymptomType.cramps,
            severity: SymptomSeverity.notPresent,
            experiencedDate: today,
            provenance: HealthRecordProvenance.sameDay,
          ),
        );
        final p = projectRecordReport(
          await port.loadRecordSources(),
          RecordReportSelection(range: recent),
        );
        await health.delete(record.id);
        final result = await port.exportSelected(
          preview: p,
          format: ReportExportFormat.csv,
          hasPlus: false,
        );
        expect(result.outcome, ExperienceFileOutcome.failed);
        expect(result.message, contains('Refresh the preview'));
        expect(share.files, isEmpty);
      },
    );
    test(
      'selected Unicode text is preserved in UTF-8 CSV and never silently corrupted in PDF',
      () async {
        notes.notes.add(
          CaptureNote(
            id: 'unicode',
            text: '例：私の記録 🌿',
            source: CaptureSource.typed,
            createdAt: DateTime.utc(2026, 10, 9),
            experiencedDate: today,
          ),
        );
        final p = projectRecordReport(
          await port.loadRecordSources(),
          RecordReportSelection(
            range: recent,
            categories: {RecordReportCategory.privateNotes},
            selectedNoteIds: {'private:capture_note:unicode'},
          ),
        );
        final pdf = await port.exportSelected(
          preview: p,
          format: ReportExportFormat.pdf,
          hasPlus: false,
        );
        expect(pdf.outcome, ExperienceFileOutcome.failed);
        expect(pdf.message, contains('preserve every character'));
        expect(share.files, isEmpty);
        final csv = await port.exportSelected(
          preview: p,
          format: ReportExportFormat.csv,
          hasPlus: false,
        );
        expect(csv.outcome, ExperienceFileOutcome.shared);
        expect(utf8.decode(share.files.single.bytes), contains('例：私の記録 🌿'));
      },
    );
    test(
      'paid access is rechecked after asynchronous PDF preparation before any durable share',
      () async {
        active = true;
        final changing = LetterReportExperiencePort(
          periodRepository: port.periodRepository,
          careMemoryRepository: port.careMemoryRepository,
          healthRecordRepository: health,
          momentCheckInRepository: port.momentCheckInRepository,
          captureNoteStore: notes,
          entitlementRepository: LocalEntitlementRepository(
            initial: const EntitlementState(
              status: EntitlementStatus.activePaid,
            ),
          ),
          fileShareAdapter: share,
          now: () => DateTime(2026, 10, 9, 12),
          hasPlus: () => active,
          readTransaction: AfterReadTransaction(() => active = false),
        );
        final p = projectRecordReport(
          await port.loadRecordSources(),
          RecordReportSelection(range: recent, customRange: true),
        );
        final result = await changing.exportSelected(
          preview: p,
          format: ReportExportFormat.pdf,
          hasPlus: true,
        );
        expect(result.outcome, ExperienceFileOutcome.failed);
        expect(active, isFalse);
        expect(share.files, isEmpty);
      },
    );
    test(
      'midnight calendar-window change is revalidated at the actual PDF handoff',
      () async {
        var current = DateTime(2026, 10, 9, 23, 59);
        final changing = LetterReportExperiencePort(
          periodRepository: port.periodRepository,
          careMemoryRepository: port.careMemoryRepository,
          healthRecordRepository: health,
          momentCheckInRepository: port.momentCheckInRepository,
          captureNoteStore: notes,
          entitlementRepository: LocalEntitlementRepository(
            initial: const EntitlementState(
              status: EntitlementStatus.activePaid,
            ),
          ),
          fileShareAdapter: share,
          now: () => current,
          hasPlus: () => false,
          readTransaction: AfterReadTransaction(
            () => current = DateTime(2026, 10, 10),
          ),
        );
        final s = await port.loadRecordSources();
        final p = projectRecordReport(s, RecordReportSelection(range: recent));
        final result = await changing.exportSelected(
          preview: p,
          format: ReportExportFormat.pdf,
          hasPlus: false,
        );
        expect(result.outcome, ExperienceFileOutcome.failed);
        expect(result.message, contains('date or PDF access changed'));
        expect(share.files, isEmpty);
      },
    );
    test(
      'base dated notes filter actual experienced date; unknown notes never borrow createdAt',
      () async {
        notes.notes.addAll([
          CaptureNote(
            id: 'dated',
            text: 'text',
            source: CaptureSource.typed,
            createdAt: DateTime.utc(2026, 10, 9),
            experiencedDate: const LocalDate(2026, 6, 1),
          ),
          CaptureNote(
            id: 'undated',
            text: 'text',
            source: CaptureSource.typed,
            createdAt: DateTime.utc(2026, 10, 9),
          ),
        ]);
        final input = await port.load();
        expect(input.notes, hasLength(1));
        expect(input.notes.single.date, const LocalDate(2026, 6, 1));
        final raw = await port.loadRecordSources();
        expect(
          raw.sources.where((r) => r.sourceType == 'capture_note'),
          hasLength(2),
        );
      },
    );
  });
}
