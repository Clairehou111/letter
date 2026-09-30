import 'package:flutter/material.dart';

import '../experience/theme/experience_foundation.dart';

// ---------------------------------------------------------------------------
// Letter design system — Quiet Dusk facade.
//
// Every `Letter*` identifier is preserved source-compatibly, but this file
// no longer owns a single raw color: the former teal/cool-paper system is
// remapped onto the Quiet Dusk foundation (ember/plum replacing teal, the
// dusk canvas replacing cool paper, the Experience radius/space/type scale
// replacing the 7–8px radii and the Arial/Newsreader stacks). Older screens
// outside this module re-render inside the dusk with no code changes.
//
//   teal family   → ember family (action is the light source)
//   cool paper    → dusk canvas / surface steps
//   soft washes   → translucent dusk glass / raised-surface steps
//   safetyRed     → dusk error (warm desaturated red, never ember)
//   Newsreader    → Georgia serif stack (the single display voice;
//                   Newsreader was never bundled, so this makes the
//                   already-silent fallback explicit)
//   Arial         → the humanist sans fallback stack (platform default)
// ---------------------------------------------------------------------------

abstract final class LetterColors {
  // Ink family — the global dusk ink values.
  static const Color ink = ExperienceColors.ink;
  static const Color muted = ExperienceColors.inkSoft;

  // Canvas & surfaces — the everyday dusk depth (no daylight world remains).
  static const Color canvas = ExperienceColors.canvas;
  static const Color surface = ExperienceColors.surface;
  static const Color line = ExperienceColors.hairline;

  // Teal family → the ember family. Action borrows the one light source.
  static const Color teal = ExperienceColors.ember;
  static const Color tealDark = ExperienceColors.emberDeep;
  static const Color tealSoft = ExperienceColors.surfaceWarm;

  // Coral family → ember softs (memory/warmth cues stay in the ember hue).
  static const Color coral = ExperienceColors.emberSoft;
  static const Color coralSoft = ExperienceColors.emberGlow;

  // Semantic accents → the retuned dusk accent family. Soft washes resolve
  // to translucent dusk glass so they stay quiet on the plum canvas.
  static const Color blue = ExperienceColors.phaseFollicular;
  static const Color blueSoft = ExperienceColors.careGlass;
  static const Color amber = ExperienceColors.accentGravity;
  static const Color amberSoft = ExperienceColors.careGlass;
  static const Color violet = ExperienceColors.phaseLuteal;
  static const Color violetSoft = ExperienceColors.careGlass;

  // Brand-spec roles, remapped into the dusk environment.
  static const Color safetyRed = ExperienceColors.error;
  static const Color night = ExperienceColors.canvas;
  static const Color moonMetal = ExperienceColors.accentGravity;
  static const Color mist = ExperienceColors.surface;
}

abstract final class LetterShadows {
  /// One soft, low-elevation shadow for panels and the letter hero. Utility
  /// surfaces stay flat; this is reserved for the single focal object per
  /// viewport. In dusk, shadows deepen rather than lighten (plum-black).
  static List<BoxShadow> get soft => ExperienceShadows.card;
}

abstract final class LetterGradients {
  /// Restrained canvas wash used behind ritual surfaces — now a quiet dusk
  /// depth step (canvas into the first surface lift), never loud.
  static const LinearGradient canvasFade = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [ExperienceColors.canvas, ExperienceColors.surface],
  );
}

abstract final class LetterMotion {
  // Brand-spec classes: instant 80–120ms, responsive 160–220ms,
  // ritual 400–700ms, ambient.
  static const Duration instant = Duration(milliseconds: 100);
  static const Duration responsive = Duration(milliseconds: 180);
  static const Duration ritual = Duration(milliseconds: 500);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeInOutCubic;
}

abstract final class LetterSpacing {
  // Bridged onto the Experience 8-pt scale where a step exists; `sm` (12)
  // has no Experience step and is retained to keep legacy rhythm intact.
  static const double xxs = ExperienceSpacing.xs; // 4
  static const double xs = ExperienceSpacing.unit; // 8
  static const double sm = 12.0;
  static const double md = ExperienceSpacing.sm; // 16
  static const double lg = ExperienceSpacing.md; // 20
  static const double xl = ExperienceSpacing.lg; // 24
}

