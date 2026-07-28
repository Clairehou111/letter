import 'package:flutter/material.dart';

import '../../../design_system/letter_theme.dart';
import '../domain/archive_view_models.dart';

class ArchiveStoryView extends StatelessWidget {
  const ArchiveStoryView({required this.viewModel, super.key});

  final ArchiveStoryViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('archive-story-scroll'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        const _EvidenceNote(
          text:
              'Story keeps saved words and factual Care memories together. '
              'Letter does not add a narrative or interpretation.',
        ),
        const SizedBox(height: LetterSpacing.md),
        if (viewModel.items.isEmpty)
          const _EmptyArchiveSection(
            key: Key('archive-story-empty'),
            title: 'Nothing saved here yet',
            body:
                'Saved Care memories and reflections will appear in this cycle.',
          )
        else
          ...viewModel.items.map((item) => _StoryItem(item: item)),
        if (viewModel.missingNote case final missing?) ...[
          const SizedBox(height: LetterSpacing.md),
          _MissingNote(text: missing),
        ],
      ],
    );
  }
}

class _StoryItem extends StatelessWidget {
  const _StoryItem({required this.item});

  final ArchiveStoryItem item;

  @override
  Widget build(BuildContext context) {
    final icon = switch (item.kind) {
      ArchiveStoryItemKind.careMemory => Icons.volunteer_activism_outlined,
      ArchiveStoryItemKind.reflection => Icons.edit_note_outlined,
      ArchiveStoryItemKind.futureSelfNote => Icons.bookmark_border,
    };
    return Container(
      key: Key(
        'archive-story-item-${item.kind.name}-${item.occurredAt.microsecondsSinceEpoch}',
      ),
      margin: const EdgeInsets.only(bottom: LetterSpacing.sm),
      padding: const EdgeInsets.all(LetterSpacing.md),
      decoration: BoxDecoration(
        color: LetterColors.surface,
        border: Border.all(color: LetterColors.line),
        borderRadius: BorderRadius.circular(LetterRadius.panel),
      ),
      child: Semantics(
        container: true,
        label: '${item.title}. ${item.body}. ${item.sourceLabel}',
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: LetterColors.violet, size: 22),
            const SizedBox(width: LetterSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: LetterSpacing.xs),
                  Text(item.body),
                  const SizedBox(height: LetterSpacing.xs),
                  Text(
                    item.sourceLabel,
                    style: const TextStyle(
                      color: LetterColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
      child: Text(
        text,
        style: const TextStyle(color: LetterColors.ink, height: 1.45),
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
