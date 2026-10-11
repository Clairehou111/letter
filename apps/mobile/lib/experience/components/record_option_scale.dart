import 'package:flutter/material.dart';

import 'interaction_controls.dart';

/// Values and labels stay in the caller's vocabulary, including an explicit zero.
class RecordScaleOption<T> {
  const RecordScaleOption({
    required this.value,
    required this.label,
    this.marker,
    this.semanticLabel,
    this.key,
  });

  final T value;
  final String label;
  final Widget? marker;
  final String? semanticLabel;
  final Key? key;
}

/// One ordinal family for distinct vocabularies; selection never writes a fact.
/// Repeated selections still return T. The caller owns clearing and saving.
class RecordOptionScale<T> extends StatelessWidget {
  const RecordOptionScale({
    required this.options,
    required this.selected,
    required this.onSelected,
    this.showCurrentLabel = true,
    this.showEndpointLabels = true,
    super.key,
  });

  final List<RecordScaleOption<T>> options;
  final T? selected;
  final ValueChanged<T>? onSelected;
  final bool showCurrentLabel;
  final bool showEndpointLabels;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final chosen = options
        .where((option) => option.value == selected)
        .firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final count = options.length;
            final availableColumns = ((constraints.maxWidth + 6) / 54)
                .floor()
                .clamp(1, count);
            final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.5;
            final columns = largeText && availableColumns > 3
                ? 3
                : count == 6 && availableColumns < 6 && availableColumns >= 3
                ? 3
                : availableColumns;
            final width = (constraints.maxWidth - 6 * (columns - 1)) / columns;
            return Wrap(
              spacing: 6,
              runSpacing: 8,
              children: [
                for (var index = 0; index < count; index++)
                  SizedBox(
                    width: width,
                    child: InteractionSurface(
                      key: options[index].key,
                      semanticLabel:
                          options[index].semanticLabel ?? options[index].label,
                      selected: options[index].value == selected,
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 12,
                      ),
                      onTap: onSelected == null
                          ? null
                          : () => onSelected!(options[index].value),
                      child: Center(
                        child:
                            options[index].marker ??
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Center(
                                child: Icon(
                                  index == 0
                                      ? Icons.circle_outlined
                                      : Icons.circle,
                                  size: count == 1
                                      ? 14
                                      : 8 + 12 * index / (count - 1),
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        if (showEndpointLabels) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  options.first.label,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              if (options.length > 1) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    options.last.label,
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ],
          ),
        ],
        if (showCurrentLabel) ...[
          const SizedBox(height: 10),
          Semantics(
            liveRegion: true,
            child: Text(
              chosen?.label ?? 'Not recorded',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Shared categorical duration ruler. Exact input remains a different value kind.
class RecordDurationPicker<T> extends StatelessWidget {
  const RecordDurationPicker({
    required this.options,
    required this.selected,
    required this.exact,
    required this.onSelected,
    required this.onExactChanged,
    required this.exactInput,
    super.key,
  });
  final List<RecordScaleOption<T>> options;
  final T? selected;
  final bool exact;
  final ValueChanged<T>? onSelected;
  final ValueChanged<bool>? onExactChanged;
  final Widget exactInput;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        RecordOptionScale<T>(
          options: [
            for (final option in options)
              RecordScaleOption<T>(
                value: option.value,
                label: option.label,
                key: option.key,
                semanticLabel: option.semanticLabel,
                marker: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 2,
                      height: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      option.label,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
          ],
          selected: exact ? null : selected,
          onSelected: onSelected,
          showCurrentLabel: !exact,
          showEndpointLabels: false,
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('record-duration-exact'),
            onPressed: onExactChanged == null
                ? null
                : () => onExactChanged!(!exact),
            icon: Icon(
              exact ? Icons.check_circle_outline : Icons.edit_outlined,
              size: 18,
            ),
            label: const Text('Enter exact'),
          ),
        ),
        if (exact) exactInput,
      ],
    );
  }
}
