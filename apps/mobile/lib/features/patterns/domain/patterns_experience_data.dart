import '../../care/domain/care_memory.dart';
import '../../check_in/domain/moment_check_in.dart';
import '../../cycle/domain/bleeding_flow.dart';
import '../../cycle/domain/local_date.dart';
import '../../cycle/domain/period_record.dart';
import '../../health_records/domain/health_record.dart';
import 'pattern_source.dart';

/// The single factual data contract for the consumer Patterns experience.
///
/// Every visual uses the same selected history: the six most recent completed
/// cycles, where a completed cycle is the interval from one recorded period
/// start to the next recorded period start. The newest recorded period start
/// is always the current cycle until another start is recorded. This is true
/// whether its bleeding record is open or closed.
final class PatternsExperienceData {
  const PatternsExperienceData({
    required this.completedCycles,
    required this.currentCycle,
    required this.symptoms,
    required this.moods,
    required this.care,
    required this.today,
  });

  final List<PatternsCompletedCycle> completedCycles;
  final PatternsCurrentCycle? currentCycle;
  final List<PatternsSymptomRecord> symptoms;
  final List<PatternsMoodRecord> moods;
  final List<PatternsCareRecord> care;
  final LocalDate today;

  bool get hasAnyPeriodHistory =>
      completedCycles.isNotEmpty || currentCycle != null;

  /// The first day shared by every Patterns tab. Older imported records are
  /// intentionally outside the current six-cycle report rather than silently
  /// being mixed into its totals.
  LocalDate? get firstIncludedDate => completedCycles.isNotEmpty
      ? completedCycles.first.startDate
      : currentCycle?.startDate;

  /// The final day represented by the shared Patterns report range.
  ///
  /// Once completed cycles exist, every analytical tab stops at the end of
  /// the newest completed cycle. The in-progress cycle remains available as
  /// current-cycle context, but is not silently mixed into cross-cycle
  /// comparisons.
  LocalDate? get lastIncludedDate => completedCycles.isNotEmpty
      ? completedCycles.last.lastDate
      : currentCycle == null
      ? null
      : today;

  int get completedCycleCount => completedCycles.length;
}

final class PatternsCompletedCycle {
  const PatternsCompletedCycle({
    required this.periodId,
    required this.startDate,
    required this.nextStartDate,
    required this.bleedingEndDate,
    required this.flowDays,
  });

  final String periodId;
  final LocalDate startDate;
  final LocalDate nextStartDate;
  final LocalDate? bleedingEndDate;
  final List<PatternsFlowDay> flowDays;

  /// The observed interval is deliberately not filtered by a "normal" range.
  /// An unusual cycle belongs in a personal report as much as any other one.
  int get lengthDays => nextStartDate.epochDay - startDate.epochDay;

  LocalDate get lastDate => nextStartDate.addDays(-1);

  /// Period dates are the source of truth for which days were bleeding days.
  /// Flow entries only enrich those already-recorded days; an omitted entry is
  /// intentionally an unknown flow, never an absent period day.
  List<LocalDate> get bleedingDates =>
      _bleedingDates(startDate: startDate, endDate: bleedingEndDate);

  bool isBleedingDate(LocalDate date) => bleedingDates.contains(date);

  PatternsFlowDay? flowFor(LocalDate date) =>
      flowDays.where((entry) => entry.date == date).firstOrNull;

  bool contains(LocalDate date) =>
      !date.isBefore(startDate) && date.isBefore(nextStartDate);
}

final class PatternsCurrentCycle {
  const PatternsCurrentCycle({
    required this.periodId,
    required this.startDate,
    required this.bleedingEndDate,
    required this.flowDays,
  });

  final String periodId;
  final LocalDate startDate;
  final LocalDate? bleedingEndDate;
  final List<PatternsFlowDay> flowDays;

  List<LocalDate> get bleedingDates =>
      _bleedingDates(startDate: startDate, endDate: bleedingEndDate);

  /// While a period remains open, its saved start through the displayed day is
  /// a bleeding range. This never manufactures a flow level for those days.
  List<LocalDate> bleedingDatesThrough(LocalDate displayedDay) =>
      _bleedingDates(
        startDate: startDate,
        endDate: bleedingEndDate ?? displayedDay,
      );

