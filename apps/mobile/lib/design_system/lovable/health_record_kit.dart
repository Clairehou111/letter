import 'package:flutter/material.dart';

import '../letter_brand_mark.dart';
import 'letter_kit.dart';
import 'letter_theme.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    this.eyebrow,
    required this.title,
    this.support,
  });

  final String? eyebrow;
  final String title;
  final String? support;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      LetterTokens.gutter,
      LetterTokens.s28,
      LetterTokens.gutter,
      0,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eyebrow != null) ...[
          Text(eyebrow!, style: letterEyebrow()),
          const SizedBox(height: LetterTokens.s4),
        ],
        Semantics(
          header: true,
          child: Text(
            title,
            style: letterSerif(size: context.isLovableNarrow ? 26 : 30),
          ),
        ),
        if (support != null) ...[
          const SizedBox(height: LetterTokens.s12),
          Text(
            support!,
            style: letterBody(size: 14, color: LetterTokens.muted),
          ),
        ],
      ],
    ),
  );
}

class _KitButton extends StatelessWidget {
  const _KitButton({
    required this.label,
    required this.onPressed,
    required this.background,
    required this.foreground,
    required this.border,
    this.semanticHint,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color background;
  final Color foreground;
  final Color border;
  final String? semanticHint;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    final child = AnimatedContainer(
      duration: context.lovableMotion(LetterTokens.durBase),
      curve: LetterTokens.ease,
      constraints: const BoxConstraints(
        minHeight: LetterTokens.tapTarget,
        minWidth: LetterTokens.tapTarget,
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(
        horizontal: LetterTokens.s20,
        vertical: LetterTokens.s12,
      ),
      decoration: BoxDecoration(
        color: disabled ? LetterTokens.canvas : background,
        borderRadius: LetterTokens.brControl,
        border: Border.all(color: disabled ? LetterTokens.line : border),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: letterBody(
          size: 14,
          weight: FontWeight.w500,
          color: disabled ? LetterTokens.muted : foreground,
          height: 1.3,
        ),
      ),
    );
    return Semantics(
      button: true,
      enabled: !disabled,
      hint: semanticHint,
      child: InkWell(
        onTap: onPressed,
        borderRadius: LetterTokens.brControl,
        child: expand ? SizedBox(width: double.infinity, child: child) : child,
      ),
    );
  }
}

class QuietButton extends StatelessWidget {
  const QuietButton({
    super.key,
    required this.label,
    this.onPressed,
    this.expand = false,
    this.semanticHint,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool expand;
  final String? semanticHint;
  @override
  Widget build(BuildContext context) => _KitButton(
    label: label,
    onPressed: onPressed,
    background: LetterTokens.surface,
    foreground: LetterTokens.ink,
    border: LetterTokens.line,
    expand: expand,
    semanticHint: semanticHint,
  );
}

class DestructiveButton extends StatelessWidget {
  const DestructiveButton({
    super.key,
    required this.label,
    this.onPressed,
    this.expand = false,
    this.semanticHint,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool expand;
  final String? semanticHint;
  @override
  Widget build(BuildContext context) => _KitButton(
    label: label,
    onPressed: onPressed,
    background: LetterTokens.surface,
    foreground: LetterTokens.safety,
    border: LetterTokens.safety,
    expand: expand,
    semanticHint: semanticHint,
  );
}

class SegmentedControl<T> extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final List<({T id, String label})> options;
  final T value;
  final ValueChanged<T> onChanged;
  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: Wrap(
      spacing: LetterTokens.s8,
      runSpacing: LetterTokens.s8,
      children: [
        for (final option in options)
          _SegmentChip(
            label: option.label,
            selected: option.id == value,
            onTap: () => onChanged(option.id),
          ),
      ],
    ),
  );
}

class _SegmentChip extends StatelessWidget {
  const _SegmentChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: InkWell(
      onTap: onTap,
      borderRadius: LetterTokens.brControl,
      child: AnimatedContainer(
        duration: context.lovableMotion(LetterTokens.durFast),
        curve: LetterTokens.ease,
        constraints: const BoxConstraints(minHeight: LetterTokens.tapTarget),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: LetterTokens.s16),
        decoration: BoxDecoration(
          color: selected ? LetterTokens.tealSoft : LetterTokens.surface,
          borderRadius: LetterTokens.brControl,
          border: Border.all(
            color: selected ? LetterTokens.teal : LetterTokens.line,
          ),
        ),
        child: Text(
          selected ? '$label ✓' : label,
          style: letterBody(
            size: 13,
            color: selected ? LetterTokens.teal : LetterTokens.muted,
            weight: selected ? FontWeight.w600 : FontWeight.w400,
            height: 1.3,
          ),
        ),
      ),
    ),
  );
}

class LoadingBlock extends StatelessWidget {
  const LoadingBlock({super.key, this.lines = 3, required this.label});
  final int lines;
  final String label;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: label,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(
        LetterTokens.gutter,
        LetterTokens.s20,
        LetterTokens.gutter,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < lines; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: LetterTokens.s12),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: i.isEven ? 1 : .7,
                child: Container(
                  height: 12,
                  decoration: const BoxDecoration(
                    color: LetterTokens.tealSoft,
                    borderRadius: LetterTokens.brControl,
                  ),
                ),
              ),
            ),
          Text(label, style: letterHelper(size: 12)),
        ],
      ),
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.body,
    this.action,
  });
  final String title;
  final String body;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(LetterTokens.gutter),
    child: LetterCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: letterSerif(size: 20)),
          const SizedBox(height: LetterTokens.s8),
          Text(body, style: letterHelper(size: 13)),
          if (action != null) ...[
            const SizedBox(height: LetterTokens.s16),
            action!,
          ],
        ],
      ),
    ),
  );
}

