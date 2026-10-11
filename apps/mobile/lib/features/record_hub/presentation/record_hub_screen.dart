import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../experience/care/care_safety_route.dart';
import '../../../experience/components/interaction_controls.dart';
import '../../../experience/components/record_option_scale.dart';
import '../../../experience/theme/experience_foundation.dart';
import '../../../experience/degree/degree_graphics.dart';
import '../../../experience/records/observation_picker.dart';
import '../../capture/domain/capture_models.dart';
import '../../cycle/domain/bleeding_flow.dart';
import '../../cycle/domain/local_date.dart';
import '../../cycle/domain/period_repository.dart';
import '../../health_records/domain/health_record.dart';
import '../../health_records/domain/health_record_repository.dart';
import '../../health_records/domain/health_record_write_policy.dart';
import '../application/record_session_controller.dart';
import '../domain/record_hub_facts.dart';
import '../domain/record_hub_repository.dart';
import '../domain/record_session.dart';
import '../domain/record_interventions.dart';
import 'record_calendar.dart';
import 'record_entry_section.dart';
import 'record_workspace_stage.dart';
import 'record_context_editor.dart';
import 'record_interventions_editor.dart';

enum _NoteSaveState { idle, saving, saved, failed }

final class _SymptomSourceChanged implements Exception {
  const _SymptomSourceChanged();
}

enum _RecordWorkspace {
  symptoms('Symptoms'),
  dailyLife('Daily life'),
  products('Products'),
  notes('Notes');

  const _RecordWorkspace(this.label);
  final String label;
}

/// An independent route. Pushing it preserves the exact origin underneath.
final class RecordHubScreen extends StatefulWidget {
  const RecordHubScreen({
    required this.healthRecordRepository,
    required this.captureNoteStore,
    super.key,
    this.recordHubRepository,
    this.interventionsRepository,
    this.periodRepository,
    this.initialDate,
    this.origin = RecordOrigin.today,
    this.initialSymptom,
    this.initialSection,
    this.clock,
    this.onChanged,
    this.onOpenSafety,
    this.returnAfterSymptomEdit = false,
  });

  final HealthRecordRepository healthRecordRepository;
  final CaptureNoteStore captureNoteStore;
  final RecordHubRepository? recordHubRepository;
  final RecordInterventionsRepository? interventionsRepository;
  final PeriodRepository? periodRepository;
  final LocalDate? initialDate;
  final RecordOrigin origin;
  final SymptomType? initialSymptom;

  /// Direct Today shortcuts may dismiss the intermediary Record route after
  /// closing their focused editor. Normal Record and Pattern keep their place.
  final bool returnAfterSymptomEdit;
  final RecordEntrySection? initialSection;
  final DateTime Function()? clock;
  final VoidCallback? onChanged;
  final VoidCallback? onOpenSafety;

  @override
  State<RecordHubScreen> createState() => _RecordHubScreenState();
}

final class _RecordHubScreenState extends State<RecordHubScreen> {
  late final RecordSessionController _session;
  _RecordWorkspace _workspace = _RecordWorkspace.symptoms;
  _NoteSaveState _noteSaveState = _NoteSaveState.idle;
  final Map<_RecordWorkspace, GlobalKey> _workspaceAnchors = {
    for (final workspace in _RecordWorkspace.values) workspace: GlobalKey(),
  };
  final TextEditingController _note = TextEditingController();
  final GlobalKey _noteAnchor = GlobalKey();
  final FocusNode _noteFocus = FocusNode();
  bool _initialSectionHandled = false;
  final GlobalKey _pickerAnchor = GlobalKey();
  final GlobalKey _bleedingAnchor = GlobalKey();
  String _previousNoteText = '';
  CaptureNote? _editingNote;
  SymptomType? _focusedSymptom;
  int _pickerGeneration = 0;
  List<HealthRecord> _records = [];
  List<CaptureNote> _notes = [];
  List<RecordHubDateFacts> _facts = [];
  List<BleedingDayRecord> _periodFlows = [];
  SymptomPins? _pins;
  bool _loading = true;
  bool _busy = false;
  bool _pickerDraft = false;
  bool _allowPop = false;
  bool _askingDiscard = false;
  String? _error;
  String? _feedback;
  String? _operationGroup;
  String? _feedbackGroup;
  String? _errorGroup;
  int? _pendingImpact;
  BleedingFlow? _pendingFlow;
  bool _pendingHasFlow = false;
  bool _pendingImpactActive = false;
  bool _pendingFlowActive = false;
  bool _impactExpanded = false;
  bool _bleedingExpanded = false;
  Future<void> Function()? _undo;

  LocalDate get _date => _session.session.selectedDate;
  bool get _careWorld => Theme.of(context).brightness == Brightness.dark;
  HealthRecordProvenance get _provenance => _date == _session.today
      ? HealthRecordProvenance.sameDay
      : HealthRecordProvenance.laterRecall;
  List<HealthRecord> get _dayRecords =>
      _records.where((record) => record.experiencedDate == _date).toList();
  List<CaptureNote> get _dayNotes =>
      _notes.where((note) => note.experiencedDate == _date).toList();
  RecordHubDateFacts get _dayFacts => _facts.firstWhere(
    (facts) => facts.date == _date,
    orElse: () => RecordHubDateFacts(date: _date),
  );

  @override
  void initState() {
    super.initState();
    final clock = widget.clock ?? DateTime.now;
    _focusedSymptom = widget.initialSymptom;
    _workspace = switch (widget.initialSection) {
      RecordEntrySection.sleep => _RecordWorkspace.dailyLife,
      RecordEntrySection.note => _RecordWorkspace.notes,
      _ => _RecordWorkspace.symptoms,
    };
    _session = RecordSessionController(
      initialSession: RecordSession(
        selectedDate:
            widget.initialDate ?? LocalDate.fromDateTime(clock().toLocal()),
        returnContext: RecordReturnContext(origin: widget.origin),
      ),
      clock: clock,
    );
    _note.addListener(_draftChanged);
    _load();
  }

  @override
  void dispose() {
    _noteFocus.dispose();
    _note.dispose();
    _session.dispose();
    super.dispose();
  }

  void _draftChanged() {
    final noteChanged = _note.text != _previousNoteText;
    _previousNoteText = _note.text;
    _session.setDraftDirty(_note.text.isNotEmpty || _pickerDraft);
    if (mounted) {
      setState(() {
        if (noteChanged && !_busy) _noteSaveState = _NoteSaveState.idle;
        if (noteChanged && !_busy && _note.text.isNotEmpty) {
          if (_feedbackGroup == 'Private note') {
            _feedback = null;
            _undo = null;
          }
          if (_errorGroup == 'Private note') _error = null;
        }
      });
    }
  }