  bool isBleedingDate(LocalDate date, {required LocalDate displayedDay}) =>
      bleedingDatesThrough(displayedDay).contains(date);

  PatternsFlowDay? flowFor(LocalDate date) =>
      flowDays.where((entry) => entry.date == date).firstOrNull;
}

List<LocalDate> _bleedingDates({
  required LocalDate startDate,
  required LocalDate? endDate,
}) {
  final lastDay = endDate ?? startDate;
  if (lastDay.isBefore(startDate)) return const [];
  return List.unmodifiable([
    for (var day = startDate; !day.isAfter(lastDay); day = day.addDays(1)) day,
  ]);
}

final class PatternsFlowDay {
  const PatternsFlowDay({
    required this.date,
    required this.flow,
    required this.color,
  });

  final LocalDate date;
  final BleedingFlow flow;
  final BleedingColor? color;
}

enum PatternsSymptomCategory {
  pain,
  emotions,
  energyAndSleep,
  digestion,
  otherBody,
}

final class PatternsSymptomRecord {
  const PatternsSymptomRecord({
    required this.id,
    required this.date,
    required this.category,
    required this.label,
    required this.severity,
  });

  final String id;
  final LocalDate date;
  final PatternsSymptomCategory category;
  final String label;
  final SymptomSeverity severity;

  /// "Heavier" is a display threshold only. It never changes a saved symptom
  /// severity and leaves minimal/mild records visible in detailed drill-downs.
  bool get isHeavier => severity.score >= SymptomSeverity.moderate.score;
}

enum PatternsMoodTone { positive, steady, difficult }

/// A direct observation from Today's one-per-day mood check-in. Unlike a
/// symptom, it never has an inferred severity. A difficult feeling contributes
/// to the emotional Patterns category; the explicit `Physical` check-in
/// contributes to other body experiences instead. Neither becomes a symptom
/// record just because it is included in a pattern.
final class PatternsMoodRecord {
  const PatternsMoodRecord({
    required this.id,
    required this.date,
    required this.label,
    required this.tone,
    this.harderCategory,
  });

  final String id;
  final LocalDate date;
  final String label;
  final PatternsMoodTone tone;
  final PatternsSymptomCategory? harderCategory;

  bool get isHarder => harderCategory != null;
}

final class PatternsCareRecord {
  const PatternsCareRecord({
    required this.id,
    required this.date,
    required this.actionLabel,
    required this.outcome,
    this.reflection,
  });

  final String id;
  final LocalDate date;
  final String actionLabel;
  final CareOutcome outcome;
  final String? reflection;
}

/// Builds the display contract from a freshly-read database snapshot. It has no
/// storage side effects, so every refresh and every test sees the same rules.
final class PatternsExperienceDataBuilder {
  const PatternsExperienceDataBuilder({this.maxCompletedCycles = 6});

  final int maxCompletedCycles;

  PatternsExperienceData build(
    PatternSourceSnapshot source, {
    required LocalDate today,
  }) {
    final periods = _normalizedPastPeriods(source.periods, today);
    final cycles = _completedCycles(periods, source.flowDays);
    final selectedCycles = cycles.length <= maxCompletedCycles
        ? cycles
        : cycles.sublist(cycles.length - maxCompletedCycles);
    final current = periods.isEmpty
        ? null
        : _currentCycle(periods.last, source.flowDays, today: today);
    final firstIncluded = selectedCycles.isNotEmpty
        ? selectedCycles.first.startDate
        : current?.startDate;
    final lastIncluded = selectedCycles.isNotEmpty
        ? selectedCycles.last.lastDate
        : today;

    return PatternsExperienceData(
      completedCycles: List.unmodifiable(selectedCycles),
      currentCycle: current,
      symptoms: List.unmodifiable(
        _symptoms(source.healthRecords, firstIncluded, lastIncluded),
      ),
      moods: List.unmodifiable(
        _moods(source.momentCheckIns, firstIncluded, lastIncluded),
      ),
      care: List.unmodifiable(
        _care(
          source.careRecords,
          source.careReflections,
          firstIncluded,
          lastIncluded,
        ),
      ),
      today: today,
    );
  }