class FailureState extends StatelessWidget {
  const FailureState({
    super.key,
    required this.title,
    required this.cause,
    this.action,
  });
  final String title;
  final String cause;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(LetterTokens.gutter),
    child: Container(
      padding: const EdgeInsets.all(LetterTokens.s16),
      decoration: BoxDecoration(
        color: LetterTokens.surface,
        borderRadius: LetterTokens.brSurface,
        border: Border.all(color: LetterTokens.safety),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.error_outline,
                size: 18,
                color: LetterTokens.safety,
              ),
              const SizedBox(width: LetterTokens.s8),
              Expanded(
                child: Text(
                  title,
                  style: letterBody(
                    size: 15,
                    weight: FontWeight.w600,
                    color: LetterTokens.safety,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: LetterTokens.s8),
          Text(cause, style: letterHelper(size: 13)),
          if (action != null) ...[
            const SizedBox(height: LetterTokens.s16),
            action!,
          ],
        ],
      ),
    ),
  );
}

class DisabledHint extends StatelessWidget {
  const DisabledHint({super.key, required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: LetterTokens.s8),
    child: Text(text, style: letterHelper(size: 12)),
  );
}

class RetryAction extends StatelessWidget {
  const RetryAction({
    super.key,
    required this.onRetry,
    this.label = 'Try again',
  });
  final VoidCallback onRetry;
  final String label;
  @override
  Widget build(BuildContext context) =>
      PrimaryButton(label: label, onPressed: onRetry);
}

class FormSheet extends StatelessWidget {
  const FormSheet({
    super.key,
    required this.title,
    required this.children,
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryDisabledReason,
    this.destructive = false,
    this.secondaryLabel = 'Cancel',
    this.primaryKey,
  });
  final String title;
  final List<Widget> children;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String? primaryDisabledReason;
  final bool destructive;
  final String secondaryLabel;
  final Key? primaryKey;
  @override
  Widget build(BuildContext context) {
    final stacked = context.isLovableNarrow || context.isLovableLargeText;
    final primary = destructive
        ? DestructiveButton(
            key: primaryKey,
            label: primaryLabel,
            onPressed: onPrimary,
            expand: stacked,
          )
        : PrimaryButton(
            key: primaryKey,
            label: primaryLabel,
            onPressed: onPrimary,
            expand: stacked,
          );
    final secondary = QuietButton(
      label: secondaryLabel,
      onPressed: () => Navigator.of(context).maybePop(),
      expand: stacked,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: letterSerif(size: 20)),
        ),
        const SizedBox(height: LetterTokens.s16),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ),
        if (onPrimary == null && primaryDisabledReason != null) ...[
          const SizedBox(height: LetterTokens.s12),
          Text(primaryDisabledReason!, style: letterHelper(size: 12)),
        ],
        const SizedBox(height: LetterTokens.s20),
        if (stacked)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              primary,
              const SizedBox(height: LetterTokens.s8),
              secondary,
            ],
          )
        else
          Row(
            children: [
              Expanded(child: secondary),
              const SizedBox(width: LetterTokens.s12),
              Expanded(child: primary),
            ],
          ),
      ],
    );
  }
}

