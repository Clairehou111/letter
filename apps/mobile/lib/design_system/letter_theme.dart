import 'package:flutter/material.dart';

abstract final class LetterColors {
  static const ink = Color(0xFF252626);
  static const muted = Color(0xFF687278);
  static const canvas = Color(0xFFFAF9F6);
  static const surface = Color(0xFFFFFFFF);
  static const line = Color(0xFFE3E4E1);
  static const teal = Color(0xFF176D67);
  static const tealDark = Color(0xFF155D59);
  static const tealSoft = Color(0xFFE4F2EF);
  static const coral = Color(0xFFF29A91);
  static const coralSoft = Color(0xFFF9E6E3);
  static const blue = Color(0xFF3D79A8);
  static const blueSoft = Color(0xFFE7EFF7);
  static const amber = Color(0xFFB87016);
  static const amberSoft = Color(0xFFFAEEDC);
  static const violet = Color(0xFF746390);
  static const violetSoft = Color(0xFFEFEAF5);

  // Brand-spec roles (specs/brand-and-experience-system.md).
  static const safetyRed = Color(0xFFB42318);
  static const night = Color(0xFF121517);
  static const moonMetal = Color(0xFFC4A66A);
  static const mist = Color(0xFFF3F5F2);
}

abstract final class LetterShadows {
  /// One soft, low-elevation shadow for panels and the letter hero. Utility
  /// surfaces stay flat; this is reserved for focal objects.
  static List<BoxShadow> get soft => [
    BoxShadow(
      color: LetterColors.ink.withValues(alpha: 0.06),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ];
}

abstract final class LetterGradients {
  /// Restrained canvas wash used behind ritual surfaces. Never a loud or
  /// saturated gradient.
  static const LinearGradient canvasFade = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [LetterColors.canvas, LetterColors.mist],
  );
}

abstract final class LetterMotion {
  // Brand-spec classes: instant 80–120ms, responsive 160–220ms,
  // ritual 400–700ms, ambient.
  static const instant = Duration(milliseconds: 100);
  static const responsive = Duration(milliseconds: 180);
  static const ritual = Duration(milliseconds: 500);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeInOutCubic;
}

abstract final class LetterSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 28.0;
}

abstract final class LetterRadius {
  static const control = 7.0;
  static const panel = 8.0;
}

abstract final class LetterTheme {
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: LetterColors.canvas,
      colorScheme: ColorScheme.fromSeed(
        seedColor: LetterColors.teal,
        brightness: Brightness.light,
        primary: LetterColors.teal,
        surface: LetterColors.surface,
      ),
    );

    return base.copyWith(
      splashFactory: InkSparkle.splashFactory,
      textTheme: base.textTheme
          .apply(
            bodyColor: LetterColors.ink,
            displayColor: LetterColors.ink,
            fontFamily: 'Arial',
          )
          .copyWith(
            bodyMedium: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: LetterColors.ink,
            ),
            labelLarge: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
      bottomSheetTheme: const BottomSheetThemeData(
        showDragHandle: false,
        backgroundColor: Colors.transparent,
      ),
      dividerColor: LetterColors.line,
      // Keep stock Material pickers, dialogs, bars, and indicators inside the
      // Letter visual language instead of default web chrome (AGENTS.md).
      datePickerTheme: DatePickerThemeData(
        backgroundColor: LetterColors.canvas,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LetterRadius.panel),
        ),
        headerBackgroundColor: LetterColors.tealDark,
        headerForegroundColor: LetterColors.canvas,
        todayForegroundColor: WidgetStateProperty.all(LetterColors.tealDark),
        todayBorder: const BorderSide(color: LetterColors.tealDark),
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return LetterColors.canvas;
          }
          return LetterColors.ink;
        }),
        dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return LetterColors.teal;
          }
          return Colors.transparent;
        }),
        yearForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return LetterColors.canvas;
          }
          return LetterColors.ink;
        }),
        yearBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return LetterColors.teal;
          }
          return Colors.transparent;
        }),
        confirmButtonStyle: TextButton.styleFrom(
          foregroundColor: LetterColors.teal,
        ),
        cancelButtonStyle: TextButton.styleFrom(
          foregroundColor: LetterColors.muted,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: LetterColors.canvas,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LetterRadius.panel),
        ),
        titleTextStyle: const TextStyle(
          fontFamily: 'Newsreader',
          fontSize: 20,
          height: 1.15,
          fontWeight: FontWeight.w700,
          color: LetterColors.ink,
        ),
        contentTextStyle: const TextStyle(
          fontSize: 14,
          height: 1.5,
          color: LetterColors.muted,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: LetterColors.canvas,
        foregroundColor: LetterColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Newsreader',
          fontSize: 20,
          height: 1.15,
          fontWeight: FontWeight.w700,
          color: LetterColors.ink,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: LetterColors.teal,
        linearTrackColor: LetterColors.tealSoft,
        circularTrackColor: LetterColors.tealSoft,
        linearMinHeight: 4,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: LetterColors.surface,
        selectedColor: LetterColors.tealSoft,
        disabledColor: LetterColors.mist,
        side: const BorderSide(color: LetterColors.line),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LetterRadius.control),
        ),
        labelStyle: const TextStyle(color: LetterColors.ink, fontSize: 13),
        secondaryLabelStyle: const TextStyle(
          color: LetterColors.tealDark,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return LetterColors.canvas;
          }
          return LetterColors.muted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return LetterColors.teal;
          }
          return LetterColors.line;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
    );
  }
}

class LetterEyebrow extends StatelessWidget {
  const LetterEyebrow(this.text, {super.key, this.color = LetterColors.muted});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: color,
        fontSize: 10,
        height: 1.2,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.4,
      ),
    );
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
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            height: 1.1,
            fontWeight: FontWeight.w800,
          ),
        ),
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
