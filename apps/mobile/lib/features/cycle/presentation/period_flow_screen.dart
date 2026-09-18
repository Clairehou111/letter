import 'package:flutter/material.dart';

import '../../../design_system/lovable/health_record_kit.dart';
import '../../../design_system/lovable/letter_kit.dart';
import '../../../design_system/lovable/letter_theme.dart';
import '../domain/bleeding_flow.dart';
import '../domain/local_date.dart';
import '../domain/period_record.dart';
import '../domain/period_repository.dart';
import 'flow_controls.dart';

class PeriodFlowScreen extends StatefulWidget {
  const PeriodFlowScreen({
    required this.repository,
    required this.record,
    required this.today,
    required this.initialFlowDays,
    super.key,
    this.initialDate,
  });

  final PeriodRepository repository;
  final PeriodRecord record;
  final LocalDate today;
  final List<BleedingDayRecord> initialFlowDays;
  final LocalDate? initialDate;

  @override
  State<PeriodFlowScreen> createState() => _PeriodFlowScreenState();
}

class _PeriodFlowScreenState extends State<PeriodFlowScreen> {
  late LocalDate _selected;
  late Map<LocalDate, BleedingDayRecord> _flowByDate;
  bool _saving = false;
  String? _error;

  LocalDate get _end => widget.record.endDate ?? widget.today;
  int get _dayCount => _end.epochDay - widget.record.startDate.epochDay + 1;

  @override
  void initState() {
    super.initState();
    _flowByDate = {
      for (final flowDay in widget.initialFlowDays) flowDay.date: flowDay,
    };
    final requested = widget.initialDate;
    _selected = requested != null && _contains(requested)
        ? requested
        : widget.record.isOpen && _contains(widget.today)
        ? widget.today
        : widget.record.startDate;
  }

  bool _contains(LocalDate date) =>
      !date.isBefore(widget.record.startDate) && !date.isAfter(_end);

