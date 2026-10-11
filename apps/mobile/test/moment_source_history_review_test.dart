import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/experience/theme/experience_foundation.dart';
import 'package:letter_mobile/features/check_in/data/in_memory_moment_check_in_repository.dart';
import 'package:letter_mobile/features/check_in/domain/moment_check_in.dart';
import 'package:letter_mobile/features/check_in/domain/moment_check_in_repository.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';
import 'package:letter_mobile/features/record_hub/presentation/moment_source_history_screen.dart';

final _created = DateTime.utc(2026, 10, 8, 12);
final _updated = DateTime.utc(2026, 10, 9, 12);
MomentCheckIn _source({bool legacy = false}) => MomentCheckIn(
  id: 'fictional-moment-source',
  state: MomentCheckInState.calm,
  occurredAt: _created,
  createdAt: _created,
  experiencedDate: legacy ? null : const LocalDate(2026, 10, 8),
  provenance: legacy
      ? HealthRecordProvenance.timingUnknown
      : HealthRecordProvenance.sameDay,
  writeZoneOffsetMinutes: legacy ? null : 120,
  writeZoneName: legacy ? null : 'Europe/Berlin',
);

void main() {
  Future<void> open(
    WidgetTester tester,
    InMemoryMomentCheckInRepository repository, {
    VoidCallback? onChanged,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ExperienceFoundation.lightTheme(),
        home: MomentSourceHistoryScreen(
          repository: repository,
          onChanged: onChanged,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String text) async {
    final target = find.text(text);
    if (target.evaluate().isEmpty) {
      await tester.drag(find.byType(ListView).last, const Offset(0, 1000));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        target,
        150,
        scrollable: find.byType(Scrollable).last,
      );
    }
    await tester.ensureVisible(target.last);
    await tester.pumpAndSettle();
    await tester.tap(target.last);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'reading unknown-date history never changes source or invents a date',
    (tester) async {
      final original = _source(legacy: true);
      final repository = InMemoryMomentCheckInRepository(
        seed: [original],
        clock: () => _updated,
      );
      var changes = 0;
      await open(tester, repository, onChanged: () => changes++);
      expect(find.text('Date unknown · Timing unknown'), findsOneWidget);
      await tap(tester, 'Calm');
      expect(find.text('Date unknown · Timing unknown'), findsOneWidget);
      expect(find.byType(DatePickerDialog), findsNothing);
      expect(find.text('Add Moment'), findsNothing);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Moment history'), findsOneWidget);
      expect(changes, 0);
      expect(
        momentCheckInsMatch((await repository.getAll()).single, original),
        isTrue,
      );
    },
  );

  testWidgets(
    'correction guards draft and retains ID, date and initial provenance',
    (tester) async {
      final original = _source();
      final repository = InMemoryMomentCheckInRepository(
        seed: [original],
        clock: () => _updated,
      );
      var changes = 0;
      await open(tester, repository, onChanged: () => changes++);
      await tap(tester, 'Calm');
      await tap(tester, 'Low');
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Keep editing this Moment?'), findsOneWidget);
      await tap(tester, 'Keep editing');
      expect(
        momentCheckInsMatch((await repository.getAll()).single, original),
        isTrue,
      );
      await tap(tester, 'Save correction');
      expect(find.text('Moment history'), findsOneWidget);
      expect(find.text('Low'), findsOneWidget);
      expect(find.text('2026-10-08 · Later recall'), findsOneWidget);
      final corrected = (await repository.getAll()).single;
      expect(corrected.id, original.id);
      expect(corrected.experiencedDate, original.experiencedDate);
      expect(corrected.createdAt, original.createdAt);
      expect(corrected.occurredAt, original.occurredAt);
      expect(corrected.originalProvenance, HealthRecordProvenance.sameDay);
      expect(corrected.provenance, HealthRecordProvenance.laterRecall);
      expect(corrected.updatedAt, _updated);
      expect(corrected.writeZoneName, 'Europe/Berlin');
      expect(corrected.updatedZoneName, _updated.toLocal().timeZoneName);
      expect(changes, 1);
    },
  );

  testWidgets('confirmed deletion and Undo restore the exact saved source', (
    tester,
  ) async {
    final original = _source();
    final repository = InMemoryMomentCheckInRepository(
      seed: [original],
      clock: () => _updated,
    );
    var changes = 0;
    await open(tester, repository, onChanged: () => changes++);
    await tester.tap(find.byTooltip('Delete saved Moment'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this Moment?'), findsOneWidget);
    expect(await repository.getAll(), hasLength(1));
    await tap(tester, 'Keep Moment');
    expect(changes, 0);
    await tester.tap(find.byTooltip('Delete saved Moment'));
    await tester.pumpAndSettle();
    await tap(tester, 'Delete Moment');
    expect(await repository.getAll(), isEmpty);
    expect(changes, 1);
    expect(find.textContaining('No saved Moments yet'), findsOneWidget);
    await tap(tester, 'Undo');
    expect(
      momentCheckInsMatch((await repository.getAll()).single, original),
      isTrue,
    );
    expect(changes, 2);
    expect(find.text('Calm'), findsOneWidget);
    expect(find.text('2026-10-08 · Same day'), findsOneWidget);
  });
}
