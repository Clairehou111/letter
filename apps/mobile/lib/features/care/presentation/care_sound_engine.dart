import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import '../domain/care_mode.dart';

/// Local ambience engine matching the Lovable Web Audio graph.
///
/// Away deliberately uses one raw crowd recording and moves a realtime
/// low-pass filter as the door closes. Crossfading three rendered recordings
/// changes the room tone and cannot reproduce that effect.
class CareSoundEngine {
  static final SoLoud _engine = SoLoud.instance;
  static Future<void>? _initializing;

  static const _assets = <CareMode, String>{
    CareMode.explode: 'assets/audio/care/prototype/explode.mp3',
    CareMode.heavy: 'assets/audio/care/prototype/heavy.mp3',
    CareMode.racing: 'assets/audio/care/prototype/racing.mp3',
    CareMode.space: 'assets/audio/care/prototype/space.mp3',
    CareMode.physical: 'assets/audio/care/prototype/physical.mp3',
  };

  static const _shape = <CareMode, _AudioShape>{
    CareMode.explode: _AudioShape(
      cutoff: 320,
      open: 260,
      gain: 0.85,
      rate: 0.94,
    ),
    CareMode.heavy: _AudioShape(cutoff: 420, open: 580, gain: 0.50, rate: 0.94),
    CareMode.racing: _AudioShape(
      cutoff: 620,
      open: 380,
      gain: 0.80,
      rate: 0.96,
    ),
    CareMode.space: _AudioShape(cutoff: 1100, open: 700, gain: 0.46, rate: 1),
    CareMode.physical: _AudioShape(
      cutoff: 420,
      open: 220,
      gain: 0.85,
      rate: 0.98,
    ),
  };

  _Voice? _voice;
  CareMode? _mode;
  double _level = 0.6;
  double _intensity = 0;
  double _outside = 1;
  int _generation = 0;

  Future<bool> play(
    CareMode mode, {
    bool settled = false,
    bool words = false,
    double intensity = 0.6,
  }) async {
    final generation = ++_generation;
    await _disposeVoice();
    if (generation != _generation) return false;

    _mode = mode;
    _intensity = intensity.clamp(0.0, 1.0);
    await _ensureEngine();

    final shape = _shape[mode]!;
    final voice = await _spin(
      _assets[mode]!,
      cutoff: mode == CareMode.space ? 4200 : shape.cutoff,
      rate: shape.rate,
    );
    if (voice == null || generation != _generation) {
      await _disposeVoice(voice);
      _mode = null;
      return false;
    }
    _voice = voice;
    _apply(seconds: mode == CareMode.space ? 4 : 8);
    unawaited(setIntensity(_intensity));
    return true;
  }

  static Future<void> _ensureEngine() async {
    if (_engine.isInitialized) return;
    final pending = _initializing;
    if (pending != null) return pending;

    final initializing = _engine.init(
      sampleRate: 44100,
      bufferSize: 2048,
      channels: Channels.stereo,
      lowLatency: true,
    );
    _initializing = initializing;
    try {
      await initializing;
    } finally {
      if (identical(_initializing, initializing)) _initializing = null;
    }
  }

  Future<_Voice?> _spin(
    String asset, {
    required double cutoff,
    required double rate,
  }) async {
    AudioSource? source;
    SoundHandle? handle;
    try {
      source = await _engine.loadAsset(asset);
      source.filters.biquadFilter.activate();
      source.filters.parametricEqFilter.activate();
      source.filters.compressorFilter.activate();

      handle = _engine.play(source, volume: 0, paused: true, looping: true);
      _configureLowPass(source, handle, cutoff);
      _configureHighShelf(source, handle);
      _configureCompressor(source, handle);
      _engine.setRelativePlaySpeed(handle, rate);

      final duration = _engine.getLength(source);
      if (duration.inMilliseconds > 0) {
        _engine.seek(
          handle,
          Duration(
            milliseconds: (Random().nextDouble() * duration.inMilliseconds)
                .round(),
          ),
        );
      }
      _engine.setPause(handle, false);
      debugPrint('CareSoundEngine: started $asset (rate=${rate}x)');
      return _Voice(source, handle);
    } on Object catch (error, stackTrace) {
      debugPrint('CareSoundEngine: failed to load $asset: $error');
      debugPrintStack(stackTrace: stackTrace);
      await _disposeVoice(
        handle == null || source == null ? null : _Voice(source, handle),
      );
      return null;
    }
  }

  void _configureLowPass(
    AudioSource source,
    SoundHandle handle,
    double cutoff,
  ) {
    final filter = source.filters.biquadFilter;
    filter.wet(soundHandle: handle).value = 1;
    filter.type(soundHandle: handle).value = 0;
    filter.frequency(soundHandle: handle).value = cutoff;
    filter.resonance(soundHandle: handle).value = 0.3;
  }

