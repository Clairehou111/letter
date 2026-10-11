import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../experience/components/interaction_controls.dart';
import '../../../experience/theme/experience_foundation.dart';
import '../../record_hub/domain/record_calendar_month.dart';
import '../domain/local_date.dart';

/// A presentation draft. Selecting a band never writes periods or daily flow.
final class PeriodRangeSelection {
  const PeriodRangeSelection({
    this.startDate,
    this.endDate,
    this.ongoing = false,
  });
  final LocalDate? startDate, endDate;
  final bool ongoing;

  bool get isComplete =>
      startDate != null &&
      (ongoing || endDate != null && !endDate!.isBefore(startDate!));
}

enum _Boundary { start, end, none }

/// A single calendar for the period's two boundaries, inside its existing sheet.
/// The caller owns the explicit Save action and any source-impact confirmation.
class PeriodRangeEditor extends StatefulWidget {
  const PeriodRangeEditor({
    required this.today,
    required this.onChanged,
    this.initialStartDate,
    this.initialEndDate,
    this.initialOngoing = false,
    this.firstDate,
    this.enabled = true,
    super.key,
  });

  final LocalDate today;
  final LocalDate? initialStartDate, initialEndDate, firstDate;
  final bool initialOngoing, enabled;
  final ValueChanged<PeriodRangeSelection> onChanged;

  @override
  State<PeriodRangeEditor> createState() => _PeriodRangeEditorState();
}

class _PeriodRangeEditorState extends State<PeriodRangeEditor> {
  late LocalDate? _start = widget.initialStartDate;
  late LocalDate? _end = widget.initialOngoing ? null : widget.initialEndDate;
  late bool _ongoing = widget.initialOngoing;
  late _Boundary _boundary = _start == null
      ? _Boundary.start
      : _end == null && !_ongoing
      ? _Boundary.end
      : _Boundary.none;
  late RecordCalendarMonth _month = RecordCalendarMonth.of(
    _start != null && !_start!.isAfter(widget.today) ? _start! : widget.today,
  );
  String? _error;

  LocalDate get _first => widget.firstDate ?? const LocalDate(1, 1, 1);

  void _emit() => widget.onChanged(
    PeriodRangeSelection(
      startDate: _start,
      endDate: _ongoing ? null : _end,
      ongoing: _ongoing,
    ),
  );

  bool _eligible(LocalDate date) =>
      !date.isBefore(_first) && !date.isAfter(widget.today);

  void _select(LocalDate date) {
    if (!widget.enabled || !_eligible(date)) return;
    setState(() {
      _error = null;
      if (_boundary == _Boundary.none) {
        // A fresh band always starts with Start, then End. Direct boundary
        // controls preserve the other boundary instead of restarting the band.
        _start = date;
        _end = null;
        _boundary = _ongoing ? _Boundary.none : _Boundary.end;
      } else if (_boundary == _Boundary.start) {
        if (_end != null && date.isAfter(_end!)) {
          _error =
              'Start must be on or before End. Your selected range has not changed.';
          return;
        }
        _start = date;
        _boundary = _end == null && !_ongoing ? _Boundary.end : _Boundary.none;
      } else {
        if (_start == null) {
          _start = date;
          return;
        }
        if (date.isBefore(_start!)) {
          _error =
              'End must be on or after Start. Tap Start to begin a different range.';
          return;
        }
        _end = date;
        _ongoing = false;
        _boundary = _Boundary.none;
      }
    });
    if (_error == null) _emit();
  }

  void _editBoundary(_Boundary boundary) {
    if (!widget.enabled) return;
    setState(() {
      _boundary = boundary;
      _error = null;
      if (boundary == _Boundary.end) _ongoing = false;
      final date = boundary == _Boundary.start ? _start : _end ?? _start;
      if (date != null && _eligible(date)) {
        _month = RecordCalendarMonth.of(date);
      }
    });
    _emit();
  }

