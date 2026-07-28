import 'package:flutter/material.dart';

import '../../../design_system/letter_theme.dart';

const clearerDayTextLimit = 280;

enum ClearerDayNeed {
  boundaries('Boundaries'),
  connection('Connection'),
  autonomy('Autonomy'),
  restOrPhysicalCapacity('Rest or physical capacity'),
  somethingElse('Something else'),
  notSure('Not sure');

  const ClearerDayNeed(this.label);

  final String label;
}

final class ClearerDayCareRecordContext {
  const ClearerDayCareRecordContext({
    required this.recordId,
    required this.modeLabel,
    required this.actionLabel,
    required this.outcomeLabel,
    required this.occurredLabel,
  });

  final String recordId;
  final String modeLabel;
  final String actionLabel;
  final String outcomeLabel;
  final String occurredLabel;
}

final class ClearerDayReflectionDraft {
  const ClearerDayReflectionDraft({
    this.stillFeelsTrue,
    this.need,
    this.whatHelped,
    this.futureSelfNote,
  });

  final String? stillFeelsTrue;
  final ClearerDayNeed? need;
  final String? whatHelped;
  final String? futureSelfNote;
}

final class ClearerDayReflectionViewModel {
  const ClearerDayReflectionViewModel({
    required this.reflectionId,
    this.stillFeelsTrue,
    this.need,
    this.whatHelped,
    this.futureSelfNote,
  });

  final String reflectionId;
  final String? stillFeelsTrue;
  final ClearerDayNeed? need;
  final String? whatHelped;
  final String? futureSelfNote;
}

typedef SaveClearerDayReflection =
    Future<void> Function(ClearerDayReflectionDraft draft);

class ClearerDayReflectionFlow extends StatefulWidget {
  const ClearerDayReflectionFlow({
    required this.careRecord,
    required this.onSave,
    required this.onDiscard,
    required this.onDone,
    super.key,
    this.existingReflection,
    this.onDelete,
  });

  final ClearerDayCareRecordContext careRecord;
  final ClearerDayReflectionViewModel? existingReflection;
  final SaveClearerDayReflection onSave;
  final VoidCallback onDiscard;
  final VoidCallback onDone;
  final Future<void> Function()? onDelete;

  @override
  State<ClearerDayReflectionFlow> createState() =>
      _ClearerDayReflectionFlowState();
}

enum _ReflectionStage { questionOne, questionTwo, questionThree, review, saved }

class _ClearerDayReflectionFlowState extends State<ClearerDayReflectionFlow> {
  late final TextEditingController _truthController;
  late final TextEditingController _helpedController;
  late final TextEditingController _noteController;
  late ClearerDayNeed? _need;
  late _ReflectionStage _stage;
  bool _busy = false;
  bool _deleted = false;
  String? _error;