abstract final class LetterRadius {
  // Consolidated onto the Experience radius scale: control → chip,
  // panel → card.
  static const double control = ExperienceRadius.chip; // 12
  static const double panel = ExperienceRadius.card; // 20
}

abstract final class LetterDimensions {
  static const double tapTarget = ExperienceSpacing.minTouchTarget; // 44
  static const double maxContentWidth = 480.0;
  static const double narrowWidth = 340.0;
}

abstract final class LetterButtonStyles {
  // Ember primary action with dark plum text — white-on-ember is reserved
  // for display sizes; button labels ride on the deep plum ink-on-ember
  // pairing instead.
  static final ButtonStyle filled = FilledButton.styleFrom(
    minimumSize: const Size(
      LetterDimensions.tapTarget,
      LetterDimensions.tapTarget,
    ),
    backgroundColor: LetterColors.teal, // ember
    foregroundColor: ExperienceColors.canvas, // dark plum on ember
    disabledBackgroundColor: ExperienceColors.surfaceWarm,
    disabledForegroundColor: ExperienceColors.inkFaint,
    padding: const EdgeInsets.symmetric(
      horizontal: LetterSpacing.md,
      vertical: LetterSpacing.sm,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(LetterRadius.control),
    ),
    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
  );

  static final ButtonStyle outlined = OutlinedButton.styleFrom(
    minimumSize: const Size(
      LetterDimensions.tapTarget,
      LetterDimensions.tapTarget,
    ),
    foregroundColor: ExperienceColors.emberSoft,
    side: const BorderSide(color: ExperienceColors.hairline),
    padding: const EdgeInsets.symmetric(
      horizontal: LetterSpacing.md,
      vertical: LetterSpacing.sm,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(LetterRadius.control),
    ),
    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
  );
}

extension LetterMedia on BuildContext {
  /// Platform accessibility setting only. Delegates to the single reduced-
  /// motion resolver in the foundation — there is exactly one
  /// implementation app-wide and no in-app toggle.
  bool get reduceMotion => ExperienceMotion.reducedMotion(this);

  Duration letterMotion(Duration duration) =>
      reduceMotion ? Duration.zero : duration;

  bool get isLetterNarrow =>
      MediaQuery.sizeOf(this).width <= LetterDimensions.narrowWidth;

  bool get isLetterLargeText => MediaQuery.textScalerOf(this).scale(16) > 22;
}

