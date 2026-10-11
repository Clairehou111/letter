import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/experience/theme/experience_foundation.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/record_hub/presentation/record_calendar.dart';

Widget _host(Widget child, {double textScale = 1}) => MaterialApp(
  theme: ExperienceFoundation.careTheme(),
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
    child: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

void main() {
  testWidgets(
    'one-tap selection; real saved markers and disabled future semantics',
    (tester) async {
      final selected = <LocalDate>[];
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          RecordCalendar(
            selectedDate: const LocalDate(2026, 10, 8),
            today: const LocalDate(2026, 10, 9),
            savedDates: {const LocalDate(2026, 10, 7)},
            onDateSelected: selected.add,
          ),
        ),
      );
      expect(find.text('Thursday, October 8, 2026'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Wednesday, October 7, 2026, Saved records'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Friday, October 9, 2026, Today'),
        findsOneWidget,
      );
      final future = tester.widget<InkWell>(
        find.byKey(const Key('record-calendar-day-2026-10-10')),
      );
      expect(future.onTap, isNull);
      await tester.tap(find.byKey(const Key('record-calendar-day-2026-10-07')));
      expect(selected, [const LocalDate(2026, 10, 7)]);
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const Key('record-calendar-next-month')),
            )
            .onPressed,
        isNull,
      );
      semantics.dispose();
    },
  );

  testWidgets(
    'month browsing supports nonbleeding days and cross-year cycle bounds',
    (tester) async {
      final selected = <LocalDate>[];
      await tester.pumpWidget(
        _host(
          RecordCalendar(
            selectedDate: const LocalDate(2025, 12, 29),
            today: const LocalDate(2026, 10, 9),
            firstDate: const LocalDate(2025, 12, 29),
            lastDate: const LocalDate(2026, 1, 3),
            onDateSelected: selected.add,
          ),
        ),
      );
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const Key('record-calendar-previous-month')),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const Key('record-calendar-next-month')));
      await tester.pump();
      expect(find.text('January 2026'), findsOneWidget);
      expect(
        tester
            .widget<InkWell>(
              find.byKey(const Key('record-calendar-day-2026-01-04')),
            )
            .onTap,
        isNull,
      );
      await tester.tap(find.byKey(const Key('record-calendar-day-2026-01-02')));
      expect(selected, [const LocalDate(2026, 1, 2)]);
    },
  );

  testWidgets(
    'year selection preserves month and leap day is keyboard reachable',
    (tester) async {
      final selected = <LocalDate>[];
      await tester.pumpWidget(
        _host(
          RecordCalendar(
            selectedDate: const LocalDate(2001, 2, 1),
            today: const LocalDate(2002, 3, 1),
            firstDate: const LocalDate(1899, 1, 1),
            onDateSelected: selected.add,
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('record-calendar-year')));
      await tester.pumpAndSettle();
      expect(find.byType(YearPicker), findsOneWidget);
      await tester.tap(find.text('2000'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('record-calendar-day-2000-02-29')),
        findsOneWidget,
      );
      final day = find.byKey(const Key('record-calendar-day-2000-02-29'));
      // Native InkWell exposes Enter/Space activation through its focus action.
      Focus.of(
        tester.element(
          find.descendant(of: day, matching: find.byType(Text)).first,
        ),
      ).requestFocus();
      await tester.pump();
      // Pointer selection confirms that year browsing never auto-writes a fact.
      expect(selected, isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(selected, [const LocalDate(2000, 2, 29)]);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '320-pixel large text retains 44-pixel day targets without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _host(
          RecordCalendar(
            selectedDate: const LocalDate(2026, 10, 8),
            today: const LocalDate(2026, 10, 9),
            onDateSelected: (_) {},
          ),
          textScale: 2,
        ),
      );
      expect(tester.takeException(), isNull);
      final size = tester.getSize(
        find.byKey(const Key('record-calendar-day-2026-10-08')),
      );
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
      expect(find.text('Saved records'), findsOneWidget);
    },
  );

  testWidgets('cancelled calendar returns null and does not select a date', (
    tester,
  ) async {
    LocalDate? result;
    var completed = false;
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showRecordCalendar(
                context: context,
                selectedDate: const LocalDate(2026, 10, 8),
                today: const LocalDate(2026, 10, 9),
              );
              completed = true;
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('record-calendar-cancel')));
    await tester.pumpAndSettle();
    expect(completed, isTrue);
    expect(result, isNull);
  });
  testWidgets(
    'rapid month reversals settle on the latest month without selecting; cancelled press does not write',
    (tester) async {
      final selected = <LocalDate>[];
      await tester.pumpWidget(
        _host(
          RecordCalendar(
            selectedDate: const LocalDate(2026, 10, 8),
            today: const LocalDate(2026, 10, 9),
            onDateSelected: selected.add,
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('record-calendar-previous-month')));
      await tester.pump(const Duration(milliseconds: 30));
      await tester.tap(find.byKey(const Key('record-calendar-previous-month')));
      await tester.pump(const Duration(milliseconds: 30));
      await tester.tap(find.byKey(const Key('record-calendar-next-month')));
      await tester.pumpAndSettle();
      expect(find.text('September 2026'), findsOneWidget);
      expect(selected, isEmpty);
      final gesture = await tester.startGesture(
        tester.getCenter(
          find.byKey(const Key('record-calendar-day-2026-09-07')),
        ),
      );
      await tester.pump(const Duration(milliseconds: 80));
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(selected, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
