import 'package:flutter/foundation.dart';

import '../domain/capture_models.dart';
import '../domain/speech_to_text_adapter.dart';

typedef CaptureClock = DateTime Function();

final class TextVoiceCaptureController extends ChangeNotifier {
  TextVoiceCaptureController({
    required this.speechAdapter,
    required this.noteStore,
    CaptureClock? clock,
    String initialText = '',
  }) : _clock = clock ?? DateTime.now,
       _state = CaptureState(draftText: _limitText(initialText));

  final SpeechToTextAdapter speechAdapter;
  final CaptureNoteStore noteStore;
  final CaptureClock _clock;

  CaptureState _state;
  bool _voiceSessionActive = false;
  bool _transcriptApplied = false;
  CaptureNote? _notePendingDelete;

  CaptureState get state => _state;

  bool get canSave =>
      _state.hasText &&
      _state.status != CaptureStatus.listening &&
      _state.status != CaptureStatus.requestingPermission &&
      _state.status != CaptureStatus.saving;

  void updateDraft(String text) {
    final limited = _limitText(text);
    final status = switch (_state.status) {
      CaptureStatus.saved || CaptureStatus.deleted => CaptureStatus.editing,
      CaptureStatus.canceled ||
      CaptureStatus.permissionDenied ||
      CaptureStatus.unavailable ||
      CaptureStatus.interrupted ||
      CaptureStatus.failed ||
      CaptureStatus.saveFailed ||
      CaptureStatus.deleteFailed => CaptureStatus.editing,
      final current => current,
    };
    _setState(
      _state.copyWith(status: status, draftText: limited, clearError: true),
    );
  }

  Future<void> startVoice() async {
    if (_voiceSessionActive || _state.status == CaptureStatus.saving) {
      return;
    }
    _transcriptApplied = false;
    _voiceSessionActive = false;
    _setState(
      _state.copyWith(
        status: CaptureStatus.requestingPermission,
        transcriptText: '',
        clearError: true,
      ),
    );

    try {
      final permission = await speechAdapter.requestPermission();
      if (permission == SpeechPermissionStatus.denied) {
        _setState(
          _state.copyWith(
            status: CaptureStatus.permissionDenied,
            clearError: true,
          ),
        );
        return;
      }

      final availability = await speechAdapter.checkAvailability();
      if (availability == SpeechAvailability.unavailable) {
        _setState(
          _state.copyWith(status: CaptureStatus.unavailable, clearError: true),
        );
        return;
      }

      _voiceSessionActive = true;
      _setState(
        _state.copyWith(status: CaptureStatus.listening, clearError: true),
      );
      await speechAdapter.start(
        onTranscript: _handleTranscript,
        onFailure: _handleFailure,
      );
    } on SpeechCaptureFailure catch (error) {
      _voiceSessionActive = false;
      _handleFailure(error);
    } catch (_) {
      _voiceSessionActive = false;
      _setState(
        _state.copyWith(
          status: CaptureStatus.failed,
          errorMessage:
              'Voice capture stopped. You can try again or keep typing.',
        ),
      );
    }
  }

  Future<void> stopVoice() async {
    if (!_voiceSessionActive) {
      return;
    }
    try {
      await speechAdapter.stop();
    } catch (_) {
      _voiceSessionActive = false;
      _setState(
        _state.copyWith(
          status: CaptureStatus.failed,
          errorMessage:
              'Voice capture stopped. You can try again or keep typing.',
        ),
      );
      return;
    }
    _voiceSessionActive = false;
    _applyTranscriptIfNeeded();
    _setState(
      _state.copyWith(status: CaptureStatus.reviewing, clearError: true),
    );
  }

  Future<void> cancelVoice() async {
    if (!_voiceSessionActive && _state.status != CaptureStatus.listening) {
      return;
    }
    try {
      await speechAdapter.cancel();
    } finally {
      _voiceSessionActive = false;
      _transcriptApplied = false;
      _setState(
        _state.copyWith(
          status: CaptureStatus.canceled,
          transcriptText: '',
          clearError: true,
        ),
      );
    }
  }