  bool get _editing => widget.existingReflection != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingReflection;
    _truthController = TextEditingController(text: existing?.stillFeelsTrue);
    _helpedController = TextEditingController(text: existing?.whatHelped);
    _noteController = TextEditingController(text: existing?.futureSelfNote);
    _need = existing?.need;
    _stage = existing == null
        ? _ReflectionStage.questionOne
        : _ReflectionStage.review;
  }

  @override
  void dispose() {
    _clearDraft();
    _truthController.dispose();
    _helpedController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _clearDraft() {
    _truthController.clear();
    _helpedController.clear();
    _noteController.clear();
    _need = null;
  }

  String? _optionalText(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  ClearerDayReflectionDraft _draft() {
    return ClearerDayReflectionDraft(
      stillFeelsTrue: _optionalText(_truthController),
      need: _need,
      whatHelped: _optionalText(_helpedController),
      futureSelfNote: _optionalText(_noteController),
    );
  }

  void _discard() {
    if (_busy) {
      return;
    }
    _clearDraft();
    widget.onDiscard();
  }

  void _goBack() {
    setState(() {
      _error = null;
      _stage = switch (_stage) {
        _ReflectionStage.questionOne => _ReflectionStage.questionOne,
        _ReflectionStage.questionTwo => _ReflectionStage.questionOne,
        _ReflectionStage.questionThree => _ReflectionStage.questionTwo,
        _ReflectionStage.review => _ReflectionStage.questionThree,
        _ReflectionStage.saved => _ReflectionStage.saved,
      };
    });
  }

  void _next() {
    setState(() {
      _error = null;
      _stage = switch (_stage) {
        _ReflectionStage.questionOne => _ReflectionStage.questionTwo,
        _ReflectionStage.questionTwo => _ReflectionStage.questionThree,
        _ReflectionStage.questionThree => _ReflectionStage.review,
        _ReflectionStage.review => _ReflectionStage.review,
        _ReflectionStage.saved => _ReflectionStage.saved,
      };
    });
  }

  Future<void> _save() async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSave(_draft());
      if (!mounted) {
        return;
      }
      _clearDraft();
      setState(() {
        _busy = false;
        _stage = _ReflectionStage.saved;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _error = 'Letter could not save this reflection. Try again.';
      });
    }
  }

  Future<void> _confirmDelete() async {
    final onDelete = widget.onDelete;
    if (onDelete == null || _busy) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this reflection?'),
        content: const Text(
          'This permanently deletes the reflection and future-self note.',
        ),
        actions: [
          TextButton(
            key: const Key('clearer-day-cancel-delete'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('clearer-day-confirm-delete'),
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: LetterColors.ink),
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await onDelete();
      if (!mounted) {
        return;
      }
      _clearDraft();
      setState(() {
        _busy = false;
        _deleted = true;
        _stage = _ReflectionStage.saved;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _error = 'Letter could not delete this reflection. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F3EE),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                _Header(
                  canGoBack:
                      _stage != _ReflectionStage.questionOne &&
                      _stage != _ReflectionStage.saved,
                  complete: _stage == _ReflectionStage.saved,
                  busy: _busy,
                  onBack: _goBack,
                  onDiscard: _discard,
                  onDone: widget.onDone,
                ),
                Expanded(
                  child: CustomScrollView(
                    key: const Key('clearer-day-scroll'),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _CareRecordCard(context: widget.careRecord),
                              const SizedBox(height: LetterSpacing.xl),
                              _buildStage(),
                            ],
                          ),
                        ),
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

  Widget _buildStage() {
    return switch (_stage) {
      _ReflectionStage.questionOne => _TextQuestion(
        number: 1,
        question: 'Does any part of this still feel true?',
        hint: 'Only what you want to put into words.',
        fieldKey: const Key('clearer-day-truth-field'),
        controller: _truthController,
        onContinue: _next,
      ),
      _ReflectionStage.questionTwo => _NeedQuestion(
        selected: _need,
        onSelected: (need) => setState(() => _need = need),
        onContinue: _next,
      ),
      _ReflectionStage.questionThree => _FinalQuestion(
        helpedController: _helpedController,
        noteController: _noteController,
        onReview: _next,
      ),
      _ReflectionStage.review => _Review(
        draft: _draft(),
        editing: _editing,
        busy: _busy,
        error: _error,
        canDelete: _editing && widget.onDelete != null,
        onEdit: () => setState(() {
          _error = null;
          _stage = _ReflectionStage.questionOne;
        }),
        onSave: _save,
        onDelete: _confirmDelete,
      ),
      _ReflectionStage.saved => _Completion(
        deleted: _deleted,
        onDone: widget.onDone,
      ),
    };
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.canGoBack,
    required this.complete,
    required this.busy,
    required this.onBack,
    required this.onDiscard,
    required this.onDone,
  });

  final bool canGoBack;
  final bool complete;
  final bool busy;
  final VoidCallback onBack;
  final VoidCallback onDiscard;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.45;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
      child: SizedBox(
        height: largeText ? 88 : 54,
        child: Row(
          key: const Key('clearer-day-header'),
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: canGoBack
                  ? IconButton(
                      key: const Key('clearer-day-back'),
                      tooltip: 'Previous question',
                      onPressed: busy ? null : onBack,
                      icon: const Icon(Icons.arrow_back),
                    )
                  : null,
            ),
            const Expanded(
              child: Text(
                'A clearer-day reply',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: LetterColors.muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              key: Key(
                complete ? 'clearer-day-header-done' : 'clearer-day-discard',
              ),
              onPressed: busy ? null : (complete ? onDone : onDiscard),
              style: TextButton.styleFrom(
                minimumSize: const Size(64, 48),
                foregroundColor: LetterColors.ink,
              ),
              child: Text(complete ? 'Done' : 'Discard'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CareRecordCard extends StatelessWidget {
  const _CareRecordCard({required this.context});

  final ClearerDayCareRecordContext context;

  @override
  Widget build(BuildContext buildContext) {
    return Semantics(
      container: true,
      label: 'Care record from ${context.occurredLabel}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: LetterColors.surface,
          border: Border.all(color: LetterColors.line),
          borderRadius: BorderRadius.circular(LetterRadius.panel),
        ),
        child: Padding(
          padding: const EdgeInsets.all(LetterSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LetterEyebrow(context.occurredLabel, color: LetterColors.teal),
              const SizedBox(height: LetterSpacing.xs),
              Text(
                context.modeLabel,
                style: const TextStyle(
                  fontFamily: 'Newsreader',
                  fontSize: 22,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: LetterSpacing.sm),
              Text(
                '${context.actionLabel}  ·  ${context.outcomeLabel}',
                style: const TextStyle(
                  color: LetterColors.muted,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TextQuestion extends StatelessWidget {
  const _TextQuestion({
    required this.number,
    required this.question,
    required this.hint,
    required this.fieldKey,
    required this.controller,
    required this.onContinue,
  });

  final int number;
  final String question;
  final String hint;
  final Key fieldKey;
  final TextEditingController controller;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LetterEyebrow('Optional · $number of 3'),
        const SizedBox(height: LetterSpacing.xs),
        _QuestionTitle(question),
        const SizedBox(height: LetterSpacing.md),
        _PrivateTextField(key: fieldKey, controller: controller, hint: hint),
        const SizedBox(height: LetterSpacing.lg),
        _ContinueButton(
          key: Key('clearer-day-question-$number-continue'),
          onPressed: onContinue,
          label: 'Continue',
        ),
      ],
    );
  }
}

class _NeedQuestion extends StatelessWidget {
  const _NeedQuestion({
    required this.selected,
    required this.onSelected,
    required this.onContinue,
  });

  final ClearerDayNeed? selected;
  final ValueChanged<ClearerDayNeed?> onSelected;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const LetterEyebrow('Optional · 2 of 3'),
        const SizedBox(height: LetterSpacing.xs),
        const _QuestionTitle('What did you need, if you know?'),
        const SizedBox(height: LetterSpacing.md),
        ...ClearerDayNeed.values.map(
          (need) => Padding(
            padding: const EdgeInsets.only(bottom: LetterSpacing.xs),
            child: Semantics(
              selected: selected == need,
              button: true,
              child: OutlinedButton(
                key: Key('clearer-day-need-${need.name}'),
                onPressed: () => onSelected(selected == need ? null : need),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  alignment: Alignment.centerLeft,
                  foregroundColor: LetterColors.ink,
                  backgroundColor: selected == need
                      ? LetterColors.tealSoft
                      : LetterColors.surface,
                  side: BorderSide(
                    color: selected == need
                        ? LetterColors.teal
                        : LetterColors.line,
                    width: selected == need ? 2 : 1,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(LetterRadius.control),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(need.label)),
                    if (selected == need)
                      const Icon(
                        Icons.check,
                        size: 20,
                        color: LetterColors.teal,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: LetterSpacing.sm),
        _ContinueButton(
          key: const Key('clearer-day-question-2-continue'),
          onPressed: onContinue,
          label: 'Continue',
        ),
      ],
    );
  }
}

class _FinalQuestion extends StatelessWidget {
  const _FinalQuestion({
    required this.helpedController,
    required this.noteController,
    required this.onReview,
  });

  final TextEditingController helpedController;
  final TextEditingController noteController;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const LetterEyebrow('Optional · 3 of 3'),
        const SizedBox(height: LetterSpacing.xs),
        const _QuestionTitle('What helped, even a little?'),
        const SizedBox(height: LetterSpacing.md),
        _PrivateTextField(
          key: const Key('clearer-day-helped-field'),
          controller: helpedController,
          hint: 'Something you tried, or something that changed.',
        ),
        const SizedBox(height: LetterSpacing.xl),
        const Divider(),
        const SizedBox(height: LetterSpacing.lg),
        const LetterEyebrow('Next time · optional'),
        const SizedBox(height: LetterSpacing.xs),
        const Text(
          'A note in your own words',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: LetterSpacing.xs),
        const Text(
          'Letter will not interpret or rewrite this note.',
          style: TextStyle(color: LetterColors.muted, height: 1.4),
        ),
        const SizedBox(height: LetterSpacing.sm),
        _PrivateTextField(
          key: const Key('clearer-day-note-field'),
          controller: noteController,
          hint: 'A short note for a similar future moment.',
        ),
        const SizedBox(height: LetterSpacing.lg),
        _ContinueButton(
          key: const Key('clearer-day-review-draft'),
          onPressed: onReview,
          label: 'Review my reply',
          icon: Icons.rate_review_outlined,
        ),
      ],
    );
  }
}

class _Review extends StatelessWidget {
  const _Review({
    required this.draft,
    required this.editing,
    required this.busy,
    required this.error,
    required this.canDelete,
    required this.onEdit,
    required this.onSave,
    required this.onDelete,
  });

  final ClearerDayReflectionDraft draft;
  final bool editing;
  final bool busy;
  final String? error;
  final bool canDelete;
  final VoidCallback onEdit;
  final VoidCallback onSave;
  final VoidCallback onDelete;

  String _value(String? value) => value ?? 'Not added';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const LetterEyebrow('Review before saving'),
        const SizedBox(height: LetterSpacing.xs),
        Text(
          editing ? 'Review your changes.' : 'This reply stays in your words.',
          style: const TextStyle(
            fontFamily: 'Newsreader',
            fontSize: 28,
            height: 1.08,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: LetterSpacing.md),
        _ReviewSection(
          label: 'What happened',
          value: _value(draft.stillFeelsTrue),
        ),
        _ReviewSection(
          label: 'What I needed',
          value: draft.need?.label ?? 'Not added',
        ),
        _ReviewSection(label: 'What helped', value: _value(draft.whatHelped)),
        _ReviewSection(label: 'Next time', value: _value(draft.futureSelfNote)),
        const SizedBox(height: LetterSpacing.md),
        OutlinedButton.icon(
          key: const Key('clearer-day-edit'),
          onPressed: busy ? null : onEdit,
          style: _secondaryButtonStyle(),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Edit'),
        ),
        const SizedBox(height: LetterSpacing.sm),
        FilledButton.icon(
          key: const Key('clearer-day-save'),
          onPressed: busy ? null : onSave,
          style: _primaryButtonStyle(),
          icon: busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.lock_outline),
          label: Text(editing ? 'Save changes' : 'Save my reply'),
        ),
        if (error != null) ...[
          const SizedBox(height: LetterSpacing.sm),
          Semantics(
            liveRegion: true,
            child: Text(
              error!,
              key: const Key('clearer-day-error'),
              style: const TextStyle(
                color: Color(0xFF9F312C),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
        if (canDelete) ...[
          const SizedBox(height: LetterSpacing.lg),
          TextButton.icon(
            key: const Key('clearer-day-delete'),
            onPressed: busy ? null : onDelete,
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: const Color(0xFF8A2F2B),
            ),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete reflection'),
          ),
        ],
      ],
    );
  }
}

class _ReviewSection extends StatelessWidget {
  const _ReviewSection({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: LetterSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LetterEyebrow(label, color: LetterColors.teal),
          const SizedBox(height: LetterSpacing.xs),
          Text(
            value,
            style: TextStyle(
              color: value == 'Not added'
                  ? LetterColors.muted
                  : LetterColors.ink,
              fontSize: 16,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _Completion extends StatelessWidget {
  const _Completion({required this.deleted, required this.onDone});

  final bool deleted;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Column(
        key: const Key('clearer-day-completion'),
        children: [
          Icon(
            deleted ? Icons.delete_outline : Icons.mark_email_read_outlined,
            size: 68,
            color: LetterColors.teal,
          ),
          const SizedBox(height: LetterSpacing.lg),
          Text(
            deleted ? 'Reflection deleted.' : 'Your reply is saved.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Newsreader',
              fontSize: 28,
              height: 1.1,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: LetterSpacing.sm),
          Text(
            deleted
                ? 'The reflection and future-self note are no longer here.'
                : 'Letter saved only what you reviewed and confirmed.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: LetterColors.muted, height: 1.45),
          ),
          const SizedBox(height: LetterSpacing.xl),
          FilledButton.icon(
            key: const Key('clearer-day-completion-done'),
            onPressed: onDone,
            style: _primaryButtonStyle(),
            icon: const Icon(Icons.check),
            label: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

class _QuestionTitle extends StatelessWidget {
  const _QuestionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Newsreader',
        fontSize: 28,
        height: 1.08,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _PrivateTextField extends StatelessWidget {
  const _PrivateTextField({
    required super.key,
    required this.controller,
    required this.hint,
  });

  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: 3,
      maxLines: 6,
      maxLength: clearerDayTextLimit,
      autocorrect: false,
      enableSuggestions: false,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: LetterColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LetterRadius.panel),
          borderSide: const BorderSide(color: LetterColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LetterRadius.panel),
          borderSide: const BorderSide(color: LetterColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LetterRadius.panel),
          borderSide: const BorderSide(color: LetterColors.teal, width: 2),
        ),
      ),
    );
  }
}

class _ContinueButton extends StatelessWidget {
  const _ContinueButton({
    required super.key,
    required this.onPressed,
    required this.label,
    this.icon = Icons.arrow_forward,
  });

  final VoidCallback onPressed;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      style: _primaryButtonStyle(),
      iconAlignment: IconAlignment.end,
      icon: Icon(icon),
      label: Text(label),
    );
  }
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
    foregroundColor: LetterColors.ink,
    backgroundColor: LetterColors.surface,
    side: const BorderSide(color: LetterColors.line),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(LetterRadius.control),
    ),
  );
}
