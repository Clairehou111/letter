import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../design_system/letter_theme.dart';

const _clipboardDisclosure =
    'Copying puts this text on your device clipboard. It may remain there '
    'after you leave Letter.';
const _copyAcknowledgement = 'Copied to your device clipboard.';

const _durations = <_BoundaryDuration>[
  _BoundaryDuration(keyName: '30m', label: '30 minutes'),
  _BoundaryDuration(keyName: '2h', label: '2 hours'),
  _BoundaryDuration(keyName: '4h', label: '4 hours'),
];

const _templates = <_BoundaryTemplate>[
  _BoundaryTemplate(
    buildText: _quietTimeTemplate,
    semanticsLabel: 'Quiet time boundary',
  ),
  _BoundaryTemplate(
    buildText: _steppingAwayTemplate,
    semanticsLabel: 'Stepping away boundary',
  ),
];

String _quietTimeTemplate(String duration) {
  return 'I need some quiet time for the next $duration. '
      'I will not be available to reply.';
}

String _steppingAwayTemplate(String duration) {
  return 'I am stepping away for $duration. '
      'Please do not call or message me during that time.';
}

class NeedSpaceBoundaryCard extends StatefulWidget {
  const NeedSpaceBoundaryCard({
    required this.controller,
    required this.onBack,
    required this.onFinish,
    super.key,
  });

  final TextEditingController controller;
  final VoidCallback onBack;
  final VoidCallback onFinish;

  @override
  State<NeedSpaceBoundaryCard> createState() => _NeedSpaceBoundaryCardState();
}

class _NeedSpaceBoundaryCardState extends State<NeedSpaceBoundaryCard> {
  int? _selectedTemplate;
  _BoundaryDuration _selectedDuration = _durations.first;
  bool _copied = false;
  bool _showValidation = false;
  String? _copyError;

  bool get _hasDraft => widget.controller.text.trim().isNotEmpty;

  String? get _validationMessage {
    final text = widget.controller.text.trim();
    if (text.isEmpty) {
      return 'Write at least one character, or choose Discard.';
    }
    if (text.length > 280) {
      return 'Keep the text to 280 characters or fewer.';
    }
    return null;
  }

  void _selectTemplate(int index) {
    widget.controller.text = _templates[index].buildText(
      _selectedDuration.label,
    );
    widget.controller.selection = TextSelection.collapsed(
      offset: widget.controller.text.length,
    );
    setState(() {
      _selectedTemplate = index;
      _copied = false;
      _copyError = null;
      _showValidation = false;
    });
  }

  void _selectDuration(_BoundaryDuration duration) {
    if (_selectedDuration == duration) {
      return;
    }

    setState(() {
      _selectedDuration = duration;
      _copied = false;
      _copyError = null;
      _showValidation = false;
      if (_selectedTemplate case final index?) {
        widget.controller.text = _templates[index].buildText(duration.label);
        widget.controller.selection = TextSelection.collapsed(
          offset: widget.controller.text.length,
        );
      }
    });
  }

  void _onTextChanged(String _) {
    setState(() {
      _copied = false;
      _copyError = null;
      if (_showValidation) {
        _showValidation = _validationMessage != null;
      }
    });
  }

  bool _validate() {
    final message = _validationMessage;
    setState(() => _showValidation = message != null);
    return message == null;
  }

