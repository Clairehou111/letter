import 'package:flutter/material.dart';

import '../../../design_system/lovable/health_record_kit.dart';
import '../../../design_system/lovable/letter_kit.dart';
import '../../../design_system/lovable/letter_theme.dart';
import '../domain/bleeding_flow.dart';
import '../domain/local_date.dart';
import '../domain/period_record.dart';
import 'flow_controls.dart';

class TodayFlowCard extends StatelessWidget {
  const TodayFlowCard({
    required this.record,
    required this.today,
    required this.flow,
    required this.recordedDays,
    required this.onOpenFlow,
    super.key,
  });

  final PeriodRecord record;
  final LocalDate today;
  final BleedingFlow? flow;
  final int recordedDays;
  final VoidCallback onOpenFlow;

  @override
  Widget build(BuildContext context) {
    final totalDays = today.epochDay - record.startDate.epochDay + 1;
    final stacked = context.isLovableNarrow || context.isLovableLargeText;
    final flow = this.flow;
    final action = flow == null
        ? PrimaryButton(
            key: const Key('flow-record-today'),
            label: "Record today's flow",
            expand: stacked,
            onPressed: onOpenFlow,
          )
        : QuietButton(
            key: const Key('flow-change-today'),
            label: "Change today's flow",
            expand: stacked,
            onPressed: onOpenFlow,
          );
    return LetterCard(
      key: const Key('flow-today-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TODAY’S FLOW', style: letterEyebrow()),
          const SizedBox(height: LetterTokens.s4),
          Semantics(
            header: true,
            child: Text(
              flow?.label ?? 'Not recorded yet',
              key: const Key('flow-today-value'),
              style: letterSerif(size: stacked ? 20 : 22),
            ),
          ),
          const SizedBox(height: LetterTokens.s8),
          Wrap(
            spacing: LetterTokens.s8,
            runSpacing: LetterTokens.s4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const ProvenanceTag(observed: true),
              if (flow != null) FlowGlyph(flow: flow, emphasis: true),
              Text(
                '${MaterialLocalizations.of(context).formatMediumDate(today.asLocalDateTime)} · '
                '${_coverage(recordedDays, totalDays)}',
                style: letterHelper(size: 12.5),
              ),
            ],
          ),
          const SizedBox(height: LetterTokens.s12),
          Text(
            'Flow describes today inside your recorded period.',
            style: letterHelper(size: 12.5),
          ),
          const SizedBox(height: LetterTokens.s16),
          action,
        ],
      ),
    );
  }
}

String _coverage(int recorded, int total) {
  if (recorded == 0) return 'flow not recorded';
  if (recorded == total) return 'all $total days recorded';
  return '$recorded of $total days recorded';
}
