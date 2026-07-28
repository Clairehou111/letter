import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../design_system/letter_theme.dart';

enum TodayState {
  good(
    'Good',
    Icons.wb_sunny_outlined,
    LetterColors.teal,
    LetterColors.tealSoft,
  ),
  steady(
    'Steady',
    Icons.favorite_border,
    LetterColors.blue,
    LetterColors.blueSoft,
  ),
  energized(
    'Energized',
    Icons.auto_awesome_outlined,
    LetterColors.amber,
    LetterColors.amberSoft,
  ),
  low('Low', Icons.bedtime_outlined, LetterColors.blue, LetterColors.blueSoft),
  irritable(
    'Irritable',
    Icons.local_fire_department_outlined,
    Color(0xFFB45046),
    LetterColors.coralSoft,
  ),
  physical(
    'Physical',
    Icons.waves_outlined,
    LetterColors.violet,
    LetterColors.violetSoft,
  );

  const TodayState(this.label, this.icon, this.foreground, this.background);

  final String label;
  final IconData icon;
  final Color foreground;
  final Color background;
}

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key, this.onNavigationSelected});

  final ValueChanged<int>? onNavigationSelected;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  TodayState? selectedState;

  Future<void> _openStateSheet(TodayState state) async {
    setState(() => selectedState = state);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      barrierColor: LetterColors.ink.withValues(alpha: 0.35),
      builder: (context) => StateDetailSheet(state: state),
    );
  }

  Future<void> _openCareSheet() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      barrierColor: LetterColors.ink.withValues(alpha: 0.35),
      builder: (context) => const CareSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: LetterBottomNavigation(
        onSelected: widget.onNavigationSelected,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: CustomScrollView(
            key: const Key('today-scroll'),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 32),
                sliver: SliverList.list(
                  children: [
                    const MockStatusBar(),
                    const AppHeader(),
                    const SizedBox(height: LetterSpacing.md),
                    const CycleHero(),
                    const SizedBox(height: LetterSpacing.xl),
                    CarePlanPreview(onOpenCare: _openCareSheet),
                    const SizedBox(height: LetterSpacing.xl),
                    LetterSectionTitle(
                      eyebrow: 'Good days count too',
                      title: 'What is your body saying today?',
                      action: TextButton(
                        onPressed: () => _openStateSheet(TodayState.steady),
                        style: TextButton.styleFrom(
                          foregroundColor: LetterColors.teal,
                          minimumSize: const Size(44, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                        child: const Text(
                          'Add details',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(height: LetterSpacing.sm),
                    StateGrid(
                      selectedState: selectedState,
                      onSelected: _openStateSheet,
                    ),
                    const SizedBox(height: LetterSpacing.lg),
                    const CalmNote(),
                    const SizedBox(height: LetterSpacing.xl),
                    const RecentEntry(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MockStatusBar extends StatelessWidget {
  const MockStatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 36,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '9:41',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
          Row(
            children: [
              Icon(Icons.signal_cellular_alt, size: 15),
              SizedBox(width: 4),
              Icon(Icons.wifi, size: 15),
              SizedBox(width: 4),
              Icon(Icons.battery_full, size: 17),
            ],
          ),
        ],
      ),
    );
  }
}

class AppHeader extends StatelessWidget {
  const AppHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.textScalerOf(context).scale(1) > 1.45 &&
        MediaQuery.sizeOf(context).width < 360;

    return SizedBox(
      height: 54,
      child: Row(
        children: [
          if (!compact) ...[
            Container(
              width: 29,
              height: 29,
              decoration: BoxDecoration(
                color: LetterColors.teal,
                borderRadius: BorderRadius.circular(LetterRadius.control),
              ),
              child: const Icon(
                Icons.description_outlined,
                size: 17,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: LetterSpacing.sm),
          ],
          Text(
            'LETTER',
            style: TextStyle(
              fontFamily: 'Newsreader',
              fontSize: compact ? 14 : 16,
              fontWeight: FontWeight.w900,
              letterSpacing: compact ? 0.8 : 2.1,
            ),
          ),
          const Spacer(),
          if (compact)
            IconButton.outlined(
              key: const Key('header-log-button'),
              tooltip: 'Log symptoms',
              onPressed: () {},
              icon: const Icon(Icons.add),
            )
          else
            OutlinedButton.icon(
              key: const Key('header-log-button'),
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                foregroundColor: LetterColors.ink,
                side: const BorderSide(color: LetterColors.line),
                minimumSize: const Size(70, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(LetterRadius.control),
                ),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text(
                'Log',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ),
    );
  }
}

class CycleHero extends StatelessWidget {
  const CycleHero({super.key});

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);

    return LayoutBuilder(
      builder: (context, constraints) {
        final stackContent = constraints.maxWidth < 340 || textScale > 1.45;
        final copy = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LetterEyebrow('Monday, July 27', color: Color(0xFFA7D4D1)),
            const SizedBox(height: LetterSpacing.sm),
            const Text(
              'Your body may be asking for a softer day.',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Newsreader',
                fontSize: 27,
                height: 0.98,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: LetterSpacing.sm),
            const Text(
              'You are on cycle day 24. In recent cycles, mood and energy '
              'shifted around days 23-27.',
              style: TextStyle(color: Colors.white, fontSize: 12, height: 1.45),
            ),
            const SizedBox(height: LetterSpacing.sm),
            TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: EdgeInsets.zero,
                minimumSize: const Size(44, 44),
                alignment: Alignment.centerLeft,
              ),
              child: const Text(
                "Read today's signals  ›",
                maxLines: 2,
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        );

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 21, 16, 18),
          decoration: BoxDecoration(
            color: LetterColors.tealDark,
            borderRadius: BorderRadius.circular(LetterRadius.panel),
          ),
          child: stackContent
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    copy,
                    const Align(
                      alignment: Alignment.centerRight,
                      child: CycleRing(size: 112),
                    ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: copy),
                    const SizedBox(width: LetterSpacing.sm),
                    const CycleRing(size: 114),
                  ],
                ),
        );
      },
    );
  }
}

class CycleRing extends StatelessWidget {
  const CycleRing({required this.size, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Cycle day 24, luteal phase',
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: const CycleRingPainter(),
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.2,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'DAY',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '24',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Newsreader',
                        fontSize: 34,
                        height: 1.0,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Luteal',
                      style: TextStyle(color: Colors.white, fontSize: 9),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CycleRingPainter extends CustomPainter {
  const CycleRingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 7;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final track = Paint()
      ..color = const Color(0xFF4C8D88)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;
    final progress = Paint()
      ..color = LetterColors.coral
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt
      ..strokeWidth = 10;

    canvas.drawCircle(center, radius, track);
    const start = math.pi;
    const sweep = math.pi * 1.33;
    canvas.drawArc(rect, start, sweep, false, progress);

    final markerAngle = start + sweep;
    final marker = Offset(
      center.dx + radius * math.cos(markerAngle),
      center.dy + radius * math.sin(markerAngle),
    );
    canvas.drawCircle(marker, 4.2, Paint()..color = Colors.white);
    canvas.drawCircle(marker, 2.2, Paint()..color = LetterColors.tealDark);
  }

  @override
  bool shouldRepaint(CycleRingPainter oldDelegate) => false;
}

class CarePlanPreview extends StatelessWidget {
  const CarePlanPreview({required this.onOpenCare, super.key});

  final VoidCallback onOpenCare;

  @override
  Widget build(BuildContext context) {
    final stackActions =
        MediaQuery.textScalerOf(context).scale(1) > 1.45 ||
        MediaQuery.sizeOf(context).width < 340;
    final primary = FilledButton.icon(
      key: const Key('open-care-button'),
      onPressed: onOpenCare,
      style: FilledButton.styleFrom(
        backgroundColor: LetterColors.teal,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LetterRadius.control),
        ),
      ),
      icon: const Icon(Icons.volunteer_activism_outlined, size: 19),
      label: const Text('Find comfort now'),
    );
    final secondary = OutlinedButton(
      onPressed: () {},
      style: OutlinedButton.styleFrom(
        foregroundColor: LetterColors.ink,
        side: const BorderSide(color: LetterColors.line),
        minimumSize: const Size.fromHeight(44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LetterRadius.control),
        ),
      ),
      child: const Text(
        'View plan',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: LetterColors.tealSoft,
                borderRadius: BorderRadius.circular(LetterRadius.panel),
              ),
              child: const Icon(
                Icons.health_and_safety_outlined,
                color: LetterColors.teal,
                size: 21,
              ),
            ),
            const SizedBox(width: LetterSpacing.sm),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LetterEyebrow('Your care plan is ready'),
                  SizedBox(height: LetterSpacing.xxs),
                  Text(
                    'Comfort, without figuring it out.',
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: LetterSpacing.sm),
        const Row(
          children: [
            Expanded(
              child: PlanPreviewItem(
                icon: Icons.local_cafe_outlined,
                label: 'Warm drink',
              ),
            ),
            SizedBox(width: LetterSpacing.xs),
            Expanded(
              child: PlanPreviewItem(
                icon: Icons.bathtub_outlined,
                label: 'Heat + quiet',
              ),
            ),
            SizedBox(width: LetterSpacing.xs),
            Expanded(
              child: PlanPreviewItem(
                icon: Icons.chat_bubble_outline,
                label: 'Message Maya',
              ),
            ),
          ],
        ),
        const SizedBox(height: LetterSpacing.md),
        if (stackActions) ...[
          primary,
          const SizedBox(height: LetterSpacing.xs),
          secondary,
        ] else
          Row(
            children: [
              Expanded(flex: 3, child: primary),
              const SizedBox(width: LetterSpacing.xs),
              Expanded(flex: 2, child: secondary),
            ],
          ),
      ],
    );
  }
}

