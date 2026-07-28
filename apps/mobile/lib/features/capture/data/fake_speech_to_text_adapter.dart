import '../domain/capture_models.dart';
import '../domain/speech_to_text_adapter.dart';

/// Deterministic adapter for tests and local development. It never creates or
/// stores audio; tests only inject transcript events.
final class FakeSpeechToTextAdapter implements SpeechToTextAdapter {
  FakeSpeechToTextAdapter({
    this.permission = SpeechPermissionStatus.granted,
    this.availability = SpeechAvailability.available,
  });

  SpeechPermissionStatus permission;
  SpeechAvailability availability;
  bool isListening = false;
  int startCount = 0;
  int stopCount = 0;
  int cancelCount = 0;

  SpeechTranscriptListener? _onTranscript;
  SpeechFailureListener? _onFailure;

  @override
  Future<SpeechPermissionStatus> requestPermission() async => permission;

  @override
  Future<SpeechAvailability> checkAvailability() async => availability;

  @override
  Future<void> start({
    required SpeechTranscriptListener onTranscript,
    required SpeechFailureListener onFailure,
  }) async {
    startCount += 1;
    if (permission == SpeechPermissionStatus.denied) {
      throw const SpeechCaptureFailure(SpeechFailureReason.permissionDenied);
    }
    if (availability == SpeechAvailability.unavailable) {
      throw const SpeechCaptureFailure(SpeechFailureReason.unavailable);
    }
    _onTranscript = onTranscript;
    _onFailure = onFailure;
    isListening = true;
  }

  @override
  Future<void> stop() async {
    stopCount += 1;
    isListening = false;
  }

  @override
  Future<void> cancel() async {
    cancelCount += 1;
    isListening = false;
    _onTranscript = null;
    _onFailure = null;
  }

  void emitPartial(String text) {
    _onTranscript?.call(SpeechTranscript(text: text, isFinal: false));
  }

  void emitFinal(String text) {
    _onTranscript?.call(SpeechTranscript(text: text, isFinal: true));
  }

  void emitInterruption() {
    isListening = false;
    _onFailure?.call(
      const SpeechCaptureFailure(SpeechFailureReason.interrupted),
    );
  }

  void emitFailure(SpeechFailureReason reason) {
    isListening = false;
    _onFailure?.call(SpeechCaptureFailure(reason));
  }
}
