import 'package:flutter/foundation.dart';

import '../../features/capture/domain/capture_models.dart';
import '../../features/check_in/domain/moment_check_in.dart';
import '../../features/check_in/domain/moment_check_in_repository.dart';
import '../../features/cycle/domain/bleeding_flow.dart';
import '../../features/cycle/domain/local_date.dart';
import '../../features/cycle/domain/period_record.dart';
import '../../features/cycle/domain/period_repository.dart';
import '../../features/health_records/domain/health_record.dart';
import '../../features/health_records/domain/health_record_repository.dart';
import '../../features/today/today_cycle_context.dart';

/// The complete, factual Today state supplied to the visual layer.
final class TodayVisualSnapshot {
  const TodayVisualSnapshot({
    required this.today,
    required this.containingPeriod,
    required this.openPeriod,
    required this.flowRecord,
    required this.mood,
    required this.symptoms,
    required this.note,
    required this.cycleContext,
    this.rememberedHelpLine,
  });

  final LocalDate today;
  final PeriodRecord? containingPeriod;
  final PeriodRecord? openPeriod;
  final BleedingDayRecord? flowRecord;
  final MomentCheckInState? mood;
  final List<HealthRecord> symptoms;
  final String? note;
  final TodayCycleContext cycleContext;

  /// Factual copy composed upstream from explicitly saved Care check-backs.
  /// Null means the evidence gate chose silence.
  final String? rememberedHelpLine;

  bool get canRecordFlow => containingPeriod != null;
  bool get canEndPeriod => openPeriod != null;
}

/// Non-visual boundary shared by Today's quick recording surface and Cycle's
/// day editor. All methods return a fresh snapshot after a successful write.
abstract interface class TodayVisualPort {
  Future<TodayVisualSnapshot> load();

  Future<TodayVisualSnapshot> saveMood(MomentCheckInState state);
  Future<TodayVisualSnapshot> startPeriod();
  Future<TodayVisualSnapshot> endOpenPeriodToday();
  Future<TodayVisualSnapshot> setFlow(BleedingFlow? flow);
  Future<TodayVisualSnapshot> setColor(BleedingColor color);
  Future<TodayVisualSnapshot> saveSymptom(
    SymptomType symptom,
    SymptomSeverity severity,
  );
  Future<TodayVisualSnapshot> removeSymptom(String recordId);
  Future<TodayVisualSnapshot> saveNote(String text);
  Future<void> openCare();
}

/// Repository-backed port. It deliberately uses the same three repositories
/// as Cycle's day editor; there is no parallel Today store.
final class RepositoryTodayVisualPort implements TodayVisualPort {
  RepositoryTodayVisualPort({
    required this.periodRepository,
    required this.checkInRepository,
    required this.healthRecordRepository,
    required this.captureNoteStore,
    required this.today,
    required this.now,
    required this.onCycleDataChanged,
    required this.onOpenCare,
    this.loadRememberedHelpLine,
  });

  final PeriodRepository periodRepository;
  final MomentCheckInRepository checkInRepository;
  final HealthRecordRepository healthRecordRepository;
  final CaptureNoteStore captureNoteStore;
  final LocalDate Function() today;
  final DateTime Function() now;
  final VoidCallback onCycleDataChanged;
  final VoidCallback onOpenCare;
  final Future<String?> Function()? loadRememberedHelpLine;

  @override
  Future<TodayVisualSnapshot> load() async {
    final values = await Future.wait<Object>(<Future<Object>>[
      periodRepository.getAll(),
      periodRepository.getAllFlowDays(),
      checkInRepository.getAll(),
      healthRecordRepository.getAll(),
      captureNoteStore.getAll(),
    ]);
    final date = today();
    final periods = values[0] as List<PeriodRecord>;
    final flows = values[1] as List<BleedingDayRecord>;
    final checkIns = values[2] as List<MomentCheckIn>;
    final records = values[3] as List<HealthRecord>;
    final notes = values[4] as List<CaptureNote>;
    String? rememberedHelpLine;
    try {
      rememberedHelpLine = await loadRememberedHelpLine?.call();
    } on Object {
      // Remembered-help is optional context. It must never block today's
      // factual record from loading when derived analysis is unavailable.
      rememberedHelpLine = null;
    }

    final containing = periods.where((period) {
      final end = period.endDate;
      return !date.isBefore(period.startDate) &&
          (end == null || !date.isAfter(end));
    }).firstOrNull;
    final open = periods.where((period) => period.isOpen).firstOrNull;
    final flow = containing == null
        ? null
        : flows
              .where(
                (entry) =>
                    entry.periodId == containing.id && entry.date == date,
              )
              .firstOrNull;
    final mood = checkIns
        .where(
          (entry) => LocalDate.fromDateTime(entry.occurredAt.toLocal()) == date,
        )
        .firstOrNull
        ?.state;
    final symptoms = records
        .where((record) => record.experiencedDate == date)
        .toList(growable: false);
    return TodayVisualSnapshot(
      today: date,
      containingPeriod: containing,
      openPeriod: open,
      flowRecord: flow,
      mood: mood,
      symptoms: symptoms,
      note: notes.firstOrNull?.text,
      // This is the exact shared prediction contract. Today does not keep a
      // visual-only day count or date estimate of its own.
      cycleContext: TodayCycleContext.fromRecords(
        records: periods,
        today: date,
      ),
      rememberedHelpLine: rememberedHelpLine,
    );
  }

