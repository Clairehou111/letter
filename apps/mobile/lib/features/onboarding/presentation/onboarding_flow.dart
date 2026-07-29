import 'package:flutter/material.dart';

import '../../../design_system/letter_theme.dart';
import '../domain/onboarding_profile.dart';

typedef CompleteOnboarding = Future<void> Function(OnboardingProfile profile);

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({required this.onComplete, super.key});

  final CompleteOnboarding onComplete;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  static const _stepCount = 3;

  int _step = 0;
  CloudToolsPreference _cloudPreference = CloudToolsPreference.off;
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
          cloudToolsPreference: _cloudPreference,
          selectedGoals: _selectedGoals,
        ),
      );
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _saveError = 'Letter could not save this on your device. Try again.';
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
    setState(() {
      if (!_selectedGoals.add(goal)) {
        _selectedGoals.remove(goal);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_step + 1) / _stepCount;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
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
                            const _LetterMark(),
                            const Spacer(),
                            Text(
                              '${_step + 1} of $_stepCount',
                              style: const TextStyle(
                                color: LetterColors.muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: LetterSpacing.md),
                      Semantics(
                        label: 'Onboarding step ${_step + 1} of $_stepCount',
                        value: '${(progress * 100).round()} percent',
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 4,
                          borderRadius: BorderRadius.circular(2),
                          color: LetterColors.teal,
                          backgroundColor: LetterColors.tealSoft,
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
                      duration: const Duration(milliseconds: 180),
                      child: KeyedSubtree(
                        key: ValueKey(_step),
                        child: switch (_step) {
                          0 => const _PromiseStep(),
                          1 => _PrivacyStep(
                            preference: _cloudPreference,
                            onSelected: (value) {
                              setState(() => _cloudPreference = value);
                            },
                          ),
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
                    color: LetterColors.surface,
                    border: Border(top: BorderSide(color: LetterColors.line)),
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
                              bottom: LetterSpacing.sm,
                            ),
                            child: Semantics(
                              liveRegion: true,
                              child: Text(
                                error,
                                key: const Key('onboarding-save-error'),
                                style: const TextStyle(
                                  color: LetterColors.safetyRed,
                                  fontWeight: FontWeight.w700,
                                ),
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
                                      icon: const Icon(Icons.arrow_back),
                                    ),
                            ),
                            const SizedBox(width: LetterSpacing.sm),
                            Expanded(
                              child: FilledButton(
                                key: const Key('onboarding-continue'),
                                onPressed: _saving ? null : _continue,
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(48),
                                  backgroundColor: LetterColors.teal,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      LetterRadius.control,
                                    ),
                                  ),
                                ),
                                child: _saving
                                    ? const SizedBox.square(
                                        dimension: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        _step == _stepCount - 1
                                            ? 'Open Letter'
                                            : 'Continue',
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

class _LetterMark extends StatelessWidget {
  const _LetterMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: LetterColors.teal,
            borderRadius: BorderRadius.circular(LetterRadius.control),
          ),
          child: const Icon(
            Icons.description_outlined,
            size: 18,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: LetterSpacing.sm),
        const Text(
          'LETTER',
          style: TextStyle(
            fontFamily: 'Newsreader',
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
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
        const SizedBox(height: LetterSpacing.lg),
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: LetterColors.tealSoft,
            borderRadius: BorderRadius.circular(LetterRadius.panel),
          ),
          child: const Icon(
            Icons.mark_unread_chat_alt_outlined,
            color: LetterColors.teal,
            size: 29,
          ),
        ),
        const SizedBox(height: LetterSpacing.xl),
        const LetterEyebrow('A clearer cycle starts here'),
        const SizedBox(height: LetterSpacing.sm),
        const Text(
          "Read your body's letter.",
          style: TextStyle(
            fontFamily: 'Newsreader',
            fontSize: 38,
            height: 1.05,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: LetterSpacing.md),
        const Text(
          'Track the full pattern: energy, flow, good days, difficult days, '
          'and what helps you feel more like yourself.',
          style: TextStyle(
            color: LetterColors.muted,
            fontSize: 16,
            height: 1.5,
          ),
        ),
        const SizedBox(height: LetterSpacing.xl),
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
      padding: const EdgeInsets.only(bottom: LetterSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: LetterColors.teal, size: 23),
          const SizedBox(width: LetterSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: LetterSpacing.xxs),
                Text(
                  body,
                  style: const TextStyle(
                    color: LetterColors.muted,
                    height: 1.4,
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

class _PrivacyStep extends StatelessWidget {
  const _PrivacyStep({required this.preference, required this.onSelected});

  final CloudToolsPreference preference;
  final ValueChanged<CloudToolsPreference> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: LetterSpacing.lg),
        const LetterEyebrow('Private by default'),
        const SizedBox(height: LetterSpacing.sm),
        const Text(
          'Your story stays with you.',
          style: TextStyle(
            fontFamily: 'Newsreader',
            fontSize: 34,
            height: 1.05,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: LetterSpacing.md),
        const Text(
          'Your records stay on this device. Letter never sends them to a '
          'cloud tool unless you first see what is selected and approve that '
          'specific request.',
          style: TextStyle(
            color: LetterColors.muted,
            fontSize: 15,
            height: 1.5,
          ),
        ),
        const SizedBox(height: LetterSpacing.xl),
        _SelectionTile(
          key: const Key('cloud-tools-off'),
          selected: preference == CloudToolsPreference.off,
          icon: Icons.cloud_off_outlined,
          title: 'Cloud tools off',
          body: 'Keep optional AI tools unavailable for now.',
          onTap: () => onSelected(CloudToolsPreference.off),
        ),
        const SizedBox(height: LetterSpacing.sm),
        _SelectionTile(
          key: const Key('cloud-tools-ask'),
          selected: preference == CloudToolsPreference.askEachTime,
          icon: Icons.visibility_outlined,
          title: 'Ask me each time',
          body: 'Show the exact purpose and selected data before I decide.',
          onTap: () => onSelected(CloudToolsPreference.askEachTime),
        ),
        const SizedBox(height: LetterSpacing.xl),
        const _PrivacyFact(
          icon: Icons.lock_outline,
          text: 'Onboarding choices are stored securely on this device.',
        ),
        const _PrivacyFact(
          icon: Icons.delete_outline,
          text: 'You can clear these choices from the You tab.',
        ),
        const _PrivacyFact(
          icon: Icons.no_accounts_outlined,
          text: 'No account is required to begin.',
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
      padding: const EdgeInsets.only(bottom: LetterSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: LetterColors.teal),
          const SizedBox(width: LetterSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(height: 1.4, fontWeight: FontWeight.w600),
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
        const SizedBox(height: LetterSpacing.lg),
        const LetterEyebrow('Start with what matters'),
        const SizedBox(height: LetterSpacing.sm),
        const Text(
          'What would you like Letter to help with?',
          style: TextStyle(
            fontFamily: 'Newsreader',
            fontSize: 32,
            height: 1.08,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: LetterSpacing.md),
        const Text(
          'Choose any, or skip for now. These are goals, not diagnoses.',
          style: TextStyle(
            color: LetterColors.muted,
            fontSize: 15,
            height: 1.45,
          ),
        ),
        const SizedBox(height: LetterSpacing.xl),
        for (final goal in OnboardingGoal.values) ...[
          _SelectionTile(
            key: Key('goal-${goal.storageId}'),
            selected: selectedGoals.contains(goal),
            icon: goal.icon,
            title: goal.title,
            body: goal.description,
            onTap: () => onToggle(goal),
          ),
          const SizedBox(height: LetterSpacing.sm),
        ],
      ],
    );
  }
}

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
        color: selected ? LetterColors.tealSoft : LetterColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LetterRadius.panel),
          side: BorderSide(
            color: selected ? LetterColors.teal : LetterColors.line,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(LetterRadius.panel),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.all(LetterSpacing.md),
              child: Row(
                children: [
                  Icon(
                    icon,
                    color: selected ? LetterColors.teal : LetterColors.muted,
                    size: 24,
                  ),
                  const SizedBox(width: LetterSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: LetterSpacing.xxs),
                        Text(
                          body,
                          style: const TextStyle(
                            color: LetterColors.muted,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: LetterSpacing.sm),
                  Icon(
                    selected ? Icons.check_circle : Icons.circle_outlined,
                    color: selected ? LetterColors.teal : LetterColors.line,
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
