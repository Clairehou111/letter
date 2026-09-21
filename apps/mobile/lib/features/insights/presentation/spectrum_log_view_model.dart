import '../../cycle/domain/local_date.dart';
import '../../health_records/domain/health_record.dart';
import '../../patterns/domain/pattern_source.dart';

enum SymptomKey { all, physical, mood, energy, sleep }

const Map<SymptomKey, String> symptomLabels = {
  SymptomKey.all: 'All symptoms',
  SymptomKey.physical: 'Physical',
  SymptomKey.mood: 'Mood',
  SymptomKey.energy: 'Energy',
  SymptomKey.sleep: 'Sleep',
};

/// d-14 through d-1, ordered furthest from the recorded period first.
final List<int> dayKeys = List<int>.generate(14, (index) => -(14 - index));

final class SourceRecord {
  const SourceRecord({
    required this.id,
    required this.date,
    required this.anchorPeriodStart,
    required this.symptom,
    required this.symptomLabel,
    required this.rating,
    required this.confirmedAt,
    required this.cycleLabel,
    this.provenanceLabel,
  });

  final String id;
  final LocalDate date;
  final LocalDate anchorPeriodStart;
  final SymptomKey symptom;
  final String symptomLabel;
  final int rating;
  final DateTime confirmedAt;
  final String cycleLabel;
  final String? provenanceLabel;
}

/// One relative day's cycle-balanced distribution.
final class SpectrumDaySummary {
  const SpectrumDaySummary({
    required this.day,
    required this.typical,
    required this.minimum,
    required this.maximum,
    required this.cycleCount,
  });

  final int day;
  final double? typical;
  final int? minimum;
  final int? maximum;
  final int cycleCount;

  bool get hasValue => typical != null;
  bool get hasLimitedEvidence => cycleCount > 0 && cycleCount < 3;
}

/// A cycle-balanced trend point. Multiple symptoms on one day contribute only
/// that day's strongest confirmed level; the point is the median rated day.
final class SpectrumCycleTrend {
  const SpectrumCycleTrend({
    required this.anchorPeriodStart,
    required this.typical,
    required this.ratedDayCount,
    required this.ratingCount,
  });

  final LocalDate anchorPeriodStart;
  final double typical;
  final int ratedDayCount;
  final int ratingCount;
}

final class SpectrumData {
  const SpectrumData({
    required this.id,
    required this.label,
    required this.note,
    required this.cyclesCovered,
    required this.summaries,
    required this.trends,
    required this.records,
  });

  final String id;
  final String label;
  final String note;
  final int cyclesCovered;
  final Map<SymptomKey, Map<int, SpectrumDaySummary>> summaries;
  final Map<SymptomKey, List<SpectrumCycleTrend>> trends;
  final List<SourceRecord> records;

  Map<int, SpectrumDaySummary> summariesFor(SymptomKey key) =>
      summaries[key] ?? _emptySummaries();

  /// Compatibility/readability projection: typical levels, never raw maxima.
  Map<int, double?> daysFor(SymptomKey key) => {
    for (final entry in summariesFor(key).entries)
      entry.key: entry.value.typical,
  };

  List<SpectrumCycleTrend> trendsFor(SymptomKey key) => trends[key] ?? const [];

  int confirmedCountFor(SymptomKey key) => records
      .where((record) => key == SymptomKey.all || record.symptom == key)
      .length;

  int cyclesCoveredFor(SymptomKey key) => records
      .where((record) => key == SymptomKey.all || record.symptom == key)
      .map((record) => record.anchorPeriodStart)
      .toSet()
      .length;
}

final class SpectrumLogViewModel {
  const SpectrumLogViewModel({required this.data});

  final SpectrumData data;

  int get confirmedRatingCount => data.records.length;
  int get observedDayCount =>
      data.records.map((record) => record.date).toSet().length;

  factory SpectrumLogViewModel.fromSource(PatternSourceSnapshot source) =>
      SpectrumLogViewModel(data: SpectrumLogAdapter.fromSource(source));
}

abstract final class SpectrumLogAdapter {
  static SpectrumData fromSource(PatternSourceSnapshot source) {
    final periods = [...source.periods]
      ..sort((left, right) => left.startDate.compareTo(right.startDate));

    final latestByDay = <String, HealthRecordLike>{};
    for (final record in source.healthRecords.where(
      (record) => record.userConfirmed,
    )) {
      final key = '${record.symptom.name}:${record.experiencedDate}';
      final previous = latestByDay[key];
      if (previous == null || record.updatedAt.isAfter(previous.updatedAt)) {
        latestByDay[key] = HealthRecordLike(record);
      }
    }

    final records = <SourceRecord>[];
    for (final item in latestByDay.values) {
      final anchor = periods.firstWhereOrNull(
        (period) => period.startDate.isAfter(item.date),
      );
      if (anchor == null) continue;
      final day = item.date.epochDay - anchor.startDate.epochDay;
      if (!dayKeys.contains(day)) continue;
      records.add(
        SourceRecord(
          id: item.id,
          date: item.date,
          anchorPeriodStart: anchor.startDate,
          symptom: _categoryFor(item.category),
          symptomLabel: item.symptomLabel,
          rating: item.rating,
          confirmedAt: item.updatedAt,
          cycleLabel: 'Period starting ${anchor.startDate}',
          provenanceLabel: item.provenanceLabel,
        ),
      );
    }
    records.sort((left, right) {
      final byDate = left.date.compareTo(right.date);
      return byDate == 0 ? left.id.compareTo(right.id) : byDate;
    });

    return _dataFromRecords(
      id: _sourceId(source, records),
      records: records,
      note: records.isEmpty
          ? 'No confirmed ratings are anchored to the 14 days before a recorded period yet.'
          : 'Confirmed ratings are aligned to recorded period starts. Missing days stay blank.',
    );
  }