Future<bool> showLetterConfirm({
  required BuildContext context,
  required String title,
  required String body,
  required String confirmLabel,
  bool destructive = true,
  Key? key,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: LetterTokens.scrim,
    builder: (dialogContext) {
      final stacked =
          dialogContext.isLovableNarrow || dialogContext.isLovableLargeText;
      final confirm = destructive
          ? DestructiveButton(
              label: confirmLabel,
              expand: stacked,
              onPressed: () => Navigator.of(dialogContext).pop(true),
            )
          : PrimaryButton(
              label: confirmLabel,
              expand: stacked,
              onPressed: () => Navigator.of(dialogContext).pop(true),
            );
      final cancel = QuietButton(
        label: 'Cancel',
        expand: stacked,
        onPressed: () => Navigator.of(dialogContext).pop(false),
      );
      return Dialog(
        key: key,
        backgroundColor: LetterTokens.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: LetterTokens.brSurface,
        ),
        insetPadding: const EdgeInsets.all(LetterTokens.s16),
        child: Padding(
          padding: const EdgeInsets.all(LetterTokens.s20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                header: true,
                child: Text(title, style: letterSerif(size: 20)),
              ),
              const SizedBox(height: LetterTokens.s8),
              Text(body, style: letterHelper(size: 13)),
              const SizedBox(height: LetterTokens.s20),
              if (stacked)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    confirm,
                    const SizedBox(height: LetterTokens.s8),
                    cancel,
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(child: cancel),
                    const SizedBox(width: LetterTokens.s12),
                    Expanded(child: confirm),
                  ],
                ),
            ],
          ),
        ),
      );
    },
  );
  return result ?? false;
}

class SeverityChip extends StatelessWidget {
  const SeverityChip({
    super.key,
    required this.value,
    required this.word,
    this.compact = false,
  });
  final int value;
  final String word;
  final bool compact;
  Color get _swatch => value <= 1
      ? LetterTokens.muted
      : severityRamp[(value - 2).clamp(0, severityRamp.length - 1)];
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Severity $value, $word',
    excludeSemantics: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: _swatch,
            borderRadius: const BorderRadius.all(Radius.circular(2)),
            border: Border.all(color: LetterTokens.ink.withValues(alpha: .20)),
          ),
        ),
        const SizedBox(width: LetterTokens.s8),
        Text(
          '$value',
          style: letterBody(size: 13, weight: FontWeight.w600, height: 1.2),
        ),
        const SizedBox(width: LetterTokens.s4),
        if (!compact) Text(word, style: letterHelper(size: 12.5)),
      ],
    ),
  );
}

class RecordProvenanceLine extends StatelessWidget {
  const RecordProvenanceLine({
    super.key,
    required this.provenanceLabel,
    required this.recordedAtLabel,
    required this.impactCount,
  });
  final String provenanceLabel;
  final String recordedAtLabel;
  final int impactCount;
  @override
  Widget build(BuildContext context) {
    final impacts = impactCount == 0
        ? 'No functional impact recorded'
        : impactCount == 1
        ? '1 functional impact'
        : '$impactCount functional impacts';
    return Text(
      '$provenanceLabel · $recordedAtLabel · $impacts',
      style: letterHelper(size: 12),
    );
  }
}