  Future<void> _load() async {
    try {
      final recordFuture = widget.healthRecordRepository.getAll();
      final noteFuture = widget.captureNoteStore.getAll();
      final factFuture = widget.recordHubRepository?.getAllFacts();
      final pinFuture = widget.recordHubRepository?.getPins();
      final flowFuture = widget.periodRepository?.getAllFlowDays();
      final records = await recordFuture;
      final notes = await noteFuture;
      final facts = await factFuture ?? <RecordHubDateFacts>[];
      final pins = await pinFuture;
      final flows = await flowFuture ?? <BleedingDayRecord>[];
      if (!mounted) return;
      setState(() {
        _records = records;
        _notes = notes;
        _facts = facts;
        _pins = pins;
        _periodFlows = flows;
        _loading = false;
      });
      _scheduleInitialSection();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Your private records could not be opened. Try again.';
      });
    }
  }

  void _scheduleInitialSection() {
    if (_initialSectionHandled || widget.initialSection == null) return;
    _initialSectionHandled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // A delayed repository load must never discard a draft started meanwhile.
      if (!mounted || _busy || _session.hasUnsavedDraft) return;
      switch (widget.initialSection!) {
        case RecordEntrySection.bleeding:
          final entryDate = _date;
          setState(() => _bleedingExpanded = true);
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            // Let the existing 180ms disclosure finish before calculating the
            // scroll extent; the collapsed layout cannot expose its controls.
            if (!ExperienceMotion.reducedMotion(context)) {
              await Future<void>.delayed(const Duration(milliseconds: 180));
              await WidgetsBinding.instance.endOfFrame;
            }
            final anchor = _bleedingAnchor.currentContext;
            if (mounted &&
                _date == entryDate &&
                _workspace == _RecordWorkspace.symptoms &&
                !_busy &&
                !_session.hasUnsavedDraft &&
                anchor != null &&
                anchor.mounted) {
              await Scrollable.ensureVisible(
                anchor,
                alignment: 0,
                duration: ExperienceMotion.reducedMotion(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
              );
            }
          });
        case RecordEntrySection.sleep:
          await _openContext(
            RecordContextType.sleep,
            initialDraft: _dayFacts.sleep?.value,
          );
        case RecordEntrySection.note:
          final anchor = _noteAnchor.currentContext;
          if (anchor == null || !anchor.mounted) return;
          await Scrollable.ensureVisible(
            anchor,
            duration: ExperienceMotion.reducedMotion(context)
                ? Duration.zero
                : const Duration(milliseconds: 200),
          );
          if (mounted && !_busy && !_session.hasUnsavedDraft) {
            _noteFocus.requestFocus();
          }
        case RecordEntrySection.body:
          final anchor = _pickerAnchor.currentContext;
          if (anchor != null && anchor.mounted) {
            await Scrollable.ensureVisible(
              anchor,
              duration: ExperienceMotion.reducedMotion(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
            );
          }
      }
    });
  }

  String _groupFor(String label) => switch (label) {
    'Undo' => _feedbackGroup ?? 'Symptoms',
    'Private note' || 'Private note removal' => 'Private note',
    'Daily impact' => 'Daily impact',
    'Bleeding' || 'Bleeding color' || 'Clot observation' => 'Bleeding',
    _ => 'Symptoms',
  };

  Widget _operationStatus(String group) {
    final pending = _busy && _operationGroup == group;
    final error = _errorGroup == group ? _error : null;
    final feedback = _feedbackGroup == group ? _feedback : null;
    if (!pending && error == null && feedback == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      key: Key('record-status-$group'),
      padding: const EdgeInsets.only(top: 8),
      child: Semantics(
        liveRegion: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              error != null
                  ? Icons.error_outline
                  : pending
                  ? Icons.more_horiz
                  : Icons.check_circle_outline,
              size: 18,
              color: error != null
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                pending ? 'Saving…' : error ?? feedback!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: error != null
                      ? Theme.of(context).colorScheme.error
                      : null,
                ),
              ),
            ),
            if (!pending && error == null && _undo != null)
              TextButton(
                onPressed: _busy
                    ? null
                    : () {
                        final undo = _undo;
                        if (undo != null) _write('Undo', undo);
                      },
                child: const Text('Undo'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _categoryRow(
    String label,
    String summary,
    VoidCallback? onTap,
  ) => Column(
    children: [
      InteractionSurface(
        key: Key('record-category-$label'),
        onTap: onTap,
        color: Colors.transparent,
        borderRadius: BorderRadius.zero,
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.titleSmall),
                  if (summary.isNotEmpty)
                    Text(
                      summary,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 20),
          ],
        ),
      ),
      Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
    ],
  );

  bool _flowSelected(
    bool hasFact,
    BleedingFlow? flow,
    BleedingFlow? candidate,
  ) => _busy && _pendingFlowActive
      ? _pendingHasFlow && _pendingFlow == candidate
      : hasFact && flow == candidate;

  Widget _namedSection(
    String label,
    String summary,
    bool expanded,
    VoidCallback toggle,
  ) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 4),
    child: Semantics(
      expanded: expanded,
      child: InteractionSurface(
        key: Key('record-section-$label'),
        color: Colors.transparent,
        borderRadius: BorderRadius.zero,
        onTap: _busy ? null : toggle,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.titleSmall),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                summary,
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(width: 6),
            AnimatedRotation(
              turns: expanded ? .5 : 0,
              duration: ExperienceMotion.reducedMotion(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              child: const Icon(Icons.expand_more_rounded),
            ),
          ],
        ),
      ),
    ),
  );

  String _joinedSummary(Iterable<String?> parts) {
    final summary = parts
        .whereType<String>()
        .where((part) => part.isNotEmpty)
        .join(' · ');
    return summary.isEmpty ? 'Recorded' : summary;
  }

  String _contextSummary(RecordContextType type, RecordHubDateFacts facts) =>
      switch (type) {
        RecordContextType.sleep =>
          facts.sleep == null
              ? 'Not recorded'
              : _joinedSummary([
                  facts.sleep!.value.duration?.label,
                  facts.sleep!.value.quality?.label,
                ]),
        RecordContextType.appetite =>
          facts.appetite == null
              ? 'Not recorded'
              : _joinedSummary([
                  facts.appetite!.value.appetite?.label,
                  if (facts.appetite!.value.cravingScore != null)
                    'Cravings ${facts.appetite!.value.cravingScore}',
                ]),
        RecordContextType.activity =>
          facts.activities.isEmpty
              ? 'Not recorded'
              : '${facts.activities.length} recorded',
        RecordContextType.event =>
          facts.events.isEmpty
              ? 'Not recorded'
              : '${facts.events.length} recorded',
        RecordContextType.temperature =>
          facts.temperatures.isEmpty
              ? 'Not recorded'
              : '${facts.temperatures.length} recorded',
      };

  String _dateLabel(LocalDate date) =>
      MaterialLocalizations.of(context).formatMediumDate(date.asLocalDateTime);

  Future<bool> _discardDraft() async {
    if (!_session.hasUnsavedDraft) return true;
    if (_askingDiscard) return false;
    _askingDiscard = true;
    final discard =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Keep your unfinished record?'),
            content: const Text(
              'Leave this draft open, or discard the unsaved changes.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep editing'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Discard draft'),
              ),
            ],
          ),
        ) ??
        false;
    _askingDiscard = false;
    return discard;
  }

  Future<void> _done() async {
    if (_busy || !await _discardDraft() || !mounted) return;
    if (_session.requestClose(discardDraft: true) !=
        RecordTransitionResult.applied) {
      return;
    }
    setState(() => _allowPop = true);
    // PopScope must rebuild before the route can be popped.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> _chooseDate() async {
    if (_busy) return;
    final date = await showRecordCalendar(
      context: context,
      selectedDate: _date,
      today: _session.today,
      savedDates: {
        for (final record in _records) record.experiencedDate,
        for (final note in _notes)
          if (note.experiencedDate != null) note.experiencedDate!,
        for (final facts in _facts)
          if (!facts.isEmpty) facts.date,
        for (final flow in _periodFlows) flow.date,
      },
    );
    if (!mounted || date == null || date == _date) return;
    if (!await _discardDraft() || !mounted) return;
    final result = _session.requestDateChange(date, discardDraft: true);
    if (result != RecordTransitionResult.applied) {
      setState(
        () => _error =
            'Choose today or an earlier date. Your draft is still here.',
      );
      return;
    }
    _note.clear();
    setState(() {
      _editingNote = null;
      _noteSaveState = _NoteSaveState.idle;
      _pickerDraft = false;
      _feedback = null;
      _error = null;
      _undo = null;
      _feedbackGroup = null;
      _errorGroup = null;
    });
  }

  Future<bool> _write(
    String label,
    Future<void> Function() action, {
    Future<void> Function()? undo,
    String? feedbackGroup,
  }) async {
    if (_busy) return false;
    final group = feedbackGroup ?? _groupFor(label);
    if (group == 'Private note' && label != 'Private note') {
      _noteSaveState = _NoteSaveState.idle;
    }
    if (_session.beginSave() != RecordTransitionResult.applied) {
      setState(() {
        _errorGroup = group;
        _error =
            'This date is now in the future. Choose today or an earlier date; your draft is still here.';
      });
      return false;
    }
    setState(() {
      _busy = true;
      _operationGroup = group;
      _error = null;
      _errorGroup = null;
      _feedback = null;
      _undo = null;
    });
    try {
      await action();
      _session.saveSucceeded();
      if (!mounted) return true;
      setState(() {
        _feedback = '$label saved locally for ${_dateLabel(_date)}.';
        _feedbackGroup = group;
        _undo = undo;
      });
      widget.onChanged?.call();
      await _load();
      return true;
    } catch (error) {
      _session.saveFailed();
      if (!mounted) return false;
      setState(() {
        _errorGroup = group;
        _error = switch (error) {
          _SymptomSourceChanged() =>
            'This observation changed while the impact editor was open. Reopen its impact editor to use the saved record.',
          HealthRecordException() => error.userMessage,
          RecordHubException() => error.userMessage,
          PeriodWriteException() => error.userMessage,
          _ => 'Your private record could not be saved. Try again.',
        };
      });
      if (error is _SymptomSourceChanged) await _load();
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _pendingImpactActive = false;
          _pendingFlowActive = false;
        });
        _draftChanged();
      }
    }
  }

  Future<HealthRecord> _saveSymptom(HealthRecordDraft input) async {
    final existing = _dayRecords
        .where((record) => record.symptom == input.symptom)
        .firstOrNull;
    HealthRecord? saved;
    final draft = HealthRecordDraft(
      symptom: input.symptom,
      severity: input.severity,
      experiencedDate: _date,
      provenance: _provenance,
      functionalImpacts: existing?.functionalImpacts ?? input.functionalImpacts,
    );
    final success = await _write(
      input.symptom.label,
      () async {
        saved = existing == null
            ? await widget.healthRecordRepository.create(draft)
            : await widget.healthRecordRepository.update(existing.id, draft);
      },
      undo: existing == null
          ? () async {
              final current = saved;
              if (current != null) {
                await widget.healthRecordRepository.delete(
                  current.id,
                  expectedCurrent: current,
                );
              }
            }
          : () async {
              await widget.healthRecordRepository.restore(
                existing,
                expectedCurrent: saved,
              );
            },
    );
    if (!success || saved == null) {
      throw const HealthRecordException(HealthRecordFailure.storageUnavailable);
    }
    return saved!;
  }

  Future<void> _deleteSymptom(HealthRecord record) async {
    final success = await _write(
      '${record.symptom.label} removal',
      () => widget.healthRecordRepository.delete(
        record.id,
        expectedCurrent: record,
      ),
      undo: () async {
        await widget.healthRecordRepository.restore(record);
      },
    );
    if (!success) {
      throw const HealthRecordException(HealthRecordFailure.storageUnavailable);
    }
  }

  Future<void> _saveNote() async {
    final text = _note.text.trim();
    if (text.isEmpty || _busy) return;
    setState(() => _noteSaveState = _NoteSaveState.saving);
    final now = (widget.clock ?? DateTime.now)();
    final original = _editingNote;
    final note = CaptureNote(
      id:
          original?.id ??
          'record-note-${now.microsecondsSinceEpoch}-${math.Random.secure().nextInt(1 << 32).toRadixString(16)}',
      text: text,
      source: original?.source ?? CaptureSource.typed,
      createdAt: original?.createdAt ?? now,
      experiencedDate: _date,
      keepInComfortKit: original?.keepInComfortKit ?? false,
      provenance: original?.provenance ?? HealthRecordProvenance.timingUnknown,
      originalProvenance: original?.originalProvenance,
      writeZoneOffsetMinutes: original?.writeZoneOffsetMinutes,
      writeZoneName: original?.writeZoneName,
    );
    CaptureNote? saved;
    final success = await _write(
      'Private note',
      () async {
        if (original == null) {
          saved = await widget.captureNoteStore.save(note);
        } else {
          saved = await widget.captureNoteStore.update(note);
        }
      },
      undo: original == null
          ? () async {
              final current = saved;
              if (current != null) {
                await widget.captureNoteStore.delete(
                  current,
                  expectedCurrent: current,
                );
              }
            }
          : () async {
              await widget.captureNoteStore.restore(
                original,
                expectedCurrent: saved,
              );
            },
    );
    if (!mounted) return;
    if (success) {
      _editingNote = null;
      _note.clear();
    }
    setState(
      () => _noteSaveState = success
          ? _NoteSaveState.saved
          : _NoteSaveState.failed,
    );
  }

  Future<void> _editPins() async {
    final repository = widget.recordHubRepository;
    if (repository == null || _busy) return;
    final working = [...?_pins?.symptoms];
    final chosen = await showDialog<List<SymptomType>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Pin 2–4 symptoms'),
          content: SingleChildScrollView(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final symptom in SymptomType.values.where(
                  (symptom) => symptom.availableForNewRecords,
                ))
                  FilterChip(
                    label: Text(symptom.label),
                    selected: working.contains(symptom),
                    onSelected: (selected) => update(() {
                      if (!selected) {
                        working.remove(symptom);
                      } else if (working.length < 4) {
                        working.add(symptom);
                      }
                    }),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: working.length < 2
                  ? null
                  : () => Navigator.pop(context, working),
              child: const Text('Save pins'),
            ),
          ],
        ),
      ),
    );
    if (chosen == null || !mounted) return;
    await _write(
      'Pinned symptoms',
      () => repository.setPins(SymptomPins(chosen)),
    );
  }

  void _openSafety() {
    final callback = widget.onOpenSafety;
    if (callback != null) {
      callback();
    } else {
      CareSafetyRoute.show(context, careWorld: _careWorld);
    }
  }

  Future<void> _openContext(
    RecordContextType type, {
    DatedRecordDraft? initialDraft,
    String? id,
  }) async {
    final repository = widget.recordHubRepository;
    if (repository == null || _busy) return;
    if (!await _discardDraft() || !mounted) return;
    _note.clear();
    _editingNote = null;
    _pickerDraft = false;
    _pickerGeneration++;
    _session.setDraftDirty(false);
    final changed = await showRecordContextEditor(
      context,
      type: type,
      date: _date,
      repository: repository,
      initialDraft: initialDraft,
      id: id,
      clock: widget.clock,
    );
    if (!mounted || changed != true) return;
    widget.onChanged?.call();
    setState(() {
      _feedback = '${type.label} saved locally for ${_dateLabel(_date)}.';
      _feedbackGroup = type.label;
      _error = null;
      _errorGroup = null;
      _undo = null;
    });
    await _load();
  }

  Future<void> _openInterventions(ProductFamily? family) async {
    final repository = widget.interventionsRepository;
    if (repository == null || _busy || !await _discardDraft() || !mounted) {
      return;
    }
    _note.clear();
    _editingNote = null;
    _pickerDraft = false;
    _pickerGeneration++;
    _session.setDraftDirty(false);
    await showRecordInterventionsManager(
      context,
      family: family,
      date: _date,
      repository: repository,
      clock: widget.clock,
      onChanged: () {
        widget.onChanged?.call();
        _load();
      },
    );
    if (mounted) await _load();
  }

  Future<HealthRecord?> _editSymptomImpacts(HealthRecord record) async {
    if (_busy) return null;
    final working = {...record.functionalImpacts};
    final selected = await showDialog<Set<FunctionalImpact>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text('${record.symptom.label}: impact'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_dateLabel(_date)),
                for (final impact in FunctionalImpact.values)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(impact.label),
                    value: working.contains(impact),
                    onChanged: (selected) => update(() {
                      if (selected ?? false) {
                        working.add(impact);
                      } else {
                        working.remove(impact);
                      }
                    }),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, working),
              child: const Text('Save impact'),
            ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return null;
    HealthRecord? saved;
    final success = await _write(
      '${record.symptom.label} impact',
      () async {
        final current = (await widget.healthRecordRepository.getAll())
            .where((candidate) => candidate.id == record.id)
            .firstOrNull;
        if (current == null || !sameHealthRecordVersion(current, record)) {
          throw const _SymptomSourceChanged();
        }
        saved = await widget.healthRecordRepository.update(
          record.id,
          HealthRecordDraft(
            symptom: record.symptom,
            severity: record.severity,
            experiencedDate: _date,
            provenance: _provenance,
            functionalImpacts: selected,
          ),
        );
      },
      undo: () async {
        await widget.healthRecordRepository.restore(
          record,
          expectedCurrent: saved,
        );
      },
    );
    return success ? saved : null;
  }

  Widget _heading(String label) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Semantics(
      header: true,
      child: Text(label, style: Theme.of(context).textTheme.titleMedium),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _done();
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: math.max(
            kToolbarHeight,
            MediaQuery.textScalerOf(context).scale(24) * 1.4 + 16,
          ),
          automaticallyImplyLeading: false,
          title: const Text('Record'),
          actions: [
            TextButton(
              onPressed: _busy ? null : _done,
              child: const Text('Done'),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                top: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _dateToolbar(),
                        ),
                        if (_error != null && _errorGroup == null)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            child: Semantics(
                              liveRegion: true,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _error!,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.error,
                                        ),
                                  ),
                                  if (_records.isEmpty &&
                                      _notes.isEmpty &&
                                      _facts.isEmpty)
                                    TextButton(
                                      onPressed: _load,
                                      child: const Text('Try again'),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        _workspaceRail(),
                        Expanded(
                          child: RecordWorkspaceStage(
                            selectedIndex: _workspace.index,
                            children: [
                              for (final workspace in _RecordWorkspace.values)
                                SingleChildScrollView(
                                  primary: false,
                                  key: PageStorageKey(
                                    'record-workspace-scroll-${workspace.name}',
                                  ),
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    20,
                                    20,
                                    28,
                                  ),
                                  child: switch (workspace) {
                                    _RecordWorkspace.symptoms =>
                                      _symptomsWorkspace(),
                                    _RecordWorkspace.dailyLife =>
                                      _dailyLifeWorkspace(),
                                    _RecordWorkspace.products =>
                                      _productsWorkspace(),
                                    _RecordWorkspace.notes => _notesWorkspace(),
                                  },
                                ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            children: [
                              Divider(
                                height: 1,
                                color: Theme.of(
                                  context,
                                ).colorScheme.outlineVariant,
                              ),
                              InteractionSurface(
                                key: const Key('record-saved-on-day'),
                                color: Colors.transparent,
                                borderRadius: BorderRadius.zero,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                onTap: _busy ? null : _showDayLog,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Saved on this day',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodyMedium,
                                          ),
                                          Text(
                                            _savedDaySummary,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      size: 20,
                                    ),
                                  ],
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
      ),
    );
  }

  String get _savedDaySummary {
    final parts = <String>[
      if (_dayRecords.isNotEmpty)
        '${_dayRecords.length} ${_dayRecords.length == 1 ? 'symptom' : 'symptoms'}',
      if (_dayNotes.isNotEmpty)
        '${_dayNotes.length} ${_dayNotes.length == 1 ? 'note' : 'notes'}',
      if (!_dayFacts.isEmpty || _periodFlows.any((flow) => flow.date == _date))
        'Daily records',
    ];
    return parts.isEmpty ? 'View this date’s records' : parts.join(' · ');
  }

  Widget _dateToolbar() {
    final theme = Theme.of(context);
    final status = _provenance == HealthRecordProvenance.sameDay
        ? 'Recording today'
        : 'Later recall';
    return InteractionSurface(
      key: const Key('record-date'),
      color: Colors.transparent,
      borderRadius: BorderRadius.zero,
      onTap: _busy ? null : _chooseDate,
      padding: const EdgeInsets.symmetric(vertical: 12),
      semanticLabel:
          'Choose record date, ${MaterialLocalizations.of(context).formatFullDate(_date.asLocalDateTime)}, $status',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final date = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_month_outlined, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _dateLabel(_date),
                  style: theme.textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.expand_more_rounded, size: 18),
            ],
          );
          if (constraints.maxWidth < 320 ||
              MediaQuery.textScalerOf(context).scale(14) > 21) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                date,
                Text(
                  status,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: date),
              const SizedBox(width: 12),
              Text(
                status,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _selectWorkspace(_RecordWorkspace workspace) {
    if (_busy || _workspace == workspace) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _workspace = workspace;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final tabContext = _workspaceAnchors[workspace]!.currentContext;
      if (tabContext != null && tabContext.mounted) {
        Scrollable.ensureVisible(
          tabContext,
          alignment: .5,
          duration: ExperienceMotion.reducedMotion(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
        );
      }
    });
  }

  Widget _workspaceRail() => LayoutBuilder(
    builder: (context, constraints) {
      final theme = Theme.of(context);
      final style = theme.textTheme.labelLarge!;
      final widths = <double>[];
      for (final workspace in _RecordWorkspace.values) {
        final painter = TextPainter(
          text: TextSpan(
            text: workspace.label,
            style: style.copyWith(fontWeight: FontWeight.w600),
          ),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        widths.add(painter.width + 28);
        painter.dispose();
      }
      final measured = widths.fold<double>(0, (sum, width) => sum + width);
      final scrollable = measured > constraints.maxWidth;
      final actualWidths = scrollable
          ? widths
          : List<double>.filled(4, constraints.maxWidth / 4);
      final lineLeft = actualWidths
          .take(_workspace.index)
          .fold<double>(0, (sum, width) => sum + width);
      final railHeight = math.max(
        48.0,
        MediaQuery.textScalerOf(context).scale(style.fontSize ?? 14) * 1.5 + 20,
      );
      final rail = SizedBox(
        width: scrollable ? measured : constraints.maxWidth,
        height: railHeight,
        child: Stack(
          children: [
            Row(
              children: [
                for (final workspace in _RecordWorkspace.values)
                  SizedBox(
                    width: actualWidths[workspace.index],
                    height: railHeight,
                    child: Semantics(
                      key: _workspaceAnchors[workspace],
                      button: true,
                      selected: workspace == _workspace,
                      enabled: !_busy,
                      label: '${workspace.label} tab',
                      excludeSemantics: true,
                      onTap: _busy ? null : () => _selectWorkspace(workspace),
                      child: InkWell(
                        key: Key('record-workspace-${workspace.name}'),
                        onTap: _busy ? null : () => _selectWorkspace(workspace),
                        child: Center(
                          child: Text(
                            workspace.label,
                            style: style.copyWith(
                              fontWeight: workspace == _workspace
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: workspace == _workspace
                                  ? theme.colorScheme.onSurface
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            AnimatedPositioned(
              key: const Key('record-workspace-underline'),
              duration: ExperienceMotion.reducedMotion(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              left: lineLeft,
              bottom: 0,
              width: actualWidths[_workspace.index],
              child: Center(
                child: Container(
                  width: actualWidths[_workspace.index] - 28,
                  height: 2,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      );
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: rail,
      );
    },
  );

  Widget _symptomsWorkspace() {
    final theme = Theme.of(context);
    final repository = widget.recordHubRepository;
    final facts = _dayFacts;
    final pins = _pins?.symptoms ?? <SymptomType>[];
    final periodFlow = _periodFlows
        .where((flow) => flow.date == _date)
        .firstOrNull;
    final flow = facts.bleeding != null
        ? facts.bleeding!.value.flow
        : periodFlow?.flow;
    final hasBleedingFact = facts.bleeding != null || periodFlow != null;
    final color = facts.bleeding != null
        ? facts.bleeding!.value.color
        : periodFlow?.color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Symptoms', style: theme.textTheme.bodyMedium),
            ),
            if (repository != null)
              TextButton(
                onPressed: _busy ? null : _editPins,
                child: const Text('Edit pins'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          key: _pickerAnchor,
          child: ObservationPicker(
            key: ValueKey('record-observations-$_date-$_pickerGeneration'),
            initialSymptom: _focusedSymptom,
            fullScreenEditor: true,
            editorBusy: _busy,
            editorFooterBuilder: (_) => _operationStatus('Symptoms'),
            onDetailClosed: () {
              if (widget.returnAfterSymptomEdit &&
                  widget.initialSymptom != null &&
                  widget.origin == RecordOrigin.today) {
                _done();
              }
            },
            pinnedSymptoms: pins,
            onDraftChanged: (dirty) {
              _pickerDraft = dirty;
              _session.setDraftDirty(_note.text.isNotEmpty || dirty);
            },
            experiencedDate: _date,
            provenance: _provenance,
            existingRecords: _dayRecords,
            onSave: _saveSymptom,
            onDelete: _deleteSymptom,
            onWithdraw: (symptom) async {
              final record = _dayRecords
                  .where((record) => record.symptom == symptom)
                  .firstOrNull;
              if (record != null) await _deleteSymptom(record);
            },
            onMedicalAttention: _openSafety,
            onEditImpacts: _editSymptomImpacts,
            careWorld: _careWorld,
          ),
        ),
        _operationStatus('Symptoms'),
        if (repository != null) ...[
          _namedSection(
            'Daily impact',
            facts.impact == null ? 'Not recorded' : facts.impact!.value.label,
            _impactExpanded,
            () => setState(() => _impactExpanded = !_impactExpanded),
          ),
          AnimatedSize(
            duration: ExperienceMotion.reducedMotion(context)
                ? Duration.zero
                : const Duration(milliseconds: 180),
            alignment: Alignment.topCenter,
            curve: Curves.easeOutCubic,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_impactExpanded) ...[
                  Text(
                    'Overall effect on your day',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  RecordOptionScale<int>(
                    options: [
                      for (final degree in SymptomSeverity.orderedDegrees)
                        RecordScaleOption<int>(
                          value: degree.score,
                          label: degree.score == 0 ? 'No impact' : degree.label,
                          key: Key('record-impact-${degree.score}'),
                          semanticLabel:
                              'Daily impact, ${degree.score == 0 ? 'No impact' : degree.label}, ${degree.score} of 5',
                          marker: DegreeGraphics.severity(
                            degree,
                            showWord: false,
                            careWorld: _careWorld,
                          ),
                        ),
                    ],
                    selected: _pendingImpactActive
                        ? _pendingImpact
                        : facts.impact?.value.overall,
                    showCurrentLabel: false,
                    onSelected: _busy
                        ? null
                        : (score) {
                            final selected =
                                facts.impact?.value.overall != score;
                            _pendingImpactActive = true;
                            _pendingImpact = selected ? score : null;
                            _write('Daily impact', () async {
                              if (!selected) {
                                await repository.clearImpact(_date);
                              } else {
                                await repository.upsertImpact(
                                  DailyImpactDraft(
                                    experiencedDate: _date,
                                    overall: score,
                                    domains: facts.impact?.value.domains ?? {},
                                  ),
                                );
                              }
                            });
                          },
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      facts.impact == null
                          ? 'Not recorded'
                          : facts.impact!.value.overall == 0
                          ? 'No impact'
                          : facts.impact!.value.label,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  _operationStatus('Daily impact'),
                  if (facts.impact != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Areas affected (optional)',
                      style: theme.textTheme.bodyMedium,
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final domain in DailyImpactDomain.values)
                          FilterChip(
                            label: Text(domain.label),
                            selected: facts.impact!.value.domains.contains(
                              domain,
                            ),
                            onSelected: _busy
                                ? null
                                : (selected) => _write(
                                    'Daily impact',
                                    () async {
                                      final domains = {
                                        ...facts.impact!.value.domains,
                                      };
                                      if (selected) {
                                        domains.add(domain);
                                      } else {
                                        domains.remove(domain);
                                      }
                                      await repository.upsertImpact(
                                        DailyImpactDraft(
                                          experiencedDate: _date,
                                          overall: facts.impact!.value.overall,
                                          domains: domains,
                                        ),
                                      );
                                    },
                                  ),
                          ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
          Container(
            key: _bleedingAnchor,
            child: _namedSection(
              'Bleeding',
              hasBleedingFact
                  ? 'Recorded: ${flow?.label ?? 'None'}'
                  : 'Not recorded',
              _bleedingExpanded,
              () => setState(() => _bleedingExpanded = !_bleedingExpanded),
            ),
          ),
          AnimatedSize(
            duration: ExperienceMotion.reducedMotion(context)
                ? Duration.zero
                : const Duration(milliseconds: 180),
            alignment: Alignment.topCenter,
            curve: Curves.easeOutCubic,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_bleedingExpanded) ...[
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns =
                          constraints.maxWidth >= 5 * 56 + 4 * 6 &&
                              MediaQuery.textScalerOf(context).scale(14) <= 21
                          ? 5
                          : 2;
                      final width =
                          (constraints.maxWidth - (columns - 1) * 6) / columns;
                      return Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final candidate in <BleedingFlow?>[
                            null,
                            ...BleedingFlow.values,
                          ])
                            SizedBox(
                              width: width,
                              child: InteractionSurface(
                                key: Key(
                                  'record-flow-${candidate?.name ?? 'none'}',
                                ),
                                selected: _flowSelected(
                                  hasBleedingFact,
                                  flow,
                                  candidate,
                                ),
                                semanticLabel:
                                    'Bleeding flow: ${candidate?.label ?? 'None'}',
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 2,
                                ),
                                onTap: _busy
                                    ? null
                                    : () {
                                        final clear =
                                            hasBleedingFact &&
                                            flow == candidate;
                                        _pendingFlowActive = true;
                                        _pendingHasFlow = !clear;
                                        _pendingFlow = candidate;
                                        _write('Bleeding', () async {
                                          if (clear) {
                                            await repository.clearBleeding(
                                              _date,
                                            );
                                          } else {
                                            await repository.upsertBleeding(
                                              BleedingFactDraft(
                                                experiencedDate: _date,
                                                flow: candidate,
                                                periodId: periodFlow?.periodId,
                                                color: candidate == null
                                                    ? null
                                                    : color,
                                                clots: candidate == null
                                                    ? null
                                                    : facts
                                                          .bleeding
                                                          ?.value
                                                          .clots,
                                              ),
                                            );
                                          }
                                        });
                                      },
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ExcludeSemantics(
                                      child: candidate == null
                                          ? const Icon(
                                              Icons.block_outlined,
                                              size: 28,
                                            )
                                          : DegreeGraphics.flow(
                                              candidate,
                                              showWord: false,
                                              careWorld: _careWorld,
                                            ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            candidate?.label ?? 'None',
                                            style: theme.textTheme.labelMedium,
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                        if (_flowSelected(
                                          hasBleedingFact,
                                          flow,
                                          candidate,
                                        )) ...[
                                          const SizedBox(width: 3),
                                          Icon(
                                            Icons.check,
                                            size: 12,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      hasBleedingFact
                          ? 'Recorded: ${flow?.label ?? 'None'} · Tap again to remove'
                          : 'Not recorded · None records no bleeding',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  _operationStatus('Bleeding'),
                  if (flow != null) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final candidate in BleedingColor.values)
                          DegreeGraphics.bleedingColorChoice(
                            candidate,
                            selected: color == candidate,
                            onTap: () {
                              if (!_busy) {
                                _write('Bleeding color', () async {
                                  await repository.upsertBleeding(
                                    BleedingFactDraft(
                                      experiencedDate: _date,
                                      flow: flow,
                                      periodId: periodFlow?.periodId,
                                      color: color == candidate
                                          ? null
                                          : candidate,
                                      clots: facts.bleeding?.value.clots,
                                    ),
                                  );
                                });
                              }
                            },
                          ),
                      ],
                    ),
                  ],
                  if (flow != null) ...[
                    const SizedBox(height: 12),
                    Text('Clots (optional)', style: theme.textTheme.bodyMedium),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final clots in ClotObservation.values)
                          ChoiceChip(
                            checkmarkColor: Theme.of(
                              context,
                            ).colorScheme.onSurface,
                            label: Text(clots.label),
                            selected: facts.bleeding?.value.clots == clots,
                            onSelected: _busy
                                ? null
                                : (selected) =>
                                      _write('Clot observation', () async {
                                        await repository.upsertBleeding(
                                          BleedingFactDraft(
                                            experiencedDate: _date,
                                            flow: flow,
                                            periodId: periodFlow?.periodId,
                                            color: color,
                                            clots: selected ? clots : null,
                                          ),
                                        );
                                      }),
                          ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _dailyLifeWorkspace() {
    final repository = widget.recordHubRepository;
    final facts = _dayFacts;
    if (repository == null) {
      return const Text('Daily life records are unavailable in this view.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final type in RecordContextType.values) ...[
          _categoryRow(
            type.label,
            _contextSummary(type, facts),
            _busy
                ? null
                : () => _openContext(
                    type,
                    initialDraft: switch (type) {
                      RecordContextType.sleep => facts.sleep?.value,
                      RecordContextType.appetite => facts.appetite?.value,
                      _ => null,
                    },
                  ),
          ),
          _operationStatus(type.label),
        ],
      ],
    );
  }

  Widget _productsWorkspace() {
    if (widget.interventionsRepository == null) {
      return const Text(
        'Product and action records are unavailable in this view.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final family in <ProductFamily?>[null, ...ProductFamily.values])
          _categoryRow(
            switch (family) {
              null => 'What I tried',
              ProductFamily.medication => 'Medication',
              ProductFamily.supplement => 'Supplement',
              ProductFamily.birthControl => 'Birth control',
            },
            '',
            _busy ? null : () => _openInterventions(family),
          ),
      ],
    );
  }

  Widget _notesWorkspace() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _heading('Private note'),
      Container(
        key: _noteAnchor,
        child: TextField(
          key: const Key('record-note'),
          controller: _note,
          focusNode: _noteFocus,
          minLines: 5,
          maxLines: 8,
          maxLength: captureTextLimit,
          enabled: !_busy,
          decoration: const InputDecoration(
            filled: false,
            border: UnderlineInputBorder(),
            enabledBorder: UnderlineInputBorder(),
            focusedBorder: UnderlineInputBorder(),
            labelText: 'What would you like to remember?',
          ),
        ),
      ),
      if (_editingNote != null)
        TextButton(
          onPressed: _busy
              ? null
              : () async {
                  if (await _discardDraft() && mounted) {
                    setState(() {
                      _editingNote = null;
                      _note.clear();
                    });
                  }
                },
          child: const Text('Cancel note edit'),
        ),
      _noteSaveButton(),
      _operationStatus('Private note'),
    ],
  );

  Widget _noteSaveButton() {
    final reduced = ExperienceMotion.reducedMotion(context);
    final label = switch (_noteSaveState) {
      _NoteSaveState.saving => 'Saving',
      _NoteSaveState.saved => 'Saved',
      _NoteSaveState.failed => 'Try again',
      _NoteSaveState.idle =>
        _editingNote == null ? 'Save note' : 'Save note changes',
    };
    final enabled = !_busy && _note.text.trim().isNotEmpty;
    final foreground = enabled || _noteSaveState != _NoteSaveState.idle
        ? ExperienceColors.ink
        : ExperienceColors.inkFaint;
    return Align(
      alignment: Alignment.centerRight,
      child: Semantics(
        liveRegion: true,
        child: InteractionSurface(
          key: const Key('record-note-save'),
          onTap: enabled ? _saveNote : null,
          color: enabled || _noteSaveState != _NoteSaveState.idle
              ? ExperienceColors.ember
              : ExperienceColors.surfaceWarm,
          borderRadius: BorderRadius.circular(24),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
          child: AnimatedSize(
            duration: reduced
                ? Duration.zero
                : const Duration(milliseconds: 180),
            alignment: Alignment.centerRight,
            curve: Curves.easeOutCubic,
            child: AnimatedSwitcher(
              duration: reduced
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              child: Row(
                key: ValueKey(label),
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_noteSaveState == _NoteSaveState.saving) ...[
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: foreground,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ] else if (_noteSaveState == _NoteSaveState.saved ||
                      _noteSaveState == _NoteSaveState.failed) ...[
                    Icon(
                      _noteSaveState == _NoteSaveState.saved
                          ? Icons.check_rounded
                          : Icons.refresh_rounded,
                      size: 18,
                      color: foreground,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(label, style: ExperienceType.label(foreground)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showDayLog() async {
    if (_busy) return;
    final action = await showModalBottomSheet<Future<void> Function()>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        final repository = widget.recordHubRepository;
        final facts = _dayFacts;
        final periodFlow = _periodFlows
            .where((flow) => flow.date == _date)
            .firstOrNull;
        final flow = facts.bleeding != null
            ? facts.bleeding!.value.flow
            : periodFlow?.flow;
        final hasBleedingFact = facts.bleeding != null || periodFlow != null;
        final color = facts.bleeding != null
            ? facts.bleeding!.value.color
            : periodFlow?.color;
        final theme = Theme.of(sheetContext);
        return SafeArea(
          top: false,
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * .75,
            child: Column(
              children: [
                ListTile(
                  title: Text(
                    'Saved on this day',
                    style: theme.textTheme.titleMedium,
                  ),
                  subtitle: Text(_dateLabel(_date)),
                  trailing: IconButton(
                    tooltip: 'Close saved records',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(sheetContext),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_dayNotes.isEmpty &&
                            _dayRecords.isEmpty &&
                            facts.isEmpty &&
                            periodFlow == null)
                          Text(
                            'No symptom, daily life or note records saved for this day yet.',
                            style: theme.textTheme.bodyMedium,
                          ),
                        if (facts.impact != null)
                          ListTile(
                            key: Key('record-log-impact-${facts.impact!.id}'),
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Daily impact'),
                            subtitle: Text(
                              '${facts.impact!.value.label} · ${facts.impact!.metadata.provenance.label}',
                            ),
                            onTap: () => Navigator.pop(sheetContext, () async {
                              _selectWorkspace(_RecordWorkspace.symptoms);
                              setState(() => _impactExpanded = true);
                            }),
                          ),
                        if (hasBleedingFact)
                          ListTile(
                            key: Key(
                              'record-log-bleeding-${facts.bleeding?.id ?? '${periodFlow!.periodId}:${periodFlow.date.epochDay}'}',
                            ),
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Bleeding'),
                            subtitle: Text(
                              '${flow?.label ?? 'None'}${color == null ? '' : ' · ${color.label}'}',
                            ),
                            onTap: () => Navigator.pop(sheetContext, () async {
                              _selectWorkspace(_RecordWorkspace.symptoms);
                              setState(() => _bleedingExpanded = true);
                            }),
                          ),
                        for (final record in _dayRecords)
                          ListTile(
                            key: Key('record-log-symptom-${record.id}'),
                            contentPadding: EdgeInsets.zero,
                            title: Text(record.symptom.label),
                            subtitle: Text(
                              '${record.severity.label} · ${record.provenance.label}',
                            ),
                            onTap: _busy
                                ? null
                                : () => Navigator.pop(
                                    sheetContext,
                                    () => _focusSymptom(record.symptom),
                                  ),
                            trailing: IconButton(
                              tooltip: 'Delete ${record.symptom.label}',
                              onPressed: _busy
                                  ? null
                                  : () => Navigator.pop(sheetContext, () async {
                                      if (await _confirmDelete(
                                            record.symptom.label,
                                          ) &&
                                          mounted) {
                                        await _deleteSymptom(record);
                                      }
                                    }),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ),
                        if (repository != null) ...[
                          if (facts.sleep case final sleep?)
                            _contextLogRowFromSheet(
                              sheetContext,
                              'Sleep',
                              [
                                sleep.value.duration?.label,
                                sleep.value.quality?.label,
                              ].whereType<String>().join(' · '),
                              RecordContextType.sleep,
                              sleep.value,
                              id: sleep.id,
                              delete: () => repository.clearSleep(_date),
                            ),
                          if (facts.appetite case final appetite?)
                            _contextLogRowFromSheet(
                              sheetContext,
                              'Appetite/cravings',
                              [
                                appetite.value.appetite?.label,
                                if (appetite.value.cravingScore != null)
                                  'Cravings ${SymptomSeverity.fromScore(appetite.value.cravingScore!).label}',
                              ].whereType<String>().join(' · '),
                              RecordContextType.appetite,
                              appetite.value,
                              id: appetite.id,
                              delete: () => repository.clearAppetite(_date),
                            ),
                          for (final activity in facts.activities)
                            _contextLogRowFromSheet(
                              sheetContext,
                              activity.value.customName ??
                                  activity.value.type.label,
                              [
                                activity.value.duration?.label,
                                activity.value.intensity?.label,
                              ].whereType<String>().join(' · '),
                              RecordContextType.activity,
                              activity.value,
                              id: activity.id,
                              delete: () =>
                                  repository.deleteActivity(activity.id),
                            ),
                          for (final event in facts.events)
                            _contextLogRowFromSheet(
                              sheetContext,
                              event.value.customName ?? event.value.type.label,
                              [
                                event.value.intensity?.label,
                                event.value.note,
                              ].whereType<String>().join(' · '),
                              RecordContextType.event,
                              event.value,
                              id: event.id,
                              delete: () => repository.deleteEvent(event.id),
                            ),
                          for (final temperature in facts.temperatures)
                            _contextLogRowFromSheet(
                              sheetContext,
                              'Basal body temperature',
                              '${temperature.value.enteredValue} ${temperature.value.unit.label} · ${temperature.value.method.label}',
                              RecordContextType.temperature,
                              temperature.value,
                              id: temperature.id,
                              delete: () =>
                                  repository.deleteTemperature(temperature.id),
                            ),
                          if (_facts.any(
                            (facts) => facts.temperatures.isNotEmpty,
                          )) ...[
                            _heading('Temperature history'),
                            RecordTemperatureTrend(
                              records: [
                                for (final facts in _facts)
                                  ...facts.temperatures,
                              ],
                            ),
                          ],
                        ],
                        for (final note in _dayNotes)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            key: Key('record-log-note-${note.id}'),
                            title: Text(note.text),
                            subtitle: Text(note.provenance.label),
                            onTap: _busy
                                ? null
                                : () => Navigator.pop(
                                    sheetContext,
                                    () => _editNote(note),
                                  ),
                            trailing: IconButton(
                              tooltip: 'Delete private note',
                              onPressed: _busy
                                  ? null
                                  : () => Navigator.pop(
                                      sheetContext,
                                      () => _confirmDeleteNote(note),
                                    ),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ),
                        if (widget.interventionsRepository != null)
                          ListTile(
                            title: const Text('Products and What I tried'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.pop(
                              sheetContext,
                              () async =>
                                  _selectWorkspace(_RecordWorkspace.products),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted || action == null) return;
    try {
      await action();
    } on HealthRecordException {
      // The existing write boundary keeps the actual source error inline.
    }
  }

  Future<void> _focusSymptom(SymptomType symptom) async {
    if (_busy || !await _discardDraft() || !mounted) return;
    _note.clear();
    setState(() {
      _workspace = _RecordWorkspace.symptoms;
      _focusedSymptom = symptom;
      _pickerDraft = false;
      _pickerGeneration++;
    });
    _session.setDraftDirty(false);
  }

  Widget _contextLogRowFromSheet(
    BuildContext sheetContext,
    String label,
    String detail,
    RecordContextType type,
    DatedRecordDraft draft, {
    String? id,
    Future<void> Function()? delete,
  }) => ListTile(
    key: Key('record-log-context-${type.name}-${id ?? draft.experiencedDate}'),
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    subtitle: Text(detail),
    onTap: () => Navigator.pop(sheetContext, () async {
      _selectWorkspace(_RecordWorkspace.dailyLife);
      await _openContext(type, initialDraft: draft, id: id);
    }),
    trailing: delete == null
        ? const Icon(Icons.edit_outlined)
        : IconButton(
            tooltip: 'Delete $label',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => Navigator.pop(sheetContext, () async {
              if (await _confirmDelete(label) && mounted) {
                _selectWorkspace(_RecordWorkspace.dailyLife);
                await _write(
                  '$label removal',
                  delete,
                  feedbackGroup: type.label,
                );
              }
            }),
          ),
  );

  Future<bool> _confirmDelete(String label) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Delete $label?'),
          content: Text('Remove this saved record for ${_dateLabel(_date)}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _confirmDeleteNote(CaptureNote note) async {
    if (await _confirmDelete('private note') && mounted) {
      await _write(
        'Private note removal',
        () => widget.captureNoteStore.delete(note, expectedCurrent: note),
        undo: () async {
          await widget.captureNoteStore.restore(note);
        },
      );
    }
  }

  Future<void> _editNote(CaptureNote note) async {
    if (!await _discardDraft() || !mounted) return;
    setState(() {
      _workspace = _RecordWorkspace.notes;
      _editingNote = note;
      _pickerDraft = false;
      _pickerGeneration++;
      _note.text = note.text;
    });
    await WidgetsBinding.instance.endOfFrame;
    final noteContext = _noteAnchor.currentContext;
    if (noteContext != null && noteContext.mounted) {
      await Scrollable.ensureVisible(noteContext);
      if (mounted && !_busy) _noteFocus.requestFocus();
    }
  }
}
