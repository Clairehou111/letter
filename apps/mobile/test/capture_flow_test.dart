import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/design_system/letter_theme.dart';
import 'package:letter_mobile/features/capture/application/text_voice_capture_controller.dart';
import 'package:letter_mobile/features/capture/data/fake_speech_to_text_adapter.dart';
import 'package:letter_mobile/features/capture/domain/capture_models.dart';
import 'package:letter_mobile/features/capture/presentation/text_voice_capture_flow.dart';

Future<void> pumpCapture(
  WidgetTester tester, {
  FakeSpeechToTextAdapter? adapter,
  InMemoryCaptureNoteStore? store,
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  final speech = adapter ?? FakeSpeechToTextAdapter();
  final notes = store ?? InMemoryCaptureNoteStore();
  final controller = TextVoiceCaptureController(
    speechAdapter: speech,
    noteStore: notes,
    clock: () => DateTime(2026, 7, 28),
  );
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: LetterTheme.light,
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: TextVoiceCaptureFlow(controller: controller),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('text remains usable and save is explicit', (tester) async {
    final store = InMemoryCaptureNoteStore();
    final controller = TextVoiceCaptureController(
      speechAdapter: FakeSpeechToTextAdapter(
        availability: SpeechAvailability.unavailable,
      ),
      noteStore: store,
      clock: () => DateTime(2026, 7, 28),
    );
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: LetterTheme.light,
        home: TextVoiceCaptureFlow(controller: controller),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('capture-text-field')),
      'A sentence I authored myself.',
    );
    await tester.pump();
    expect(controller.state.draftText, 'A sentence I authored myself.');
    expect(controller.canSave, isTrue);
    expect(store.notes, isEmpty);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('capture-save-note')))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const Key('capture-save-note')));
    await tester.pumpAndSettle();

    expect(controller.state.status, CaptureStatus.saved);
    expect(store.notes.single.text, 'A sentence I authored myself.');
    expect(find.byKey(const Key('capture-saved-note')), findsOneWidget);
    expect(find.text('Saved on this device'), findsOneWidget);
  });

  testWidgets('partial transcript is visible and final text needs review', (
    tester,
  ) async {
    final adapter = FakeSpeechToTextAdapter();
    await pumpCapture(tester, adapter: adapter);

    await tester.tap(find.byKey(const Key('capture-start-voice')));
    await tester.pump();
    adapter.emitPartial('My head feels');
    await tester.pump();

    expect(find.byKey(const Key('capture-partial-transcript')), findsOneWidget);
    expect(find.text('My head feels'), findsOneWidget);
    expect(find.byKey(const Key('capture-stop-voice')), findsOneWidget);

    adapter.emitFinal('My head feels full today.');
    await tester.pump();

    expect(
      find.text('These are still your words. Nothing has been interpreted.'),
      findsOneWidget,
    );
    expect(find.text('Save transcript as note'), findsOneWidget);
    expect(find.text('My head feels full today.'), findsWidgets);
  });

  testWidgets('permission denial shows fallback and keeps the text field', (
    tester,
  ) async {
    await pumpCapture(
      tester,
      adapter: FakeSpeechToTextAdapter(
        permission: SpeechPermissionStatus.denied,
      ),
    );

    await tester.tap(find.byKey(const Key('capture-start-voice')));
    await tester.pump();

    expect(find.byKey(const Key('capture-text-field')), findsOneWidget);
    expect(
      find.text('Microphone permission is off. You can keep typing.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('capture-retry-voice')), findsOneWidget);
  });

  testWidgets('cancel exposes a recoverable local message without saving', (
    tester,
  ) async {
    final adapter = FakeSpeechToTextAdapter();
    final store = InMemoryCaptureNoteStore();
    final controller = TextVoiceCaptureController(
      speechAdapter: adapter,
      noteStore: store,
    );
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: LetterTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(size: Size(320, 844)),
          child: TextVoiceCaptureFlow(controller: controller),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('capture-start-voice')));
    await tester.pump();
    adapter.emitPartial('No audio should survive cancel.');
    await tester.pump();
    await tester.tap(find.byKey(const Key('capture-cancel-voice')));
    await tester.pump();

    expect(
      find.text('Voice capture canceled. Your typed words remain.'),
      findsOneWidget,
    );
    expect(store.notes, isEmpty);
  });

  testWidgets('large text at a narrow width remains scrollable', (
    tester,
  ) async {
    await pumpCapture(tester, size: const Size(320, 844), textScale: 1.8);

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('capture-scroll')), findsOneWidget);
    expect(find.byKey(const Key('capture-text-field')), findsOneWidget);
  });

  testWidgets('saved note can be deleted from the flow', (tester) async {
    final store = InMemoryCaptureNoteStore();
    await pumpCapture(tester, store: store);
    await tester.enterText(
      find.byKey(const Key('capture-text-field')),
      'Delete me locally.',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('capture-save-note')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('capture-delete-note')));
    await tester.pumpAndSettle();

    expect(
      find.text('This note was deleted from this device.'),
      findsOneWidget,
    );
    expect(store.notes, isEmpty);
  });
}
