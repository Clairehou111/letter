import 'package:flutter/material.dart';

import '../../../design_system/lovable/letter_theme.dart';
import '../../cycle/domain/local_date.dart';
import 'spectrum_log_view_model.dart';

const List<Color> _spectrumSeverityRamp = [
  Color(0xFF6E7BA8),
  Color(0xFFA97E92),
  Color(0xFFC06F7F),
  LetterColors.coral,
  Color(0xFFD65F70),
];

const Map<int, String> _spectrumSeverityLabels = {
  1: 'Minimal',
  2: 'Mild',
  3: 'Moderate',
  4: 'Severe',
  5: 'Extreme',
};

/// Lovable's generated Spectrum Log presentation, transplanted into the
/// production Letter Within theme. The view receives only confirmed local records;
/// its visual hierarchy intentionally leaves missing observations blank.
class SpectrumLog extends StatefulWidget {
  const SpectrumLog({super.key, required this.data, this.horizontalInset = 20});

  final SpectrumData data;
  final double horizontalInset;

  @override
  State<SpectrumLog> createState() => _SpectrumLogState();
}

class _SpectrumLogState extends State<SpectrumLog> {
  SymptomKey _filter = SymptomKey.all;

  @override
  Widget build(BuildContext context) {
    final summaries = widget.data.summariesFor(_filter);
    final trends = widget.data.trendsFor(_filter);
    final confirmed = widget.data.confirmedCountFor(_filter);
    final cyclesCovered = widget.data.cyclesCoveredFor(_filter);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            widget.horizontalInset,
            20,
            widget.horizontalInset,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('LETTERS · PATTERNS', style: letterEyebrow()),
              const SizedBox(height: 6),
              Text('Spectrum Log', style: letterSerif(size: 30)),
              const SizedBox(height: 10),
              const Text(
                'Your typical level on each of the 14 days before a recorded '
                'period, with variation across cycles. Unrated days stay blank.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: LetterColors.muted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: kTapTarget + 8,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: widget.horizontalInset),
            children: [
              for (final key in SymptomKey.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _FilterChip(
                    label: symptomLabels[key]!,
                    selected: key == _filter,
                    onTap: () => setState(() => _filter = key),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: widget.horizontalInset),
          child: Text(
            '$confirmed confirmed ${confirmed == 1 ? 'rating' : 'ratings'} · '
            '$cyclesCovered ${cyclesCovered == 1 ? 'cycle' : 'cycles'} covered',
            style: const TextStyle(fontSize: 12.5, color: LetterColors.muted),
          ),
        ),
        const SizedBox(height: 14),
        if (confirmed == 0)
          _EmptyState(
            note: widget.data.note,
            horizontalInset: widget.horizontalInset,
          )
        else
          _Spectrum(
            summaries: summaries,
            horizontalInset: widget.horizontalInset == 0 ? 0 : 16,
            onSelect: _showDaySource,
          ),
        const SizedBox(height: 16),
        if (trends.isNotEmpty)
          _CycleTrend(points: trends, horizontalInset: widget.horizontalInset),
        Padding(
          padding: EdgeInsets.fromLTRB(
            widget.horizontalInset,
            12,
            widget.horizontalInset,
            28,
          ),
          child: Text(
            'Each mark is the median of cycle-level daily peaks. The thin range '
            'shows cycle-to-cycle variation; fewer than three cycles is marked '
            'limited. Tap a day to see its source records.',
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.55,
              color: LetterColors.muted,
            ),
          ),
        ),
      ],
    );
  }

  /// Records whose distance to their anchor period matches the tapped day.
  List<SourceRecord> _recordsForDay(int day) {
    return widget.data.records.where((record) {
      final offset = record.date.epochDay - record.anchorPeriodStart.epochDay;
      final matchesFilter =
          _filter == SymptomKey.all || record.symptom == _filter;
      return offset == day && matchesFilter;
    }).toList();
  }

  Future<void> _showDaySource(int day) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: 20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: _DayDetail(
            day: day,
            summary: widget.data.summariesFor(_filter)[day]!,
            records: _recordsForDay(day),
          ),
        ),
      ),
    );
  }
}

class _Spectrum extends StatelessWidget {
  const _Spectrum({
    required this.summaries,
    required this.onSelect,
    required this.horizontalInset,
  });

