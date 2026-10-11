import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';

import '../../../experience/theme/experience_foundation.dart';
import '../../care/domain/care_memory.dart';
import '../../care/domain/care_mode.dart';
import '../../care/domain/care_memory_repository.dart';
import '../../preparation/domain/preparation_plan.dart';

/// Explicitly selected personal evidence. Saved references retain their words
/// and counts when a source changes; neither read nor forecast creates a plan.
class RecordPreparationScreen extends StatefulWidget {
  const RecordPreparationScreen({
    required this.repository,
    required this.careRepository,
    required this.onOpenCare,
    this.clock,
    this.onChanged,
    super.key,
  });
  final PreparationRepository repository;
  final CareMemoryRepository careRepository;
  final VoidCallback onOpenCare;
  final DateTime Function()? clock;
  final VoidCallback? onChanged;
  @override
  State<RecordPreparationScreen> createState() =>
      _RecordPreparationScreenState();
}

class _RecordPreparationScreenState extends State<RecordPreparationScreen> {
  final _words = TextEditingController();
  List<CareRecord> _sources = [];
  List<CareReflection> _reflections = [];
  PreparationPlan? _plan;
  String? _selectedAction, _selectedNote;
  String? _error;
  bool _loading = true,
      _saving = false,
      _dirty = false,
      _allowPop = false,
      _stale = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _words.dispose();
    super.dispose();
  }

  List<CareRecord> get _eligible => _sources
      .where((source) => source.pinned || source.outcome == CareOutcome.better)
      .toList();
  List<CareRecord> _actionSources(String? actionId) => _sources
      .where(
        (source) =>
            source.actionId == actionId &&
            (_eligible.any((eligible) => eligible.actionId == source.actionId)),
      )
      .toList();

  Future<void> _load() async {
    try {
      final plan = await widget.repository.getActivePlan();
      final sources = await widget.careRepository.getRecords();
      final reflections = await widget.careRepository.getReflections();
      final chosen = plan == null
          ? <CareRecord>[]
          : sources
                .where((source) => plan.sourceRecordIds.contains(source.id))
                .toList();
      final noteStillPresent =
          plan?.noteText == null ||
          reflections.any(
            (reflection) =>
                plan!.sourceRecordIds.contains(reflection.careRecordId) &&
                reflection.futureSelfNote == plan.noteText,
          );
      final fingerprint = plan == null
          ? null
          : await preparationSelectionFingerprint(chosen, plan.noteText);
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _sources = sources;
        _reflections = reflections;
        _selectedAction = plan?.includeCare == true ? plan!.careActionId : null;
        _selectedNote = plan?.noteText;
        _words.text = plan?.personalText ?? '';
        _stale =
            plan != null &&
            (!noteStillPresent ||
                fingerprint != plan.evidenceFingerprint ||
                chosen.length != plan.sourceRecordIds.length);
        _loading = false;
        _error = null;
        _dirty = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Your private plan could not be opened. Try again.';
        });
      }
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final selected = _actionSources(_selectedAction);
    final words = _words.text.trim();
    if (selected.isEmpty && words.isEmpty && _selectedNote == null) {
      setState(
        () => _error = 'Choose your own saved support or add your own words.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // Reload and require the exact reviewed evidence rather than silently
      // snapshotting a changed action between opening the editor and Save.
      final current = await widget.careRepository.getRecords();
      final currentSelected = current
          .where((source) => selected.any((old) => old.id == source.id))
          .toList();
      if (await preparationSelectionFingerprint(selected, _selectedNote) !=
          await preparationSelectionFingerprint(
            currentSelected,
            _selectedNote,
          )) {
        throw StateError('Source changed');
      }
      if (_selectedNote != null) {
        final currentNotes = await widget.careRepository.getReflections();
        if (!currentNotes.any(
          (reflection) =>
              currentSelected.any(
                (source) => source.id == reflection.careRecordId,
              ) &&
              reflection.futureSelfNote == _selectedNote,
        )) {
          throw StateError('Source changed');
        }
      }
      final representative = selected.firstOrNull;
      final now = DateTime.fromMillisecondsSinceEpoch(
        (widget.clock ?? DateTime.now)().millisecondsSinceEpoch,
        isUtc: true,
      );
      final plan = PreparationPlan(
        id: PreparationPlan.activeId,
        status: PreparationPlanStatus.current,
        evidenceFingerprint: await preparationSelectionFingerprint(
          selected,
          _selectedNote,
        ),
        sourceRecordIds: selected.map((source) => source.id).toList(),
        includeCare: selected.isNotEmpty,
        careActionId: representative?.actionId ?? '',
        careActionLabel: representative?.actionLabel ?? '',
        careMode:
            representative?.mode ?? (_plan?.careMode ?? CareMode.physical),
        betterCount: selected
            .where((source) => source.outcome == CareOutcome.better)
            .length,
        sameCount: selected
            .where((source) => source.outcome == CareOutcome.same)
            .length,
        worseCount: selected
            .where((source) => source.outcome == CareOutcome.worse)
            .length,
        noteText: _selectedNote,
        personalText: words.isEmpty ? null : words,
        createdAt: _plan?.createdAt ?? now,
        updatedAt: now,
      );
      await widget.repository.savePlan(plan);
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _dirty = false;
        _stale = false;
      });
      widget.onChanged?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preparation plan saved privately on this device.'),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'The plan could not be saved, or its source changed. Your draft is still here. Review it and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirmLeave() async {
    if (_saving) return false;
    if (_dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Keep editing your plan?'),
          content: const Text(
            'Your unsaved words will be discarded if you leave.',
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
      );
      if (discard != true || !mounted) return false;
    }
    return mounted;
  }

  Future<void> _leave() async {
    if (!await _confirmLeave()) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _openCare() async {
    if (!await _confirmLeave()) return;
    setState(() {
      _allowPop = true;
      _dirty = false;
    });
    widget.onOpenCare();
  }

  Future<void> _refreshEvidence() async {
    if (_saving) return;
    try {
      final sources = await widget.careRepository.getRecords();
      final reflections = await widget.careRepository.getReflections();
      if (mounted) {
        setState(() {
          _sources = sources;
          _reflections = reflections;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Saved support could not be refreshed. Your draft is still here.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _leave();
    },
    child: Scaffold(
      backgroundColor: ExperienceColors.canvas,
      appBar: AppBar(
        title: const Text('Preparation plan'),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: _leave,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Your own words and saved support',
                  style: ExperienceType.title(ExperienceColors.ink),
                ),
                const SizedBox(height: 12),
                const Text(
                  'A plan is a private reference you choose. Self-reported outcomes do not prove that an action caused relief.',
                ),
                if (_plan != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _stale
                        ? 'Saved reference — its source has changed. Your saved words and evidence have been kept.'
                        : 'Your saved preparation plan',
                    style: ExperienceType.bodyStrong(ExperienceColors.ink),
                  ),
                  if (_plan!.includeCare)
                    Text(
                      '${_plan!.careActionLabel}: ${_plan!.betterCount} Better · ${_plan!.sameCount} Same · ${_plan!.worseCount} Worse (self-reported)',
                    ),
                  if (_plan!.noteText != null) Text(_plan!.noteText!),
                  if (_plan!.personalText != null) Text(_plan!.personalText!),
                ],
                const SizedBox(height: 20),
                TextButton(
                  onPressed: _saving ? null : _refreshEvidence,
                  child: const Text('Refresh saved support'),
                ),
                Text(
                  'Choose saved support for your next plan',
                  style: ExperienceType.bodyStrong(ExperienceColors.ink),
                ),
                if (_eligible.isEmpty)
                  const Text(
                    'No pinned or Better-marked Care actions yet. Your own words are always available.',
                  ),
                for (final actionId
                    in _eligible.map((source) => source.actionId).toSet())
                  CheckboxListTile(
                    value: _selectedAction == actionId,
                    title: Text(
                      _eligible
                          .firstWhere((source) => source.actionId == actionId)
                          .actionLabel,
                    ),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() {
                            _selectedAction = value == true ? actionId : null;
                            _selectedNote = null;
                            _dirty = true;
                          }),
                  ),
                if (_selectedAction != null)
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => setState(() {
                            _selectedAction = null;
                            _selectedNote = null;
                            _dirty = true;
                          }),
                    child: const Text('Use only my own words'),
                  ),
                for (final reflection in _reflections.where(
                  (reflection) =>
                      _actionSources(
                        _selectedAction,
                      ).any((source) => source.id == reflection.careRecordId) &&
                      reflection.futureSelfNote?.trim().isNotEmpty == true,
                ))
                  CheckboxListTile(
                    value: _selectedNote == reflection.futureSelfNote,
                    title: Text(reflection.futureSelfNote!),
                    subtitle: const Text(
                      'Include these saved words explicitly',
                    ),
                    onChanged: _saving
                        ? null
                        : (checked) => setState(() {
                            _selectedNote = checked == true
                                ? reflection.futureSelfNote
                                : null;
                            _dirty = true;
                          }),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: _words,
                  maxLength: 280,
                  maxLines: 4,
                  enabled: !_saving,
                  decoration: const InputDecoration(
                    labelText: 'My own words (optional)',
                  ),
                  onChanged: (_) => setState(() => _dirty = true),
                ),
                if (_error != null)
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _error!,
                      style: const TextStyle(color: ExperienceColors.error),
                    ),
                  ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving privately…' : 'Save my plan'),
                ),
                TextButton(
                  onPressed: _saving ? null : _openCare,
                  child: const Text('Open ordinary Care'),
                ),
              ],
            ),
    ),
  );
}

Future<String> preparationSelectionFingerprint(
  Iterable<CareRecord> records,
  String? note,
) async {
  final ordered = records.toList()..sort((a, b) => a.id.compareTo(b.id));
  final digest = await Sha256().hash(
    utf8.encode(
      jsonEncode({
        'version': 'native-preparation-selection-v2',
        'sources': [
          for (final source in ordered)
            {
              'id': source.id,
              'action': source.actionId,
              'label': source.actionLabel,
              'mode': source.mode.name,
              'outcome': source.outcome.name,
              'pinned': source.pinned,
              'updated': source.updatedAt.millisecondsSinceEpoch,
            },
        ],
        'selectedNote': note,
      }),
    ),
  );
  return 'native-preparation-selection-v2:${digest.bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join()}';
}