class PlanPreviewItem extends StatelessWidget {
  const PlanPreviewItem({required this.icon, required this.label, super.key});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.45;
    return Container(
      height: largeText ? 76 : 56,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: LetterColors.surface,
        border: Border.all(color: LetterColors.line),
        borderRadius: BorderRadius.circular(LetterRadius.control),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, size: 18, color: LetterColors.teal),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: LetterColors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class StateGrid extends StatelessWidget {
  const StateGrid({
    required this.selectedState,
    required this.onSelected,
    super.key,
  });

  final TodayState? selectedState;
  final ValueChanged<TodayState> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.45;
        final columns = constraints.maxWidth < 340 ? 2 : 3;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: columns,
          childAspectRatio: largeText
              ? 1.6
              : columns == 2
              ? 2.05
              : 1.85,
          mainAxisSpacing: LetterSpacing.xs,
          crossAxisSpacing: LetterSpacing.xs,
          children: TodayState.values
              .map(
                (state) => StateButton(
                  state: state,
                  selected: selectedState == state,
                  onPressed: () => onSelected(state),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class StateButton extends StatelessWidget {
  const StateButton({
    required this.state,
    required this.selected,
    required this.onPressed,
    super.key,
  });

  final TodayState state;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${state.label} state',
      child: Material(
        color: state.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LetterRadius.panel),
          side: BorderSide(
            color: selected ? state.foreground : Colors.transparent,
            width: 2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('state-${state.label.toLowerCase()}'),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(state.icon, size: 20, color: state.foreground),
                const SizedBox(height: LetterSpacing.xxs),
                Text(
                  state.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: state.foreground,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
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

class CalmNote extends StatelessWidget {
  const CalmNote({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(LetterSpacing.md),
      decoration: BoxDecoration(
        color: LetterColors.amberSoft,
        borderRadius: BorderRadius.circular(LetterRadius.panel),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.wb_sunny_outlined, color: LetterColors.amber, size: 21),
          SizedBox(width: LetterSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LetterEyebrow('A note from calm-you'),
                SizedBox(height: LetterSpacing.xs),
                Text(
                  'Do not make relationship decisions in this window. '
                  'Sleep first.',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RecentEntry extends StatelessWidget {
  const RecentEntry({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: LetterSpacing.sm),
        Container(
          padding: const EdgeInsets.all(LetterSpacing.sm),
          decoration: BoxDecoration(
            color: LetterColors.surface,
            border: Border.all(color: LetterColors.line),
            borderRadius: BorderRadius.circular(LetterRadius.panel),
          ),
          child: const Row(
            children: [
              CircleAvatar(radius: 5, backgroundColor: LetterColors.coral),
              SizedBox(width: LetterSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Low mood and poor focus',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'Yesterday, cycle day 23',
                      style: TextStyle(color: LetterColors.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Text(
                'Heat helped',
                style: TextStyle(
                  color: LetterColors.teal,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Icon(Icons.chevron_right, size: 18),
            ],
          ),
        ),
      ],
    );
  }
}

class LetterBottomNavigation extends StatelessWidget {
  const LetterBottomNavigation({
    super.key,
    this.selectedIndex = 2,
    this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int>? onSelected;

  static const items = [
    ('Cycle', Icons.calendar_today_outlined),
    ('Insights', Icons.bar_chart_outlined),
    ('Today', Icons.home_outlined),
    ('Care', Icons.volunteer_activism_outlined),
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
          }).toList(),
        ),
      ),
    );
  }
}

class StateDetailSheet extends StatefulWidget {
  const StateDetailSheet({required this.state, super.key});

  final TodayState state;

  @override
  State<StateDetailSheet> createState() => _StateDetailSheetState();
}

class _StateDetailSheetState extends State<StateDetailSheet> {
  static const painOptions = [
    'Pelvic cramps',
    'Lower back pain',
    'Headache',
    'Breast tenderness',
    'Joint or muscle pain',
    'Other pelvic pain',
  ];
  final Map<String, String> painRatings = {};
  String selectedSeverity = 'Moderate';
  String? activePain;

  void _togglePain(String pain) {
    setState(() {
      if (painRatings.containsKey(pain)) {
        painRatings.remove(pain);
        if (activePain == pain) {
          activePain = painRatings.keys.firstOrNull;
        }
      } else {
        painRatings[pain] = 'Moderate';
        activePain = pain;
      }
    });
  }

  void _setSeverity(String severity) {
    setState(() {
      selectedSeverity = severity;
      if (activePain != null) {
        painRatings[activePain!] = severity;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isPhysical = widget.state == TodayState.physical;
    final activeSeverity = activePain == null
        ? selectedSeverity
        : painRatings[activePain]!;

    return LetterSheetFrame(
      title: isPhysical
          ? 'Where does your body hurt?'
          : 'How ${widget.state.label.toLowerCase()} do you feel?',
      subtitle: isPhysical
          ? 'Choose every pain that applies. Give each one its own severity.'
          : 'One tap is enough. You can add context later.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isPhysical) ...[
            Wrap(
              spacing: LetterSpacing.xs,
              runSpacing: LetterSpacing.xs,
              children: painOptions.map((pain) {
                final selected = painRatings.containsKey(pain);
                return Semantics(
                  selected: selected,
                  button: true,
                  label: '$pain pain location',
                  child: FilterChip(
                    key: Key('pain-${pain.toLowerCase().replaceAll(' ', '-')}'),
                    label: Text(pain),
                    selected: selected,
                    onSelected: (_) => _togglePain(pain),
                    showCheckmark: false,
                    avatar: Icon(
                      selected ? Icons.check : Icons.add,
                      size: 17,
                      color: selected ? Colors.white : LetterColors.violet,
                    ),
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : LetterColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                    backgroundColor: LetterColors.violetSoft,
                    selectedColor: LetterColors.violet,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(LetterRadius.control),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: LetterSpacing.lg),
            LetterEyebrow(
              activePain == null
                  ? 'Select a pain to rate it'
                  : 'Severity for $activePain',
            ),
          ] else
            const LetterEyebrow('Severity'),
          const SizedBox(height: LetterSpacing.sm),
          SeveritySelector(
            selected: activeSeverity,
            enabled: !isPhysical || activePain != null,
            onSelected: _setSeverity,
          ),
          if (isPhysical && painRatings.length > 1) ...[
            const SizedBox(height: LetterSpacing.md),
            Text(
              '${painRatings.length} pain locations added',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: LetterColors.violet,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          const SizedBox(height: LetterSpacing.lg),
          FilledButton(
            onPressed: !isPhysical || painRatings.isNotEmpty
                ? () => Navigator.of(context).pop()
                : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: LetterColors.teal,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(LetterRadius.control),
              ),
            ),
            child: const Text('Save today'),
          ),
        ],
      ),
    );
  }
}

class SeveritySelector extends StatelessWidget {
  const SeveritySelector({
    required this.selected,
    required this.enabled,
    required this.onSelected,
    super.key,
  });

  final String selected;
  final bool enabled;
  final ValueChanged<String> onSelected;

  static const options = ['Mild', 'Moderate', 'Strong', 'Severe'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: LetterColors.canvas,
        border: Border.all(color: LetterColors.line),
        borderRadius: BorderRadius.circular(LetterRadius.control),
      ),
      child: Row(
        children: options.map((option) {
          final isSelected = option == selected;
          return Expanded(
            child: Semantics(
              button: true,
              selected: isSelected,
              enabled: enabled,
              label: '$option severity',
              child: InkWell(
                key: Key('severity-${option.toLowerCase()}'),
                onTap: enabled ? () => onSelected(option) : null,
                borderRadius: BorderRadius.circular(5),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  constraints: const BoxConstraints(minHeight: 44),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected && enabled
                        ? LetterColors.teal
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    option,
                    maxLines: 1,
                    style: TextStyle(
                      color: !enabled
                          ? LetterColors.muted.withValues(alpha: 0.55)
                          : isSelected
                          ? Colors.white
                          : LetterColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class CareSheet extends StatefulWidget {
  const CareSheet({super.key});

  @override
  State<CareSheet> createState() => _CareSheetState();
}

class _CareSheetState extends State<CareSheet> {
  String? selectedAction;

  static const actions = [
    ('Ease pain', Icons.thermostat_outlined, 'Heat, position, and quiet'),
    ('Settle my body', Icons.spa_outlined, 'Breathing without a lesson'),
    ('Feel less alone', Icons.chat_bubble_outline, 'A saved message or person'),
    ('Use my plan', Icons.bookmark_outline, 'What helped in past cycles'),
  ];

  @override
  Widget build(BuildContext context) {
    return LetterSheetFrame(
      title: 'What would feel easier right now?',
      subtitle:
          'No lesson. No perfect choice. Start with the smallest comfort.',
      child: Column(
        children: [
          ...actions.map(
            (action) => Padding(
              padding: const EdgeInsets.only(bottom: LetterSpacing.xs),
              child: Semantics(
                button: true,
                selected: selectedAction == action.$1,
                child: InkWell(
                  key: Key(
                    'care-${action.$1.toLowerCase().replaceAll(' ', '-')}',
                  ),
                  onTap: () => setState(() => selectedAction = action.$1),
                  borderRadius: BorderRadius.circular(LetterRadius.panel),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    constraints: const BoxConstraints(minHeight: 64),
                    padding: const EdgeInsets.all(LetterSpacing.sm),
                    decoration: BoxDecoration(
                      color: selectedAction == action.$1
                          ? LetterColors.tealSoft
                          : LetterColors.surface,
                      border: Border.all(
                        color: selectedAction == action.$1
                            ? LetterColors.teal
                            : LetterColors.line,
                      ),
                      borderRadius: BorderRadius.circular(LetterRadius.panel),
                    ),
                    child: Row(
                      children: [
                        Icon(action.$2, color: LetterColors.teal),
                        const SizedBox(width: LetterSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                action.$1,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                action.$3,
                                style: const TextStyle(
                                  color: LetterColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          selectedAction == action.$1
                              ? Icons.check_circle
                              : Icons.chevron_right,
                          color: selectedAction == action.$1
                              ? LetterColors.teal
                              : LetterColors.muted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: LetterSpacing.sm),
          FilledButton(
            onPressed: selectedAction == null
                ? null
                : () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: LetterColors.teal,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(LetterRadius.control),
              ),
            ),
            child: Text(
              selectedAction == null ? 'Choose one comfort' : 'Start gently',
            ),
          ),
        ],
      ),
    );
  }
}

class LetterSheetFrame extends StatelessWidget {
  const LetterSheetFrame({
    required this.title,
    required this.subtitle,
    required this.child,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.78,
      alignment: Alignment.bottomCenter,
      child: Container(
        decoration: const BoxDecoration(
          color: LetterColors.canvas,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: LetterColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: LetterSpacing.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Newsreader',
                      fontSize: 25,
                      height: 1.05,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: LetterSpacing.xs),
            Text(
              subtitle,
              style: const TextStyle(
                color: LetterColors.muted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: LetterSpacing.lg),
            child,
          ],
        ),
      ),
    );
  }
}