  final Map<int, SpectrumDaySummary> summaries;
  final ValueChanged<int> onSelect;
  final double horizontalInset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalInset),
      child: Column(
        children: [
          ExcludeSemantics(
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.3,
              child: SizedBox(
                height: 132,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final day in dayKeys)
                      Expanded(child: _DayColumn(summary: summaries[day]!)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: kTapTarget,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: dayKeys.length,
              separatorBuilder: (_, _) => const SizedBox(width: 4),
              itemBuilder: (context, index) {
                final day = dayKeys[index];
                return _DaySelector(
                  day: day,
                  summary: summaries[day]!,
                  onTap: () => onSelect(day),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: const Row(
              children: [
                Expanded(
                  child: Text(
                    '14 days before period',
                    style: TextStyle(fontSize: 11, color: LetterColors.muted),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Day before period',
                    textAlign: TextAlign.end,
                    style: TextStyle(fontSize: 11, color: LetterColors.muted),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const _SeverityLegend(),
        ],
      ),
    );
  }
}

class _SeverityLegend extends StatelessWidget {
  const _SeverityLegend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 6,
      children: [
        for (var level = 1; level <= 5; level += 1)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _spectrumSeverityRamp[level - 1],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                _spectrumSeverityLabels[level]!,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: LetterColors.muted,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _DaySelector extends StatelessWidget {
  const _DaySelector({
    required this.day,
    required this.summary,
    required this.onTap,
  });

  final int day;
  final SpectrumDaySummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final detail = summary.typical == null
        ? 'no confirmed rating'
        : 'typical ${_severityLabel(summary.typical!)}, across '
              '${summary.cycleCount} ${summary.cycleCount == 1 ? 'cycle' : 'cycles'}';
    return Semantics(
      button: true,
      label:
          '${day.abs()} ${day.abs() == 1 ? 'day' : 'days'} before period, $detail',
      child: InkWell(
        key: Key('spectrum-day-$day'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: kTapTarget,
          height: kTapTarget,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: LetterColors.border, width: 1),
          ),
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: Text(
              'd$day',
              style: TextStyle(
                fontSize: 11,
                color: LetterColors.muted,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({required this.summary});

  final SpectrumDaySummary summary;

  @override
  Widget build(BuildContext context) {
    final hasValue = summary.typical != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1.5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (hasValue)
            Text(
              summary.hasLimitedEvidence ? '•' : '',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
            )
          else
            const Text(
              '–',
              style: TextStyle(fontSize: 10, color: LetterColors.muted),
            ),
          const SizedBox(height: 4),
          SizedBox(
            height: 106,
            width: double.infinity,
            child: CustomPaint(
              painter: hasValue
                  ? _SpectrumColumnPainter(summary)
                  : _DashedPlaceholderPainter(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpectrumColumnPainter extends CustomPainter {
  const _SpectrumColumnPainter(this.summary);

  final SpectrumDaySummary summary;

  @override
  void paint(Canvas canvas, Size size) {
    double yFor(double severity) =>
        size.height - 10 - ((severity - 1) / 4) * (size.height - 20);

    final typical = summary.typical!;
    final bar = RRect.fromRectAndRadius(
      Rect.fromLTRB(2, yFor(typical), size.width - 2, size.height - 2),
      const Radius.circular(4),
    );
    canvas.drawRRect(
      bar,
      Paint()..color = _spectrumSeverityRamp[typical.round().clamp(1, 5) - 1],
    );

    if (summary.minimum == summary.maximum) return;
    final x = size.width / 2;
    final top = yFor(summary.maximum!.toDouble());
    final bottom = yFor(summary.minimum!.toDouble());
    final rangePaint = Paint()
      ..color = LetterColors.ink
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(x, top), Offset(x, bottom), rangePaint);
    canvas.drawLine(Offset(x - 3, top), Offset(x + 3, top), rangePaint);
    canvas.drawLine(Offset(x - 3, bottom), Offset(x + 3, bottom), rangePaint);
  }

  @override
  bool shouldRepaint(covariant _SpectrumColumnPainter oldDelegate) =>
      oldDelegate.summary != summary;
}

/// Visual signal for "no confirmed observation" — deliberately not a zero bar.
class _DashedPlaceholderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = LetterColors.border
      ..strokeWidth = 1;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTRB(2, size.height - 44, size.width - 2, size.height - 2),
      const Radius.circular(4),
    );
    canvas.drawRRect(rect, paint..style = PaintingStyle.stroke);
    paint.style = PaintingStyle.fill;
    for (var y = size.height - 40; y < size.height - 4; y += 6) {
      canvas.drawLine(Offset(2, y), Offset(size.width - 2, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DayDetail extends StatelessWidget {
  const _DayDetail({
    required this.day,
    required this.summary,
    required this.records,
  });

  final int day;
  final SpectrumDaySummary summary;
  final List<SourceRecord> records;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${day.abs()} ${day.abs() == 1 ? 'DAY' : 'DAYS'} BEFORE PERIOD',
          style: letterEyebrow(),
        ),
        const SizedBox(height: 8),
        Text(
          summary.typical == null
              ? 'No confirmed rating for this day.'
              : 'Typical · ${_severityLabel(summary.typical!)}',
          style: letterSerif(size: 17),
        ),
        const SizedBox(height: 12),
        if (summary.typical != null) ...[
          Text(
            '${summary.cycleCount} ${summary.cycleCount == 1 ? 'cycle' : 'cycles'} · '
            'range ${_spectrumSeverityLabels[summary.minimum]}–${_spectrumSeverityLabels[summary.maximum]}'
            '${summary.hasLimitedEvidence ? ' · limited evidence' : ''}',
            style: const TextStyle(fontSize: 12.5, color: LetterColors.muted),
          ),
          const SizedBox(height: 12),
        ],
        if (records.isEmpty)
          const Text(
            'Nothing was recorded on this day, so nothing is shown. '
            'It is not counted as zero.',
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: LetterColors.muted,
            ),
          )
        else
          for (final record in records)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${record.symptomLabel} · ${_spectrumSeverityLabels[record.rating]}',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_fmtLocal(record.date)} · ${record.cycleLabel} · '
                    'anchored to period starting ${_fmtLocal(record.anchorPeriodStart)} · '
                    '${record.provenanceLabel == null ? '' : '${record.provenanceLabel} · '}'
                    'confirmed ${_fmtTimestamp(record.confirmedAt)}',
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: LetterColors.muted,
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String _fmtLocal(LocalDate date) =>
      '${_months[date.month - 1]} ${date.day}';

  static String _fmtTimestamp(DateTime date) {
    final local = date.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${_months[local.month - 1]} ${local.day}, $hour:$minute';
  }
}

class _CycleTrend extends StatelessWidget {
  const _CycleTrend({required this.points, required this.horizontalInset});

  final List<SpectrumCycleTrend> points;
  final double horizontalInset;

  @override
  Widget build(BuildContext context) {
    final first = points.first.anchorPeriodStart;
    final last = points.last.anchorPeriodStart;
    return Semantics(
      label: [
        'Across-cycle trend.',
        for (final point in points)
          'Period ${point.anchorPeriodStart}: ${_severityLabel(point.typical)}, '
              '${point.ratedDayCount} rated days.',
      ].join(' '),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: horizontalInset),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: LetterColors.mist.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: LetterColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ACROSS CYCLES', style: letterEyebrow()),
            const SizedBox(height: 6),
            Text('Typical pre-period level', style: letterSerif(size: 18)),
            const SizedBox(height: 4),
            const Text(
              'Each point is the median daily peak in that cycle’s d−14 to d−1 window.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: LetterColors.muted,
              ),
            ),
            const SizedBox(height: 12),
            ExcludeSemantics(
              child: SizedBox(
                height: 110,
                width: double.infinity,
                child: CustomPaint(painter: _TrendPainter(points)),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: Text(_shortDate(first), style: _trendLabel)),
                if (points.length < 3)
                  const Text('Limited', style: _trendLabel),
                Expanded(
                  child: Text(
                    _shortDate(last),
                    textAlign: TextAlign.end,
                    style: _trendLabel,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static const _trendLabel = TextStyle(fontSize: 11, color: LetterColors.muted);
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter(this.points);

  final List<SpectrumCycleTrend> points;

  @override
  void paint(Canvas canvas, Size size) {
    final guide = Paint()
      ..color = LetterColors.border
      ..strokeWidth = 1;
    final line = Paint()
      ..color = LetterColors.teal
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final dot = Paint()
      ..color = LetterColors.teal
      ..style = PaintingStyle.fill;
    for (var level = 1; level <= 5; level += 1) {
      final y = size.height - ((level - 1) / 4) * size.height;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), guide);
    }
    if (points.isEmpty) return;
    final path = Path();
    for (var index = 0; index < points.length; index += 1) {
      final x = points.length == 1
          ? size.width / 2
          : index / (points.length - 1) * size.width;
      final y = size.height - ((points[index].typical - 1) / 4) * size.height;
      final position = Offset(x, y);
      index == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      canvas.drawCircle(position, 4, dot);
    }
    if (points.length > 1) canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.points != points;
}

String _severityLabel(double value) {
  if (value == value.roundToDouble()) {
    return _spectrumSeverityLabels[value.round()]!;
  }
  final lower = value.floor().clamp(1, 5);
  final upper = value.ceil().clamp(1, 5);
  return '${_spectrumSeverityLabels[lower]}–${_spectrumSeverityLabels[upper]}';
}

String _shortDate(LocalDate value) => '${value.month}/${value.day}';

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.note, required this.horizontalInset});

  final String note;
  final double horizontalInset;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: horizontalInset),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: LetterColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nothing to show yet', style: letterSerif(size: 18)),
          const SizedBox(height: 8),
          Text(
            '$note A spectrum appears once you have confirmed ratings in the days '
            'before a recorded period.',
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.55,
              color: LetterColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(kTapTarget),
        onTap: onTap,
        child: Container(
          height: kTapTarget,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: selected ? LetterColors.ink : LetterColors.paper,
            borderRadius: BorderRadius.circular(kTapTarget),
            border: Border.all(color: LetterColors.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              color: selected ? LetterColors.paper : LetterColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

/// Existing production call-site name retained as a compatibility wrapper.
/// It contains no hormone or prediction semantics.
class HormonalSpectrumStrip extends StatelessWidget {
  const HormonalSpectrumStrip({required this.viewModel, super.key});

  final SpectrumLogViewModel viewModel;

  @override
  Widget build(BuildContext context) =>
      SpectrumLog(data: viewModel.data, horizontalInset: 0);
}