  List<PeriodRecord> _normalizedPastPeriods(
    List<PeriodRecord> records,
    LocalDate today,
  ) {
    final byStartDay = <int, PeriodRecord>{};
    for (final period in records) {
      if (period.startDate.isAfter(today)) continue;
      final current = byStartDay[period.startDate.epochDay];
      if (current == null || period.updatedAt.isAfter(current.updatedAt)) {
        byStartDay[period.startDate.epochDay] = period;
      }
    }
    final normalized = byStartDay.values.toList()
      ..sort((left, right) => left.startDate.compareTo(right.startDate));
    return normalized;
  }

  List<PatternsCompletedCycle> _completedCycles(
    List<PeriodRecord> periods,
    List<BleedingDayRecord> flowDays,
  ) {
    if (periods.length < 2) return const [];
    return List.unmodifiable([
      for (var index = 0; index < periods.length - 1; index++)
        PatternsCompletedCycle(
          periodId: periods[index].id,
          startDate: periods[index].startDate,
          nextStartDate: periods[index + 1].startDate,
          bleedingEndDate: periods[index].endDate,
          flowDays: _flowDaysFor(
            periods[index],
            flowDays,
            through: periods[index + 1].startDate.addDays(-1),
          ),
        ),
    ]);
  }

  PatternsCurrentCycle _currentCycle(
    PeriodRecord period,
    List<BleedingDayRecord> flowDays, {
    required LocalDate today,
  }) {
    return PatternsCurrentCycle(
      periodId: period.id,
      startDate: period.startDate,
      bleedingEndDate: period.endDate,
      flowDays: _flowDaysFor(period, flowDays, through: today),
    );
  }

  List<PatternsFlowDay> _flowDaysFor(
    PeriodRecord period,
    List<BleedingDayRecord> records, {
    required LocalDate through,
  }) {
    final byDate = <int, BleedingDayRecord>{};
    for (final record in records.where(
      (record) =>
          record.periodId == period.id &&
          !record.date.isBefore(period.startDate) &&
          !record.date.isAfter(through) &&
          (period.endDate == null || !record.date.isAfter(period.endDate!)),
    )) {
      final current = byDate[record.date.epochDay];
      if (current == null || record.updatedAt.isAfter(current.updatedAt)) {
        byDate[record.date.epochDay] = record;
      }
    }
    final sorted = byDate.values.toList()
      ..sort((left, right) => left.date.compareTo(right.date));
    return List.unmodifiable([
      for (final record in sorted)
        PatternsFlowDay(
          date: record.date,
          flow: record.flow,
          color: record.color,
        ),
    ]);
  }

  List<PatternsSymptomRecord> _symptoms(
    List<HealthRecord> records,
    LocalDate? firstIncluded,
    LocalDate today,
  ) {
    if (firstIncluded == null) return const [];
    final latestDaily = <String, HealthRecord>{};
    for (final record in records) {
      if (!record.userConfirmed ||
          record.experiencedDate.isBefore(firstIncluded) ||
          record.experiencedDate.isAfter(today)) {
        continue;
      }
      final key = '${record.symptom.name}:${record.experiencedDate.epochDay}';
      final previous = latestDaily[key];
      if (previous == null || record.updatedAt.isAfter(previous.updatedAt)) {
        latestDaily[key] = record;
      }
    }
    final sorted = latestDaily.values.toList()
      ..sort((left, right) {
        final byDate = left.experiencedDate.compareTo(right.experiencedDate);
        return byDate != 0
            ? byDate
            : left.symptom.label.compareTo(right.symptom.label);
      });
    return [
      for (final record in sorted)
        PatternsSymptomRecord(
          id: record.id,
          date: record.experiencedDate,
          category: _categoryFor(record.symptom),
          label: record.symptom.label,
          severity: record.severity,
        ),
    ];
  }

