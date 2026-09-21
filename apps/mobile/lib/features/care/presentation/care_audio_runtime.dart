import 'package:flutter_soloud/flutter_soloud.dart';

/// Process-wide owner for Care audio.
///
/// SoLoud is a singleton. Individual scenes may stop and dispose their own
/// sources, but they must not deinitialize the engine underneath another
/// scene. Keeping initialization here also serializes simultaneous starts.
final class CareAudioRuntime {
  CareAudioRuntime._();

  static final SoLoud engine = SoLoud.instance;
  static Future<void>? _initializing;

  static Future<SoLoud> ensureInitialized() async {
    if (engine.isInitialized) return engine;
    final pending = _initializing;
    if (pending != null) {
      await pending;
      return engine;
    }

    final initializing = engine.init(
      sampleRate: 44100,
      bufferSize: 2048,
      channels: Channels.stereo,
      lowLatency: true,
    );
    _initializing = initializing;
    try {
      await initializing;
      return engine;
    } finally {
      if (identical(_initializing, initializing)) _initializing = null;
    }
  }
}