  Future<void> _setFlow(BleedingFlow flow) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await widget.repository.setFlow(
        widget.record.id,
        _selected,
        flow,
        today: widget.today,
      );
      if (mounted) {
        setState(() => _flowByDate[_selected] = saved);
      }
    } on PeriodWriteException catch (error) {
      if (mounted) setState(() => _error = error.userMessage);
    } on Object {
      if (mounted) {
        setState(
          () => _error = 'Letter Within could not save this flow. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setColor(BleedingColor color) async {
    if (_saving || _flowByDate[_selected] == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await widget.repository.setBleedingColor(
        widget.record.id,
        _selected,
        color,
      );
      if (mounted) setState(() => _flowByDate[_selected] = saved);
    } on PeriodWriteException catch (error) {
      if (mounted) setState(() => _error = error.userMessage);
    } on Object {
      if (mounted) {
        setState(
          () => _error = 'Letter Within could not save this color. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _clearFlow() async {
    if (_saving || _flowByDate[_selected] == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.clearFlow(widget.record.id, _selected);
      if (mounted) setState(() => _flowByDate.remove(_selected));
    } on PeriodWriteException catch (error) {
      if (mounted) setState(() => _error = error.userMessage);
    } on Object {
      if (mounted) {
        setState(
          () => _error = 'Letter Within could not clear this flow. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final flow = _flowByDate[_selected]?.flow;
    final bleedingColor = _flowByDate[_selected]?.color;
    final stacked = context.isLovableNarrow || context.isLovableLargeText;
    return ScreenScaffold(
      key: const Key('period-flow-screen'),
      showHeader: false,
      stickyAction: PrimaryButton(
        key: const Key('flow-done'),
        label: 'Done',
        expand: true,
        onPressed: _saving ? null : () => Navigator.of(context).maybePop(),
        semanticHint: 'Closes daily flow and returns to your cycle',
      ),
      child: Column(
        children: [
          _FlowTopBar(record: widget.record),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: LetterTokens.s28),
              children: [
                const SectionHeader(
                  eyebrow: 'DAILY FLOW',
                  title: 'Flow, day by day',
                  support: 'Flow describes a day inside a period you recorded.',
                ),
                const SizedBox(height: LetterTokens.s16),
                FlowDateStrip(
                  start: widget.record.startDate,
                  end: _end,
                  selected: _selected,
                  onSelect: (date) => setState(() {
                    _selected = date;
                    _error = null;
                  }),
                  flowFor: (date) => _flowByDate[date]?.flow,
                ),
                const SizedBox(height: LetterTokens.s8),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: LetterTokens.gutter,
                  ),
                  child: Text(
                    widget.record.isOpen
                        ? 'This period is still open, so days run from ${_shortDate(context, widget.record.startDate)} to today. Future days are never offered.'
                        : '$_dayCount recorded ${_dayCount == 1 ? 'day' : 'days'} in this period.',
                    style: letterHelper(size: 12),
                  ),
                ),
                const SizedBox(height: LetterTokens.s20),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: LetterTokens.gutter,
                  ),
                  child: LetterCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('SELECTED DAY', style: letterEyebrow()),
                        const SizedBox(height: LetterTokens.s4),
                        Semantics(
                          header: true,
                          child: Text(
                            _fullDate(context, _selected),
                            key: const Key('flow-selected-date'),
                            style: letterSerif(size: stacked ? 19 : 21),
                          ),
                        ),
                        const SizedBox(height: LetterTokens.s8),
                        Wrap(
                          spacing: LetterTokens.s8,
                          runSpacing: LetterTokens.s4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const ProvenanceTag(observed: true),
                            if (flow != null) ...[
                              FlowGlyph(flow: flow),
                              Text(
                                'Saved: ${flow.label}',
                                style: letterBody(
                                  size: 13,
                                  weight: FontWeight.w600,
                                ),
                              ),
                            ] else
                              Text(
                                'No flow recorded for this day',
                                style: letterHelper(size: 12.5),
                              ),
                          ],
                        ),
                        const SizedBox(height: LetterTokens.s16),
                        for (final option in BleedingFlow.values)
                          FlowChoiceTile(
                            key: Key('flow-choice-${option.name}'),
                            flow: option,
                            selected: flow == option,
                            onTap: _saving ? null : () => _setFlow(option),
                          ),
                        if (flow != null) ...[
                          const SizedBox(height: LetterTokens.s16),
                          Container(
                            padding: const EdgeInsets.all(LetterTokens.s16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF5F1),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(0xFFECCFC7),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'COLOR · OPTIONAL',
                                  style: letterEyebrow(),
                                ),
                                const SizedBox(height: LetterTokens.s4),
                                Text(
                                  'What color did you notice?',
                                  style: letterSerif(size: 19),
                                ),
                                const SizedBox(height: LetterTokens.s4),
                                Text(
                                  'Choose the closest visual match. Color is saved as an observation, not an interpretation.',
                                  style: letterHelper(size: 12.5),
                                ),
                                const SizedBox(height: LetterTokens.s12),
                                GridView.count(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  crossAxisCount: 2,
                                  crossAxisSpacing: LetterTokens.s8,
                                  mainAxisSpacing: LetterTokens.s8,
                                  childAspectRatio: 1.75,
                                  children: [
                                    for (final option in BleedingColor.values)
                                      BleedingColorChoice(
                                        key: Key('color-choice-${option.name}'),
                                        color: option,
                                        selected: bleedingColor == option,
                                        onTap: _saving
                                            ? null
                                            : () => _setColor(option),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (flow != null) ...[
                          const SizedBox(height: LetterTokens.s4),
                          DestructiveButton(
                            key: const Key('flow-clear'),
                            label: 'Clear this day',
                            expand: stacked,
                            onPressed: _saving ? null : _clearFlow,
                            semanticHint:
                                'Removes the saved flow for ${_fullDate(context, _selected)}. Period dates are not changed.',
                          ),
                        ],
                        if (_error case final message?) ...[
                          const SizedBox(height: LetterTokens.s12),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              message,
                              style: letterHelper(
                                size: 12.5,
                                color: LetterTokens.safety,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowTopBar extends StatelessWidget {
  const _FlowTopBar({required this.record});

  final PeriodRecord record;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('flow-top-bar'),
      decoration: const BoxDecoration(
        border: Border(bottom: LetterTokens.hairline),
      ),
      padding: const EdgeInsets.fromLTRB(
        LetterTokens.s8,
        LetterTokens.s8,
        LetterTokens.gutter,
        LetterTokens.s8,
      ),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close),
            label: const Text('Close'),
          ),
          const SizedBox(width: LetterTokens.s8),
          Expanded(
            child: Text(
              _periodLabel(context, record),
              textAlign: TextAlign.end,
              style: letterBody(size: 13, weight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

String _shortDate(BuildContext context, LocalDate date) =>
    MaterialLocalizations.of(context).formatMediumDate(date.asLocalDateTime);

String _fullDate(BuildContext context, LocalDate date) =>
    MaterialLocalizations.of(context).formatFullDate(date.asLocalDateTime);

String _periodLabel(BuildContext context, PeriodRecord record) => record.isOpen
    ? '${_shortDate(context, record.startDate)} — in progress'
    : '${_shortDate(context, record.startDate)} – ${_shortDate(context, record.endDate!)}';