  List<PatternsCareRecord> _care(
    List<CareRecord> records,
    List<CareReflection> reflections,
    LocalDate? firstIncluded,
    LocalDate today,
  ) {
    if (firstIncluded == null) return const [];
    final reflectionByRecord = <String, CareReflection>{
      for (final reflection in reflections) reflection.careRecordId: reflection,
    };
    final sorted =
        records.where((record) {
            final date = LocalDate.fromDateTime(record.occurredAt);
            return !date.isBefore(firstIncluded) && !date.isAfter(today);
          }).toList()
          ..sort((left, right) => left.occurredAt.compareTo(right.occurredAt));
    return [
      for (final record in sorted)
        PatternsCareRecord(
          id: record.id,
          date: LocalDate.fromDateTime(record.occurredAt),
          actionLabel: record.actionLabel,
          outcome: record.outcome,
          reflection: _reflectionText(reflectionByRecord[record.id]),
        ),
    ];
  }

  List<PatternsMoodRecord> _moods(
    List<MomentCheckIn> checkIns,
    LocalDate? firstIncluded,
    LocalDate today,
  ) {
    if (firstIncluded == null) return const [];
    // A Today mood is one primary check-in for a local calendar day. Existing
    // devices can contain historical duplicates from older builds, so read the
    // newest one exactly as Today's save path does rather than showing two
    // conflicting moods in Patterns.
    final newestByDay = <int, MomentCheckIn>{};
    for (final checkIn in checkIns) {
      final date = LocalDate.fromDateTime(checkIn.occurredAt);
      if (date.isBefore(firstIncluded) || date.isAfter(today)) continue;
      final current = newestByDay[date.epochDay];
      if (current == null || checkIn.occurredAt.isAfter(current.occurredAt)) {
        newestByDay[date.epochDay] = checkIn;
      }
    }
    final sorted =
        newestByDay.entries.map((entry) {
          final checkIn = entry.value;
          return _moodForCheckIn(
            checkIn,
            LocalDate.fromDateTime(checkIn.occurredAt),
          );
        }).toList()..sort((left, right) {
          final byDate = left.date.compareTo(right.date);
          return byDate != 0 ? byDate : left.label.compareTo(right.label);
        });
    return sorted;
  }

  PatternsSymptomCategory _categoryFor(SymptomType symptom) =>
      switch (symptom) {
        SymptomType.cramps ||
        SymptomType.pelvicPain ||
        SymptomType.backPain ||
        SymptomType.jointMusclePain ||
        SymptomType.headache ||
        SymptomType.migraine => PatternsSymptomCategory.pain,
        SymptomType.bloating ||
        SymptomType.nausea ||
        SymptomType.appetiteChange ||
        SymptomType.constipation ||
        SymptomType.diarrhea => PatternsSymptomCategory.digestion,
        _ when symptom.category == SymptomCategory.mood =>
          PatternsSymptomCategory.emotions,
        _
            when symptom.category == SymptomCategory.energy ||
                symptom.category == SymptomCategory.sleep =>
          PatternsSymptomCategory.energyAndSleep,
        _ => PatternsSymptomCategory.otherBody,
      };

  PatternsMoodRecord _moodForCheckIn(MomentCheckIn checkIn, LocalDate date) {
    final state = checkIn.state;
    final positive = switch (state) {
      MomentCheckInState.good ||
      MomentCheckInState.calm ||
      MomentCheckInState.energized ||
      MomentCheckInState.hopeful ||
      MomentCheckInState.tender => true,
      _ => false,
    };
    final steady = state == MomentCheckInState.steady;
    final physical = state == MomentCheckInState.physical;
    return PatternsMoodRecord(
      id: checkIn.id,
      date: date,
      label: state.label,
      tone: positive
          ? PatternsMoodTone.positive
          : steady
          ? PatternsMoodTone.steady
          : PatternsMoodTone.difficult,
      harderCategory: positive || steady
          ? null
          : physical
          ? PatternsSymptomCategory.otherBody
          : PatternsSymptomCategory.emotions,
    );
  }

  String? _reflectionText(CareReflection? reflection) {
    if (reflection == null) return null;
    final text =
        [
              reflection.observation,
              reflection.whatHelped,
              reflection.futureSelfNote,
            ]
            .whereType<String>()
            .map((text) => text.trim())
            .where((text) => text.isNotEmpty)
            .join(' ');
    return text.isEmpty ? null : text;
  }
}
