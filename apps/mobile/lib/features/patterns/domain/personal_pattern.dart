import '../../care/domain/care_mode.dart';
import '../../cycle/domain/local_date.dart';
import '../../health_records/domain/health_record.dart';

enum PersonalPatternKind { symptom, careAction }

enum PatternComparisonBasis { observedDates, observedCycleDays, careMode }

enum PatternSourceKind { healthRecord, careRecord }

final class PatternSourceReference {
  const PatternSourceReference({
    required this.id,
    required this.kind,
    required this.date,
  });

  final String id;
  final PatternSourceKind kind;
  final LocalDate date;
}

final class PatternCycleDayObservation {
  const PatternCycleDayObservation({
    required this.date,
    required this.cycleDay,
    required this.daysBeforeMenses,
  });

  final LocalDate date;

  /// Forward index: days since the most recent period start (1-based).
  final int cycleDay;

  /// Negative index: days before the NEXT confirmed period start.
  /// Example: -3 means 3 days before the next period began.
  /// Null if there is no subsequent period start to anchor against.
  final int? daysBeforeMenses;
}

final class ObservedSymptomPattern {
  const ObservedSymptomPattern({
    required this.id,
    required this.symptom,
    required this.count,
    required this.firstDate,
    required this.lastDate,
    required this.coveredDates,
    required this.severityCounts,
    required this.painLocationCounts,
    required this.functionalImpactCounts,
    required this.sources,
    required this.cycleDayObservations,
    this.severityByDaysBeforeMenses = const {},
  });

  final String id;
  final SymptomType symptom;
  final int count;
  final LocalDate firstDate;
  final LocalDate lastDate;
  final List<LocalDate> coveredDates;
  final Map<SymptomSeverity, int> severityCounts;
  final Map<PainLocation, int> painLocationCounts;
  final Map<FunctionalImpact, int> functionalImpactCounts;
  final List<PatternSourceReference> sources;
  final List<PatternCycleDayObservation> cycleDayObservations;

  /// Aggregated severity by days-before-menses (negative index).
  /// Key: days before menses (-14 to -1). Value: average severity.
  /// Empty if no subsequent period starts are available for anchoring.
  final Map<int, double> severityByDaysBeforeMenses;

  PersonalPatternKind get kind => PersonalPatternKind.symptom;

  PatternComparisonBasis get comparisonBasis {
    final cycleDays = cycleDayObservations.map((item) => item.cycleDay).toSet();
    return cycleDays.length == 1 && cycleDayObservations.length >= 2
        ? PatternComparisonBasis.observedCycleDays
        : PatternComparisonBasis.observedDates;
  }
}

final class AuthoredReflectionEvidence {
  const AuthoredReflectionEvidence({
    required this.careRecordId,
    required this.text,
  });

  final String careRecordId;
  final String text;
}

final class SupportActionPattern {
  const SupportActionPattern({
    required this.id,
    required this.actionId,
    required this.actionLabel,
    required this.mode,
    required this.count,
    required this.firstDate,
    required this.lastDate,
    required this.coveredDates,
    required this.betterCount,
    required this.sameCount,
    required this.worseCount,
    required this.sources,
    required this.pinned,
    required this.reflections,
  });

  final String id;
  final String actionId;
  final String actionLabel;
  final CareMode mode;
  final int count;
  final LocalDate firstDate;
  final LocalDate lastDate;
  final List<LocalDate> coveredDates;
  final int betterCount;
  final int sameCount;
  final int worseCount;
  final List<PatternSourceReference> sources;
  final bool pinned;
  final List<AuthoredReflectionEvidence> reflections;

  PersonalPatternKind get kind => PersonalPatternKind.careAction;

  PatternComparisonBasis get comparisonBasis => PatternComparisonBasis.careMode;

  String get factualOutcomeSummary {
    if (betterCount > 0) {
      return 'Better in $betterCount of $count check-backs';
    }
    return 'Recorded $count times; no Better check-back recorded';
  }
}

final class PersonalPatternAnalysis {
  const PersonalPatternAnalysis({
    required this.symptomPatterns,
    required this.supportActions,
    required this.selectedCareMode,
  });

  static const empty = PersonalPatternAnalysis(
    symptomPatterns: [],
    supportActions: [],
    selectedCareMode: null,
  );

  final List<ObservedSymptomPattern> symptomPatterns;
  final List<SupportActionPattern> supportActions;
  final CareMode? selectedCareMode;

  bool get isEmpty => symptomPatterns.isEmpty && supportActions.isEmpty;

  PersonalPatternAnalysis copyWith({
    List<ObservedSymptomPattern>? symptomPatterns,
    List<SupportActionPattern>? supportActions,
    CareMode? selectedCareMode,
    bool clearSelectedCareMode = false,
  }) {
    return PersonalPatternAnalysis(
      symptomPatterns: symptomPatterns ?? this.symptomPatterns,
      supportActions: supportActions ?? this.supportActions,
      selectedCareMode: clearSelectedCareMode
          ? null
          : selectedCareMode ?? this.selectedCareMode,
    );
  }
}