  Future<void> _copyText() async {
    if (!_validate()) {
      return;
    }

    setState(() {
      _copied = false;
      _copyError = null;
    });

    try {
      await Clipboard.setData(
        ClipboardData(text: widget.controller.text.trim()),
      );
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _copyError = 'Could not copy. Your text is still here.';
      });
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() => _copied = true);
  }

  void _continue() {
    if (!_validate()) {
      return;
    }
    widget.onFinish();
  }

  void _discard() {
    widget.controller.clear();
    widget.onFinish();
  }

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.45;

    return Column(
      key: const Key('need-space-boundary-card-content'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              key: const Key('need-space-boundary-back'),
              tooltip: 'Back to your quiet space',
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: LetterSpacing.xs),
            const Expanded(
              child: LetterEyebrow(
                'Optional boundary words',
                color: LetterColors.teal,
              ),
            ),
          ],
        ),
        const SizedBox(height: LetterSpacing.sm),
        Text(
          'Say only what is true.',
          style: TextStyle(
            color: LetterColors.ink,
            fontFamily: 'Newsreader',
            fontSize: largeText ? 23 : 27,
            height: 1.08,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: LetterSpacing.xs),
        const Text(
          'Choose a starting point, edit it, or leave without using words.',
          style: TextStyle(
            color: LetterColors.muted,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        const SizedBox(height: LetterSpacing.lg),
        const LetterEyebrow('How long'),
        const SizedBox(height: LetterSpacing.xs),
        Wrap(
          spacing: LetterSpacing.xs,
          runSpacing: LetterSpacing.xs,
          children: [
            for (final duration in _durations)
              ChoiceChip(
                key: Key('need-space-duration-${duration.keyName}'),
                label: Text(duration.label),
                selected: _selectedDuration == duration,
                showCheckmark: true,
                onSelected: (_) => _selectDuration(duration),
                selectedColor: LetterColors.tealSoft,
                backgroundColor: LetterColors.surface,
                side: BorderSide(
                  color: _selectedDuration == duration
                      ? LetterColors.teal
                      : LetterColors.line,
                ),
                labelStyle: TextStyle(
                  color: _selectedDuration == duration
                      ? LetterColors.tealDark
                      : LetterColors.ink,
                  fontWeight: FontWeight.w700,
                ),
                materialTapTargetSize: MaterialTapTargetSize.padded,
              ),
          ],
        ),
        const SizedBox(height: LetterSpacing.lg),
        const LetterEyebrow('Choose words'),
        const SizedBox(height: LetterSpacing.xs),
        for (var index = 0; index < _templates.length; index++) ...[
          Semantics(
            button: true,
            selected: _selectedTemplate == index,
            label:
                '${_templates[index].semanticsLabel}. '
                '${_templates[index].buildText(_selectedDuration.label)}',
            child: ExcludeSemantics(
              child: OutlinedButton(
                key: Key('need-space-template-$index'),
                onPressed: () => _selectTemplate(index),
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  minimumSize: const Size.fromHeight(68),
                  padding: const EdgeInsets.all(LetterSpacing.md),
                  foregroundColor: LetterColors.ink,
                  backgroundColor: _selectedTemplate == index
                      ? LetterColors.tealSoft
                      : LetterColors.surface,
                  side: BorderSide(
                    color: _selectedTemplate == index
                        ? LetterColors.teal
                        : LetterColors.line,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(LetterRadius.control),
                  ),
                ),
                child: Text(
                  _templates[index].buildText(_selectedDuration.label),
                  style: const TextStyle(height: 1.35),
                ),
              ),
            ),
          ),
          if (index != _templates.length - 1)
            const SizedBox(height: LetterSpacing.xs),
        ],
        if (_hasDraft || _selectedTemplate != null) ...[
          const SizedBox(height: LetterSpacing.lg),
          const LetterEyebrow('Edit'),
          const SizedBox(height: LetterSpacing.xs),
          TextField(
            key: const Key('need-space-boundary-field'),
            controller: widget.controller,
            onChanged: _onTextChanged,
            minLines: 3,
            maxLines: 5,
            maxLength: 280,
            autocorrect: false,
            enableSuggestions: false,
            smartDashesType: SmartDashesType.disabled,
            smartQuotesType: SmartQuotesType.disabled,
            contextMenuBuilder: (context, editableTextState) =>
                const SizedBox.shrink(),
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Boundary text',
              alignLabelWithHint: true,
              errorText: _showValidation ? _validationMessage : null,
              helperText: 'This text stays only in the current Care session.',
              filled: true,
              fillColor: LetterColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(LetterRadius.control),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(LetterRadius.control),
                borderSide: const BorderSide(color: LetterColors.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(LetterRadius.control),
                borderSide: const BorderSide(
                  color: LetterColors.teal,
                  width: 2,
                ),
              ),
            ),
          ),
          const SizedBox(height: LetterSpacing.sm),
          Semantics(
            key: const Key('need-space-clipboard-disclosure'),
            label:
                'Clipboard disclosure. Copying puts this text on your device '
                'clipboard. It may remain there after you leave Letter.',
            child: const ExcludeSemantics(
              child: Text(
                _clipboardDisclosure,
                style: TextStyle(
                  color: LetterColors.muted,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
          ),
          const SizedBox(height: LetterSpacing.sm),
          FilledButton.icon(
            key: const Key('need-space-copy'),
            onPressed: _copyText,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: LetterColors.teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(LetterRadius.control),
              ),
            ),
            icon: const Icon(Icons.copy_outlined),
            label: const Text('Copy text'),
          ),
          if (_copied) ...[
            const SizedBox(height: LetterSpacing.sm),
            Semantics(
              key: const Key('need-space-copy-acknowledgement'),
              liveRegion: true,
              label: _copyAcknowledgement,
              child: const ExcludeSemantics(
                child: Text(
                  _copyAcknowledgement,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: LetterColors.tealDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
          if (_copyError case final error?) ...[
            const SizedBox(height: LetterSpacing.sm),
            Semantics(
              key: const Key('need-space-copy-error'),
              liveRegion: true,
              label: error,
              child: ExcludeSemantics(
                child: Text(
                  error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF9B3F3A),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: LetterSpacing.sm),
          OutlinedButton(
            key: const Key('need-space-continue'),
            onPressed: _continue,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: LetterColors.ink,
              backgroundColor: LetterColors.surface,
              side: const BorderSide(color: LetterColors.line),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(LetterRadius.control),
              ),
            ),
            child: Text(_copied ? 'Continue' : 'Continue without copying'),
          ),
        ],
        const SizedBox(height: LetterSpacing.sm),
        TextButton(
          key: const Key('need-space-discard'),
          onPressed: _discard,
          style: TextButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            foregroundColor: LetterColors.muted,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(LetterRadius.control),
            ),
          ),
          child: const Text('Discard'),
        ),
      ],
    );
  }
}

class _BoundaryDuration {
  const _BoundaryDuration({required this.keyName, required this.label});

  final String keyName;
  final String label;
}

class _BoundaryTemplate {
  const _BoundaryTemplate({
    required this.buildText,
    required this.semanticsLabel,
  });

  final String Function(String duration) buildText;
  final String semanticsLabel;
}
