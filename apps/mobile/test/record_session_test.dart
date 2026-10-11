import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/record_hub/application/record_session_controller.dart';
import 'package:letter_mobile/features/record_hub/domain/record_calendar_month.dart';
import 'package:letter_mobile/features/record_hub/domain/record_session.dart';

void main() {
  test(
    'Gregorian month geometry respects century leap and cross-year dates',
    () {
      expect(const RecordCalendarMonth(1900, 2).daysInMonth, 28);
      expect(const RecordCalendarMonth(2000, 2).daysInMonth, 29);
      expect(
        const RecordCalendarMonth(2026, 12).shift(1).firstDay,
        const LocalDate(2027, 1, 1),
      );
      expect(
        const RecordCalendarMonth(2026, 1).shift(-1).firstDay,
        const LocalDate(2025, 12, 1),
      );
      final mondayFirst = const RecordCalendarMonth(
        2000,
        2,
      ).cells(firstDayOfWeek: 1);
      expect(mondayFirst.first, isNull);
      expect(mondayFirst[1], const LocalDate(2000, 2, 1));
      expect(
        mondayFirst.whereType<LocalDate>().last,
        const LocalDate(2000, 2, 29),
      );
      expect(mondayFirst.length % 7, 0);
      expect(
        const RecordCalendarMonth(2025, 12).intersects(
          firstDate: const LocalDate(2025, 12, 29),
          lastDate: const LocalDate(2026, 1, 3),
        ),
        isTrue,
      );
      expect(() => const RecordCalendarMonth(1, 1).shift(-1), throwsRangeError);
    },
  );

  test('Record retains its captured day and exact origin over midnight', () {
    var now = DateTime(2026, 10, 9, 23, 59);
    const origin = RecordReturnContext(
      origin: RecordOrigin.cycle,
      cycleId: 'synthetic-cycle',
      focusId: 'synthetic-focus',
    );
    final controller = RecordSessionController(
      initialSession: const RecordSession(
        selectedDate: LocalDate(2026, 10, 9),
        returnContext: origin,
      ),
      clock: () => now,
      zoneProvider: () => 'synthetic-zone',
    );
    addTearDown(controller.dispose);
    now = DateTime(2026, 10, 10, 0, 1);
    expect(controller.today, const LocalDate(2026, 10, 10));
    expect(controller.session.selectedDate, const LocalDate(2026, 10, 9));
    expect(controller.session.returnContext, same(origin));
    final write = controller.captureWriteClock();
    expect(write.localDay, const LocalDate(2026, 10, 10));
    expect(write.zoneName, 'synthetic-zone');
    expect(controller.beginSave(), RecordTransitionResult.applied);
    controller.saveSucceeded();
    expect(controller.session.selectedDate, const LocalDate(2026, 10, 9));
  });

  test('calendar cancellation and refused changes preserve guarded drafts', () {
    final controller = RecordSessionController(
      initialSession: const RecordSession(
        selectedDate: LocalDate(2026, 10, 9),
        returnContext: RecordReturnContext(origin: RecordOrigin.today),
      ),
      clock: () => DateTime(2026, 10, 9),
    );
    addTearDown(controller.dispose);
    controller.markDraftDirty();
    expect(controller.openCalendar(), RecordTransitionResult.applied);
    controller.cancelCalendar();
    expect(controller.hasUnsavedDraft, isTrue);
    expect(
      controller.requestDateChange(const LocalDate(2026, 10, 8)),
      RecordTransitionResult.needsDraftDecision,
    );
    expect(
      controller.requestClose(),
      RecordTransitionResult.needsDraftDecision,
    );
    expect(controller.session.selectedDate, const LocalDate(2026, 10, 9));
    expect(
      controller.requestDateChange(
        const LocalDate(2026, 10, 10),
        discardDraft: true,
      ),
      RecordTransitionResult.futureDate,
    );
    expect(controller.hasUnsavedDraft, isTrue);
    expect(
      controller.requestDateChange(
        const LocalDate(2026, 10, 8),
        discardDraft: true,
      ),
      RecordTransitionResult.applied,
    );
    expect(controller.hasUnsavedDraft, isFalse);
  });

  test('child inherits date; safety and failed save retain its draft', () {
    final controller = RecordSessionController(
      initialSession: const RecordSession(
        selectedDate: LocalDate(2026, 10, 7),
        returnContext: RecordReturnContext(origin: RecordOrigin.patterns),
      ),
      clock: () => DateTime(2026, 10, 9),
    );
    addTearDown(controller.dispose);
    expect(controller.openChild(), RecordTransitionResult.applied);
    controller.markDraftDirty();
    controller.openSafety();
    expect(controller.session.selectedDate, const LocalDate(2026, 10, 7));
    controller.returnFromSafety();
    expect(controller.activity, RecordActivity.childEditor);
    expect(controller.hasUnsavedDraft, isTrue);
    expect(
      controller.requestDateChange(const LocalDate(2026, 10, 6)),
      RecordTransitionResult.unavailable,
    );
    expect(controller.beginSave(), RecordTransitionResult.applied);
    expect(
      controller.requestClose(discardDraft: true),
      RecordTransitionResult.saveInProgress,
    );
    controller.saveFailed();
    expect(controller.closeChild(), RecordTransitionResult.needsDraftDecision);
    expect(controller.draftState, RecordDraftState.failed);
    expect(controller.beginSave(), RecordTransitionResult.applied);
    controller.saveSucceeded();
    expect(controller.closeChild(), RecordTransitionResult.applied);
    expect(controller.session.selectedDate, const LocalDate(2026, 10, 7));
  });

  test(
    'clock rollback blocks writes without silently moving date or draft',
    () {
      var now = DateTime(2026, 10, 9);
      final controller = RecordSessionController(
        initialSession: const RecordSession(
          selectedDate: LocalDate(2026, 10, 9),
          returnContext: RecordReturnContext(origin: RecordOrigin.care),
        ),
        clock: () => now,
      );
      addTearDown(controller.dispose);
      controller.markDraftDirty();
      now = DateTime(2026, 10, 8, 23);
      expect(controller.beginSave(), RecordTransitionResult.futureDate);
      expect(controller.hasUnsavedDraft, isTrue);
      expect(controller.session.selectedDate, const LocalDate(2026, 10, 9));
      expect(
        controller.requestClose(discardDraft: true),
        RecordTransitionResult.applied,
      );
      expect(controller.activity, RecordActivity.closed);
    },
  );
}
