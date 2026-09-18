import 'package:flutter/material.dart';

/// Copied from the approved Lovable Flutter build.
class LetterTokens {
  const LetterTokens._();

  static const canvas = Color(0xFFFAF9F6);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF252626);
  static const muted = Color(0xFF687278);
  static const line = Color(0xFFE3E4E1);
  static const teal = Color(0xFF176D67);
  static const tealDark = Color(0xFF155D59);
  static const tealSoft = Color(0xFFE4F2EF);
  static const safety = Color(0xFFB42318);
  static const scrim = Color(0x80121517);

  static const s4 = 4.0;
  static const s8 = 8.0;
  static const s12 = 12.0;
  static const s16 = 16.0;
  static const s20 = 20.0;
  static const s28 = 28.0;
  static const gutter = s20;

  static const rControl = Radius.circular(7);
  static const rSurface = Radius.circular(8);
  static const brControl = BorderRadius.all(rControl);
  static const brSurface = BorderRadius.all(rSurface);

  static const durFast = Duration(milliseconds: 100);
  static const durBase = Duration(milliseconds: 180);
  static const durSurface = Duration(milliseconds: 500);
  static const ease = Cubic(0.22, 0.61, 0.36, 1);

  static const tapTarget = 44.0;
  static const maxContentWidth = 480.0;
  static const minSupportedWidth = 320.0;
  static const hairline = BorderSide(color: line, width: 1);
}

extension LovableLetterMotion on BuildContext {
  bool get reduceLovableMotion =>
      MediaQuery.maybeDisableAnimationsOf(this) ?? false;

  Duration lovableMotion(Duration duration) =>
      reduceLovableMotion ? Duration.zero : duration;

  bool get isLovableLargeText => MediaQuery.textScalerOf(this).scale(16) > 22;

  bool get isLovableNarrow => MediaQuery.sizeOf(this).width <= 340;
}
