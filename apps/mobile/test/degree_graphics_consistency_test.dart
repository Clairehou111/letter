import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/experience/degree/degree_graphics.dart';
import 'package:letter_mobile/experience/theme/experience_foundation.dart';
import 'package:letter_mobile/features/cycle/domain/bleeding_flow.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';

void main() {
  testWidgets('shared degree graphics keep one visual language', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: ExperienceColors.canvas,
          body: RepaintBoundary(
            key: const ValueKey<String>('degree-graphics-golden'),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Shared recording language',
                      style: ExperienceType.title(ExperienceColors.ink),
                    ),
                    const SizedBox(height: 30),
                    Text(
                      'Bleeding flow',
                      style: ExperienceType.headline(ExperienceColors.ink),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        for (final flow in BleedingFlow.values)
                          Column(
                            children: <Widget>[
                              DegreeGraphics.flow(
                                flow,
                                size: 24,
                                showWord: false,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                flow.label,
                                style: ExperienceType.caption(
                                  ExperienceColors.inkSoft,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    Text(
                      'Bleeding color',
                      style: ExperienceType.headline(ExperienceColors.ink),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        for (final color in BleedingColor.values)
                          Expanded(
                            child: Column(
                              children: <Widget>[
                                DegreeGraphics.bleedingColor(
                                  color,
                                  size: 30,
                                  showWord: false,
                                  selected: color == BleedingColor.darkRed,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  color.label,
                                  style: ExperienceType.caption(
                                    ExperienceColors.inkSoft,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    Text(
                      'Symptom severity',
                      style: ExperienceType.headline(ExperienceColors.ink),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        for (final severity in SymptomSeverity.values)
                          DegreeGraphics.severity(
                            severity,
                            size: 30,
                            showWord: false,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const ValueKey<String>('degree-graphics-golden')),
      matchesGoldenFile('goldens/degree_graphics_consistency_390x844.png'),
    );
  });
}