  RecordCalendarMonth? _adjacent(int direction) {
    try {
      final month = _month.shift(direction);
      return month.intersects(firstDate: _first, lastDate: widget.today)
          ? month
          : null;
    } on RangeError {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = MaterialLocalizations.of(context);
    final previous = _adjacent(-1), next = _adjacent(1);
    final reducedMotion = ExperienceMotion.reducedMotion(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _boundaryControl(
                context,
                _Boundary.start,
                'Start',
                _start,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _boundaryControl(context, _Boundary.end, 'End', _end),
            ),
          ],
        ),
        SwitchListTile(
          key: const Key('period-range-ongoing'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Still bleeding'),
          subtitle: _ongoing ? const Text('No end date yet') : null,
          value: _ongoing,
          onChanged: widget.enabled
              ? (value) {
                  setState(() {
                    _ongoing = value;
                    _end = null;
                    _boundary = _start == null
                        ? _Boundary.start
                        : value
                        ? _Boundary.none
                        : _Boundary.end;
                    _error = null;
                  });
                  _emit();
                }
              : null,
        ),
        Semantics(
          liveRegion: true,
          child: Text(
            _boundary == _Boundary.start
                ? 'Choose Start, then End.'
                : _boundary == _Boundary.end
                ? 'Choose End. The same day is allowed.'
                : _ongoing
                ? 'Ongoing through today. No end date is saved.'
                : 'Tap Start or End to adjust a boundary.',
            style: theme.textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              key: const Key('period-range-previous-month'),
              tooltip: 'Previous month',
              onPressed: widget.enabled && previous != null
                  ? () => setState(() => _month = previous)
                  : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Semantics(
                header: true,
                liveRegion: true,
                child: Text(
                  localizations.formatMonthYear(
                    _month.firstDay.asLocalDateTime,
                  ),
                  key: const Key('period-range-month'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ),
            IconButton(
              key: const Key('period-range-next-month'),
              tooltip: 'Next month',
              onPressed: widget.enabled && next != null
                  ? () => setState(() => _month = next)
                  : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        AnimatedSwitcher(
          duration: reducedMotion
              ? Duration.zero
              : const Duration(milliseconds: 160),
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topCenter,
            children: [
              for (final child in previous)
                IgnorePointer(child: ExcludeSemantics(child: child)),
              ?current,
            ],
          ),
          child: _calendar(context),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Text(
              _error!,
              key: const Key('period-range-error'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          'The band marks period dates. Daily flow stays as you recorded it.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _boundaryControl(
    BuildContext context,
    _Boundary boundary,
    String label,
    LocalDate? date,
  ) {
    final theme = Theme.of(context);
    final description = boundary == _Boundary.end && _ongoing
        ? 'Ongoing'
        : date == null
        ? 'Choose date'
        : MaterialLocalizations.of(
            context,
          ).formatShortDate(date.asLocalDateTime);
    return Semantics(
      button: true,
      enabled: widget.enabled,
      selected: _boundary == boundary,
      label: '$label, $description',
      onTap: widget.enabled ? () => _editBoundary(boundary) : null,
      excludeSemantics: true,
      child: InteractionSurface(
        key: Key('period-range-${label.toLowerCase()}'),
        color: theme.colorScheme.surfaceContainerHighest,
        onTap: widget.enabled ? () => _editBoundary(boundary) : null,
        selected: _boundary == boundary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(description, style: theme.textTheme.titleMedium),
          ],
        ),
      ),
    );
  }

  Widget _calendar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final localizations = MaterialLocalizations.of(context);
    final numeral = TextPainter(
      text: TextSpan(text: '88', style: ExperienceType.data(scheme.onSurface)),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();
    final cellWidth = math.max(48.0, numeral.width + 12);
    final cellHeight = math.max(52.0, numeral.height + 20);
    final numberDiameter = math.max(
      36.0,
      math.max(numeral.width, numeral.height) + 8,
    );
    final cells = _month.cells(
      firstDayOfWeek: localizations.firstDayOfWeekIndex,
    );
    return LayoutBuilder(
      key: ValueKey('period-range-grid-${_month.year}-${_month.month}'),
      builder: (context, constraints) {
        final width = math.max(constraints.maxWidth, cellWidth * 7);
        final grid = SizedBox(
          width: width,
          child: Column(
            children: [
              Row(
                children: [
                  for (var column = 0; column < 7; column++)
                    Expanded(
                      child: ExcludeSemantics(
                        child: Text(
                          localizations.narrowWeekdays[(column +
                                  localizations.firstDayOfWeekIndex) %
                              7],
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              for (var row = 0; row < cells.length ~/ 7; row++)
                Row(
                  children: [
                    for (var column = 0; column < 7; column++)
                      Expanded(
                        child: SizedBox(
                          height: cellHeight,
                          child: cells[row * 7 + column] == null
                              ? null
                              : _day(
                                  context,
                                  cells[row * 7 + column]!,
                                  numberDiameter,
                                ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        );
        return width > constraints.maxWidth
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: grid,
              )
            : grid;
      },
    );
  }

  Widget _day(BuildContext context, LocalDate date, double numberDiameter) {
    final scheme = Theme.of(context).colorScheme;
    final start = date == _start, end = !_ongoing && date == _end;
    final endpoint = start || end;
    final rangeEnd = _ongoing ? widget.today : _end ?? _start;
    final inRange =
        _start != null &&
        rangeEnd != null &&
        !date.isBefore(_start!) &&
        !date.isAfter(rangeEnd);
    final today = date == widget.today;
    final eligible = widget.enabled && _eligible(date);
    final label = MaterialLocalizations.of(
      context,
    ).formatFullDate(date.asLocalDateTime);
    return Semantics(
      key: Key('period-range-day-$date'),
      label:
          '$label${start && end
              ? ', Start and End'
              : start
              ? ', Start'
              : end
              ? ', End'
              : inRange
              ? ', In selected period'
              : ''}${today ? ', Today' : ''}${date.isAfter(widget.today) ? ', Future date' : ''}',
      button: true,
      enabled: eligible,
      selected: inRange,
      excludeSemantics: true,
      onTap: eligible ? () => _select(date) : null,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (inRange)
            Positioned(
              left: 0,
              right: 0,
              child: Container(
                key: Key('period-range-band-$date'),
                height: 34,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: .18),
                  borderRadius: BorderRadius.horizontal(
                    left: start ? const Radius.circular(17) : Radius.zero,
                    right: end ? const Radius.circular(17) : Radius.zero,
                  ),
                ),
              ),
            ),
          InteractionSurface(
            color: Colors.transparent,
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            onTap: eligible ? () => _select(date) : null,
            child: Center(
              child: Container(
                width: numberDiameter,
                height: numberDiameter,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: endpoint ? scheme.primary : null,
                  border: today && !endpoint
                      ? Border.all(color: scheme.primary, width: 1.5)
                      : null,
                ),
                child: Center(
                  child: Text(
                    '${date.day}',
                    style:
                        ExperienceType.data(
                          !eligible
                              ? scheme.onSurfaceVariant
                              : endpoint
                              ? scheme.onPrimary
                              : scheme.onSurface,
                        ).copyWith(
                          fontWeight: endpoint || today
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
