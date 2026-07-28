import 'package:flutter/material.dart';

import '../design_system/letter_theme.dart';
import '../features/today/today_screen.dart';

class LetterApp extends StatelessWidget {
  const LetterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Letter',
      theme: LetterTheme.light,
      home: const TodayScreen(),
    );
  }
}
