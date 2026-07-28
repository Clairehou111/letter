import 'package:flutter/material.dart';

import '../../../design_system/letter_theme.dart';
import '../../care/domain/care_memory.dart';
import '../../cycle/domain/local_date.dart';
import '../../health_records/domain/health_record.dart';
import '../application/recovery_receipt_controller.dart';
import '../domain/recovery_receipt.dart';

class RecoveryReceiptEntryScreen extends StatefulWidget {
  const RecoveryReceiptEntryScreen({
    required this.careRecordId,
    required this.controller,
    super.key,
    this.onComplete,
    this.onSkipped,
  });

  final String careRecordId;
  final RecoveryReceiptController controller;
  final ValueChanged<RecoveryReceiptResult>? onComplete;
  final VoidCallback? onSkipped;

  @override
  State<RecoveryReceiptEntryScreen> createState() =>
      _RecoveryReceiptEntryScreenState();
}

class _RecoveryReceiptEntryScreenState
    extends State<RecoveryReceiptEntryScreen> {
  CareRecord? _record;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final record = await widget.controller.requirePersistedCareRecord(
        widget.careRecordId,
      );
      if (!mounted) {
        return;
      }
      setState(() => _record = record);
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final record = _record;
    if (record != null) {
      return RecoveryReceiptFlow(
        careRecord: record,
        controller: widget.controller,
        onComplete: widget.onComplete,
        onSkipped: widget.onSkipped,
      );
    }
    return Scaffold(
      key: const Key('recovery-receipt-entry'),
      appBar: AppBar(title: const Text('Recovery receipt')),
      body: SafeArea(
        child: Center(
          child: _error == null
              ? const CircularProgressIndicator(color: LetterColors.teal)
              : Padding(
                  padding: const EdgeInsets.all(LetterSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.lock_outline,
                        color: LetterColors.teal,
                        size: 38,
                      ),
                      const SizedBox(height: LetterSpacing.md),
                      Text(
                        _error is RecoveryReceiptException
                            ? (_error! as RecoveryReceiptException).userMessage
                            : 'This Care moment could not be opened.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: LetterColors.muted),
                      ),
                      const SizedBox(height: LetterSpacing.lg),
                      FilledButton.icon(
                        key: const Key('recovery-receipt-retry'),
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class RecoveryReceiptFlow extends StatefulWidget {
  const RecoveryReceiptFlow({
    required this.careRecord,
    required this.controller,
    super.key,
    this.onComplete,
    this.onSkipped,
  });

  final CareRecord careRecord;
  final RecoveryReceiptController controller;
  final ValueChanged<RecoveryReceiptResult>? onComplete;
  final VoidCallback? onSkipped;

  @override
  State<RecoveryReceiptFlow> createState() => _RecoveryReceiptFlowState();
}

enum _ReceiptStage { signal, severity, impact, physical, review }

class _RecoveryReceiptFlowState extends State<RecoveryReceiptFlow> {
  _ReceiptStage _stage = _ReceiptStage.signal;
  SymptomType? _symptom;
  SymptomSeverity? _severity;
  final Set<FunctionalImpact> _functionalImpacts = {};
  final Set<SymptomType> _physicalSignals = {};
  bool _showAllSignals = false;
  bool _nothingToRecord = false;
  bool _saving = false;
  String? _error;

  SymptomType? get _suggestedSymptom =>
      suggestedSymptomForCare(widget.careRecord);

  void _skip() {
    if (_saving) {
      return;
    }
    widget.onSkipped?.call();
  }

  void _back() {
    if (_saving) {
      return;
    }
    setState(() {
      _error = null;
      _stage = switch (_stage) {
        _ReceiptStage.signal => _ReceiptStage.signal,
        _ReceiptStage.severity => _ReceiptStage.signal,
        _ReceiptStage.impact => _ReceiptStage.severity,
        _ReceiptStage.physical => _ReceiptStage.impact,
        _ReceiptStage.review => _ReceiptStage.physical,
      };
    });
  }

  void _next() {
    if (_saving) {
      return;
    }
    setState(() {
      _error = null;
      _stage = switch (_stage) {
        _ReceiptStage.signal => _ReceiptStage.severity,
        _ReceiptStage.severity => _ReceiptStage.impact,
        _ReceiptStage.impact => _ReceiptStage.physical,
        _ReceiptStage.physical => _ReceiptStage.review,
        _ReceiptStage.review => _ReceiptStage.review,
      };
    });
  }

  void _selectSignal(SymptomType symptom) {
    setState(() {
      _symptom = symptom;
      _showAllSignals = false;
      _error = null;
    });
  }

  Future<void> _save() async {
    final symptom = _symptom;
    final severity = _severity;
    if (symptom == null) {
      setState(() {
        _stage = _ReceiptStage.signal;
        _error = 'Choose a signal before confirming.';
      });
      return;
    }
    if (severity == null) {
      setState(() {
        _stage = _ReceiptStage.severity;
        _error = 'Choose the intensity that feels true to you.';
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await widget.controller.save(
        RecoveryReceiptDraft(
          careRecordId: widget.careRecord.id,
          symptom: symptom,
          severity: severity,
          functionalImpacts: _nothingToRecord ? const {} : _functionalImpacts,
          additionalPhysicalSignals: _physicalSignals,
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      widget.onComplete?.call(result);
    } on RecoveryReceiptException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _error = error.userMessage;
      });
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _error = 'Letter could not save this private receipt. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('recovery-receipt-flow'),
      backgroundColor: LetterColors.canvas,
      appBar: AppBar(
        backgroundColor: LetterColors.canvas,
        leading: _stage == _ReceiptStage.signal
            ? null
            : IconButton(
                key: const Key('recovery-receipt-back'),
                tooltip: 'Back',
                onPressed: _back,
                icon: const Icon(Icons.arrow_back),
              ),
        title: const Text('Recovery receipt'),
        actions: [
          TextButton(
            key: Key(
              _stage == _ReceiptStage.signal
                  ? 'recovery-signal-not-remember'
                  : 'recovery-skip-${_stage.name}',
            ),
            onPressed: _skip,
            child: Text(
              _stage == _ReceiptStage.signal ? 'I do not remember' : 'Skip',
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              key: const Key('recovery-receipt-scroll'),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                const LetterEyebrow(
                  'A quiet check-back',
                  color: LetterColors.teal,
                ),
                const SizedBox(height: LetterSpacing.xs),
                Text(
                  _stageTitle,
                  key: const Key('recovery-receipt-question'),
                  style: const TextStyle(
                    fontFamily: 'Newsreader',
                    fontSize: 29,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: LetterSpacing.xs),
                Text(
                  _stageSubtitle,
                  style: const TextStyle(
                    color: LetterColors.muted,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: LetterSpacing.lg),
                _stageBody,
                if (_error != null) ...[
                  const SizedBox(height: LetterSpacing.md),
                  Text(
                    _error!,
                    key: const Key('recovery-receipt-error'),
                    style: const TextStyle(color: Color(0xFF9D3D35)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_stage != _ReceiptStage.review)
              FilledButton.icon(
                key: const Key('recovery-receipt-next'),
                onPressed: _stage == _ReceiptStage.signal && _symptom == null
                    ? null
                    : _next,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Continue'),
                style: _buttonStyle(LetterColors.teal),
              )
            else
              FilledButton.icon(
                key: const Key('recovery-receipt-confirm'),
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: const Text('Confirm and keep this record'),
                style: _buttonStyle(LetterColors.teal),
              ),
            const SizedBox(height: LetterSpacing.xs),
            TextButton(
              key: Key('recovery-skip-body-${_stage.name}'),
              onPressed: _stage == _ReceiptStage.physical ? _next : _skip,
              child: Text(
                _stage == _ReceiptStage.physical
                    ? 'Skip physical signals'
                    : 'Skip for now',
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _stageTitle => switch (_stage) {
    _ReceiptStage.signal => 'What was strongest?',
    _ReceiptStage.severity => 'How intense was it?',
    _ReceiptStage.impact => 'What did it interfere with?',
    _ReceiptStage.physical => 'Any physical signals too?',
    _ReceiptStage.review => 'Read it back to yourself.',
  };

  String get _stageSubtitle => switch (_stage) {
    _ReceiptStage.signal =>
      'Choose only what feels true. The Care moment is a suggestion, not a diagnosis.',
    _ReceiptStage.severity =>
      'Use the words and number together. Nothing is guessed from how you used Care.',
    _ReceiptStage.impact =>
      'This is your report of what was affected, not an inferred impairment score.',
    _ReceiptStage.physical =>
      'Optional. These will be kept at the same intensity you confirm above.',
    _ReceiptStage.review =>
      'Only after you confirm will Letter place these values in your private health record.',
  };

  Widget get _stageBody => switch (_stage) {
    _ReceiptStage.signal => _signalBody(),
    _ReceiptStage.severity => _severityBody(),
    _ReceiptStage.impact => _impactBody(),
    _ReceiptStage.physical => _physicalBody(),
    _ReceiptStage.review => _reviewBody(),
  };

  Widget _signalBody() {
    final suggestion = _suggestedSymptom;
    final signals = _showAllSignals
        ? SymptomType.values
        : RecoveryReceiptSignal.values
              .where((signal) => signal.symptom != null)
              .map((signal) => signal.symptom!)
              .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (suggestion != null) ...[
          Container(
            key: const Key('recovery-suggestion'),
            padding: const EdgeInsets.all(LetterSpacing.sm),
            decoration: BoxDecoration(
              color: LetterColors.tealSoft,
              borderRadius: BorderRadius.circular(LetterRadius.panel),
            ),
            child: Text(
              'Care suggested ${suggestion.label.toLowerCase()}. It is not selected.',
              style: const TextStyle(color: LetterColors.tealDark),
            ),
          ),
          const SizedBox(height: LetterSpacing.md),
        ],
        Wrap(
          spacing: LetterSpacing.xs,
          runSpacing: LetterSpacing.xs,
          children: [
            ...signals.map(
              (symptom) => _symptomChip(symptom, selected: _symptom == symptom),
            ),
            if (!_showAllSignals)
              FilterChip(
                key: const Key('recovery-signal-something-else'),
                selected: false,
                showCheckmark: false,
                onSelected: (_) => setState(() {
                  _showAllSignals = true;
                  _symptom = null;
                }),
                label: const Text('Something else'),
                avatar: const Icon(Icons.more_horiz, size: 16),
              ),
          ],
        ),
        if (_showAllSignals) ...[
          const SizedBox(height: LetterSpacing.sm),
          const Text(
            'Choose one structured signal so the record stays clear.',
            style: TextStyle(color: LetterColors.muted),
          ),
        ],
      ],
    );
  }

  Widget _symptomChip(SymptomType symptom, {required bool selected}) {
    return FilterChip(
      key: Key('recovery-signal-${symptom.name}'),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => _selectSignal(symptom),
      avatar: Icon(
        selected ? Icons.check : Icons.add,
        size: 16,
        color: selected ? Colors.white : LetterColors.teal,
      ),
      label: Text(symptom.label),
      selectedColor: LetterColors.teal,
      backgroundColor: LetterColors.tealSoft,
      labelStyle: TextStyle(
        color: selected ? Colors.white : LetterColors.ink,
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LetterRadius.control),
      ),
    );
  }

  Widget _severityBody() {
    return Wrap(
      spacing: LetterSpacing.xs,
      runSpacing: LetterSpacing.xs,
      children: SymptomSeverity.values
          .map(
            (severity) => ChoiceChip(
              key: Key('recovery-severity-${severity.name}'),
              selected: _severity == severity,
              onSelected: (_) => setState(() => _severity = severity),
              label: Text('${severity.score} · ${severity.label}'),
              showCheckmark: false,
              selectedColor: LetterColors.violet,
              backgroundColor: LetterColors.violetSoft,
              labelStyle: TextStyle(
                color: _severity == severity ? Colors.white : LetterColors.ink,
                fontWeight: FontWeight.w700,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(LetterRadius.control),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _impactBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: LetterSpacing.xs,
          runSpacing: LetterSpacing.xs,
          children: FunctionalImpact.values
              .map(
                (impact) => FilterChip(
                  key: Key('recovery-impact-${impact.name}'),
                  selected:
                      !_nothingToRecord && _functionalImpacts.contains(impact),
                  onSelected: (_) => setState(() {
                    _nothingToRecord = false;
                    if (_functionalImpacts.contains(impact)) {
                      _functionalImpacts.remove(impact);
                    } else {
                      _functionalImpacts.add(impact);
                    }
                  }),
                  label: Text(impact.label),
                  showCheckmark: false,
                ),
              )
              .toList(),
        ),
        const SizedBox(height: LetterSpacing.sm),
        CheckboxListTile(
          key: const Key('recovery-impact-nothing'),
          value: _nothingToRecord,
          onChanged: (value) => setState(() {
            _nothingToRecord = value ?? false;
            if (_nothingToRecord) {
              _functionalImpacts.clear();
            }
          }),
          contentPadding: EdgeInsets.zero,
          title: const Text('Nothing I want to record'),
          controlAffinity: ListTileControlAffinity.leading,
        ),
      ],
    );
  }

  Widget _physicalBody() {
    final options = SymptomType.values.where(
      (symptom) =>
          symptom.category == SymptomCategory.physical && symptom != _symptom,
    );
    return Wrap(
      spacing: LetterSpacing.xs,
      runSpacing: LetterSpacing.xs,
      children: options
          .map(
            (symptom) => FilterChip(
              key: Key('recovery-physical-${symptom.name}'),
              selected: _physicalSignals.contains(symptom),
              onSelected: (_) => setState(() {
                if (_physicalSignals.contains(symptom)) {
                  _physicalSignals.remove(symptom);
                } else {
                  _physicalSignals.add(symptom);
                }
              }),
              label: Text(symptom.label),
              showCheckmark: false,
            ),
          )
          .toList(),
    );
  }

  Widget _reviewBody() {
    final severity = _severity;
    final primary = _symptom;
    final provenance = recoveryReceiptProvenance(
      experiencedDate: LocalDate.fromDateTime(
        widget.careRecord.occurredAt.toLocal(),
      ),
      recordedAt: widget.controller.nowForReceipt,
    );
    return Container(
      padding: const EdgeInsets.all(LetterSpacing.md),
      decoration: BoxDecoration(
        color: LetterColors.surface,
        border: Border.all(color: LetterColors.line),
        borderRadius: BorderRadius.circular(LetterRadius.panel),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            primary?.label ?? 'No signal',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: LetterSpacing.xs),
          Text(
            severity == null
                ? 'No intensity selected'
                : '${severity.score} · ${severity.label}',
            key: const Key('recovery-review-severity'),
          ),
          const SizedBox(height: LetterSpacing.xs),
          Text(
            _functionalImpacts.isEmpty
                ? 'No functional impact recorded'
                : 'Impact: ${_functionalImpacts.map((item) => item.label).join(', ')}',
          ),
          if (_physicalSignals.isNotEmpty) ...[
            const SizedBox(height: LetterSpacing.xs),
            Text(
              'Also: ${_physicalSignals.map((item) => item.label).join(', ')}',
            ),
          ],
          const SizedBox(height: LetterSpacing.md),
          Text(
            'This will be marked ${provenance.storageKey}.',
            key: const Key('recovery-review-provenance'),
            style: const TextStyle(color: LetterColors.muted),
          ),
        ],
      ),
    );
  }
}

ButtonStyle _buttonStyle(Color color) {
  return FilledButton.styleFrom(
    backgroundColor: color,
    minimumSize: const Size.fromHeight(48),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(LetterRadius.control),
    ),
  );
}
