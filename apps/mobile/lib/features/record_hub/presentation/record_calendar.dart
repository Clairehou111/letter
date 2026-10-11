import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../experience/theme/experience_foundation.dart';
import '../../cycle/domain/local_date.dart';
import '../domain/record_calendar_month.dart';

/// Cancel returns null; tapping one eligible day returns it immediately.
Future<LocalDate?> showRecordCalendar({
  required BuildContext context,
  required LocalDate selectedDate,
  required LocalDate today,
  Set<LocalDate> savedDates = const {},
  LocalDate? firstDate,
  LocalDate? lastDate,
}) => showModalBottomSheet<LocalDate>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (sheetContext) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(6, 20, 6, 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RecordCalendar(
                selectedDate: selectedDate,
                today: today,
                savedDates: savedDates,
                firstDate: firstDate,
                lastDate: lastDate,
                onDateSelected: (date) => Navigator.of(sheetContext).pop(date),
              ),
              const SizedBox(height: ExperienceSpacing.sm),
              TextButton(
                key: const Key('record-calendar-cancel'),
                style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);

/// Saved markers come only from source dates supplied by the caller.
/// [firstDate]/[lastDate] support a Cycle chooser without restricting Record.
final class RecordCalendar extends StatefulWidget {
  const RecordCalendar({
    required this.selectedDate,
    required this.today,
    required this.onDateSelected,
    super.key,
    this.savedDates = const {},
    this.firstDate,
    this.lastDate,
  });

  final LocalDate selectedDate;
  final LocalDate today;
  final ValueChanged<LocalDate> onDateSelected;
  final Set<LocalDate> savedDates;
  final LocalDate? firstDate;
  final LocalDate? lastDate;

  @override
  State<RecordCalendar> createState() => _RecordCalendarState();
}

final class _RecordCalendarState extends State<RecordCalendar> {
  late RecordCalendarMonth _month;
  int _monthDirection = 1;
  LocalDate? _pressedDate;

  LocalDate get _firstDate => widget.firstDate ?? const LocalDate(1, 1, 1);
  LocalDate get _lastDate {
    final bound = widget.lastDate;
    return bound != null && bound.isBefore(widget.today) ? bound : widget.today;
  }

  @override
  void initState() {
    super.initState();
    _month = RecordCalendarMonth.of(_visibleSelection());
  }

  @override
  void didUpdateWidget(covariant RecordCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate ||
        oldWidget.firstDate != widget.firstDate ||
        oldWidget.lastDate != widget.lastDate) {
      _month = RecordCalendarMonth.of(_visibleSelection());
    }
  }

  LocalDate _visibleSelection() {
    if (widget.selectedDate.isAfter(_lastDate)) return _lastDate;
    if (widget.selectedDate.isBefore(_firstDate)) return _firstDate;
    return widget.selectedDate;
  }

  bool _eligible(LocalDate date) =>
      !date.isBefore(_firstDate) && !date.isAfter(_lastDate);

  RecordCalendarMonth? _adjacent(int direction) {
    try {
      final next = _month.shift(direction);
      return next.intersects(firstDate: _firstDate, lastDate: _lastDate)
          ? next
          : null;
    } on RangeError {
      return null;
    }
  }

  void _changeMonth(RecordCalendarMonth next) {
    setState(() {
      _monthDirection = next.firstDay.isBefore(_month.firstDay) ? -1 : 1;
      _month = next;
      _pressedDate = null;
    });
  }

  Future<void> _chooseYear() async {
    final year = await showDialog<int>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: SizedBox(
          width: 360,
          height: math.min(MediaQuery.sizeOf(dialogContext).height * .7, 420),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(ExperienceSpacing.sm),
                child: Text(
                  'Choose year',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Expanded(
                child: YearPicker(
                  firstDate: _firstDate.asLocalDateTime,
                  lastDate: _lastDate.asLocalDateTime,
                  currentDate: widget.today.asLocalDateTime,
                  selectedDate: _month.firstDay.asLocalDateTime,
                  onChanged: (date) =>
                      Navigator.of(dialogContext).pop(date.year),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || year == null) return;
    var next = RecordCalendarMonth(year, _month.month);
    if (next.lastDay.isBefore(_firstDate)) {
      next = RecordCalendarMonth.of(_firstDate);
    } else if (next.firstDay.isAfter(_lastDate)) {
      next = RecordCalendarMonth.of(_lastDate);
    }
    _changeMonth(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final localizations = MaterialLocalizations.of(context);
    final previous = _adjacent(-1);
    final next = _adjacent(1);
    final cells = _month.cells(
      firstDayOfWeek: localizations.firstDayOfWeekIndex,
    );
    final scale = MediaQuery.textScalerOf(context);
    final numeral = TextPainter(
      text: TextSpan(text: '88', style: ExperienceType.data(scheme.onSurface)),
      textScaler: scale,
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();
    final cellWidth = math.max(
      ExperienceSpacing.minTouchTarget,
      numeral.width + 8,
    );
    final cellHeight = math.max(
      ExperienceSpacing.minTouchTarget,
      numeral.height + 16,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: ExperienceSpacing.sm),
          child: Semantics(
            header: true,
            child: Text(
              localizations.formatFullDate(widget.selectedDate.asLocalDateTime),
              key: const Key('record-calendar-full-date'),
              style: theme.textTheme.titleLarge,
            ),
          ),
        ),
        const SizedBox(height: ExperienceSpacing.sm),
        Row(
          children: [
            IconButton(
              key: const Key('record-calendar-previous-month'),
              tooltip: 'Previous month',
              onPressed: previous == null ? null : () => _changeMonth(previous),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: TextButton(
                key: const Key('record-calendar-year'),
                style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                onPressed: _chooseYear,
                child: Text(
                  localizations.formatMonthYear(
                    _month.firstDay.asLocalDateTime,
                  ),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ),
            IconButton(
              key: const Key('record-calendar-next-month'),
              tooltip: 'Next month',
              onPressed: next == null ? null : () => _changeMonth(next),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        AnimatedSwitcher(
          duration: ExperienceMotion.reducedMotion(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeOutCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: Offset(_monthDirection * .04, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topCenter,
            children: [
              for (final child in previous)
                ExcludeSemantics(child: IgnorePointer(child: child)),
              ?current,
            ],
          ),
          child: LayoutBuilder(
            key: ValueKey(
              'record-calendar-month-${_month.year}-${_month.month}',
            ),
            builder: (context, constraints) {
              final width = math.max(constraints.maxWidth, 7 * cellWidth);
              final grid = SizedBox(
                width: width,
                child: Column(
                  children: [
                    Row(
                      children: [
                        for (var column = 0; column < 7; column++)
                          Expanded(
                            child: ExcludeSemantics(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Text(
                                  localizations.narrowWeekdays[(column +
                                          localizations.firstDayOfWeekIndex) %
                                      7],
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    for (var row = 0; row < cells.length ~/ 7; row++)
                      Row(
                        children: [
                          for (var column = 0; column < 7; column++)
                            Expanded(
                              child: SizedBox(
                                height: cellHeight,
                                child: _cell(context, cells[row * 7 + column]),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              );
              if (width <= constraints.maxWidth) return grid;
              // Keep 44-pixel controls reachable when embedded in a narrow host.
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: grid,
              );
            },
          ),
        ),
        const SizedBox(height: ExperienceSpacing.sm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: ExperienceSpacing.sm),
          child: Row(
            children: [
              Icon(Icons.circle, size: 6, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Flexible(
                child: Text('Saved records', style: theme.textTheme.bodySmall),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cell(BuildContext context, LocalDate? date) =>
      date == null ? const SizedBox.shrink() : _day(context, date);

  Widget _day(BuildContext context, LocalDate date) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selected = date == widget.selectedDate;
    final isToday = date == widget.today;
    final saved = widget.savedDates.contains(date);
    final eligible = _eligible(date);
    final color = selected ? scheme.onPrimary : scheme.onSurface;
    final fullDate = MaterialLocalizations.of(
      context,
    ).formatFullDate(date.asLocalDateTime);
    return Semantics(
      label:
          '$fullDate${isToday ? ', Today' : ''}${saved ? ', Saved records' : ''}${date.isAfter(widget.today) ? ', Future date' : ''}',
      button: true,
      selected: selected,
      enabled: eligible,
      onTap: eligible ? () => widget.onDateSelected(date) : null,
      excludeSemantics: true,
      child: Material(
        color: selected
            ? scheme.primary
            : _pressedDate == date
            ? scheme.primary.withValues(alpha: .16)
            : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: ExperienceRadius.chipRadius,
          side: isToday
              ? BorderSide(color: scheme.primary, width: 1.5)
              : BorderSide.none,
        ),
        child: InkWell(
          key: Key('record-calendar-day-$date'),
          borderRadius: ExperienceRadius.chipRadius,
          onTap: eligible ? () => widget.onDateSelected(date) : null,
          onHighlightChanged: eligible
              ? (pressed) =>
                    setState(() => _pressedDate = pressed ? date : null)
              : null,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${date.day}',
                style:
                    ExperienceType.data(
                      eligible ? color : scheme.onSurfaceVariant,
                    ).copyWith(
                      fontWeight: selected || isToday
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
              ),
              SizedBox(
                height: 7,
                child: saved ? Icon(Icons.circle, size: 5, color: color) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