abstract final class LetterTheme {
  /// The `light` identifier is preserved for source compatibility only —
  /// there is no daylight world left in the UI. This is a Quiet Dusk
  /// [ThemeData]: plum canvas, warm off-white ink, ember actions, with the
  /// stock Material pickers, dialogs, app bars, chips, and switches held
  /// inside the same dusk environment.
  static ThemeData get light {
    final base = ExperienceFoundation.lightTheme();

    return base.copyWith(
      splashFactory: InkSparkle.splashFactory,
      textTheme: base.textTheme.copyWith(
        bodyMedium: const TextStyle(
          fontSize: 14,
          height: 1.45,
          color: LetterColors.ink,
        ),
        labelLarge: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          color: LetterColors.ink,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        showDragHandle: false,
        backgroundColor: Colors.transparent,
      ),
      dividerColor: LetterColors.line,
      // Stock Material pickers, dialogs, bars, and indicators stay inside
      // the Quiet Dusk visual language — plum surfaces, ember selection,
      // translucent-warm hairlines.
      datePickerTheme: DatePickerThemeData(
        backgroundColor: LetterColors.canvas,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LetterRadius.panel),
        ),
        headerBackgroundColor: ExperienceColors.surfaceWarm,
        headerForegroundColor: LetterColors.ink,
        todayForegroundColor: WidgetStateProperty.all(
          ExperienceColors.emberSoft,
        ),
        todayBorder: const BorderSide(color: ExperienceColors.ember),
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return ExperienceColors.canvas; // dark plum on ember
          }
          return LetterColors.ink;
        }),
        dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return ExperienceColors.ember;
          }
          return Colors.transparent;
        }),
        yearForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return ExperienceColors.canvas;
          }
          return LetterColors.ink;
        }),
        yearBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return ExperienceColors.ember;
          }
          return Colors.transparent;
        }),
        confirmButtonStyle: TextButton.styleFrom(
          foregroundColor: ExperienceColors.emberSoft,
        ),
        cancelButtonStyle: TextButton.styleFrom(
          foregroundColor: LetterColors.muted,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: LetterColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LetterRadius.panel),
        ),
        titleTextStyle: ExperienceType.headline(LetterColors.ink),
        contentTextStyle: const TextStyle(
          fontSize: 14,
          height: 1.5,
          color: LetterColors.muted,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: LetterColors.canvas,
        foregroundColor: LetterColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: ExperienceType.headline(LetterColors.ink),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: ExperienceColors.ember,
        linearTrackColor: ExperienceColors.surfaceWarm,
        circularTrackColor: ExperienceColors.surfaceWarm,
        linearMinHeight: 4,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: LetterColors.surface,
        selectedColor: ExperienceColors.surfaceWarm,
        disabledColor: LetterColors.canvas,
        side: const BorderSide(color: ExperienceColors.hairline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LetterRadius.control),
        ),
        labelStyle: const TextStyle(color: LetterColors.ink, fontSize: 13),
        secondaryLabelStyle: const TextStyle(
          color: ExperienceColors.emberSoft,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return ExperienceColors.canvas; // dark plum thumb on ember track
          }
          return LetterColors.muted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return ExperienceColors.ember;
          }
          return ExperienceColors.surfaceWarm;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
    );
  }
}

class LetterPageHeader extends StatelessWidget {
  const LetterPageHeader({
    required this.title,
    super.key,
    this.eyebrow,
    this.support,
  });

  final String? eyebrow;
  final String title;
  final String? support;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eyebrow case final value?) ...[
          LetterEyebrow(value),
          const SizedBox(height: LetterSpacing.xs),
        ],
        Semantics(
          header: true,
          child: Text(
            title,
            // Georgia serif display voice; shrinks one Experience scale step
            // on narrow widths (display 34 → title 24).
            style: context.isLetterNarrow
                ? ExperienceType.title(LetterColors.ink)
                : ExperienceType.display(LetterColors.ink),
          ),
        ),
        if (support case final value?) ...[
          const SizedBox(height: LetterSpacing.sm),
          Text(value, style: ExperienceType.bodySmall(LetterColors.muted)),
        ],
      ],
    );
  }
}

class LetterSurface extends StatelessWidget {
  const LetterSurface({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(LetterSpacing.md),
    this.color = LetterColors.surface,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: LetterColors.line),
        borderRadius: BorderRadius.circular(LetterRadius.panel),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class LetterEyebrow extends StatelessWidget {
  const LetterEyebrow(this.text, {super.key, this.color = LetterColors.muted});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Remapped onto the Experience eyebrow step: 12/16, tracked +2.4,
    // uppercase applied here at the call site.
    return Text(text.toUpperCase(), style: ExperienceType.eyebrow(color));
  }
}

class LetterSectionTitle extends StatelessWidget {
  const LetterSectionTitle({
    required this.eyebrow,
    required this.title,
    super.key,
    this.action,
  });

  final String eyebrow;
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.45;
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LetterEyebrow(eyebrow),
        const SizedBox(height: LetterSpacing.xs),
        // 17pt section titles remap onto the headline step (19/28 serif).
        Text(title, style: ExperienceType.headline(LetterColors.ink)),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (largeText || constraints.maxWidth < 330) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading,
              if (action != null)
                Align(alignment: Alignment.centerRight, child: action),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: heading),
            ?action,
          ],
        );
      },
    );
  }
}