  void _configureHighShelf(AudioSource source, SoundHandle handle) {
    const bands = 32;
    const shelfStart = 1400.0;
    const lowerEdge = shelfStart / sqrt2;
    const upperEdge = shelfStart * sqrt2;
    const fullCut = 0.06309573444801933;

    final eq = source.filters.parametricEqFilter;
    eq.wet(soundHandle: handle).value = 1;
    eq.stftWindowSize(soundHandle: handle).value = 1024;
    eq.numBands(soundHandle: handle).value = bands.toDouble();
    for (var index = 0; index < bands; index++) {
      final t = index / (bands - 1);
      final frequency = 30 * pow(16000 / 30, t);
      final gain = frequency <= lowerEdge
          ? 1.0
          : frequency >= upperEdge
          ? fullCut
          : pow(
              10,
              -24 *
                  (log(frequency / lowerEdge) / log(upperEdge / lowerEdge)) /
                  20,
            ).toDouble();
      eq.bandGain(index, soundHandle: handle).value = gain;
    }
  }

  void _configureCompressor(AudioSource source, SoundHandle handle) {
    final compressor = source.filters.compressorFilter;
    compressor.wet(soundHandle: handle).value = 1;
    compressor.threshold(soundHandle: handle).value = -28;
    compressor.makeupGain(soundHandle: handle).value = 0;
    compressor.kneeWidth(soundHandle: handle).value = 26;
    compressor.ratio(soundHandle: handle).value = 8;
    compressor.attackTime(soundHandle: handle).value = 50;
    compressor.releaseTime(soundHandle: handle).value = 800;
  }

  double _base() {
    final shape = _shape[_mode]!;
    return shape.gain * (0.15 + _level * 0.85);
  }

  void _apply({double seconds = 3}) {
    final voice = _voice;
    final mode = _mode;
    if (voice == null || mode == null || !_engine.isInitialized) return;

    final target = mode == CareMode.space
        ? _base() * 1.25 * pow(_outside.clamp(0.0, 1.0), 1.7)
        : _base();
    _engine.fadeVolume(
      voice.handle,
      target.clamp(0.0, 1.0),
      Duration(milliseconds: max(1, (seconds * 1000).round())),
    );
  }

  /// Intensity changes timbre, not loudness.
  Future<void> setIntensity(double value) async {
    _intensity = value.clamp(0.0, 1.0);
    final voice = _voice;
    final mode = _mode;
    if (voice == null || mode == null || mode == CareMode.space) return;
    final shape = _shape[mode]!;
    voice.source.filters.biquadFilter
        .frequency(soundHandle: voice.handle)
        .fadeFilterParameter(
          to: shape.cutoff + _intensity * shape.open,
          time: const Duration(milliseconds: 2500),
        );
  }

  /// Kept for compatibility with callers that treat the slider as a level.
  Future<void> setLevel(double value) async {
    _level = value.clamp(0.0, 1.0);
    _apply(seconds: 2);
  }

  Future<void> setOutside(double value) async {
    if (_mode != CareMode.space) return;
    _outside = value.clamp(0.0, 1.0);
    final voice = _voice;
    if (voice != null && _engine.isInitialized) {
      voice.source.filters.biquadFilter
          .frequency(soundHandle: voice.handle)
          .fadeFilterParameter(
            to: 360 + _outside * 3840,
            time: const Duration(milliseconds: 360),
          );
    }
    _apply(seconds: 0.36);
  }

  Future<void> stop() async {
    final generation = ++_generation;
    final voice = _voice;
    if (voice == null) {
      _mode = null;
      return;
    }
    if (_engine.isInitialized) {
      _engine.fadeVolume(voice.handle, 0, const Duration(milliseconds: 2200));
    }
    await Future<void>.delayed(const Duration(milliseconds: 2400));
    if (generation != _generation) return;
    await _disposeVoice();
    _mode = null;
  }

  Future<void> _disposeVoice([_Voice? voice]) async {
    final target = voice ?? _voice;
    if (target == null || !_engine.isInitialized) {
      if (voice == null) _voice = null;
      return;
    }
    if (identical(_voice, target)) _voice = null;
    try {
      await _engine.stop(target.handle);
    } catch (_) {}
    try {
      await _engine.disposeSource(target.source);
    } catch (_) {}
  }

  Future<void> dispose() async {
    await stop();
  }
}

class _AudioShape {
  const _AudioShape({
    required this.cutoff,
    required this.open,
    required this.gain,
    required this.rate,
  });

  final double cutoff;
  final double open;
  final double gain;
  final double rate;
}

class _Voice {
  const _Voice(this.source, this.handle);

  final AudioSource source;
  final SoundHandle handle;
}
