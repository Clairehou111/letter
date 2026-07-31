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
    ('Today', Icons.home_outlined),
    ('Cycle', Icons.calendar_today_outlined),
    ('Care', Icons.volunteer_activism_outlined),
    ('Letters', Icons.mail_outline),
    ('You', Icons.person_outline),
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
                label: '${item.$1} tab',
                child: InkWell(
                  key: Key('navigation-${item.$1.toLowerCase()}'),
                  onTap: () => onSelected?.call(index),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: active
                              ? LetterColors.teal
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Icon(
                          item.$2,
                          size: 20,
                          color: active ? Colors.white : LetterColors.muted,
                        ),
                      ),
                      const SizedBox(height: 3),
                      MediaQuery.withClampedTextScaling(
                        maxScaleFactor: 1.3,
                        child: Text(
                          item.$1,
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
