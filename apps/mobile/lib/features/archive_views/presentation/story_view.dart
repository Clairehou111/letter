import 'package:flutter/material.dart';

import '../../../design_system/letter_theme.dart';
import '../domain/archive_view_models.dart';

class ArchiveStoryView extends StatelessWidget {
  const ArchiveStoryView({required this.viewModel, super.key});

  final ArchiveStoryViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final hasContent =
        viewModel.cycleReflection != null || viewModel.careGroups.isNotEmpty;
    return ListView(
      key: const Key('archive-story-scroll'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        const _EvidenceNote(
          text:
              'Story organizes your saved words and factual Care memories. '
              'Letter does not add a narrative or interpretation.',
        ),
        const SizedBox(height: LetterSpacing.lg),
        if (!hasContent)
          const _EmptyArchiveSection(
            key: Key('archive-story-empty'),
            title: 'Nothing saved here yet',
            body:
                'A cycle reflection and grouped Care moments will appear here.',
          )
        else ...[
          const _SectionHeading(
            eyebrow: 'Your words',
            title: 'Cycle reflection',
          ),
          const SizedBox(height: LetterSpacing.sm),
          if (viewModel.cycleReflection case final reflection?)
            _CycleReflectionCard(reflection: reflection)
          else
            const _NotRecordedCard(
              text: 'No cycle reflection was saved for this cycle.',
            ),
          const SizedBox(height: LetterSpacing.xl),
          const _SectionHeading(
            eyebrow: 'What you tried',
            title: 'Care overview',
          ),
          const SizedBox(height: LetterSpacing.xs),
          const Text(
            'Repeated actions are grouped. Open a group for dates, outcomes, '
            'and any older Care notes.',
            style: TextStyle(color: LetterColors.muted, height: 1.45),
          ),
          const SizedBox(height: LetterSpacing.sm),
          if (viewModel.careGroups.isEmpty)
            const _NotRecordedCard(
              text: 'No Care moments were saved for this cycle.',
            )
          else
            for (final group in viewModel.careGroups)
              _CareGroupCard(group: group),
        ],
        if (viewModel.missingNote case final missing?) ...[
          const SizedBox(height: LetterSpacing.md),
          _MissingNote(text: missing),
        ],
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.eyebrow, required this.title});

  final String eyebrow;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LetterEyebrow(eyebrow, color: LetterColors.violet),
        const SizedBox(height: LetterSpacing.xxs),
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Newsreader',
            fontSize: 23,
            height: 1.1,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _CycleReflectionCard extends StatelessWidget {
  const _CycleReflectionCard({required this.reflection});

  final ArchiveStoryReflection reflection;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      if (reflection.observation case final value?) ('What stood out', value),
      if (reflection.needLabel case final value?) ('What you needed', value),
      if (reflection.whatHelped case final value?) ('What helped', value),
      if (reflection.futureSelfNote case final value?) ('For next time', value),
    ];
    return Container(
      key: const Key('archive-cycle-reflection'),
      padding: const EdgeInsets.all(LetterSpacing.md),
      decoration: BoxDecoration(
        color: LetterColors.violetSoft,
        border: Border.all(color: LetterColors.line),
        borderRadius: BorderRadius.circular(LetterRadius.panel),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Updated ${reflection.updatedLabel}',
            style: const TextStyle(color: LetterColors.muted, fontSize: 12),
          ),
          for (final row in rows) ...[
            const SizedBox(height: LetterSpacing.sm),
            Text(
              row.$1,
              style: const TextStyle(
                color: LetterColors.violet,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: LetterSpacing.xxs),
            Text(row.$2, style: const TextStyle(height: 1.45)),
          ],
        ],
      ),
    );
  }
}

class _CareGroupCard extends StatelessWidget {
  const _CareGroupCard({required this.group});

  final ArchiveStoryCareGroup group;

  @override
  Widget build(BuildContext context) {
    final outcomes = [
      if (group.better > 0) '${group.better} better',
      if (group.same > 0) '${group.same} same',
      if (group.worse > 0) '${group.worse} worse',
    ].join(' · ');
    return Container(
      key: Key('archive-care-group-${group.actionLabel.hashCode}'),
      margin: const EdgeInsets.only(bottom: LetterSpacing.sm),
      decoration: BoxDecoration(
        color: LetterColors.surface,
        border: Border.all(color: LetterColors.line),
        borderRadius: BorderRadius.circular(LetterRadius.panel),
      ),
      child: Material(
        color: Colors.transparent,
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: LetterSpacing.md),
          childrenPadding: const EdgeInsets.fromLTRB(
            LetterSpacing.md,
            0,
            LetterSpacing.md,
            LetterSpacing.md,
          ),
          leading: const Icon(
            Icons.volunteer_activism_outlined,
            color: LetterColors.teal,
          ),
          title: Text(
            group.actionLabel,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            [
              'Used ${group.total} ${group.total == 1 ? 'time' : 'times'}',
              if (outcomes.isNotEmpty) outcomes,
            ].join('  •  '),
            style: const TextStyle(color: LetterColors.muted, fontSize: 12),
          ),
          children: [
            for (final moment in group.moments) _CareMomentRow(moment: moment),
          ],
        ),
      ),
    );
  }
}

class _CareMomentRow extends StatelessWidget {
  const _CareMomentRow({required this.moment});

  final ArchiveStoryCareMoment moment;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: LetterSpacing.sm),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: LetterColors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            moment.dateLabel,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: LetterSpacing.xxs),
          Text(
            moment.outcomeLabel,
            style: const TextStyle(color: LetterColors.muted),
          ),
          if (moment.careNote case final note?) ...[
            const SizedBox(height: LetterSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(LetterSpacing.sm),
              decoration: const BoxDecoration(
                color: LetterColors.tealSoft,
                border: Border(
                  left: BorderSide(color: LetterColors.teal, width: 3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Saved Care note',
                    style: TextStyle(
                      color: LetterColors.tealDark,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: LetterSpacing.xxs),
                  Text(note, style: const TextStyle(height: 1.45)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EvidenceNote extends StatelessWidget {
  const _EvidenceNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(LetterSpacing.md),
      decoration: const BoxDecoration(
        color: LetterColors.violetSoft,
        border: Border(left: BorderSide(color: LetterColors.violet, width: 4)),
      ),
      child: Text(text, style: const TextStyle(height: 1.45)),
    );
  }
}

class _NotRecordedCard extends StatelessWidget {
  const _NotRecordedCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(LetterSpacing.md),
      decoration: BoxDecoration(
        color: LetterColors.surface,
        border: Border.all(color: LetterColors.line),
        borderRadius: BorderRadius.circular(LetterRadius.panel),
      ),
      child: Text(
        text,
        style: const TextStyle(color: LetterColors.muted, height: 1.45),
      ),
    );
  }
}

class _EmptyArchiveSection extends StatelessWidget {
  const _EmptyArchiveSection({
    required this.title,
    required this.body,
    super.key,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(LetterSpacing.lg),
      decoration: BoxDecoration(
        color: LetterColors.surface,
        border: Border.all(color: LetterColors.line),
        borderRadius: BorderRadius.circular(LetterRadius.panel),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.mail_outline, color: LetterColors.violet, size: 28),
          const SizedBox(height: LetterSpacing.sm),
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: LetterSpacing.xs),
          Text(
            body,
            style: const TextStyle(color: LetterColors.muted, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _MissingNote extends StatelessWidget {
  const _MissingNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      key: const Key('archive-story-missing'),
      style: const TextStyle(color: LetterColors.muted, height: 1.45),
    );
  }
}
