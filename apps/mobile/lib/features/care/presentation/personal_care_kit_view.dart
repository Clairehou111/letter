import 'package:flutter/material.dart';

import '../../../design_system/letter_theme.dart';

const _careKitError = 'Letter could not update private Care memory. Try again.';

final class PersonalCareKitItemViewModel {
  const PersonalCareKitItemViewModel({
    required this.id,
    required this.actionLabel,
    required this.modeLabel,
    required this.betterCount,
    required this.sameCount,
    required this.worseCount,
  }) : assert(betterCount >= 0),
       assert(sameCount >= 0),
       assert(worseCount >= 0);

  final String id;
  final String actionLabel;
  final String modeLabel;
  final int betterCount;
  final int sameCount;
  final int worseCount;

  int get totalCount => betterCount + sameCount + worseCount;
}

class PersonalCareKitView extends StatelessWidget {
  const PersonalCareKitView({
    required this.items,
    required this.onUnpin,
    required this.onDelete,
    super.key,
    this.onBack,
    this.busyItemIds = const {},
    this.isLoading = false,
    this.hasError = false,
    this.onRetry,
  });

  final List<PersonalCareKitItemViewModel> items;
  final ValueChanged<String> onUnpin;
  final ValueChanged<String> onDelete;
  final VoidCallback? onBack;
  final Set<String> busyItemIds;
  final bool isLoading;
  final bool hasError;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.45;

