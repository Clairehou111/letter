import 'package:flutter/material.dart';

import 'letter_tokens.dart';

export 'letter_tokens.dart';

/// Copied from the approved Lovable Flutter build.
class LetterColors {
  const LetterColors._();

  static const ink = LetterTokens.ink;
  static const mist = LetterTokens.tealSoft;
  static const paper = LetterTokens.canvas;
  static const surface = LetterTokens.surface;
  static const teal = LetterTokens.teal;
  static const tealDark = LetterTokens.tealDark;
  static const coral = LetterTokens.safety;
  static const amber = Color(0xFFA86A16);
  static const clinicalBlue = Color(0xFF3E6F9C);
  static const night = Color(0xFF121517);
  static const moonMetal = Color(0xFFC4A66A);
  static const border = LetterTokens.line;
  static const muted = LetterTokens.muted;
}

const List<Color> severityRamp = [
  Color(0xFF6E7BA8),
  Color(0xFF8A7FA0),
  Color(0xFFA97E92),
  Color(0xFFC06F7F),
  LetterColors.coral,
];

const Map<int, String> severityLabels = {
  1: 'Very mild',
  2: 'Mild',
  3: 'Moderate',
  4: 'Strong',
  5: 'Very strong',
};

TextStyle letterSerif({
  double size = 28,
  FontWeight weight = FontWeight.w400,
  Color color = LetterTokens.ink,
  double height = 1.25,
}) => TextStyle(
  fontFamily: 'Newsreader',
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: height,
);

TextStyle letterEyebrow({Color color = LetterTokens.muted}) => TextStyle(
  fontSize: 11,
  letterSpacing: 1.6,
  fontWeight: FontWeight.w500,
  color: color,
);

TextStyle letterBody({
  double size = 15,
  Color color = LetterTokens.ink,
  FontWeight weight = FontWeight.w400,
  double height = 1.55,
}) =>
    TextStyle(fontSize: size, color: color, fontWeight: weight, height: height);

TextStyle letterHelper({double size = 13, Color color = LetterTokens.muted}) =>
    TextStyle(fontSize: size, color: color, height: 1.5);

const double kTapTarget = LetterTokens.tapTarget;
