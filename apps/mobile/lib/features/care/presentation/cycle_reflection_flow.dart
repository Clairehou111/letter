import 'package:flutter/material.dart';

import '../../../design_system/letter_theme.dart';
import '../domain/care_memory.dart';
import '../domain/care_memory_repository.dart';

typedef SaveCycleReflection = Future<void> Function(CycleReflectionDraft draft);

class CycleReflectionFlow extends StatefulWidget {
  const CycleReflectionFlow({
    required this.cycleLabel,
    required this.onSave,
    required this.onClose,
    super.key,
    this.existingReflection,
    this.onDelete,
  });

  final String cycleLabel;
  final CycleReflection? existingReflection;
  final SaveCycleReflection onSave;
  final VoidCallback onClose;
  final Future<void> Function()? onDelete;

  @override
  State<CycleReflectionFlow> createState() => _CycleReflectionFlowState();
}

class _CycleReflectionFlowState extends State<CycleReflectionFlow> {
  late final TextEditingController _observationController;
  late final TextEditingController _helpedController;
  late final TextEditingController _futureController;
  late ReflectionNeed? _need;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final reflection = widget.existingReflection;
    _observationController = TextEditingController(
      text: reflection?.observation,
    );
    _helpedController = TextEditingController(text: reflection?.whatHelped);
    _futureController = TextEditingController(text: reflection?.futureSelfNote);
    _need = reflection?.need;
  }

  @override
  void dispose() {
    _observationController.dispose();
    _helpedController.dispose();
    _futureController.dispose();
    super.dispose();
  }

  String? _text(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSave(
        CycleReflectionDraft(
          observation: _text(_observationController),
          need: _need,
          whatHelped: _text(_helpedController),
          futureSelfNote: _text(_futureController),
        ),
      );
      if (mounted) widget.onClose();
    } on CareMemoryException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.userMessage;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Letter could not save this cycle reflection. Try again.';
      });
    }
  }

  Future<void> _delete() async {
    final onDelete = widget.onDelete;
    if (onDelete == null || _busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this cycle reflection?'),
        content: const Text(
          'This deletes the cycle reflection. Saved Care events and older '
          'Care notes will stay in the archive.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('cycle-reflection-confirm-delete'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete reflection'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await onDelete();
      if (mounted) widget.onClose();
    } on Object {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Letter could not delete this cycle reflection. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const Key('cycle-reflection-close'),
          tooltip: 'Return to cycle letter',
          onPressed: _busy ? null : widget.onClose,
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(
          widget.existingReflection == null
              ? 'Reflect on this cycle'
              : 'Edit cycle reflection',
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              key: const Key('cycle-reflection-scroll'),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
              children: [
                Container(
                  padding: const EdgeInsets.all(LetterSpacing.md),
                  decoration: const BoxDecoration(
                    color: LetterColors.violetSoft,
                    border: Border(
                      left: BorderSide(color: LetterColors.violet, width: 4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.cycleLabel,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: LetterSpacing.xs),
                      const Text(
                        'One optional reflection for the whole cycle. Add only '
                        'what feels useful; Care events stay factual.',
                        style: TextStyle(height: 1.45),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: LetterSpacing.xl),
                _ReflectionTextField(
                  fieldKey: const Key('cycle-reflection-observation'),
                  label: 'What stood out this cycle?',
                  hint: 'A moment, feeling, or change you want to remember.',
                  controller: _observationController,
                ),
                const SizedBox(height: LetterSpacing.lg),
                const Text(
                  'What did you need, if you know?',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: LetterSpacing.sm),
                Wrap(
                  spacing: LetterSpacing.xs,
                  runSpacing: LetterSpacing.xs,
                  children: [
                    for (final need in ReflectionNeed.values)
                      ChoiceChip(
                        key: Key('cycle-reflection-need-${need.name}'),
                        label: Text(_needLabel(need)),
                        selected: _need == need,
                        onSelected: _busy
                            ? null
                            : (selected) => setState(
                                () => _need = selected ? need : null,
                              ),
                      ),
                  ],
                ),
                const SizedBox(height: LetterSpacing.lg),
                _ReflectionTextField(
                  fieldKey: const Key('cycle-reflection-helped'),
                  label: 'What helped across the cycle?',
                  hint: 'Care, support, space, or something else.',
                  controller: _helpedController,
                ),
                const SizedBox(height: LetterSpacing.lg),
                _ReflectionTextField(
                  fieldKey: const Key('cycle-reflection-future'),
                  label: 'What do you want to remember next time?',
                  hint: 'A note for your future self.',
                  controller: _futureController,
                ),
                if (_error case final error?) ...[
                  const SizedBox(height: LetterSpacing.md),
                  Text(
                    error,
                    key: const Key('cycle-reflection-error'),
                    style: const TextStyle(color: LetterColors.safetyRed),
                  ),
                ],
                const SizedBox(height: LetterSpacing.xl),
                FilledButton.icon(
                  key: const Key('cycle-reflection-save'),
                  onPressed: _busy ? null : _save,
                  icon: _busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(
                    widget.existingReflection == null
                        ? 'Save cycle reflection'
                        : 'Save changes',
                  ),
                ),
                if (widget.onDelete != null) ...[
                  const SizedBox(height: LetterSpacing.sm),
                  TextButton(
                    key: const Key('cycle-reflection-delete'),
                    onPressed: _busy ? null : _delete,
                    child: const Text('Delete cycle reflection'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReflectionTextField extends StatelessWidget {
  const _ReflectionTextField({
    required this.fieldKey,
    required this.label,
    required this.hint,
    required this.controller,
  });

  final Key fieldKey;
  final String label;
  final String hint;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: fieldKey,
      controller: controller,
      maxLength: careMemoryTextMaximumCharacters,
      minLines: 2,
      maxLines: 5,
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: true,
        hintText: hint,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

String _needLabel(ReflectionNeed need) => switch (need) {
  ReflectionNeed.boundaries => 'Boundaries',
  ReflectionNeed.connection => 'Connection',
  ReflectionNeed.autonomy => 'Autonomy',
  ReflectionNeed.restOrPhysicalCapacity => 'Rest or physical capacity',
  ReflectionNeed.somethingElse => 'Something else',
  ReflectionNeed.notSure => 'Not sure',
};
