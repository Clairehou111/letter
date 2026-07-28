import 'package:flutter/material.dart';

import '../../../design_system/letter_theme.dart';
import '../domain/care_memory.dart';

const _careMemoryError =
    'Letter could not update private Care memory. Try again.';

class CareCheckBackFlow extends StatelessWidget {
  const CareCheckBackFlow({
    required this.onOutcome,
    required this.onSkip,
    required this.onKeepInKit,
    required this.onDone,
    super.key,
    this.recordedOutcome,
    this.isPinned = false,
    this.isBusy = false,
    this.hasError = false,
    this.onRetry,
  });

  final ValueChanged<CareOutcome> onOutcome;
  final VoidCallback onSkip;
  final VoidCallback onKeepInKit;
  final VoidCallback onDone;
  final CareOutcome? recordedOutcome;
  final bool isPinned;
  final bool isBusy;
  final bool hasError;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.45;

    return Scaffold(
      key: const Key('care-checkback-flow'),
      backgroundColor: const Color(0xFFF3F5F4),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: CustomScrollView(
              key: const Key('care-checkback-scroll'),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 24, 18, 28),
                  sliver: SliverList.list(
                    children: [
                      const LetterEyebrow(
                        'A quiet check-back',
                        color: LetterColors.teal,
                      ),
                      const SizedBox(height: LetterSpacing.md),
                      Text(
                        'How is this moment now?',
                        key: const Key('care-checkback-question'),
                        style: TextStyle(
                          color: LetterColors.ink,
                          fontFamily: 'Newsreader',
                          fontSize: largeText ? 25 : 30,
                          height: 1.08,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: LetterSpacing.xs),
                      const Text(
                        'Choose only what feels true. You can also skip.',
                        style: TextStyle(
                          color: LetterColors.muted,
                          fontSize: 14,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: LetterSpacing.xl),
                      if (recordedOutcome == null)
                        _OutcomeChoices(
                          enabled: !isBusy,
                          onOutcome: onOutcome,
                          onSkip: onSkip,
                        )
                      else
                        _RecordedOutcome(
                          outcome: recordedOutcome!,
                          isPinned: isPinned,
                          isBusy: isBusy,
                          onKeepInKit: onKeepInKit,
                          onDone: onDone,
                        ),
                      if (isBusy) ...[
                        const SizedBox(height: LetterSpacing.md),
                        Center(
                          child: Semantics(
                            label: 'Updating private Care memory',
                            child: const SizedBox.square(
                              dimension: 24,
                              child: CircularProgressIndicator(
                                key: Key('care-checkback-progress'),
                                strokeWidth: 2.5,
                                color: LetterColors.teal,
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (hasError) ...[
                        const SizedBox(height: LetterSpacing.md),
                        _CareError(onRetry: onRetry),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OutcomeChoices extends StatelessWidget {
  const _OutcomeChoices({
    required this.enabled,
    required this.onOutcome,
    required this.onSkip,
  });

  final bool enabled;
  final ValueChanged<CareOutcome> onOutcome;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stack =
            constraints.maxWidth < 340 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.45;
        final choices = [
          _OutcomeButton(
            buttonKey: const Key('care-checkback-better'),
            label: 'Better',
            icon: Icons.arrow_upward,
            color: LetterColors.teal,
            enabled: enabled,
            onPressed: () => onOutcome(CareOutcome.better),
          ),
          _OutcomeButton(
            buttonKey: const Key('care-checkback-same'),
            label: 'Same',
            icon: Icons.remove,
            color: LetterColors.blue,
            enabled: enabled,
            onPressed: () => onOutcome(CareOutcome.same),
          ),
          _OutcomeButton(
            buttonKey: const Key('care-checkback-worse'),
            label: 'Worse',
            icon: Icons.arrow_downward,
            color: LetterColors.coral,
            enabled: enabled,
            onPressed: () => onOutcome(CareOutcome.worse),
          ),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (stack)
              for (var index = 0; index < choices.length; index++) ...[
                choices[index],
                if (index != choices.length - 1)
                  const SizedBox(height: LetterSpacing.xs),
              ]
            else
              Row(
                children: [
                  for (var index = 0; index < choices.length; index++) ...[
                    Expanded(child: choices[index]),
                    if (index != choices.length - 1)
                      const SizedBox(width: LetterSpacing.xs),
                  ],
                ],
              ),
            const SizedBox(height: LetterSpacing.sm),
            TextButton(
              key: const Key('care-checkback-skip'),
              onPressed: enabled ? onSkip : null,
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: LetterColors.muted,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(LetterRadius.control),
                ),
              ),
              child: const Text('Skip'),
            ),
          ],
        );
      },
    );
  }
}

class _OutcomeButton extends StatelessWidget {
  const _OutcomeButton({
    required this.buttonKey,
    required this.label,
    required this.icon,
    required this.color,
    required this.enabled,
    required this.onPressed,
  });

  final Key buttonKey;
  final String label;
  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      key: buttonKey,
      onPressed: enabled ? onPressed : null,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(44, 54),
        padding: const EdgeInsets.symmetric(
          horizontal: LetterSpacing.sm,
          vertical: LetterSpacing.sm,
        ),
        foregroundColor: color,
        backgroundColor: LetterColors.surface,
        side: BorderSide(color: color.withValues(alpha: 0.55)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LetterRadius.control),
        ),
      ),
      icon: Icon(icon, size: 19),
      label: Text(label),
    );
  }
}

class _RecordedOutcome extends StatelessWidget {
  const _RecordedOutcome({
    required this.outcome,
    required this.isPinned,
    required this.isBusy,
    required this.onKeepInKit,
    required this.onDone,
  });

  final CareOutcome outcome;
  final bool isPinned;
  final bool isBusy;
  final VoidCallback onKeepInKit;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final label = switch (outcome) {
      CareOutcome.better => 'Better',
      CareOutcome.same => 'Same',
      CareOutcome.worse => 'Worse',
    };

    return Semantics(
      container: true,
      label: 'Recorded exactly as $label',
      child: Container(
        key: const Key('care-checkback-recorded'),
        padding: const EdgeInsets.all(LetterSpacing.lg),
        decoration: BoxDecoration(
          color: LetterColors.surface,
          border: Border.all(color: LetterColors.line),
          borderRadius: BorderRadius.circular(LetterRadius.panel),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.mark_email_read_outlined,
              color: LetterColors.teal,
              size: 30,
            ),
            const SizedBox(height: LetterSpacing.sm),
            Text(
              'Recorded as $label.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                height: 1.25,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: LetterSpacing.xs),
            Text(
              isPinned
                  ? 'This action is in your Care Kit.'
                  : 'Keep this action only if you want it nearby.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: LetterColors.muted,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: LetterSpacing.lg),
            if (!isPinned)
              FilledButton.icon(
                key: const Key('care-checkback-keep'),
                onPressed: isBusy ? null : onKeepInKit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: LetterColors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(LetterRadius.control),
                  ),
                ),
                icon: const Icon(Icons.bookmark_add_outlined),
                label: const Text('Keep in my Care Kit'),
              ),
            if (!isPinned) const SizedBox(height: LetterSpacing.xs),
            TextButton(
              key: const Key('care-checkback-done'),
              onPressed: isBusy ? null : onDone,
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: LetterColors.ink,
              ),
              child: Text(isPinned ? 'Done' : 'Not now'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CareError extends StatelessWidget {
  const _CareError({required this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const Key('care-checkback-error'),
      liveRegion: true,
      label: _careMemoryError,
      child: Container(
        padding: const EdgeInsets.all(LetterSpacing.md),
        decoration: BoxDecoration(
          color: LetterColors.coralSoft,
          border: Border.all(color: LetterColors.coral),
          borderRadius: BorderRadius.circular(LetterRadius.panel),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ExcludeSemantics(
              child: Text(
                _careMemoryError,
                style: TextStyle(height: 1.4, fontWeight: FontWeight.w700),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: LetterSpacing.xs),
              TextButton.icon(
                key: const Key('care-checkback-retry'),
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  foregroundColor: LetterColors.ink,
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