    return Scaffold(
      key: const Key('personal-care-kit-view'),
      backgroundColor: const Color(0xFFF3F5F4),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: CustomScrollView(
              key: const Key('personal-care-kit-scroll'),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 24, 18, 32),
                  sliver: SliverList.list(
                    children: [
                      if (onBack != null) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            key: const Key('personal-care-kit-back'),
                            onPressed: onBack,
                            tooltip: 'Back to Care',
                            constraints: const BoxConstraints(
                              minWidth: 44,
                              minHeight: 44,
                            ),
                            icon: const Icon(Icons.arrow_back),
                          ),
                        ),
                        const SizedBox(height: LetterSpacing.xs),
                      ],
                      const LetterEyebrow(
                        'Private and local',
                        color: LetterColors.teal,
                      ),
                      const SizedBox(height: LetterSpacing.md),
                      Text(
                        'My Care Kit',
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
                        'Actions you chose to keep, with only your observed '
                        'check-backs.',
                        style: TextStyle(
                          color: LetterColors.muted,
                          fontSize: 14,
                          height: 1.45,
                        ),
                      ),
                      if (hasError) ...[
                        const SizedBox(height: LetterSpacing.lg),
                        _KitError(onRetry: onRetry),
                      ],
                      const SizedBox(height: LetterSpacing.xl),
                      if (isLoading)
                        const _KitLoading()
                      else if (items.isEmpty)
                        const _EmptyKit()
                      else
                        for (var index = 0; index < items.length; index++) ...[
                          _CareKitItem(
                            item: items[index],
                            isBusy: busyItemIds.contains(items[index].id),
                            onUnpin: () => onUnpin(items[index].id),
                            onDelete: () => onDelete(items[index].id),
                          ),
                          if (index != items.length - 1)
                            const SizedBox(height: LetterSpacing.sm),
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

class _CareKitItem extends StatelessWidget {
  const _CareKitItem({
    required this.item,
    required this.isBusy,
    required this.onUnpin,
    required this.onDelete,
  });

  final PersonalCareKitItemViewModel item;
  final bool isBusy;
  final VoidCallback onUnpin;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final total = item.totalCount;
    final checkBackWord = total == 1 ? 'check-back' : 'check-backs';
    final stackActions =
        MediaQuery.textScalerOf(context).scale(1) > 1.45 ||
        MediaQuery.sizeOf(context).width < 360;

    return Semantics(
      key: Key('personal-care-kit-item-${item.id}'),
      container: true,
      label:
          '${item.actionLabel}. ${item.modeLabel}. '
          'Better ${item.betterCount}, Same ${item.sameCount}, '
          'Worse ${item.worseCount}, across $total $checkBackWord.',
      child: Container(
        padding: const EdgeInsets.all(LetterSpacing.lg),
        decoration: BoxDecoration(
          color: LetterColors.surface,
          border: Border.all(color: LetterColors.line),
          borderRadius: BorderRadius.circular(LetterRadius.panel),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: LetterColors.tealSoft,
                    borderRadius: BorderRadius.circular(LetterRadius.control),
                  ),
                  child: const Icon(
                    Icons.bookmark_outline,
                    color: LetterColors.teal,
                    size: 22,
                  ),
                ),
                const SizedBox(width: LetterSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.actionLabel,
                        style: const TextStyle(
                          fontSize: 17,
                          height: 1.25,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: LetterSpacing.xxs),
                      Text(
                        item.modeLabel,
                        style: const TextStyle(
                          color: LetterColors.muted,
                          fontSize: 13,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isBusy)
                  const Padding(
                    padding: EdgeInsets.only(left: LetterSpacing.xs),
                    child: SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.3,
                        color: LetterColors.teal,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: LetterSpacing.lg),
            Text(
              'Better in ${item.betterCount} of $total $checkBackWord',
              key: Key('personal-care-kit-observed-${item.id}'),
              style: const TextStyle(
                color: LetterColors.ink,
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: LetterSpacing.xs),
            Wrap(
              spacing: LetterSpacing.xs,
              runSpacing: LetterSpacing.xs,
              children: [
                _CountChip(label: 'Better', count: item.betterCount),
                _CountChip(label: 'Same', count: item.sameCount),
                _CountChip(label: 'Worse', count: item.worseCount),
              ],
            ),
            const SizedBox(height: LetterSpacing.lg),
            if (stackActions)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _UnpinButton(
                    itemId: item.id,
                    enabled: !isBusy,
                    onPressed: onUnpin,
                  ),
                  const SizedBox(height: LetterSpacing.xs),
                  _DeleteButton(
                    itemId: item.id,
                    enabled: !isBusy,
                    onPressed: onDelete,
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _UnpinButton(
                      itemId: item.id,
                      enabled: !isBusy,
                      onPressed: onUnpin,
                    ),
                  ),
                  const SizedBox(width: LetterSpacing.xs),
                  Expanded(
                    child: _DeleteButton(
                      itemId: item.id,
                      enabled: !isBusy,
                      onPressed: onDelete,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: LetterSpacing.sm,
        vertical: LetterSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: LetterColors.canvas,
        border: Border.all(color: LetterColors.line),
        borderRadius: BorderRadius.circular(LetterRadius.control),
      ),
      child: Text(
        '$label $count',
        style: const TextStyle(
          color: LetterColors.muted,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _UnpinButton extends StatelessWidget {
  const _UnpinButton({
    required this.itemId,
    required this.enabled,
    required this.onPressed,
  });

  final String itemId;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      key: Key('personal-care-kit-unpin-$itemId'),
      onPressed: enabled ? onPressed : null,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(44, 48),
        foregroundColor: LetterColors.ink,
        side: const BorderSide(color: LetterColors.line),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LetterRadius.control),
        ),
      ),
      icon: const Icon(Icons.bookmark_remove_outlined, size: 19),
      label: const Text('Unpin'),
    );
  }
}

class _DeleteButton extends StatelessWidget {
  const _DeleteButton({
    required this.itemId,
    required this.enabled,
    required this.onPressed,
  });

  final String itemId;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      key: Key('personal-care-kit-delete-$itemId'),
      onPressed: enabled ? onPressed : null,
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 48),
        foregroundColor: const Color(0xFF9C3F39),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LetterRadius.control),
        ),
      ),
      icon: const Icon(Icons.delete_outline, size: 19),
      label: const Text('Delete'),
    );
  }
}

class _EmptyKit extends StatelessWidget {
  const _EmptyKit();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('personal-care-kit-empty'),
      padding: const EdgeInsets.all(LetterSpacing.xl),
      decoration: BoxDecoration(
        color: LetterColors.surface,
        border: Border.all(color: LetterColors.line),
        borderRadius: BorderRadius.circular(LetterRadius.panel),
      ),
      child: const Column(
        children: [
          Icon(Icons.bookmarks_outlined, color: LetterColors.teal, size: 30),
          SizedBox(height: LetterSpacing.sm),
          Text(
            'Your Care Kit is empty.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: LetterSpacing.xs),
          Text(
            'Actions appear here only after you choose to keep them.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: LetterColors.muted,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _KitLoading extends StatelessWidget {
  const _KitLoading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        label: 'Loading private Care Kit',
        child: const CircularProgressIndicator(
          key: Key('personal-care-kit-loading'),
          color: LetterColors.teal,
        ),
      ),
    );
  }
}

class _KitError extends StatelessWidget {
  const _KitError({required this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const Key('personal-care-kit-error'),
      liveRegion: true,
      label: _careKitError,
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
                _careKitError,
                style: TextStyle(height: 1.4, fontWeight: FontWeight.w700),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: LetterSpacing.xs),
              TextButton.icon(
                key: const Key('personal-care-kit-retry'),
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
