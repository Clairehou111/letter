import 'package:flutter/material.dart';

import '../../../design_system/letter_brand_mark.dart';
import '../../../experience/theme/experience_foundation.dart';
import '../domain/onboarding_profile.dart';
import 'privacy_explainer_sheet.dart';

typedef CompleteOnboarding = Future<void> Function(OnboardingProfile profile);

/// The first minute of Letter Within: promise → privacy → goals, spoken in
/// the same warm daylight language as the Today screen that follows it —
/// cream canvas, plum Georgia lockup, an ember progress track, and one ember
/// primary action. Crossing this threshold never registers as leaving the
/// product.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({required this.onComplete, super.key});

  final CompleteOnboarding onComplete;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  static const _stepCount = 3;

  /// Daylight max-content-width convention, centered on wide surfaces.
  static const double _maxContentWidth = 440;

  int _step = 0;
  final Set<OnboardingGoal> _selectedGoals = {};
  bool _saving = false;
  String? _saveError;

  Future<void> _continue() async {
    if (_step < _stepCount - 1) {
      setState(() {
        _step += 1;
        _saveError = null;
      });
      return;
    }

    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await widget.onComplete(
        OnboardingProfile(
          cloudToolsPreference: CloudToolsPreference.off,
          selectedGoals: _selectedGoals,
        ),
      );
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _saveError =
            'Letter Within could not save this on your device. Try again.';
      });
    }
  }

  void _back() {
    if (_step == 0 || _saving) {
      return;
    }
    setState(() {
      _step -= 1;
      _saveError = null;
    });
  }

  void _toggleGoal(OnboardingGoal goal) {
    ExperienceHaptics.pick();
    setState(() {
      if (!_selectedGoals.add(goal)) {
        _selectedGoals.remove(goal);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_step + 1) / _stepCount;
    final reduceMotion = ExperienceMotion.reducedMotion(context);
    return Scaffold(
      backgroundColor: ExperienceColors.canvas,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxContentWidth),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Column(
                    children: [
                      MediaQuery.withClampedTextScaling(
                        maxScaleFactor: 1.3,
                        child: Row(
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: LetterBrandLockup(
                                  compact:
                                      MediaQuery.sizeOf(context).width < 360,
                                ),
                              ),
                            ),
                            Text(
                              '${_step + 1} of $_stepCount',
                              style: ExperienceType.data(
                                ExperienceColors.inkSoft,
                                size: 13,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: ExperienceSpacing.sm),
                      Semantics(
                        label: 'Onboarding step ${_step + 1} of $_stepCount',
                        value: '${(progress * 100).round()} percent',
                        child: _EmberProgressBar(
                          progress: progress,
                          duration: reduceMotion
                              ? Duration.zero
                              : const Duration(milliseconds: 250),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    key: const Key('onboarding-scroll'),
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    child: AnimatedSwitcher(
                      duration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 250),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeOut,
                      child: KeyedSubtree(
                        key: ValueKey(_step),
                        child: switch (_step) {
                          0 => const _PromiseStep(),
                          1 => const _PrivacyStep(),
                          _ => _GoalsStep(
                            selectedGoals: _selectedGoals,
                            onToggle: _toggleGoal,
                          ),
                        },
                      ),
                    ),
                  ),
                ),
                Container(
                  decoration: const BoxDecoration(
                    color: ExperienceColors.canvas,
                    border: Border(
                      top: BorderSide(color: ExperienceColors.hairline),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_saveError case final error?)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: ExperienceSpacing.unit,
                            ),
                            child: Semantics(
                              liveRegion: true,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(top: 1),
                                    child: Icon(
                                      Icons.error_outline,
                                      size: 18,
                                      color: ExperienceColors.error,
                                    ),
                                  ),
                                  const SizedBox(width: ExperienceSpacing.unit),
                                  Expanded(
                                    child: Text(
                                      error,
                                      key: const Key('onboarding-save-error'),
                                      style: ExperienceType.bodySmall(
                                        ExperienceColors.error,
                                      ).copyWith(fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        Row(
                          children: [
                            SizedBox(
                              width: 48,
                              height: 48,
                              child: _step == 0
                                  ? null
                                  : IconButton.outlined(
                                      key: const Key('onboarding-back'),
                                      tooltip: 'Previous step',
                                      onPressed: _saving ? null : _back,
                                      style: IconButton.styleFrom(
                                        foregroundColor: ExperienceColors.ink,
                                        side: const BorderSide(
                                          color: ExperienceColors.hairline,
                                        ),
                                      ),
                                      icon: const Icon(Icons.arrow_back),
                                    ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Material(
                                color: Colors.transparent,
                                child: Ink(
                                  decoration: BoxDecoration(
                                    gradient: _saving
                                        ? null
                                        : ExperienceColors.emberGradient,
                                    color: _saving
                                        ? ExperienceColors.surfaceWarm
                                        : null,
                                    borderRadius: ExperienceRadius.chipRadius,
                                  ),
                                  child: InkWell(
                                    key: const Key('onboarding-continue'),
                                    onTap: _saving ? null : _continue,
                                    borderRadius: ExperienceRadius.chipRadius,
                                    child: Container(
                                      width: double.infinity,
                                      constraints: const BoxConstraints(
                                        minHeight: 52,
                                      ),
                                      alignment: Alignment.center,
                                      child: _saving
                                          ? const EmberLoadingIndicator(
                                              size: 22,
                                              semanticLabel:
                                                  'Saving your choices',
                                            )
                                          : Text(
                                              _step == _stepCount - 1
                                                  ? 'Open Letter Within'
                                                  : 'Continue',
                                              style: ExperienceType.label(
                                                Colors.white,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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

/// The Ember's Path, applied to step progress: a small ember-gradient fill
/// traveling a warm hairline track. Never a teal bar, never a bare Material
/// progress indicator.
class _EmberProgressBar extends StatelessWidget {
  const _EmberProgressBar({required this.progress, required this.duration});

  final double progress;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Container(
          height: 4,
          color: ExperienceColors.hairline,
          child: Align(
            alignment: Alignment.centerLeft,
            child: AnimatedFractionallySizedBox(
              duration: duration,
              curve: Curves.easeOut,
              widthFactor: progress,
              heightFactor: 1,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: ExperienceColors.emberGradient,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Step header in the foundation's editorial voice: tracked ember eyebrow,
/// Georgia serif title, quiet supporting line.
class _StepHeader extends StatelessWidget {
  const _StepHeader({
    required this.eyebrow,
    required this.title,
    required this.support,
  });

  final String eyebrow;
  final String title;
  final String support;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: ExperienceType.eyebrow(ExperienceColors.emberDeep),
        ),
        const SizedBox(height: ExperienceSpacing.xs),
        Text(title, style: ExperienceType.title(ExperienceColors.ink)),
        const SizedBox(height: ExperienceSpacing.xs),
        Text(
          support,
          style: ExperienceType.bodySmall(ExperienceColors.inkSoft),
        ),
      ],
    );
  }
}

class _PromiseStep extends StatelessWidget {
  const _PromiseStep();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: ExperienceSpacing.lg),
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: ExperienceColors.surfaceWarm,
            borderRadius: ExperienceRadius.cardRadius,
            border: Border.all(color: ExperienceColors.hairline),
          ),
          child: const Icon(
            Icons.mark_unread_chat_alt_outlined,
            color: ExperienceColors.emberDeep,
            size: 29,
          ),
        ),
        const SizedBox(height: ExperienceSpacing.lg),
        const _StepHeader(
          eyebrow: 'A clearer cycle starts here',
          title: "Read your body's letter.",
          support:
              'Track the full pattern: energy, flow, good days, difficult days, '
              'and what helps you feel more like yourself.',
        ),
        const SizedBox(height: ExperienceSpacing.lg),
        const _PromiseRow(
          icon: Icons.calendar_month_outlined,
          title: 'Understand your rhythm',
          body: 'Build an honest picture across several cycles.',
        ),
        const _PromiseRow(
          icon: Icons.volunteer_activism_outlined,
          title: 'Prepare for harder moments',
          body:
              'Keep useful care close without turning your cycle into an enemy.',
        ),
        const _PromiseRow(
          icon: Icons.description_outlined,
          title: 'Bring clearer evidence',
          body: 'Turn your own records into something easier to discuss.',
        ),
      ],
    );
  }
}

class _PromiseRow extends StatelessWidget {
  const _PromiseRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ExperienceSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: ExperienceColors.emberDeep, size: 23),
          const SizedBox(width: ExperienceSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: ExperienceType.label(ExperienceColors.ink)),
                const SizedBox(height: ExperienceSpacing.xs),
                Text(
                  body,
                  style: ExperienceType.bodySmall(ExperienceColors.inkSoft),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyStep extends StatelessWidget {
  const _PrivacyStep();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: ExperienceSpacing.lg),
        const _StepHeader(
          eyebrow: 'Private by default',
          title: 'Your story stays with you.',
          support:
              'Period dates, symptoms, notes, and Care records stay on this device. '
              'They move only when you create an encrypted backup or export.',
        ),
        const SizedBox(height: ExperienceSpacing.unit),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('onboarding-see-privacy'),
            onPressed: () => PrivacyExplainerSheet.show(context),
            style: TextButton.styleFrom(
              minimumSize: const Size(
                ExperienceSpacing.minTouchTarget,
                ExperienceSpacing.minTouchTarget,
              ),
              foregroundColor: ExperienceColors.emberDeep,
              padding: const EdgeInsets.symmetric(
                horizontal: ExperienceSpacing.sm,
                vertical: ExperienceSpacing.unit,
              ),
            ),
            icon: const Icon(Icons.arrow_forward, size: 18),
            iconAlignment: IconAlignment.end,
            label: Text(
              'See how privacy works',
              style: ExperienceType.label(
                ExperienceColors.emberDeep,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: ExperienceSpacing.lg),
        const _PrivacyFact(
          icon: Icons.phone_android_outlined,
          text: 'Your cycle and Care records are stored locally.',
        ),
        const _PrivacyFact(
          icon: Icons.lock_outline,
          text: 'Encrypted backup and restore are available from the You tab.',
        ),
        const _PrivacyFact(
          icon: Icons.account_circle_outlined,
          text: 'Account details stay separate from your health records.',
        ),
      ],
    );
  }
}

class _PrivacyFact extends StatelessWidget {
  const _PrivacyFact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ExperienceSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: ExperienceColors.emberDeep),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: ExperienceType.bodySmall(
                ExperienceColors.ink,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalsStep extends StatelessWidget {
  const _GoalsStep({required this.selectedGoals, required this.onToggle});

  final Set<OnboardingGoal> selectedGoals;
  final ValueChanged<OnboardingGoal> onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: ExperienceSpacing.lg),
        const _StepHeader(
          eyebrow: 'Start with what matters',
          title: 'What would you like Letter Within to help with?',
          support:
              'Choose any, or skip for now. These are goals, not diagnoses.',
        ),
        const SizedBox(height: ExperienceSpacing.lg),
        for (final goal in OnboardingGoal.values) ...[
          _SelectionTile(
            key: Key('goal-${goal.storageId}'),
            selected: selectedGoals.contains(goal),
            icon: goal.icon,
            title: goal.title,
            body: goal.description,
            onTap: () => onToggle(goal),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

/// Multi-select goal tile in the outlined-selected treatment: resting on
/// warm surface with a hairline; selected takes a `surfaceWarm` fill, an
/// ember 1.6 border, and an ember check.
class _SelectionTile extends StatelessWidget {
  const _SelectionTile({
    required this.selected,
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
    super.key,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? ExperienceColors.surfaceWarm
            : ExperienceColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: ExperienceRadius.cardRadius,
          side: BorderSide(
            color: selected
                ? ExperienceColors.ember
                : ExperienceColors.hairline,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: ExperienceRadius.cardRadius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.all(ExperienceSpacing.sm),
              child: Row(
                children: [
                  Icon(
                    icon,
                    color: selected
                        ? ExperienceColors.emberDeep
                        : ExperienceColors.inkSoft,
                    size: 24,
                  ),
                  const SizedBox(width: ExperienceSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: ExperienceType.label(ExperienceColors.ink),
                        ),
                        const SizedBox(height: ExperienceSpacing.xs),
                        Text(
                          body,
                          style: ExperienceType.caption(
                            ExperienceColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    selected ? Icons.check_circle : Icons.circle_outlined,
                    color: selected
                        ? ExperienceColors.ember
                        : ExperienceColors.hairline,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

extension on OnboardingGoal {
  String get title => switch (this) {
    OnboardingGoal.understandCycle => 'Understand my cycle',
    OnboardingGoal.emotionalChanges => 'Notice emotional changes',
    OnboardingGoal.physicalDiscomfort => 'Navigate physical discomfort',
    OnboardingGoal.energyAndSleep => 'Read energy and sleep',
    OnboardingGoal.selfCarePreparation => 'Prepare useful self-care',
    OnboardingGoal.appointmentPreparation => 'Prepare for appointments',
  };

  String get description => switch (this) {
    OnboardingGoal.understandCycle => 'See timing and variation across cycles.',
    OnboardingGoal.emotionalChanges =>
      'Track mood without reducing every day to a symptom.',
    OnboardingGoal.physicalDiscomfort =>
      'Record pain, tenderness, headaches, and other body changes.',
    OnboardingGoal.energyAndSleep =>
      'Notice fatigue, rest, focus, and steadier days.',
    OnboardingGoal.selfCarePreparation =>
      'Remember what made difficult moments more manageable.',
    OnboardingGoal.appointmentPreparation =>
      'Build clearer evidence in your own words.',
  };

  IconData get icon => switch (this) {
    OnboardingGoal.understandCycle => Icons.calendar_month_outlined,
    OnboardingGoal.emotionalChanges => Icons.favorite_border,
    OnboardingGoal.physicalDiscomfort => Icons.waves_outlined,
    OnboardingGoal.energyAndSleep => Icons.bedtime_outlined,
    OnboardingGoal.selfCarePreparation => Icons.volunteer_activism_outlined,
    OnboardingGoal.appointmentPreparation => Icons.description_outlined,
  };
}
