import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/experience/theme/experience_foundation.dart';
import 'package:letter_mobile/features/capture/domain/capture_models.dart';
import 'package:letter_mobile/features/capture/presentation/capture_note_history_screen.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';

final _original = CaptureNote(
  id: 'legacy-note',
  text: 'Original undated words',
  source: CaptureSource.voiceTranscript,
  createdAt: DateTime.utc(2026, 8, 15, 3),
  updatedAt: DateTime.utc(2026, 8, 16, 4),
);
final _now = DateTime(2026, 10, 10, 12);

Future<void> _pump(
  WidgetTester tester,
  CaptureNoteStore store, {
  VoidCallback? onChanged,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ExperienceFoundation.lightTheme(),
      home: CaptureNoteHistoryScreen(repository: store, onChanged: onChanged),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester) async {
  await tester.pump();
  await tester.ensureVisible(
    find.widgetWithText(FilledButton, 'Save note changes'),
  );
  await tester.tap(find.widgetWithText(FilledButton, 'Save note changes'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'all legacy and dated sources remain reachable without a date-entry affordance',
    (tester) async {
      final store = InMemoryCaptureNoteStore(clock: () => _now)
        ..notes.addAll([
          _original,
          CaptureNote(
            id: 'dated-note',
            text: 'Dated past words',
            source: CaptureSource.typed,
            createdAt: DateTime.utc(2026, 10, 7),
            experiencedDate: const LocalDate(2026, 10, 7),
            keepInComfortKit: true,
          ),
        ]);
      await _pump(tester, store);
      expect(find.text('Original undated words'), findsOneWidget);
      expect(find.text('Dated past words'), findsOneWidget);
      expect(find.textContaining('Date unknown'), findsOneWidget);
      expect(find.textContaining('Kept in Comfort Kit'), findsOneWidget);
      expect(find.byType(CalendarDatePicker), findsNothing);
      expect(find.text('New note'), findsNothing);
      expect(store.notes.first.experiencedDate, isNull);
    },
  );

  testWidgets(
    'legacy correction and explicit Kit choice preserve original source and exact guarded Undo',
    (tester) async {
      final store = InMemoryCaptureNoteStore(clock: () => _now)
        ..notes.add(_original);
      var changed = 0;
      await _pump(tester, store, onChanged: () => changed++);
      await tester.tap(find.text(_original.text));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('saved-note-text')),
        'Corrected undated words',
      );
      await tester.ensureVisible(find.text('Keep in Comfort Kit'));
      await tester.tap(find.text('Keep in Comfort Kit'));
      await tester.pump();
      await _save(tester);
      final corrected = store.notes.single;
      expect(corrected.id, _original.id);
      expect(corrected.createdAt, _original.createdAt);
      expect(corrected.source, CaptureSource.voiceTranscript);
      expect(corrected.experiencedDate, isNull);
      expect(corrected.provenance, HealthRecordProvenance.timingUnknown);
      expect(
        corrected.effectiveOriginalProvenance,
        HealthRecordProvenance.timingUnknown,
      );
      expect(corrected.writeZoneName, isNull);
      expect(corrected.updatedAt, _now.toUtc());
      expect(corrected.keepInComfortKit, isTrue);
      expect(changed, 1);
      await tester.tap(find.text('Undo last change'));
      await tester.pumpAndSettle();
      expect(sameCaptureNoteVersion(store.notes.single, _original), isTrue);
      expect(changed, 2);
      expect(find.textContaining('Date unknown'), findsOneWidget);
    },
  );

  testWidgets(
    'delete requires confirmation and Undo restores the exact undated source',
    (tester) async {
      final store = InMemoryCaptureNoteStore(clock: () => _now)
        ..notes.add(_original.copyWith(keepInComfortKit: true));
      final saved = store.notes.single;
      await _pump(tester, store);
      await tester.tap(find.byTooltip('Delete saved note'));
      await tester.pumpAndSettle();
      expect(store.notes, hasLength(1));
      await tester.tap(find.text('Delete note'));
      await tester.pumpAndSettle();
      expect(store.notes, isEmpty);
      await tester.tap(find.text('Undo last change'));
      await tester.pumpAndSettle();
      expect(sameCaptureNoteVersion(store.notes.single, saved), isTrue);
    },
  );

  testWidgets('Undo cannot overwrite a newer edit with the same ID', (
    tester,
  ) async {
    final store = InMemoryCaptureNoteStore(clock: () => _now)
      ..notes.add(_original);
    await _pump(tester, store);
    await tester.tap(find.text(_original.text));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('saved-note-text')),
      'First correction',
    );
    await _save(tester);
    await store.update(
      store.notes.single.copyWith(
        text: 'Newer correction',
        keepInComfortKit: true,
      ),
    );
    await tester.tap(find.text('Undo last change'));
    await tester.pumpAndSettle();
    expect(store.notes.single.text, 'Newer correction');
    expect(store.notes.single.keepInComfortKit, isTrue);
    expect(
      find.textContaining('A newer note will not be overwritten'),
      findsOneWidget,
    );
  });

  testWidgets(
    'stale correction keeps the draft and never replaces a newer source',
    (tester) async {
      final store = InMemoryCaptureNoteStore(clock: () => _now)
        ..notes.add(_original);
      var changes = 0;
      await _pump(tester, store, onChanged: () => changes++);
      await tester.tap(find.text(_original.text));
      await tester.pumpAndSettle();
      await store.update(_original.copyWith(text: 'Newer durable words'));
      await tester.enterText(
        find.byKey(const Key('saved-note-text')),
        'My pending draft',
      );
      await _save(tester);
      expect(store.notes.single.text, 'Newer durable words');
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('saved-note-text')))
            .controller!
            .text,
        'My pending draft',
      );
      expect(find.textContaining('Your draft is still here'), findsOneWidget);
      expect(changes, 0);
    },
  );

  testWidgets('leaving a changed note requires an explicit discard', (
    tester,
  ) async {
    final store = InMemoryCaptureNoteStore(clock: () => _now)
      ..notes.add(_original);
    await _pump(tester, store);
    await tester.tap(find.text(_original.text));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('saved-note-text')),
      'Unsaved words',
    );
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Keep editing this note?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('saved-note-text')))
          .controller!
          .text,
      'Unsaved words',
    );
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard changes'));
    await tester.pumpAndSettle();
    expect(find.text('Note history'), findsOneWidget);
    expect(sameCaptureNoteVersion(store.notes.single, _original), isTrue);
  });
}
