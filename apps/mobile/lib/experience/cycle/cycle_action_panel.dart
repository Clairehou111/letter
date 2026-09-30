import 'package:flutter/material.dart';

import 'package:letter_mobile/experience/theme/experience_foundation.dart';

/// Kimi-owned visual component for the action area inside Cycle's existing
/// "Current cycle" card. It receives only facts and callbacks; the host keeps
/// all persistence, sheets, navigation, and state transitions.
///
/// The layout is a quiet editorial stack: a clearly tappable details target,
/// one dominant current-cycle action, a calmer secondary action, then a
/// hairline-separated group of record-keeping links that stay reachable
/// without competing with the primary task.
class CycleActionPanel extends StatelessWidget {
  const CycleActionPanel({
    super.key,
    required this.bleedingLine,
    required this.startedLabel,
    required this.primaryLabel,
    required this.onOpenDetails,
    required this.onPrimary,
    required this.onEditDates,
    required this.onRecordNewPeriodStart,
    required this.onBackfillPastPeriod,
  });

  final String bleedingLine;
  final String startedLabel;
  final String primaryLabel;

  /// Opens existing day-level flow, color, pain, and observation editing.
  final VoidCallback onOpenDetails;

  /// Ends bleeding when it is still open; otherwise opens existing Fill in
  /// days backfill for the current period. The host supplies [primaryLabel].
  final VoidCallback onPrimary;

  /// Opens the existing period date editor for the current period.
  final VoidCallback onEditDates;

  /// Records a new period start today through the existing guarded flow.
  final VoidCallback onRecordNewPeriodStart;

  /// Opens the existing whole-period backfill flow for a past period. This
  /// must remain reachable even while there is a current cycle.
  final VoidCallback onBackfillPastPeriod;

  static const double _wideBreakpoint = 560;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide =
            constraints.hasBoundedWidth &&
            constraints.maxWidth >= _wideBreakpoint;

        final primary = _PrimaryAction(
          label: primaryLabel,
          onPressed: onPrimary,
        );
        final editDates = _EditDatesAction(
          onPressed: onEditDates,
          minHeight: isWide ? 52 : 48,
        );

        final backfill = _TertiaryAction(
          icon: Icons.history_rounded,
          label: 'Backfill a past period',
          onPressed: onBackfillPastPeriod,
        );
        final recordNew = _TertiaryAction(
          icon: Icons.add_rounded,
          label: 'Record a new period start',
          onPressed: onRecordNewPeriodStart,
          subdued: true,
          alignEnd: isWide,
        );

