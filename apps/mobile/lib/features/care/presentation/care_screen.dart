import 'package:flutter/material.dart';

import '../../../design_system/letter_bottom_navigation.dart';
import '../../../design_system/letter_theme.dart';
import '../domain/care_mode.dart';
import '../domain/impulse_buffer_repository.dart';
import 'angry_impulse_flow.dart';
import 'care_safety_boundary_sheet.dart';
import 'heavy_presence_flow.dart';

class CareScreen extends StatefulWidget {
  const CareScreen({
    required this.onNavigationSelected,
    required this.impulseBufferRepository,
    super.key,
    this.now,
  });

  final ValueChanged<int> onNavigationSelected;
  final ImpulseBufferRepository impulseBufferRepository;
  final DateTime Function()? now;

  @override
  State<CareScreen> createState() => _CareScreenState();
}

class _CareScreenState extends State<CareScreen> {
  CareMode? _activeMode;

  void _openMode(CareMode mode) {
    setState(() => _activeMode = mode);
  }

  void _returnToGate() {
    setState(() => _activeMode = null);
  }

  @override
  Widget build(BuildContext context) {
    final activeMode = _activeMode;
    if (activeMode != null) {
      if (activeMode == CareMode.explode) {
        return AngryImpulseFlow(
          repository: widget.impulseBufferRepository,
          onReturnToGate: _returnToGate,
          onExitCare: () => widget.onNavigationSelected(2),
          now: widget.now,
        );
      }
      if (activeMode == CareMode.heavy) {
        return HeavyPresenceFlow(
          onReturnToGate: _returnToGate,
          onExitCare: () => widget.onNavigationSelected(2),
        );
      }
      return CareModeScene(
        mode: activeMode,
        onReturnToGate: _returnToGate,
        onExitCare: () => widget.onNavigationSelected(2),
      );
    }

    return Scaffold(
      bottomNavigationBar: LetterBottomNavigation(
        selectedIndex: 3,
        onSelected: widget.onNavigationSelected,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: CustomScrollView(
              key: const Key('care-gate-scroll'),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
                  sliver: SliverList.list(
                    children: [
                      const LetterEyebrow('Care / right now'),
                      const SizedBox(height: LetterSpacing.sm),
                      const Text(
                        'What is closest to this moment?',
                        style: TextStyle(
                          fontFamily: 'Newsreader',
                          fontSize: 31,
                          height: 1.02,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: LetterSpacing.sm),
                      const Text(
                        'Choose the nearest feeling. You can leave at any time.',
                        style: TextStyle(
                          color: LetterColors.muted,
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: LetterSpacing.xl),
                      ...CareMode.values.map(
                        (mode) => Padding(
                          padding: const EdgeInsets.only(
                            bottom: LetterSpacing.xs,
                          ),
                          child: CareModeEntrance(
                            mode: mode,
                            onPressed: () => _openMode(mode),
                          ),
                        ),
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

class CareModeEntrance extends StatelessWidget {
  const CareModeEntrance({
    required this.mode,
    required this.onPressed,
    super.key,
  });

  final CareMode mode;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${mode.label}. ${mode.gateDescription}',
      child: Material(
        color: mode.softColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LetterRadius.panel),
          side: BorderSide(color: mode.color.withValues(alpha: 0.22)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('care-mode-${mode.name}'),
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 76),
            child: Padding(
              padding: const EdgeInsets.all(LetterSpacing.sm),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: LetterColors.surface.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(LetterRadius.control),
                    ),
                    child: Icon(mode.icon, color: mode.color, size: 24),
                  ),
                  const SizedBox(width: LetterSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          mode.label,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: LetterSpacing.xxs),
                        Text(
                          mode.gateDescription,
                          style: const TextStyle(
                            color: LetterColors.muted,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: LetterSpacing.xs),
                  Icon(Icons.chevron_right, color: mode.color),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CareModeScene extends StatefulWidget {
  const CareModeScene({
    required this.mode,
    required this.onReturnToGate,
    required this.onExitCare,
    super.key,
  });

  final CareMode mode;
  final VoidCallback onReturnToGate;
  final VoidCallback onExitCare;

  @override
  State<CareModeScene> createState() => _CareModeSceneState();
}

class _CareModeSceneState extends State<CareModeScene> {
  bool _responded = false;

  void _respond() {
    if (_responded) {
      return;
    }
    setState(() => _responded = true);
  }

  Future<void> _openSafetyBoundary() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      barrierColor: LetterColors.ink.withValues(alpha: 0.42),
      builder: (context) => CareSafetyBoundarySheet(
        kind: widget.mode.safetyKind,
        onLeaveCare: () {
          Navigator.of(context).pop();
          widget.onExitCare();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mode = widget.mode;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.45;

    return Scaffold(
      backgroundColor: _responded
          ? mode.settledBackground
          : mode.sceneBackground,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: CustomScrollView(
              key: Key('care-scene-${mode.name}'),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                  sliver: SliverList.list(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            key: const Key('care-back-to-gate'),
                            tooltip: 'Back to Care choices',
                            onPressed: widget.onReturnToGate,
                            icon: const Icon(Icons.arrow_back),
                          ),
                          const Spacer(),
                          IconButton(
                            key: const Key('care-exit'),
                            tooltip: 'Leave Care',
                            onPressed: widget.onExitCare,
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: LetterSpacing.md),
                      LetterEyebrow(
                        mode.label,
                        color: _responded ? LetterColors.muted : mode.color,
                      ),
                      const SizedBox(height: LetterSpacing.sm),
                      Text(
                        mode.sceneTitle,
                        style: TextStyle(
                          color: LetterColors.ink,
                          fontFamily: 'Newsreader',
                          fontSize: largeText ? 27 : 32,
                          height: 1.02,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: LetterSpacing.xl),
                      Semantics(
                        liveRegion: true,
                        label: _responded
                            ? mode.transformedLabel
                            : 'Waiting for your first action',
                        child: AnimatedContainer(
                          key: Key('care-focal-${mode.name}'),
                          duration: reduceMotion
                              ? Duration.zero
                              : const Duration(milliseconds: 420),
                          curve: Curves.easeOutCubic,
                          constraints: BoxConstraints(
                            minHeight: largeText ? 270 : 236,
                          ),
                          decoration: BoxDecoration(
                            color: _responded
                                ? mode.settledColor
                                : mode.activeColor,
                            borderRadius: BorderRadius.circular(
                              LetterRadius.panel,
                            ),
                            border: Border.all(
                              color: _responded
                                  ? mode.color.withValues(alpha: 0.25)
                                  : mode.color.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Center(
                            child: AnimatedSwitcher(
                              duration: reduceMotion
                                  ? Duration.zero
                                  : const Duration(milliseconds: 220),
                              child: Column(
                                key: ValueKey(_responded),
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _responded
                                        ? mode.transformedIcon
                                        : mode.icon,
                                    size: _responded ? 62 : 76,
                                    color: mode.color,
                                  ),
                                  const SizedBox(height: LetterSpacing.md),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: LetterSpacing.lg,
                                    ),
                                    child: Text(
                                      _responded
                                          ? mode.transformedLabel
                                          : mode.focalAction,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: mode.color,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: LetterSpacing.lg),
                      if (!_responded)
                        FilledButton.icon(
                          key: Key('care-respond-${mode.name}'),
                          onPressed: _respond,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            backgroundColor: mode.color,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                LetterRadius.control,
                              ),
                            ),
                          ),
                          icon: Icon(mode.icon),
                          label: Text(mode.focalAction),
                        )
                      else ...[
                        Container(
                          key: const Key('care-protective-line'),
                          width: double.infinity,
                          padding: const EdgeInsets.all(LetterSpacing.md),
                          decoration: BoxDecoration(
                            color: LetterColors.surface,
                            border: Border.all(color: LetterColors.line),
                            borderRadius: BorderRadius.circular(
                              LetterRadius.panel,
                            ),
                          ),
                          child: Text(
                            mode.protectiveLine,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Newsreader',
                              fontSize: 20,
                              height: 1.15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: LetterSpacing.md),
                        FilledButton.icon(
                          key: Key('care-handoff-${mode.name}'),
                          onPressed: widget.onReturnToGate,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            backgroundColor: mode.color,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                LetterRadius.control,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.arrow_outward),
                          label: Text(mode.handOff),
                        ),
                        TextButton(
                          key: const Key('care-not-now'),
                          onPressed: widget.onReturnToGate,
                          style: TextButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            foregroundColor: LetterColors.muted,
                          ),
                          child: const Text('Not now'),
                        ),
                      ],
                      const SizedBox(height: LetterSpacing.md),
                      OutlinedButton.icon(
                        key: Key('care-safety-${mode.name}'),
                        onPressed: _openSafetyBoundary,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          foregroundColor: LetterColors.ink,
                          side: const BorderSide(color: LetterColors.line),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              LetterRadius.control,
                            ),
                          ),
                        ),
                        icon: Icon(
                          mode.safetyKind == CareSafetyKind.physical
                              ? Icons.medical_services_outlined
                              : Icons.shield_outlined,
                        ),
                        label: Text(
                          mode.safetyKind == CareSafetyKind.physical
                              ? 'This is new, unusual, or severe'
                              : 'I may not be safe',
                        ),
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

extension CareModePresentation on CareMode {
  String get gateDescription => switch (this) {
    CareMode.explode => 'Anger or an impulse needs somewhere to stop.',
    CareMode.heavy => 'Crying, emptiness, or almost no energy.',
    CareMode.racing => 'Too many thoughts are demanding attention.',
    CareMode.space => 'Being available to anyone feels like too much.',
    CareMode.physical => 'Pain or physical depletion needs less input.',
  };

  IconData get icon => switch (this) {
    CareMode.explode => Icons.bolt_outlined,
    CareMode.heavy => Icons.brightness_3_outlined,
    CareMode.racing => Icons.blur_on_outlined,
    CareMode.space => Icons.door_front_door_outlined,
    CareMode.physical => Icons.healing_outlined,
  };

  IconData get transformedIcon => switch (this) {
    CareMode.explode => Icons.pause_circle_outline,
    CareMode.heavy => Icons.light_mode_outlined,
    CareMode.racing => Icons.adjust,
    CareMode.space => Icons.door_back_door_outlined,
    CareMode.physical => Icons.dark_mode_outlined,
  };

  Color get color => switch (this) {
    CareMode.explode => const Color(0xFFAD4E46),
    CareMode.heavy => const Color(0xFF4A6482),
    CareMode.racing => LetterColors.violet,
    CareMode.space => LetterColors.teal,
    CareMode.physical => const Color(0xFF9A6416),
  };

  Color get softColor => switch (this) {
    CareMode.explode => LetterColors.coralSoft,
    CareMode.heavy => LetterColors.blueSoft,
    CareMode.racing => LetterColors.violetSoft,
    CareMode.space => LetterColors.tealSoft,
    CareMode.physical => LetterColors.amberSoft,
  };

  Color get sceneBackground => switch (this) {
    CareMode.explode => const Color(0xFFF7E9E7),
    CareMode.heavy => const Color(0xFFE8EDF2),
    CareMode.racing => const Color(0xFFF0ECF4),
    CareMode.space => const Color(0xFFE7F0ED),
    CareMode.physical => const Color(0xFFF4EEE4),
  };

  Color get settledBackground => switch (this) {
    CareMode.explode => const Color(0xFFF4F1EF),
    CareMode.heavy => const Color(0xFFF2F4F3),
    CareMode.racing => const Color(0xFFF5F3F1),
    CareMode.space => const Color(0xFFF0F4F1),
    CareMode.physical => const Color(0xFFF1F1EE),
  };

  Color get activeColor => softColor;

  Color get settledColor => LetterColors.surface.withValues(alpha: 0.75);
}
