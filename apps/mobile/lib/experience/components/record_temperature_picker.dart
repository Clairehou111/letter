import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Presentation-only, two-part manual reading. Blank wheels invent no value.
/// Typed precision is preserved until the user actually moves a wheel.
class RecordTemperaturePicker extends StatefulWidget {
  const RecordTemperaturePicker({
    required this.unitLabel,
    required this.anchorWhole,
    required this.value,
    required this.onChanged,
    super.key,
  });
  final String unitLabel;
  final int anchorWhole;
  final double? value;
  final ValueChanged<double?>? onChanged;

  @override
  State<RecordTemperaturePicker> createState() =>
      _RecordTemperaturePickerState();
}

class _RecordTemperaturePickerState extends State<RecordTemperaturePicker> {
  late final FixedExtentScrollController _wholeController;
  late final FixedExtentScrollController _fractionController;
  int? _whole;
  int? _fraction;
  double? _lastEmitted;
  bool _awaitingEmissionEcho = false;

  // This is a quick-entry window, never a validation limit for typed sources.
  List<int?> get _wholeValues => [
    for (var value = 0; value <= 199; value++) ...[
      if (value == widget.anchorWhole) null,
      value,
    ],
  ];
  static final _fractionValues = [
    null,
    ...[for (var value = 0; value < 100; value++) value],
  ];

  @override
  void initState() {
    super.initState();
    _readValue();
    _wholeController = FixedExtentScrollController(initialItem: _wholeIndex);
    _fractionController = FixedExtentScrollController(
      initialItem: _fractionIndex,
    );
  }

  int get _wholeIndex =>
      _whole == null ? widget.anchorWhole : _wholeValues.indexOf(_whole);
  int get _fractionIndex => _fraction == null ? 0 : _fraction! + 1;

  void _readValue() {
    final value = widget.value;
    if (value == null || !value.isFinite || value <= 0 || value >= 200) {
      _whole = null;
      _fraction = null;
      return;
    }
    final hundredths = (value * 100).round();
    _whole = hundredths ~/ 100;
    _fraction = hundredths % 100;
    if (_whole! > 199) {
      _whole = null;
      _fraction = null;
    }
  }

  @override
  void didUpdateWidget(RecordTemperaturePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final isEmissionEcho =
        _awaitingEmissionEcho && widget.value == _lastEmitted;
    _awaitingEmissionEcho = false;
    if (widget.value != oldWidget.value && !isEmissionEcho) {
      _readValue();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_wholeController.hasClients) {
          _wholeController.jumpToItem(_wholeIndex);
        }
        if (_fractionController.hasClients) {
          _fractionController.jumpToItem(_fractionIndex);
        }
      });
    }
  }

  void _picked({int? wholeIndex, int? fractionIndex}) {
    if (widget.onChanged == null) return;
    // Synchronizing an exact typed value also produces scroll notifications.
    // Its rounded wheel positions are already in state; only a new position
    // represents a choice, including accessibility and controller-driven moves.
    if ((wholeIndex == null || wholeIndex == _wholeIndex) &&
        (fractionIndex == null || fractionIndex == _fractionIndex)) {
      return;
    }
    setState(() {
      if (wholeIndex != null) _whole = _wholeValues[wholeIndex];
      if (fractionIndex != null) _fraction = _fractionValues[fractionIndex];
    });
    if (_whole == null || _fraction == null) {
      _lastEmitted = null;
      _awaitingEmissionEcho = true;
      widget.onChanged!(null);
      return;
    }
    final value = _whole! + _fraction! / 100;
    _lastEmitted = value;
    _awaitingEmissionEcho = true;
    widget.onChanged!(value);
  }

  @override
  void dispose() {
    _wholeController.dispose();
    _fractionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extent = math.max(
      48.0,
      MediaQuery.textScalerOf(context).scale(22) * 1.3 + 12,
    );
    final wholeValues = _wholeValues;
    final hundredths = widget.value == null ? null : widget.value! * 100;
    final hasExtraPrecision =
        hundredths != null &&
        hundredths.isFinite &&
        (hundredths - hundredths.round()).abs() > 1e-8;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            widget.value == null
                ? 'Choose a reading'
                : '${widget.value} ${widget.unitLabel}',
            key: const Key('record-temperature-current'),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
        ),
        if (hasExtraPrecision) ...[
          const SizedBox(height: 4),
          Text(
            'Exact reading kept. Moving a wheel selects 0.01 steps.',
            key: const Key('record-temperature-precision-hint'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 8),
        AbsorbPointer(
          absorbing: widget.onChanged == null,
          child: SizedBox(
            height: extent * 3,
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    label: 'Temperature whole degrees in ${widget.unitLabel}',
                    child: CupertinoPicker(
                      key: const Key('record-temperature-whole-wheel'),
                      scrollController: _wholeController,
                      itemExtent: extent,
                      selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
                        background: theme.colorScheme.primary.withValues(
                          alpha: .08,
                        ),
                      ),
                      onSelectedItemChanged: widget.onChanged == null
                          ? null
                          : (index) => _picked(wholeIndex: index),
                      children: [
                        for (final value in wholeValues)
                          Center(
                            child: Text(
                              value?.toString() ?? '—',
                              style: theme.textTheme.titleLarge,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Text('.', style: theme.textTheme.titleLarge),
                Expanded(
                  child: Semantics(
                    label: 'Temperature hundredths in ${widget.unitLabel}',
                    child: CupertinoPicker(
                      key: const Key('record-temperature-fraction-wheel'),
                      scrollController: _fractionController,
                      itemExtent: extent,
                      selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
                        background: theme.colorScheme.primary.withValues(
                          alpha: .08,
                        ),
                      ),
                      onSelectedItemChanged: widget.onChanged == null
                          ? null
                          : (index) => _picked(fractionIndex: index),
                      children: [
                        for (final value in _fractionValues)
                          Center(
                            child: Text(
                              value?.toString().padLeft(2, '0') ?? '—',
                              style: theme.textTheme.titleLarge,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