  Future<void> retryVoice() async {
    if (_state.status == CaptureStatus.permissionDenied ||
        _state.status == CaptureStatus.unavailable ||
        _state.status == CaptureStatus.interrupted ||
        _state.status == CaptureStatus.failed) {
      await startVoice();
    }
  }

  Future<void> saveNote() async {
    if (!canSave) {
      return;
    }
    final text = _state.draftText.trim();
    if (text.isEmpty) {
      return;
    }
    final source = _state.transcriptText.trim().isNotEmpty
        ? CaptureSource.voiceTranscript
        : CaptureSource.typed;
    final note = CaptureNote(text: text, source: source, createdAt: _clock());
    _setState(_state.copyWith(status: CaptureStatus.saving, clearError: true));
    try {
      await noteStore.save(note);
      _setState(_state.copyWith(status: CaptureStatus.saved, savedNote: note));
    } catch (_) {
      _setState(
        _state.copyWith(
          status: CaptureStatus.saveFailed,
          errorMessage: 'Letter could not save these words. Try again.',
        ),
      );
    }
  }

  Future<void> retrySave() async {
    if (_state.status == CaptureStatus.saveFailed) {
      await saveNote();
    }
  }

  Future<void> deleteSavedNote() async {
    final note = _state.savedNote;
    if (note == null || _state.status == CaptureStatus.saving) {
      return;
    }
    _notePendingDelete = note;
    try {
      await noteStore.delete(note);
      _notePendingDelete = null;
      _setState(
        _state.copyWith(
          status: CaptureStatus.deleted,
          draftText: '',
          transcriptText: '',
          clearSavedNote: true,
          clearError: true,
        ),
      );
    } catch (_) {
      _setState(
        _state.copyWith(
          status: CaptureStatus.deleteFailed,
          errorMessage: 'Letter could not delete these words. Try again.',
        ),
      );
    }
  }

  Future<void> retryDelete() async {
    if (_state.status == CaptureStatus.deleteFailed &&
        _notePendingDelete != null) {
      await deleteSavedNote();
    }
  }

  void _handleTranscript(SpeechTranscript transcript) {
    if (!_voiceSessionActive) {
      return;
    }
    final text = _limitText(transcript.text);
    _setState(
      _state.copyWith(
        transcriptText: text,
        status: transcript.isFinal
            ? CaptureStatus.reviewing
            : CaptureStatus.listening,
        clearError: true,
      ),
    );
    if (transcript.isFinal) {
      _applyTranscriptIfNeeded();
    }
  }

  void _handleFailure(SpeechCaptureFailure failure) {
    if (failure.reason == SpeechFailureReason.interrupted) {
      _applyTranscriptIfNeeded();
    }
    _voiceSessionActive = false;
    final status = switch (failure.reason) {
      SpeechFailureReason.permissionDenied => CaptureStatus.permissionDenied,
      SpeechFailureReason.unavailable => CaptureStatus.unavailable,
      SpeechFailureReason.interrupted => CaptureStatus.interrupted,
      SpeechFailureReason.failed => CaptureStatus.failed,
    };
    final message = switch (failure.reason) {
      SpeechFailureReason.permissionDenied =>
        'Microphone permission is off. You can keep typing.',
      SpeechFailureReason.unavailable =>
        'Voice capture is unavailable here. You can keep typing.',
      SpeechFailureReason.interrupted =>
        'Listening was interrupted. Your words are still here.',
      SpeechFailureReason.failed =>
        'Voice capture stopped. You can try again or keep typing.',
    };
    _setState(
      _state.copyWith(status: status, errorMessage: failure.message ?? message),
    );
  }

  void _applyTranscriptIfNeeded() {
    if (_transcriptApplied || _state.transcriptText.trim().isEmpty) {
      return;
    }
    final current = _state.draftText.trimRight();
    final transcript = _state.transcriptText.trim();
    final merged = current.isEmpty ? transcript : '$current\n$transcript';
    _transcriptApplied = true;
    _setState(_state.copyWith(draftText: _limitText(merged)));
  }

  void _setState(CaptureState next) {
    _state = next;
    notifyListeners();
  }

  static String _limitText(String text) {
    if (text.length <= captureTextLimit) {
      return text;
    }
    return text.substring(0, captureTextLimit);
  }
}