  static SpectrumData _dataFromRecords({
    required String id,
    required List<SourceRecord> records,
    required String note,
  }) {
    final summaries = <SymptomKey, Map<int, SpectrumDaySummary>>{};
    final trends = <SymptomKey, List<SpectrumCycleTrend>>{};
    for (final key in SymptomKey.values) {
      final filtered = records
          .where((record) => key == SymptomKey.all || record.symptom == key)
          .toList();
      final cycleDayPeaks = <LocalDate, Map<int, int>>{};
      final cycleRatingCounts = <LocalDate, int>{};
      for (final record in filtered) {
        final day = record.date.epochDay - record.anchorPeriodStart.epochDay;
        if (!dayKeys.contains(day)) continue;
        final byDay = cycleDayPeaks.putIfAbsent(
          record.anchorPeriodStart,
          () => <int, int>{},
        );
        final current = byDay[day];
        if (current == null || record.rating > current) {
          byDay[day] = record.rating;
        }
        cycleRatingCounts.update(
          record.anchorPeriodStart,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }

      summaries[key] = {
        for (final day in dayKeys)
          day: _summaryForDay(day, cycleDayPeaks.values),
      };
      final points =
          <SpectrumCycleTrend>[
            for (final entry in cycleDayPeaks.entries)
              if (entry.value.isNotEmpty)
                SpectrumCycleTrend(
                  anchorPeriodStart: entry.key,
                  typical: _median(
                    entry.value.values.map((value) => value.toDouble()),
                  ),
                  ratedDayCount: entry.value.length,
                  ratingCount: cycleRatingCounts[entry.key] ?? 0,
                ),
          ]..sort(
            (left, right) =>
                left.anchorPeriodStart.compareTo(right.anchorPeriodStart),
          );
      trends[key] = List.unmodifiable(points);
    }

    return SpectrumData(
      id: id,
      label: 'Observed history',
      note: note,
      cyclesCovered: records
          .map((record) => record.anchorPeriodStart)
          .toSet()
          .length,
      summaries: summaries,
      trends: trends,
      records: List.unmodifiable(records),
    );
  }

  static SpectrumDaySummary _summaryForDay(
    int day,
    Iterable<Map<int, int>> cycleDays,
  ) {
    final values = [
      for (final days in cycleDays)
        if (days[day] case final int value) value,
    ]..sort();
    return SpectrumDaySummary(
      day: day,
      typical: values.isEmpty
          ? null
          : _median(values.map((value) => value.toDouble())),
      minimum: values.isEmpty ? null : values.first,
      maximum: values.isEmpty ? null : values.last,
      cycleCount: values.length,
    );
  }

  static String _sourceId(
    PatternSourceSnapshot source,
    List<SourceRecord> records,
  ) => [
    ...source.periods.map((period) => period.id),
    ...records.map((record) => record.id),
  ].join('|');

  static SymptomKey _categoryFor(SymptomCategory category) =>
      switch (category) {
        SymptomCategory.physical => SymptomKey.physical,
        SymptomCategory.mood => SymptomKey.mood,
        SymptomCategory.energy => SymptomKey.energy,
        SymptomCategory.sleep => SymptomKey.sleep,
      };
}

final class HealthRecordLike {
  HealthRecordLike(this.record)
    : id = record.id,
      date = record.experiencedDate,
      category = record.symptom.category,
      symptomLabel = record.symptom.label,
      rating = record.severity.score,
      updatedAt = record.updatedAt,
      provenanceLabel = record.provenance.label;

  final HealthRecord record;
  final String id;
  final LocalDate date;
  final SymptomCategory category;
  final String symptomLabel;
  final int rating;
  final DateTime updatedAt;
  final String provenanceLabel;
}

double _median(Iterable<double> input) {
  final values = input.toList()..sort();
  final middle = values.length ~/ 2;
  if (values.length.isOdd) return values[middle];
  return (values[middle - 1] + values[middle]) / 2;
}

Map<int, SpectrumDaySummary> _emptySummaries() => {
  for (final day in dayKeys)
    day: SpectrumDaySummary(
      day: day,
      typical: null,
      minimum: null,
      maximum: null,
      cycleCount: 0,
    ),
};

extension _FirstWhereOrNull<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T item) test) {
    for (final item in this) {
      if (test(item)) return item;
    }
    return null;
  }
}
