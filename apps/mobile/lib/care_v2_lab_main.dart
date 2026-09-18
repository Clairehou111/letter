import 'package:flutter/material.dart';

import 'design_system/letter_theme.dart';
import 'screens/care/care_v2_lab.dart';

/// Isolated developer entrypoint for the Care V1/V2 lab.
///
/// Run with: `flutter run -t lib/care_v2_lab_main.dart`
/// The normal app entry path (`lib/main.dart`) is untouched.
void main() {
  runApp(const CareV2LabApp());
}

class CareV2LabApp extends StatelessWidget {
  const CareV2LabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Care lab',
      debugShowCheckedModeBanner: false,
      theme: LetterTheme.light,
      home: const CareV2Lab(),
    );
  }
}
