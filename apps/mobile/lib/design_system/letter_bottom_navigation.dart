import 'package:flutter/material.dart';

import 'letter_theme.dart';

class LetterBottomNavigation extends StatelessWidget {
  const LetterBottomNavigation({
    super.key,
    this.selectedIndex = 0,
    this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int>? onSelected;

  static const items = [
    ('Today', Icons.home_outlined, Icons.home),
    ('Care', Icons.volunteer_activism_outlined, Icons.volunteer_activism),
    ('Letters', Icons.mail_outline, Icons.mail),
    ('You', Icons.person_outline, Icons.person),
  ];

  @override
  Widget build(BuildContext context) {
    final scaledLabelHeight = MediaQuery.textScalerOf(context).scale(11);
    final navigationHeight = (scaledLabelHeight * 2.4 + 38).clamp(64.0, 104.0);

    return Semantics(
      container: true,
      label: 'Primary navigation',
      child: SafeArea(
        top: false,
        child: Container(
          height: navigationHeight,
          decoration: const BoxDecoration(
            color: LetterColors.canvas,
            border: Border(top: BorderSide(color: LetterColors.line)),
          ),
          child: Row(
            children: List.generate(items.length, (index) {
              final item = items[index];
              final active = index == selectedIndex;
              final color = active ? LetterColors.teal : LetterColors.muted;
              return Expanded(
                child: Semantics(
                  button: true,
                  selected: active,
                  label: '${item.$1} tab',
                  child: InkWell(
                    key: Key('navigation-${item.$1.toLowerCase()}'),
                    onTap: () => onSelected?.call(index),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: LetterDimensions.tapTarget,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: LetterSpacing.xxs,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              active ? item.$3 : item.$2,
                              size: 20,
                              color: color,
                            ),
                            const SizedBox(height: LetterSpacing.xxs),
                            Flexible(
                              child: Text(
                                item.$1,
                                maxLines: 2,
                                softWrap: true,
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.fade,
                                style: TextStyle(
                                  color: color,
                                  fontSize: 11,
                                  height: 1.15,
                                  fontWeight: active
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
