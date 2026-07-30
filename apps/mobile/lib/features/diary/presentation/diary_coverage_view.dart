import 'package:flutter/material.dart';

import '../../../design_system/letter_theme.dart';
import '../../cycle/domain/local_date.dart';
import '../domain/diary_enrollment.dart';

/// Coverage grid showing which days have diary entries and which are missing
/// (spec: REQ-004 — covers at least two cycles, displays coverage not streak).
///
/// Each cell represents a day. Filled cells indicate a recorded entry; empty
/// cells are missing days. The app never imputes or backfills.
class DiaryCoverageView extends StatelessWidget {
  const DiaryCoverageView({
    required this.enrollment,
    required this.entries,
    super.key,
    this.onDayTap,
  });

  final DiaryEnrollment enrollment;
  final List<DiaryEntry> entries;
  final ValueChanged<LocalDate>? onDayTap;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return _EmptyCoverage(enrollment: enrollment);
    }

    final entryDates = entries.map((entry) => entry.experiencedDate).toSet();

    final start = _startOfWeek(entries.first.experiencedDate);
    final end = _endOfWeek(
      entries.last.experiencedDate.compareTo(
            LocalDate.fromDateTime(DateTime.now()),
          ) >
          0
          ? entries.last.experiencedDate
          : LocalDate.fromDateTime(DateTime.now()),
    );

    final weeks = <List<LocalDate>>[];
    var current = start;
    while (current.compareTo(end) <= 0) {
      final week = List.generate(
        7,
        (index) => current.addDays(index),
        growable: false,
      );
      weeks.add(week);
      current = current.addDays(7);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WeekdayHeader(),
        const SizedBox(height: LetterSpacing.xs),
        for (final week in weeks)
          Padding(
            padding: const EdgeInsets.only(bottom: LetterSpacing.xxs),
            child: Row(
              children: week.map((date) {
                final hasEntry = entryDates.contains(date);
                final isAfterStart = date.compareTo(
                      LocalDate.fromDateTime(enrollment.startedAt),
                    ) >=
                    0;

                final canHaveEntry =
                    isAfterStart && enrollment.isActive ||
                    (enrollment.status == DiaryEnrollmentStatus.paused &&
                        date.compareTo(
                              LocalDate.fromDateTime(enrollment.startedAt),
                            ) >=
                            0);

                return Expanded(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Material(
                        color: hasEntry
                            ? LetterColors.teal
                            : canHaveEntry
                            ? LetterColors.tealSoft
                            : LetterColors.mist,
                        borderRadius: BorderRadius.circular(
                          LetterRadius.control,
                        ),
                        child: InkWell(
                          onTap: canHaveEntry
                              ? () => onDayTap?.call(date)
                              : null,
                          borderRadius: BorderRadius.circular(
                            LetterRadius.control,
                          ),
                          child: Center(
                            child: Text(
                              date.day.toString(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: hasEntry
                                    ? Colors.white
                                    : LetterColors.muted,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        const SizedBox(height: LetterSpacing.md),
        _CoverageLegend(),
      ],
    );
  }

  static LocalDate _startOfWeek(LocalDate date) {
    // Monday = 1, Sunday = 7 in DateTime; adjust to Monday start
    final dt = date.asLocalDateTime;
    final daysFromMonday = (dt.weekday - 1);
    return LocalDate.fromEpochDay(date.epochDay - daysFromMonday);
  }

  static LocalDate _endOfWeek(LocalDate date) {
    final dt = date.asLocalDateTime;
    final daysToSunday = 7 - dt.weekday;
    return LocalDate.fromEpochDay(date.epochDay + daysToSunday);
  }
}

class _WeekdayHeader extends StatelessWidget {
  static const _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _labels.map((label) {
        return Expanded(
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: LetterColors.muted,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _CoverageLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _LegendDot(color: LetterColors.teal, label: 'Recorded'),
        const SizedBox(width: LetterSpacing.md),
        _LegendDot(color: LetterColors.tealSoft, label: 'No entry'),
        const SizedBox(width: LetterSpacing.md),
        _LegendDot(color: LetterColors.mist, label: 'Before enrollment'),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: LetterSpacing.xxs),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: LetterColors.muted,
          ),
        ),
      ],
    );
  }
}

class _EmptyCoverage extends StatelessWidget {
  const _EmptyCoverage({required this.enrollment});

  final DiaryEnrollment enrollment;

  @override
  Widget build(BuildContext context) {
    final started = enrollment.startedAt.toLocal();
    final dateLabel =
        '${started.year}-${started.month.toString().padLeft(2, '0')}-${started.day.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(LetterSpacing.lg),
      decoration: BoxDecoration(
        color: LetterColors.surface,
        borderRadius: BorderRadius.circular(LetterRadius.panel),
        border: Border.all(color: LetterColors.line),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.calendar_month_outlined,
            size: 36,
            color: LetterColors.moonMetal,
          ),
          const SizedBox(height: LetterSpacing.md),
          const Text(
            'No entries yet',
            style: TextStyle(
              fontFamily: 'Newsreader',
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: LetterSpacing.xs),
          Text(
            'Your diary started on $dateLabel.\n'
            'Add your first daily entry to see coverage.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: LetterColors.muted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
