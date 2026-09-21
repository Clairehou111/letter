import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/design_system/letter_theme.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/cycle/domain/period_record.dart';
import 'package:letter_mobile/features/insights/presentation/gravity_horizon.dart';
import 'package:letter_mobile/features/insights/presentation/gravity_horizon_view_model.dart';

PeriodRecord _period(String id, LocalDate start) => PeriodRecord(
  id: id,
  startDate: start,
  endDate: start.addDays(4),
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
);

Widget _harness(GravityHorizonViewModel viewModel) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: LetterTheme.light,
    home: Scaffold(
      body: SingleChildScrollView(
        child: SizedBox(
          width: 390,
          child: GravityHorizonView(viewModel: viewModel, onOpenCycle: () {}),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders typical 29/29-day Gravity Horizon', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    final viewModel = GravityHorizonViewModel.fromRecords(
      today: const LocalDate(2026, 8, 5),
      records: [
        _period('may-31', const LocalDate(2026, 5, 31)),
        _period('jun-29', const LocalDate(2026, 6, 29)),
        _period('jul-28', const LocalDate(2026, 7, 28)),
      ],
    );
    await tester.pumpWidget(_harness(viewModel));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(GravityHorizonView),
      matchesGoldenFile('../goldens/gravity_horizon_typical_390x844.png'),
    );
  });

  testWidgets('renders irregular 24/30/34-day Gravity Horizon', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    final viewModel = GravityHorizonViewModel.fromRecords(
      today: const LocalDate(2026, 8, 5),
      records: [
        _period('may-03', const LocalDate(2026, 5, 3)),
        _period('may-27', const LocalDate(2026, 5, 27)),
        _period('jun-26', const LocalDate(2026, 6, 26)),
        _period('jul-30', const LocalDate(2026, 7, 30)),
      ],
    );
    await tester.pumpWidget(_harness(viewModel));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(GravityHorizonView),
      matchesGoldenFile('../goldens/gravity_horizon_irregular_390x844.png'),
    );
  });
}
