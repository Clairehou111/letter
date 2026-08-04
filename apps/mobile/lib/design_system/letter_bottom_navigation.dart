import 'package:flutter/material.dart';

import 'letter_nav_marks.dart';
import 'letter_theme.dart';

/// Bottom navigation for Letter.
///
/// 月信 — a period is a letter from your body. The five destinations are named
/// and drawn from that idea. Widget keys stay tied to the original destination
/// ids so navigation and tests are unaffected by label wording.
class LetterBottomNavigation extends StatelessWidget {
  const LetterBottomNavigation({
    super.key,
    this.selectedIndex = 0,
    this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int>? onSelected;

  static const items = <LetterNavItem>[
    LetterNavItem(id: 'today', label: 'Today', mark: LetterNavMark.todayLetter),
    LetterNavItem(id: 'cycle', label: 'Rhythm', mark: LetterNavMark.moonPhases),
    LetterNavItem(id: 'care', label: 'Stay', mark: LetterNavMark.shelter),
    LetterNavItem(
      id: 'letters',
      label: 'Letters',
      mark: LetterNavMark.letterStack,
    ),
    LetterNavItem(id: 'you', label: 'Yours', mark: LetterNavMark.waxSeal),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 70,
        decoration: const BoxDecoration(
          color: LetterColors.surface,
          border: Border(top: BorderSide(color: LetterColors.line)),
        ),
        child: Row(
          children: List.generate(items.length, (index) {
            final item = items[index];
            final active = index == selectedIndex;
            return Expanded(
              child: Semantics(
                button: true,
                selected: active,
                label: '${item.label} tab',
                child: InkWell(
                  key: Key('navigation-${item.id}'),
                  onTap: () => onSelected?.call(index),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: active
                              ? LetterColors.teal
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: LetterNavMarkIcon(
                          mark: item.mark,
                          active: active,
                          color: active ? Colors.white : LetterColors.muted,
                        ),
                      ),
                      const SizedBox(height: 3),
                      MediaQuery.withClampedTextScaling(
                        maxScaleFactor: 1.3,
                        child: Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: active
                                ? LetterColors.teal
                                : LetterColors.muted,
                            fontSize: 9,
                            fontWeight: active
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

@immutable
class LetterNavItem {
  const LetterNavItem({
    required this.id,
    required this.label,
    required this.mark,
  });

  /// Stable destination id used for widget keys.
  final String id;
  final String label;
  final LetterNavMark mark;
}