class SelectableTile extends StatelessWidget {
  const SelectableTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.helper,
    this.leading,
    this.trailing,
    this.safety = false,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? helper;
  final Widget? leading;
  final Widget? trailing;
  final bool safety;
  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? LetterTokens.teal
        : safety
        ? LetterTokens.safety.withValues(alpha: .55)
        : LetterTokens.line;
    return Semantics(
      button: true,
      selected: selected,
      hint: safety ? 'Opens support information. Creates no record.' : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: LetterTokens.brControl,
        child: AnimatedContainer(
          duration: context.lovableMotion(LetterTokens.durFast),
          curve: LetterTokens.ease,
          constraints: const BoxConstraints(minHeight: LetterTokens.tapTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: LetterTokens.s12,
            vertical: LetterTokens.s8,
          ),
          decoration: BoxDecoration(
            color: selected ? LetterTokens.tealSoft : LetterTokens.surface,
            borderRadius: LetterTokens.brControl,
            border: Border.all(color: borderColor),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: LetterTokens.s8),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: letterBody(
                        size: 14,
                        height: 1.3,
                        weight: selected ? FontWeight.w600 : FontWeight.w400,
                        color: selected ? LetterTokens.teal : LetterTokens.ink,
                      ),
                    ),
                    if (helper != null) ...[
                      const SizedBox(height: 2),
                      Text(helper!, style: letterHelper(size: 12)),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: LetterTokens.s8),
                trailing!,
              ] else if (selected) ...[
                const SizedBox(width: LetterTokens.s8),
                const Icon(Icons.check, size: 18, color: LetterTokens.teal),
              ] else if (safety) ...[
                const SizedBox(width: LetterTokens.s8),
                const Icon(
                  Icons.info_outline,
                  size: 18,
                  color: LetterTokens.safety,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ChecklistRow extends StatelessWidget {
  const ChecklistRow({
    super.key,
    required this.label,
    required this.checked,
    required this.onChanged,
    this.last = false,
  });
  final String label;
  final bool checked;
  final ValueChanged<bool> onChanged;
  final bool last;
  @override
  Widget build(BuildContext context) => Semantics(
    checked: checked,
    inMutuallyExclusiveGroup: false,
    child: InkWell(
      onTap: () => onChanged(!checked),
      child: Container(
        constraints: const BoxConstraints(minHeight: LetterTokens.tapTarget),
        padding: const EdgeInsets.symmetric(
          horizontal: LetterTokens.s16,
          vertical: LetterTokens.s8,
        ),
        decoration: BoxDecoration(
          border: last ? null : const Border(bottom: LetterTokens.hairline),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: checked ? LetterTokens.teal : LetterTokens.surface,
                borderRadius: const BorderRadius.all(Radius.circular(4)),
                border: Border.all(
                  color: checked ? LetterTokens.teal : LetterTokens.line,
                ),
              ),
              child: checked
                  ? const Icon(
                      Icons.check,
                      size: 14,
                      color: LetterTokens.surface,
                    )
                  : null,
            ),
            const SizedBox(width: LetterTokens.s12),
            Expanded(
              child: Text(label, style: letterBody(size: 14, height: 1.35)),
            ),
          ],
        ),
      ),
    ),
  );
}

class SafetyCallout extends StatelessWidget {
  const SafetyCallout({
    super.key,
    required this.title,
    required this.body,
    this.action,
  });
  final String title;
  final String body;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(LetterTokens.s16),
    decoration: const BoxDecoration(
      color: LetterTokens.surface,
      border: Border(
        left: BorderSide(color: LetterTokens.safety, width: 3),
        top: LetterTokens.hairline,
        right: LetterTokens.hairline,
        bottom: LetterTokens.hairline,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: letterBody(size: 14.5, weight: FontWeight.w600)),
        const SizedBox(height: LetterTokens.s8),
        Text(body, style: letterHelper(size: 13)),
        if (action != null) ...[
          const SizedBox(height: LetterTokens.s16),
          action!,
        ],
      ],
    ),
  );
}