        return Container(
          decoration: BoxDecoration(
            color: ExperienceColors.surface,
            borderRadius: BorderRadius.circular(ExperienceRadius.card),
            boxShadow: ExperienceShadows.card,
          ),
          child: Material(
            type: MaterialType.transparency,
            animationDuration: ExperienceMotion.chipSelect,
            child: Padding(
              padding: const EdgeInsets.all(ExperienceSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _DetailsTarget(
                    bleedingLine: bleedingLine,
                    startedLabel: startedLabel,
                    onOpenDetails: onOpenDetails,
                  ),
                  const SizedBox(height: ExperienceSpacing.md),
                  if (isWide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: primary),
                        const SizedBox(width: ExperienceSpacing.sm),
                        Expanded(flex: 2, child: editDates),
                      ],
                    )
                  else ...[
                    primary,
                    const SizedBox(height: ExperienceSpacing.sm),
                    editDates,
                  ],
                  const SizedBox(height: ExperienceSpacing.md),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: ExperienceColors.hairline,
                  ),
                  const SizedBox(height: ExperienceSpacing.sm),
                  const _SectionLabel(),
                  const SizedBox(height: ExperienceSpacing.xs),
                  if (isWide)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(child: backfill),
                        const SizedBox(width: ExperienceSpacing.sm),
                        Flexible(child: recordNew),
                      ],
                    )
                  else ...[
                    backfill,
                    recordNew,
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A completed cycle entry that keeps its date range and duration readable
/// when the viewport is narrow or accessibility text is enlarged.
class CycleRecentRow extends StatelessWidget {
  const CycleRecentRow({
    super.key,
    required this.cycleNumber,
    required this.dateRange,
    required this.cycleLengthDays,
    required this.onPressed,
  });

  final int cycleNumber;
  final String dateRange;
  final int cycleLengthDays;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ExperienceSpacing.xs * 2),
      child: Semantics(
        button: true,
        label:
            'Cycle $cycleNumber: $dateRange, '
            '$cycleLengthDays-day cycle. Activate for details, letter, and editing.',
        child: Material(
          color: ExperienceColors.surface,
          borderRadius: ExperienceRadius.chipRadius,
          child: InkWell(
            borderRadius: ExperienceRadius.chipRadius,
            onTap: onPressed,
            child: Container(
              constraints: const BoxConstraints(
                minHeight: ExperienceSpacing.minTouchTarget,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: ExperienceSpacing.sm,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                borderRadius: ExperienceRadius.chipRadius,
                border: Border.all(color: ExperienceColors.hairline),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final textScale = MediaQuery.textScalerOf(context).scale(1);
                  final stackDetails =
                      constraints.maxWidth < 360 || textScale > 1.3;
                  final dateLabel = Text(
                    dateRange,
                    style: ExperienceType.body(ExperienceColors.ink),
                  );
                  final lengthLabel = Text(
                    '$cycleLengthDays-day cycle',
                    style: ExperienceType.bodyStrong(ExperienceColors.ink),
                  );

                  return Row(
                    crossAxisAlignment: stackDetails
                        ? CrossAxisAlignment.start
                        : CrossAxisAlignment.center,
                    children: <Widget>[
                      Padding(
                        padding: EdgeInsets.only(top: stackDetails ? 6 : 0),
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: ExperienceColors.phasePeriod,
                          ),
                        ),
                      ),
                      const SizedBox(width: ExperienceSpacing.sm),
                      Expanded(
                        child: stackDetails
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  dateLabel,
                                  const SizedBox(height: ExperienceSpacing.xs),
                                  lengthLabel,
                                ],
                              )
                            : dateLabel,
                      ),
                      if (!stackDetails) lengthLabel,
                      const SizedBox(width: ExperienceSpacing.xs),
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: ExperienceColors.inkFaint,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The informational portion of the card. It is an explicit, generously sized
/// button with a visible affordance, so opening details never relies on a
/// hidden gesture and never swallows the nested action controls below it.
class _DetailsTarget extends StatelessWidget {
  const _DetailsTarget({
    required this.bleedingLine,
    required this.startedLabel,
    required this.onOpenDetails,
  });

  final String bleedingLine;
  final String startedLabel;
  final VoidCallback onOpenDetails;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label:
          '$bleedingLine, $startedLabel. Open flow, color, pain, and observation details.',
      child: InkWell(
        onTap: onOpenDetails,
        borderRadius: BorderRadius.circular(ExperienceRadius.chip),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: ExperienceSpacing.xs,
            horizontal: 2,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      bleedingLine,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: ExperienceType.headline(
                        ExperienceColors.ink,
                      ).copyWith(fontSize: 17, height: 1.25),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      startedLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: ExperienceType.body(
                        ExperienceColors.inkSoft,
                      ).copyWith(fontSize: 13.5, height: 1.35),
                    ),
                    const SizedBox(height: ExperienceSpacing.xs),
                    Text(
                      'Flow, color, pain & observations',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ExperienceType.body(
                        ExperienceColors.ember,
                      ).copyWith(fontSize: 13.5, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: ExperienceSpacing.sm),
              const Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: ExperienceColors.ember,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The single dominant current-cycle task.
class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: ExperienceColors.ember,
          foregroundColor: ExperienceColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ExperienceRadius.chip),
          ),
          textStyle: ExperienceType.body(
            ExperienceColors.surface,
          ).copyWith(fontSize: 16, fontWeight: FontWeight.w700),
          padding: const EdgeInsets.symmetric(
            horizontal: ExperienceSpacing.md,
            vertical: ExperienceSpacing.sm,
          ),
        ),
        child: Text(label, maxLines: 2, textAlign: TextAlign.center),
      ),
    );
  }
}

/// The available-but-secondary date edit for the current period.
class _EditDatesAction extends StatelessWidget {
  const _EditDatesAction({required this.onPressed, required this.minHeight});

  final VoidCallback onPressed;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: ExperienceColors.ink,
          side: const BorderSide(color: ExperienceColors.hairline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ExperienceRadius.chip),
          ),
          textStyle: ExperienceType.body(
            ExperienceColors.ink,
          ).copyWith(fontSize: 15, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(
            horizontal: ExperienceSpacing.md,
            vertical: ExperienceSpacing.sm,
          ),
        ),
        child: const Text(
          'Edit dates',
          maxLines: 2,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// A quiet record-keeping link. [subdued] keeps "Record a new period start"
/// from reading as the normal next step while the current period is active.
class _TertiaryAction extends StatelessWidget {
  const _TertiaryAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.subdued = false,
    this.alignEnd = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool subdued;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final color = subdued
        ? ExperienceColors.inkFaint
        : ExperienceColors.inkSoft;

    return Align(
      alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 17, color: color),
        label: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
        style: TextButton.styleFrom(
          foregroundColor: color,
          minimumSize: const Size(48, 44),
          alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(
            horizontal: ExperienceSpacing.sm,
            vertical: ExperienceSpacing.xs,
          ),
          textStyle: ExperienceType.body(
            color,
          ).copyWith(fontSize: 13.5, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// Small-caps editorial label separating record-keeping links from the
/// current-cycle task.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel();

  @override
  Widget build(BuildContext context) {
    return Text(
      'MORE ACTIONS',
      style: ExperienceType.label(
        ExperienceColors.inkFaint,
      ).copyWith(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.6),
    );
  }
}
