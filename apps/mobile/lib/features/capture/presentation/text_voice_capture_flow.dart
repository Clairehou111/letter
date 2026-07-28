import 'package:flutter/material.dart';

import '../../../design_system/letter_theme.dart';
import '../application/text_voice_capture_controller.dart';
import '../domain/capture_models.dart';

class TextVoiceCaptureFlow extends StatefulWidget {
  const TextVoiceCaptureFlow({
    required this.controller,
    super.key,
    this.onSaved,
  });

  final TextVoiceCaptureController controller;
  final ValueChanged<CaptureNote>? onSaved;

  @override
  State<TextVoiceCaptureFlow> createState() => _TextVoiceCaptureFlowState();
}

class _TextVoiceCaptureFlowState extends State<TextVoiceCaptureFlow> {
  late final TextEditingController _textController;

  TextVoiceCaptureController get _capture => widget.controller;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: _capture.state.draftText);
    _capture.addListener(_onCaptureChanged);
  }

  @override
  void dispose() {
    _capture.removeListener(_onCaptureChanged);
    _textController.dispose();
    super.dispose();
  }

  void _onCaptureChanged() {
    final draft = _capture.state.draftText;
    if (_textController.text != draft) {
      _textController.value = TextEditingValue(
        text: draft,
        selection: TextSelection.collapsed(offset: draft.length),
      );
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _save() async {
    await _capture.saveNote();
    if (mounted && _capture.state.status == CaptureStatus.saved) {
      final note = _capture.state.savedNote;
      if (note != null) {
        widget.onSaved?.call(note);
      }
    }
  }

  Future<void> _retrySave() async {
    await _capture.retrySave();
    if (mounted && _capture.state.status == CaptureStatus.saved) {
      final note = _capture.state.savedNote;
      if (note != null) {
        widget.onSaved?.call(note);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _capture.state;
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.45;

    return Scaffold(
      key: const Key('capture-flow'),
      backgroundColor: LetterColors.canvas,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: CustomScrollView(
              key: const Key('capture-scroll'),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 24, 18, 28),
                  sliver: SliverList.list(
                    children: [
                      const LetterEyebrow(
                        'Your words',
                        color: LetterColors.teal,
                      ),
                      const SizedBox(height: LetterSpacing.md),
                      Text(
                        'Write what you notice',
                        key: const Key('capture-title'),
                        style: TextStyle(
                          color: LetterColors.ink,
                          fontFamily: 'Newsreader',
                          fontSize: largeText ? 25 : 30,
                          height: 1.08,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: LetterSpacing.xs),
                      const Text(
                        'Use your own words. Letter does not interpret them here, and nothing is saved until you choose.',
                        style: TextStyle(
                          color: LetterColors.muted,
                          fontSize: 14,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: LetterSpacing.lg),
                      TextField(
                        key: const Key('capture-text-field'),
                        controller: _textController,
                        onChanged: _capture.updateDraft,
                        maxLength: captureTextLimit,
                        minLines: 5,
                        maxLines: 8,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          labelText: 'A private note',
                          hintText: 'What is present today?',
                          alignLabelWithHint: true,
                          filled: true,
                          fillColor: LetterColors.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              LetterRadius.control,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: LetterSpacing.sm),
                      _VoiceSection(state: state, capture: _capture),
                      const SizedBox(height: LetterSpacing.md),
                      _CaptureActions(
                        state: state,
                        capture: _capture,
                        onSave: _save,
                        onRetrySave: _retrySave,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VoiceSection extends StatelessWidget {
  const _VoiceSection({required this.state, required this.capture});

  final CaptureState state;
  final TextVoiceCaptureController capture;

  @override
  Widget build(BuildContext context) {
    final listening = state.status == CaptureStatus.listening;
    final requesting = state.status == CaptureStatus.requestingPermission;

    return Container(
      key: const Key('capture-voice-section'),
      padding: const EdgeInsets.all(LetterSpacing.md),
      decoration: BoxDecoration(
        color: LetterColors.tealSoft,
        borderRadius: BorderRadius.circular(LetterRadius.panel),
        border: Border.all(color: LetterColors.teal.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Prefer to speak?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: LetterSpacing.xxs),
          const Text(
            'Voice is transcribed on the device when available. Audio is not kept.',
            style: TextStyle(color: LetterColors.muted, height: 1.4),
          ),
          const SizedBox(height: LetterSpacing.sm),
          if (listening) ...[
            Semantics(
              liveRegion: true,
              label: state.transcriptText.isEmpty
                  ? 'Listening. No words yet.'
                  : 'Partial transcript: ${state.transcriptText}',
              child: Container(
                key: const Key('capture-partial-transcript'),
                padding: const EdgeInsets.all(LetterSpacing.sm),
                decoration: BoxDecoration(
                  color: LetterColors.surface,
                  borderRadius: BorderRadius.circular(LetterRadius.control),
                ),
                child: Text(
                  state.transcriptText.isEmpty
                      ? 'Listening...'
                      : state.transcriptText,
                  style: const TextStyle(height: 1.4),
                ),
              ),
            ),
            const SizedBox(height: LetterSpacing.sm),
            OutlinedButton.icon(
              key: const Key('capture-stop-voice'),
              onPressed: capture.stopVoice,
              style: _secondaryButtonStyle(),
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('Stop listening'),
            ),
            TextButton.icon(
              key: const Key('capture-cancel-voice'),
              onPressed: capture.cancelVoice,
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: LetterColors.muted,
              ),
              icon: const Icon(Icons.close),
              label: const Text('Cancel'),
            ),
          ] else if (requesting)
            Center(
              child: Semantics(
                label: 'Checking microphone permission',
                child: SizedBox.square(
                  key: Key('capture-permission-progress'),
                  dimension: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: LetterColors.teal,
                  ),
                ),
              ),
            )
          else ...[
            OutlinedButton.icon(
              key: const Key('capture-start-voice'),
              onPressed: capture.startVoice,
              style: _secondaryButtonStyle(),
              icon: const Icon(Icons.mic_none_outlined),
              label: Text(_voiceButtonLabel(state.status)),
            ),
            if (_voiceMessage(state.status) case final message?) ...[
              const SizedBox(height: LetterSpacing.xs),
              Semantics(
                liveRegion: true,
                child: Text(
                  message,
                  key: const Key('capture-voice-status'),
                  style: const TextStyle(
                    color: LetterColors.muted,
                    height: 1.4,
                  ),
                ),
              ),
            ],
            if (_canRetryVoice(state.status)) ...[
              const SizedBox(height: LetterSpacing.xs),
              TextButton.icon(
                key: const Key('capture-retry-voice'),
                onPressed: capture.retryVoice,
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: LetterColors.teal,
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('Try microphone again'),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _CaptureActions extends StatelessWidget {
  const _CaptureActions({
    required this.state,
    required this.capture,
    required this.onSave,
    required this.onRetrySave,
  });

  final CaptureState state;
  final TextVoiceCaptureController capture;
  final Future<void> Function() onSave;
  final Future<void> Function() onRetrySave;

  @override
  Widget build(BuildContext context) {
    if (state.status == CaptureStatus.saved && state.savedNote != null) {
      return _SavedNoteCard(
        note: state.savedNote!,
        onDelete: capture.deleteSavedNote,
      );
    }

    if (state.status == CaptureStatus.deleted ||
        state.status == CaptureStatus.canceled) {
      return Semantics(
        liveRegion: true,
        child: Text(
          state.status == CaptureStatus.deleted
              ? 'This note was deleted from this device.'
              : 'Voice capture canceled. Your typed words remain.',
          key: const Key('capture-completion-message'),
          style: const TextStyle(color: LetterColors.muted, height: 1.4),
        ),
      );
    }

    final isReview = state.status == CaptureStatus.reviewing;
    final saveFailed = state.status == CaptureStatus.saveFailed;
    final deleteFailed = state.status == CaptureStatus.deleteFailed;
    final canSave = capture.canSave && !deleteFailed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isReview) ...[
          const LetterEyebrow('Review before saving', color: LetterColors.teal),
          const SizedBox(height: LetterSpacing.xs),
          const Text(
            'These are still your words. Nothing has been interpreted.',
            style: TextStyle(color: LetterColors.muted, height: 1.4),
          ),
          const SizedBox(height: LetterSpacing.sm),
        ],
        if (state.errorMessage != null) ...[
          Semantics(
            liveRegion: true,
            child: Text(
              state.errorMessage!,
              key: const Key('capture-error'),
              style: const TextStyle(
                color: Color(0xFF9F312C),
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: LetterSpacing.sm),
        ],
        if (saveFailed)
          FilledButton.icon(
            key: const Key('capture-retry-save'),
            onPressed: onRetrySave,
            style: _primaryButtonStyle(),
            icon: const Icon(Icons.refresh),
            label: const Text('Try saving again'),
          )
        else if (!deleteFailed)
          FilledButton.icon(
            key: const Key('capture-save-note'),
            onPressed: canSave ? onSave : null,
            style: _primaryButtonStyle(),
            icon: const Icon(Icons.lock_outline),
            label: Text(isReview ? 'Save transcript as note' : 'Save note'),
          )
        else
          FilledButton.icon(
            key: const Key('capture-retry-delete'),
            onPressed: capture.retryDelete,
            style: _primaryButtonStyle(),
            icon: const Icon(Icons.refresh),
            label: const Text('Try deleting again'),
          ),
      ],
    );
  }
}

class _SavedNoteCard extends StatelessWidget {
  const _SavedNoteCard({required this.note, required this.onDelete});

  final CaptureNote note;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Note saved on this device',
      child: Container(
        key: const Key('capture-saved-note'),
        padding: const EdgeInsets.all(LetterSpacing.md),
        decoration: BoxDecoration(
          color: LetterColors.surface,
          borderRadius: BorderRadius.circular(LetterRadius.panel),
          border: Border.all(color: LetterColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.check_circle_outline, color: LetterColors.teal),
                SizedBox(width: LetterSpacing.xs),
                Text(
                  'Saved on this device',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: LetterSpacing.sm),
            Text(note.text, style: const TextStyle(height: 1.4)),
            const SizedBox(height: LetterSpacing.sm),
            TextButton.icon(
              key: const Key('capture-delete-note'),
              onPressed: onDelete,
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: const Color(0xFF8A2F2B),
              ),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete note'),
            ),
          ],
        ),
      ),
    );
  }
}

String _voiceButtonLabel(CaptureStatus status) {
  return switch (status) {
    CaptureStatus.permissionDenied => 'Try microphone again',
    CaptureStatus.unavailable => 'Try microphone again',
    CaptureStatus.interrupted => 'Try listening again',
    CaptureStatus.failed => 'Try listening again',
    _ => 'Speak instead',
  };
}

String? _voiceMessage(CaptureStatus status) {
  return switch (status) {
    CaptureStatus.permissionDenied =>
      'Microphone permission is off. You can keep typing.',
    CaptureStatus.unavailable =>
      'Voice capture is unavailable here. You can keep typing.',
    CaptureStatus.interrupted =>
      'Listening was interrupted. Your words are still here.',
    CaptureStatus.failed =>
      'Voice capture stopped. You can try again or keep typing.',
    _ => null,
  };
}

bool _canRetryVoice(CaptureStatus status) {
  return status == CaptureStatus.permissionDenied ||
      status == CaptureStatus.unavailable ||
      status == CaptureStatus.interrupted ||
      status == CaptureStatus.failed;
}

ButtonStyle _primaryButtonStyle() {
  return FilledButton.styleFrom(
    minimumSize: const Size.fromHeight(52),
    backgroundColor: LetterColors.teal,
    foregroundColor: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(LetterRadius.control),
    ),
  );
}

ButtonStyle _secondaryButtonStyle() {
  return OutlinedButton.styleFrom(
    minimumSize: const Size.fromHeight(48),
    foregroundColor: LetterColors.teal,
    backgroundColor: LetterColors.surface,
    side: const BorderSide(color: LetterColors.teal),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(LetterRadius.control),
    ),
  );
}
