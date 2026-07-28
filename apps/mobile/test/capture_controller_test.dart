import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/capture/application/text_voice_capture_controller.dart';
import 'package:letter_mobile/features/capture/data/fake_speech_to_text_adapter.dart';
import 'package:letter_mobile/features/capture/domain/capture_models.dart';

TextVoiceCaptureController createController({
  FakeSpeechToTextAdapter? adapter,
  CaptureNoteStore? store,
  String initialText = '',
}) {
  return TextVoiceCaptureController(
    speechAdapter: adapter ?? FakeSpeechToTextAdapter(),
    noteStore: store ?? InMemoryCaptureNoteStore(),
    initialText: initialText,
    clock: () => DateTime.utc(2026, 7, 28),
    idGenerator: () => 'capture-note',
  );
}

void main() {
  test('typed text remains local until the explicit save action', () async {
    final store = InMemoryCaptureNoteStore();
    final controller = createController(store: store);

    controller.updateDraft('My own words, not a checkbox.');
    expect(store.notes, isEmpty);

    await controller.saveNote();

    expect(controller.state.status, CaptureStatus.saved);
    expect(store.notes.single.text, 'My own words, not a checkbox.');
    expect(store.notes.single.source, CaptureSource.typed);
    expect(store.notes.single.id, 'capture-note');
    expect(store.notes.single.createdAt, DateTime.utc(2026, 7, 28));
  });

  test('permission denial leaves text capture fully usable', () async {
    final adapter = FakeSpeechToTextAdapter(
      permission: SpeechPermissionStatus.denied,
    );
    final controller = createController(adapter: adapter);

    await controller.startVoice();

    expect(controller.state.status, CaptureStatus.permissionDenied);
    controller.updateDraft('I can still write this.');
    expect(controller.canSave, isTrue);
  });

  test('unavailable speech is a recoverable state', () async {
    final adapter = FakeSpeechToTextAdapter(
      availability: SpeechAvailability.unavailable,
    );
    final controller = createController(adapter: adapter);

    await controller.startVoice();

    expect(controller.state.status, CaptureStatus.unavailable);
    expect(controller.state.draftText, isEmpty);
    expect(controller.canSave, isFalse);
  });

  test(
    'partial and final transcripts become editable text only after review',
    () async {
      final adapter = FakeSpeechToTextAdapter();
      final controller = createController(adapter: adapter);

      await controller.startVoice();
      adapter.emitPartial('The room feels');

      expect(controller.state.status, CaptureStatus.listening);
      expect(controller.state.transcriptText, 'The room feels');
      expect(controller.state.draftText, isEmpty);

      adapter.emitFinal('The room feels too bright.');

      expect(controller.state.status, CaptureStatus.reviewing);
      expect(controller.state.draftText, 'The room feels too bright.');
      expect(controller.state.transcriptText, 'The room feels too bright.');
    },
  );

  test(
    'stop applies a partial transcript and cancel does not save it',
    () async {
      final adapter = FakeSpeechToTextAdapter();
      final store = InMemoryCaptureNoteStore();
      final controller = createController(adapter: adapter, store: store);

      await controller.startVoice();
      adapter.emitPartial('I need a quiet room.');
      await controller.stopVoice();

      expect(controller.state.status, CaptureStatus.reviewing);
      expect(controller.state.draftText, 'I need a quiet room.');
      expect(store.notes, isEmpty);
      expect(adapter.stopCount, 1);

      await controller.startVoice();
      adapter.emitPartial('This second thought should vanish.');
      await controller.cancelVoice();

      expect(controller.state.status, CaptureStatus.canceled);
      expect(controller.state.transcriptText, isEmpty);
      expect(controller.state.draftText, 'I need a quiet room.');
      expect(store.notes, isEmpty);
      expect(adapter.cancelCount, 1);
    },
  );

  test(
    'interruption preserves a partial transcript and retry starts again',
    () async {
      final adapter = FakeSpeechToTextAdapter();
      final controller = createController(adapter: adapter);

      await controller.startVoice();
      adapter.emitPartial('I am having trouble focusing.');
      adapter.emitInterruption();

      expect(controller.state.status, CaptureStatus.interrupted);
      expect(controller.state.draftText, 'I am having trouble focusing.');

      await controller.retryVoice();
      expect(adapter.startCount, 2);
      expect(controller.state.status, CaptureStatus.listening);
    },
  );

  test(
    'saved note can be explicitly deleted and has no audio payload',
    () async {
      final store = InMemoryCaptureNoteStore();
      final controller = createController(store: store);
      controller.updateDraft('A transcript I chose to keep.');

      await controller.saveNote();
      final note = store.notes.single;
      expect(note, isA<CaptureNote>());
      expect(note.toString(), isNot(contains('audio')));

      await controller.deleteSavedNote();

      expect(controller.state.status, CaptureStatus.deleted);
      expect(store.notes, isEmpty);
    },
  );

  test('drafts are capped at the local text limit', () {
    final controller = createController();
    controller.updateDraft('x' * (captureTextLimit + 10));

    expect(controller.state.draftText.length, captureTextLimit);
  });
}
