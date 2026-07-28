import 'package:flutter/material.dart';

import '../../../design_system/letter_bottom_navigation.dart';
import '../../../design_system/letter_theme.dart';
import '../../care/presentation/care_screen.dart';
import '../../cycle/domain/period_repository.dart';
import '../../cycle/presentation/cycle_screen.dart';
import '../../today/today_screen.dart';
import '../domain/onboarding_profile.dart';

typedef UpdateOnboardingProfile =
    Future<void> Function(OnboardingProfile profile);

class LetterHome extends StatefulWidget {
  const LetterHome({
    required this.profile,
    required this.periodRepository,
    required this.onProfileChanged,
    required this.onReset,
    this.now,
    super.key,
  });

  final OnboardingProfile profile;
  final PeriodRepository periodRepository;
  final UpdateOnboardingProfile onProfileChanged;
  final Future<void> Function() onReset;
  final DateTime Function()? now;

  @override
  State<LetterHome> createState() => _LetterHomeState();
}

class _LetterHomeState extends State<LetterHome> {
  int _selectedIndex = 2;

  void _selectTab(int index) {
    if (index != 0 && index != 2 && index != 3 && index != 4) {
      return;
    }
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedIndex == 0) {
      return CycleScreen(
        repository: widget.periodRepository,
        onNavigationSelected: _selectTab,
        now: widget.now,
      );
    }
    if (_selectedIndex == 4) {
      return PrivacyCenterScreen(
        profile: widget.profile,
        onProfileChanged: widget.onProfileChanged,
        onReset: widget.onReset,
        onNavigationSelected: _selectTab,
      );
    }
    if (_selectedIndex == 3) {
      return CareScreen(onNavigationSelected: _selectTab);
    }
    return TodayScreen(
      repository: widget.periodRepository,
      onNavigationSelected: _selectTab,
      now: widget.now,
    );
  }
}

class PrivacyCenterScreen extends StatefulWidget {
  const PrivacyCenterScreen({
    required this.profile,
    required this.onProfileChanged,
    required this.onReset,
    required this.onNavigationSelected,
    super.key,
  });

  final OnboardingProfile profile;
  final UpdateOnboardingProfile onProfileChanged;
  final Future<void> Function() onReset;
  final ValueChanged<int> onNavigationSelected;

  @override
  State<PrivacyCenterScreen> createState() => _PrivacyCenterScreenState();
}

class _PrivacyCenterScreenState extends State<PrivacyCenterScreen> {
  bool _updating = false;

  Future<void> _updatePreference(CloudToolsPreference preference) async {
    if (_updating || preference == widget.profile.cloudToolsPreference) {
      return;
    }
    setState(() => _updating = true);
    try {
      await widget.onProfileChanged(
        widget.profile.copyWith(cloudToolsPreference: preference),
      );
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Letter could not update this setting. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _updating = false);
      }
    }
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear onboarding choices?'),
        content: const Text(
          'This clears your privacy mode and selected goals from this device. '
          'It does not affect future cycle records.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm-reset-onboarding'),
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF9D3D35),
            ),
            child: const Text('Clear choices'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await widget.onReset();
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Letter could not clear these choices. Try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: LetterBottomNavigation(
        selectedIndex: 4,
        onSelected: widget.onNavigationSelected,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
                  sliver: SliverList.list(
                    children: [
                      const _PrivacyHeader(),
                      const SizedBox(height: LetterSpacing.xl),
                      const LetterEyebrow('Privacy and AI'),
                      const SizedBox(height: LetterSpacing.sm),
                      const Text(
                        'You decide what leaves your phone.',
                        style: TextStyle(
                          fontFamily: 'Newsreader',
                          fontSize: 30,
                          height: 1.08,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: LetterSpacing.md),
                      const Text(
                        'Changing this preference never approves a particular '
                        'cloud request. Letter must still show its purpose and '
                        'selected data first.',
                        style: TextStyle(
                          color: LetterColors.muted,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: LetterSpacing.lg),
                      _PrivacyModeTile(
                        key: const Key('privacy-center-off'),
                        title: 'Cloud tools off',
                        body: 'Optional cloud features stay unavailable.',
                        selected:
                            widget.profile.cloudToolsPreference ==
                            CloudToolsPreference.off,
                        enabled: !_updating,
                        onTap: () =>
                            _updatePreference(CloudToolsPreference.off),
                      ),
                      const SizedBox(height: LetterSpacing.sm),
                      _PrivacyModeTile(
                        key: const Key('privacy-center-ask'),
                        title: 'Ask me each time',
                        body: 'Preview purpose and data before every decision.',
                        selected:
                            widget.profile.cloudToolsPreference ==
                            CloudToolsPreference.askEachTime,
                        enabled: !_updating,
                        onTap: () =>
                            _updatePreference(CloudToolsPreference.askEachTime),
                      ),
                      const SizedBox(height: LetterSpacing.xl),
                      const LetterEyebrow('Your starting goals'),
                      const SizedBox(height: LetterSpacing.sm),
                      if (widget.profile.selectedGoals.isEmpty)
                        const Text(
                          'No goals selected yet.',
                          style: TextStyle(color: LetterColors.muted),
                        )
                      else
                        Wrap(
                          spacing: LetterSpacing.xs,
                          runSpacing: LetterSpacing.xs,
                          children: [
                            for (final goal in widget.profile.selectedGoals)
                              Chip(
                                label: Text(goal.shortLabel),
                                side: const BorderSide(
                                  color: LetterColors.line,
                                ),
                                backgroundColor: LetterColors.surface,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    LetterRadius.control,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      const SizedBox(height: 36),
                      const Divider(),
                      const SizedBox(height: LetterSpacing.md),
                      TextButton.icon(
                        key: const Key('reset-onboarding'),
                        onPressed: _confirmReset,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF9D3D35),
                          minimumSize: const Size.fromHeight(48),
                          alignment: Alignment.centerLeft,
                        ),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Clear onboarding choices'),
                      ),
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

class _PrivacyHeader extends StatelessWidget {
  const _PrivacyHeader();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(Icons.person_outline, color: LetterColors.teal, size: 26),
        SizedBox(width: LetterSpacing.sm),
        Text(
          'You',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _PrivacyModeTile extends StatelessWidget {
  const _PrivacyModeTile({
    required this.title,
    required this.body,
    required this.selected,
    required this.enabled,
    required this.onTap,
    super.key,
  });

  final String title;
  final String body;
  final bool selected;
  final bool enabled;
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
          ),
        ),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(LetterRadius.panel),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 76),
            child: Padding(
              padding: const EdgeInsets.all(LetterSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: LetterSpacing.xxs),
                        Text(
                          body,
                          style: const TextStyle(
                            color: LetterColors.muted,
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
  String get shortLabel => switch (this) {
    OnboardingGoal.understandCycle => 'Cycle',
    OnboardingGoal.emotionalChanges => 'Emotions',
    OnboardingGoal.physicalDiscomfort => 'Physical comfort',
    OnboardingGoal.energyAndSleep => 'Energy and sleep',
    OnboardingGoal.selfCarePreparation => 'Self-care',
    OnboardingGoal.appointmentPreparation => 'Appointments',
  };
}