class StageProgressHeader extends StatelessWidget {
  const StageProgressHeader({
    super.key,
    required this.step,
    required this.total,
    required this.title,
    required this.subtitle,
    this.onBack,
    this.backLabel = 'Back',
  });
  final int step;
  final int total;
  final String title;
  final String subtitle;
  final VoidCallback? onBack;
  final String backLabel;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      LetterTokens.gutter,
      LetterTokens.s16,
      LetterTokens.gutter,
      LetterTokens.s8,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (onBack != null)
              Semantics(
                button: true,
                label: backLabel,
                child: Tooltip(
                  message: backLabel,
                  child: InkWell(
                    onTap: onBack,
                    borderRadius: LetterTokens.brControl,
                    child: const SizedBox(
                      width: LetterTokens.tapTarget,
                      height: LetterTokens.tapTarget,
                      child: Icon(
                        Icons.arrow_back,
                        size: 20,
                        color: LetterTokens.ink,
                      ),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: Text('Step $step of $total', style: letterEyebrow()),
            ),
          ],
        ),
        const SizedBox(height: LetterTokens.s8),
        Row(
          children: [
            for (var i = 1; i <= total; i++)
              Expanded(
                child: Container(
                  height: 3,
                  margin: EdgeInsets.only(
                    right: i == total ? 0 : LetterTokens.s4,
                  ),
                  decoration: BoxDecoration(
                    color: i <= step ? LetterTokens.teal : LetterTokens.line,
                    borderRadius: LetterTokens.brControl,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: LetterTokens.s16),
        Semantics(
          header: true,
          child: Text(
            title,
            style: letterSerif(size: context.isLovableNarrow ? 24 : 27),
          ),
        ),
        const SizedBox(height: LetterTokens.s8),
        Text(subtitle, style: letterHelper(size: 13)),
      ],
    ),
  );
}

class InlineErrorBanner extends StatelessWidget {
  const InlineErrorBanner({super.key, required this.text, this.action});
  final String text;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.all(LetterTokens.s12),
      decoration: BoxDecoration(
        color: LetterTokens.surface,
        borderRadius: LetterTokens.brSurface,
        border: Border.all(color: LetterTokens.safety),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.error_outline,
                  size: 16,
                  color: LetterTokens.safety,
                ),
              ),
              const SizedBox(width: LetterTokens.s8),
              Expanded(child: Text(text, style: letterHelper(size: 12.5))),
            ],
          ),
          if (action != null) ...[
            const SizedBox(height: LetterTokens.s12),
            action!,
          ],
        ],
      ),
    ),
  );
}

class RecordGroupHeading extends StatelessWidget {
  const RecordGroupHeading({
    super.key,
    required this.text,
    required this.count,
  });
  final String text;
  final int count;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      LetterTokens.gutter,
      LetterTokens.s20,
      LetterTokens.gutter,
      LetterTokens.s8,
    ),
    child: Semantics(
      header: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: letterSerif(size: context.isLovableNarrow ? 19 : 21),
          ),
          const SizedBox(height: LetterTokens.s4),
          Text(
            count == 1 ? '1 record' : '$count records',
            style: letterEyebrow(),
          ),
        ],
      ),
    ),
  );
}

class ScreenScaffold extends StatelessWidget {
  const ScreenScaffold({
    super.key,
    required this.child,
    this.bottomNavigationBar,
    this.stickyAction,
    this.showHeader = true,
  });
  final Widget child;
  final Widget? bottomNavigationBar;
  final Widget? stickyAction;
  final bool showHeader;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: LetterTokens.canvas,
    body: SafeArea(
      bottom: false,
      child: Column(
        children: [
          if (showHeader) const _BrandHeader(),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: LetterTokens.maxContentWidth,
                ),
                child: child,
              ),
            ),
          ),
          if (stickyAction != null)
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: LetterTokens.canvas,
                border: Border(top: LetterTokens.hairline),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: LetterTokens.gutter,
                vertical: LetterTokens.s12,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: LetterTokens.maxContentWidth,
                  ),
                  child: stickyAction,
                ),
              ),
            ),
        ],
      ),
    ),
    bottomNavigationBar: bottomNavigationBar,
  );
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: const BoxDecoration(
      border: Border(bottom: LetterTokens.hairline),
    ),
    padding: const EdgeInsets.symmetric(
      horizontal: LetterTokens.gutter,
      vertical: LetterTokens.s12,
    ),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: LetterTokens.maxContentWidth,
        ),
        child: const Align(
          alignment: Alignment.centerLeft,
          child: LetterBrandLockup(),
        ),
      ),
    ),
  );
}
