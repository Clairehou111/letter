import 'package:flutter/material.dart';

import '../../../design_system/letter_theme.dart';
import '../domain/diary_enrollment.dart';
import '../domain/diary_repository.dart';

/// Opt-in enrollment screen for the prospective daily symptom diary
/// (spec: 2026-07-28-doctor-mode-prospective-diary REQ-001).
///
/// Explains why daily records matter before asking any ratings. Uses
/// calm, descriptive copy; never claims diagnosis or DRSP compatibility.
class DiaryEnrollmentScreen extends StatefulWidget {
  const DiaryEnrollmentScreen({
    required this.enrollmentRepository,
    super.key,
    this.onEnrolled,
    this.onCancel,
  });

  final DiaryEnrollmentRepository enrollmentRepository;
  final VoidCallback? onEnrolled;
  final VoidCallback? onCancel;

  @override
  State<DiaryEnrollmentScreen> createState() => _DiaryEnrollmentScreenState();
}

class _DiaryEnrollmentScreenState extends State<DiaryEnrollmentScreen> {
  bool _starting = false;
  bool _reminderEnabled = false;
  int _reminderHour = 20;
  int _reminderMinute = 0;

  Future<void> _enroll() async {
    setState(() => _starting = true);
    try {
      await widget.enrollmentRepository.create(
        DiaryEnrollmentDraft(
          reminder: _reminderEnabled
              ? DiaryReminder(hour: _reminderHour, minute: _reminderMinute)
              : null,
        ),
      );
      if (mounted) widget.onEnrolled?.call();
    } on DiaryException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You already have an active diary. Pause or stop it first.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: LetterColors.canvas,
      appBar: AppBar(
        title: const Text('Daily symptom diary'),
        leading: widget.onCancel != null
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: widget.onCancel,
              )
            : null,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                const Text(
                  'Record what your body is telling you — every day.',
                  style: TextStyle(
                    fontFamily: 'Newsreader',
                    fontSize: 27,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: LetterSpacing.md),
                Text(
                  'A consistent daily diary helps your clinician understand '
                  'your pattern across at least two cycles. '
                  'Each rating is yours alone — the app never fills in '
                  'missed days.',
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: LetterColors.muted,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: LetterSpacing.lg),
                _InfoCard(
                  icon: Icons.edit_calendar_outlined,
                  title: 'You choose the pace',
                  body: 'Rate the symptoms that matter to you each day. '
                      'Stop or pause anytime. Your data stays local.',
                ),
                const SizedBox(height: LetterSpacing.sm),
                _InfoCard(
                  icon: Icons.visibility_off_outlined,
                  title: 'Missed days stay blank',
                  body: 'The diary never guesses, fills in, or backfills '
                      'a rating you did not enter. Gaps are visible '
                      'and honest.',
                ),
                const SizedBox(height: LetterSpacing.sm),
                _InfoCard(
                  icon: Icons.description_outlined,
                  title: 'For your clinician conversation',
                  body: 'After two cycles you can export a summary with '
                      'visible provenance, missingness, and dates. '
                      'It never claims to diagnose.',
                ),
                const SizedBox(height: LetterSpacing.lg),
                const Text(
                  'What you will rate each day',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: LetterSpacing.sm),
                Text(
                  'Each item uses six clear levels: None, Minimal, Mild, '
                  'Moderate, Severe, Extreme.',
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: LetterColors.muted,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: LetterSpacing.sm),
                Wrap(
                  spacing: LetterSpacing.xs,
                  runSpacing: LetterSpacing.xxs,
                  children: [
                    for (final item in diarySymptomItems)
                      _ItemChip(label: item.label),
                  ],
                ),
                const SizedBox(height: LetterSpacing.lg),
                const Text(
                  'Daily reminder (optional)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: LetterSpacing.xs),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Send a daily prompt'),
                  subtitle: Text(
                    _reminderEnabled
                        ? 'Reminder at ${_reminderHour.toString().padLeft(2, '0')}:${_reminderMinute.toString().padLeft(2, '0')}'
                        : 'No reminder set',
                  ),
                  value: _reminderEnabled,
                  activeThumbColor: LetterColors.teal,
                  onChanged: (value) {
                    setState(() => _reminderEnabled = value);
                  },
                ),
                if (_reminderEnabled) ...[
                  const SizedBox(height: LetterSpacing.xs),
                  Row(
                    children: [
                      Expanded(
                        child: _TimeDropdown(
                          label: 'Hour',
                          value: _reminderHour,
                          items: List.generate(
                            24,
                            (h) => h,
                          ),
                          onChanged: (value) {
                            setState(() => _reminderHour = value!);
                          },
                        ),
                      ),
                      const SizedBox(width: LetterSpacing.sm),
                      Expanded(
                        child: _TimeDropdown(
                          label: 'Minute',
                          value: _reminderMinute,
                          items: const [0, 15, 30, 45],
                          onChanged: (value) {
                            setState(() => _reminderMinute = value!);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: LetterSpacing.xl),
                FilledButton.icon(
                  key: const Key('diary-start-enrollment'),
                  onPressed: _starting ? null : _enroll,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: LetterColors.teal,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        LetterRadius.control,
                      ),
                    ),
                  ),
                  icon: _starting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.edit_calendar_outlined),
                  label: const Text('Start my daily diary'),
                ),
                const SizedBox(height: LetterSpacing.sm),
                Center(
                  child: TextButton(
                    onPressed:
                        _starting ? null : () => widget.onCancel?.call(),
                    child: const Text(
                      'Not right now',
                      style: TextStyle(color: LetterColors.muted),
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

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(LetterSpacing.md),
      decoration: BoxDecoration(
        color: LetterColors.surface,
        borderRadius: BorderRadius.circular(LetterRadius.panel),
        border: Border.all(color: LetterColors.line),
        boxShadow: LetterShadows.soft,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: LetterColors.tealSoft,
              borderRadius: BorderRadius.circular(LetterRadius.control),
            ),
            child: Icon(icon, size: 20, color: LetterColors.teal),
          ),
          const SizedBox(width: LetterSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: LetterSpacing.xxs),
                Text(
                  body,
                  style: const TextStyle(
                    color: LetterColors.muted,
                    fontSize: 13,
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

class _ItemChip extends StatelessWidget {
  const _ItemChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: LetterColors.tealSoft,
        borderRadius: BorderRadius.circular(LetterRadius.control),
        border: Border.all(color: LetterColors.teal.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: LetterColors.tealDark,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TimeDropdown extends StatelessWidget {
  const _TimeDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final int value;
  final List<int> items;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LetterRadius.control),
          borderSide: const BorderSide(color: LetterColors.line),
        ),
      ),
      items: items
          .map(
            (item) => DropdownMenuItem<int>(
              value: item,
              child: Text(item.toString().padLeft(2, '0')),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}
