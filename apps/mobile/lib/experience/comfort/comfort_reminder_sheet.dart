import 'package:flutter/material.dart';

import '../theme/experience_foundation.dart';

final class ComfortReminderSelection {
  const ComfortReminderSelection({
    required this.enabled,
    required this.leadDays,
  });

  final bool enabled;
  final int leadDays;
}

String comfortReminderLeadLabel(int leadDays) => switch (leadDays) {
  0 => 'On the estimated first day',
  1 => '1 day before',
  _ => '2 days before',
};

Future<ComfortReminderSelection?> showComfortReminderSheet(
  BuildContext context, {
  required bool enabled,
  required bool configured,
  required int leadDays,
}) {
  return showExperienceSheet<ComfortReminderSelection>(
    context,
    child: _ComfortReminderSheet(
      enabled: enabled,
      configured: configured,
      leadDays: leadDays,
    ),
  );
}

class _ComfortReminderSheet extends StatefulWidget {
  const _ComfortReminderSheet({
    required this.enabled,
    required this.configured,
    required this.leadDays,
  });

  final bool enabled;
  final bool configured;
  final int leadDays;

  @override
  State<_ComfortReminderSheet> createState() => _ComfortReminderSheetState();
}

class _ComfortReminderSheetState extends State<_ComfortReminderSheet> {
  late int _leadDays = widget.leadDays;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        ExperienceSpacing.screenMargin,
        0,
        ExperienceSpacing.screenMargin,
        ExperienceSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Choose a quiet reminder',
            style: ExperienceType.headline(ExperienceColors.ink),
          ),
          const SizedBox(height: ExperienceSpacing.xs),
          Text(
            'Sent at 09:00 local time. The notification stays neutral and '
            'does not name health details. System notification settings '
            'control delivery.',
            style: ExperienceType.bodySmall(ExperienceColors.inkSoft),
          ),
          const SizedBox(height: ExperienceSpacing.sm),
          RadioGroup<int>(
            groupValue: _leadDays,
            onChanged: (value) {
              if (value != null) setState(() => _leadDays = value);
            },
            child: Column(
              children: <Widget>[
                for (final value in const <int>[2, 1, 0])
                  RadioListTile<int>(
                    value: value,
                    activeColor: ExperienceColors.emberBright,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      comfortReminderLeadLabel(value),
                      style: ExperienceType.bodyStrong(ExperienceColors.ink),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: ExperienceSpacing.xs),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('save-comfort-reminder'),
              onPressed: () => Navigator.of(context).pop(
                ComfortReminderSelection(enabled: true, leadDays: _leadDays),
              ),
              style: FilledButton.styleFrom(
                foregroundColor: ExperienceColors.canvas,
                backgroundColor: ExperienceColors.emberBright,
                minimumSize: const Size.fromHeight(
                  ExperienceSpacing.minTouchTarget,
                ),
                shape: const RoundedRectangleBorder(
                  borderRadius: ExperienceRadius.chipRadius,
                ),
              ),
              child: Text(
                widget.enabled ? 'Update reminder' : 'Set reminder',
                style: ExperienceType.label(ExperienceColors.canvas),
              ),
            ),
          ),
          if (widget.configured) ...<Widget>[
            const SizedBox(height: ExperienceSpacing.xs),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                key: const Key('disable-comfort-reminder'),
                onPressed: () => Navigator.of(context).pop(
                  ComfortReminderSelection(enabled: false, leadDays: _leadDays),
                ),
                child: Text(
                  widget.enabled ? 'Turn off reminder' : 'Keep reminder off',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
