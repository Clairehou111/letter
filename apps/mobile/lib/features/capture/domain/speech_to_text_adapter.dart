import 'capture_models.dart';

typedef SpeechTranscriptListener = void Function(SpeechTranscript transcript);
typedef SpeechFailureListener = void Function(SpeechCaptureFailure failure);

/// Platform speech boundary. Implementations may use OS speech APIs, but this
/// contract exposes transcripts only and has no raw-audio persistence surface.
abstract interface class SpeechToTextAdapter {
  Future<SpeechPermissionStatus> requestPermission();

  Future<SpeechAvailability> checkAvailability();

  Future<void> start({
    required SpeechTranscriptListener onTranscript,
    required SpeechFailureListener onFailure,
  });

  Future<void> stop();

  Future<void> cancel();
}

/// Default until a platform implementation is approved and wired in.
final class UnsupportedSpeechToTextAdapter implements SpeechToTextAdapter {
  const UnsupportedSpeechToTextAdapter();

  @override
  Future<SpeechPermissionStatus> requestPermission() async {
    return SpeechPermissionStatus.granted;
  }

  @override
  Future<SpeechAvailability> checkAvailability() async {
    return SpeechAvailability.unavailable;
  }

  @override
  Future<void> start({
    required SpeechTranscriptListener onTranscript,
    required SpeechFailureListener onFailure,
  }) async {
    onFailure(const SpeechCaptureFailure(SpeechFailureReason.unavailable));
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> cancel() async {}
}