  @override
  Future<TodayVisualSnapshot> saveMood(MomentCheckInState state) async {
    final created = await checkInRepository.create(state, occurredAt: now());
    final date = today();
    for (final entry in await checkInRepository.getAll()) {
      if (entry.id != created.id &&
          LocalDate.fromDateTime(entry.occurredAt.toLocal()) == date) {
        try {
          await checkInRepository.delete(entry.id);
        } on MomentCheckInException {
          // The newest entry is authoritative; a stale duplicate is harmless.
        }
      }
    }
    onCycleDataChanged();
    return load();
  }

  @override
  Future<TodayVisualSnapshot> startPeriod() async {
    await periodRepository.create(
      PeriodDraft(startDate: today()),
      today: today(),
    );
    onCycleDataChanged();
    return load();
  }

  @override
  Future<TodayVisualSnapshot> endOpenPeriodToday() async {
    final snapshot = await load();
    final open = snapshot.openPeriod;
    if (open == null) return snapshot;
    await periodRepository.update(
      open.id,
      PeriodDraft(startDate: open.startDate, endDate: snapshot.today),
      today: snapshot.today,
    );
    onCycleDataChanged();
    return load();
  }

  @override
  Future<TodayVisualSnapshot> setFlow(BleedingFlow? flow) async {
    final snapshot = await load();
    final period = snapshot.containingPeriod;
    if (period == null) {
      throw StateError('A period must be started before flow can be saved.');
    }
    final current = snapshot.flowRecord?.flow;
    if (flow == null || current == flow) {
      await periodRepository.clearFlow(period.id, snapshot.today);
    } else {
      await periodRepository.setFlow(
        period.id,
        snapshot.today,
        flow,
        today: snapshot.today,
      );
    }
    onCycleDataChanged();
    return load();
  }

  @override
  Future<TodayVisualSnapshot> setColor(BleedingColor color) async {
    final snapshot = await load();
    final period = snapshot.containingPeriod;
    final flow = snapshot.flowRecord;
    if (period == null || flow == null) {
      throw StateError('Flow is required before color can be saved.');
    }
    if (flow.color == color) {
      await periodRepository.clearBleedingColor(period.id, snapshot.today);
    } else {
      await periodRepository.setBleedingColor(period.id, snapshot.today, color);
    }
    onCycleDataChanged();
    return load();
  }

  @override
  Future<TodayVisualSnapshot> saveSymptom(
    SymptomType symptom,
    SymptomSeverity severity,
  ) async {
    final snapshot = await load();
    final current = snapshot.symptoms
        .where((record) => record.symptom == symptom)
        .firstOrNull;
    final draft = validateHealthRecordDraft(
      HealthRecordDraft(
        symptom: symptom,
        severity: severity,
        experiencedDate: snapshot.today,
        provenance: HealthRecordProvenance.sameDay,
      ),
    );
    if (current == null) {
      await healthRecordRepository.create(draft);
    } else {
      await healthRecordRepository.update(current.id, draft);
    }
    onCycleDataChanged();
    return load();
  }

  @override
  Future<TodayVisualSnapshot> removeSymptom(String recordId) async {
    await healthRecordRepository.delete(recordId);
    onCycleDataChanged();
    return load();
  }

  @override
  Future<TodayVisualSnapshot> saveNote(String text) async {
    final timestamp = now().toUtc();
    await captureNoteStore.save(
      CaptureNote(
        id: 'today-${timestamp.microsecondsSinceEpoch}',
        text: text,
        source: CaptureSource.typed,
        createdAt: timestamp,
      ),
    );
    return load();
  }

  @override
  Future<void> openCare() async => onOpenCare();
}
