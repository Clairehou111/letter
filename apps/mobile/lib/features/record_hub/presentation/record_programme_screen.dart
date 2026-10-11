import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../cycle/domain/local_date.dart';
import '../../cycle/domain/period_record.dart';
import '../../cycle/domain/period_repository.dart';
import '../../health_records/domain/health_record.dart';
import '../../health_records/domain/health_record_repository.dart';
import '../../health_records/domain/observation_catalog.dart';
import '../domain/record_hub_facts.dart';
import '../domain/record_hub_repository.dart';
import '../domain/record_programme.dart';
import '../domain/record_programme_facts.dart';

double _toolbarHeight(BuildContext context, String title) {
  final theme = Theme.of(context);
  final text = TextPainter(
    text: TextSpan(
      text: title,
      style: theme.appBarTheme.titleTextStyle ?? theme.textTheme.titleLarge,
    ),
    textScaler: MediaQuery.textScalerOf(context),
    textDirection: Directionality.of(context),
    maxLines: 4,
  )..layout(maxWidth: math.max(120, MediaQuery.sizeOf(context).width - 88));
  return math.max(kToolbarHeight, text.height + 16);
}

/// Optional programme configuration and factual views of the same sources.
class RecordProgrammeScreen extends StatefulWidget {
  const RecordProgrammeScreen({
    required this.programmeRepository,
    required this.healthRecordRepository,
    required this.recordHubRepository,
    required this.periodRepository,
    this.onOpenRecord,
    this.clock,
    this.onChanged,
    this.legacyPauseUnresolved = false,
    super.key,
  });
  final RecordProgrammeRepository programmeRepository;
  final HealthRecordRepository healthRecordRepository;
  final RecordHubRepository recordHubRepository;
  final PeriodRepository periodRepository;
  final Future<void> Function(LocalDate date, SymptomType? symptom)?
  onOpenRecord;
  final DateTime Function()? clock;
  final VoidCallback? onChanged;
  final bool legacyPauseUnresolved;
  @override
  State<RecordProgrammeScreen> createState() => _RecordProgrammeScreenState();
}

class _RecordProgrammeScreenState extends State<RecordProgrammeScreen> {
  List<RecordProgramme> _programmes = [];
  List<HealthRecord> _records = [];
  List<RecordHubDateFacts> _facts = [];
  List<PeriodRecord> _periods = [];
  String? _selectedId;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  LocalDate get _today =>
      LocalDate.fromDateTime((widget.clock ?? DateTime.now)().toLocal());
  RecordProgramme? get _selected =>
      _programmes
          .where((programme) => programme.id == _selectedId)
          .firstOrNull ??
      _programmes.where((programme) => !programme.isEnded).firstOrNull ??
      _programmes.firstOrNull;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final sources = await Future.wait<Object>([
        widget.programmeRepository.getAll(),
        widget.healthRecordRepository.getAll(),
        widget.recordHubRepository.getAllFacts(),
        widget.periodRepository.getAll(),
      ]);
      if (!mounted) return;
      setState(() {
        _programmes = sources[0] as List<RecordProgramme>;
        _records = sources[1] as List<HealthRecord>;
        _facts = sources[2] as List<RecordHubDateFacts>;
        _periods = sources[3] as List<PeriodRecord>;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Your private programme could not be opened. Try again.';
        });
      }
    }
  }

  String _dateLabel(LocalDate date) =>
      MaterialLocalizations.of(context).formatMediumDate(date.asLocalDateTime);
  Future<void> _fields({RecordProgramme? programme}) async {
    if (_busy) return;
    final editor = _ProgrammeFieldsEditor(
      repository: widget.programmeRepository,
      programme: programme,
      date: _today,
      clock: widget.clock,
    );
    final saved = await Navigator.of(context).push<bool>(
      Theme.of(context).platform == TargetPlatform.iOS
          ? CupertinoPageRoute(builder: (_) => editor, fullscreenDialog: true)
          : MaterialPageRoute(builder: (_) => editor, fullscreenDialog: true),
    );
    if (saved == true && mounted) {
      if (programme == null) setState(() => _selectedId = null);
      widget.onChanged?.call();
      await _load();
    }
  }

  Future<void> _action(RecordProgramme programme, String action) async {
    if (_busy) return;
    if (action == 'End') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('End Pattern Record?'),
          content: Text(
            'End on ${_dateLabel(_today)}. Your saved records and programme history stay available.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('End programme'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      switch (action) {
        case 'Pause':
          await widget.programmeRepository.pause(programme.id, date: _today);
        case 'Resume':
          await widget.programmeRepository.resume(programme.id, date: _today);
        case 'End':
          await widget.programmeRepository.end(programme.id, date: _today);
      }
      widget.onChanged?.call();
      await _load();
    } on RecordProgrammeException catch (error) {
      if (mounted) setState(() => _error = error.userMessage);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Your private programme could not be updated. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openRecord(LocalDate date, [SymptomType? symptom]) async {
    final callback = widget.onOpenRecord;
    if (callback == null || _busy) return;
    await callback(date, symptom);
    if (mounted) await _load();
  }

  Widget _heading(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(top: 28, bottom: 12),
    child: Semantics(
      header: true,
      child: Text(text, style: Theme.of(context).textTheme.titleLarge),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final programme = _selected;
    final facts = programme == null
        ? null
        : composeRecordProgrammeFacts(
            programme: programme,
            today: _today,
            healthRecords: _records,
            datedFacts: _facts,
            periods: _periods,
            unresolvedLegacyPause: widget.legacyPauseUnresolved,
          );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pattern Record'),
        toolbarHeight: _toolbarHeight(context, 'Pattern Record'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Choose symptoms you want to follow, alongside overall daily impact. Entries use your usual saved records.',
                          style: theme.textTheme.bodyLarge,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              _error!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.error,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _load,
                            child: const Text('Try again'),
                          ),
                        ],
                        if (programme == null) ...[
                          const SizedBox(height: 24),
                          Text(
                            'No Pattern Record programme yet.',
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            key: const Key('programme-start'),
                            onPressed: _busy ? null : () => _fields(),
                            child: const Text('Choose fields'),
                          ),
                        ],
                        if (_programmes.length > 1) ...[
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final candidate in _programmes)
                                ChoiceChip(
                                  label: Text(
                                    '${candidate.isEnded ? 'Ended' : 'Current'} · ${_dateLabel(candidate.startDate)}',
                                  ),
                                  selected: candidate.id == programme?.id,
                                  onSelected: _busy
                                      ? null
                                      : (_) => setState(
                                          () => _selectedId = candidate.id,
                                        ),
                                ),
                            ],
                          ),
                        ],
                        if (programme != null && facts != null) ...[
                          _heading(
                            context,
                            programme.isEnded
                                ? 'Ended programme'
                                : programme.isPaused
                                ? 'Paused programme'
                                : 'Your selected fields',
                          ),
                          Text(
                            '${_dateLabel(programme.startDate)}${programme.endDate == null ? ' · Ongoing' : ' – ${_dateLabel(programme.endDate!)}'}',
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final symptom
                                  in programme.configurations.last.symptoms)
                                ActionChip(
                                  label: Text(symptom.label),
                                  onPressed: widget.onOpenRecord == null
                                      ? null
                                      : () => _openRecord(
                                          programme.endDate ?? _today,
                                          symptom,
                                        ),
                                ),
                              ActionChip(
                                label: const Text('Daily impact'),
                                onPressed: widget.onOpenRecord == null
                                    ? null
                                    : () => _openRecord(
                                        programme.endDate ?? _today,
                                      ),
                              ),
                            ],
                          ),
                          if (!programme.isEnded) ...[
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _fields(programme: programme),
                                  child: const Text('Change fields from today'),
                                ),
                                OutlinedButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _action(
                                          programme,
                                          programme.isPaused
                                              ? 'Resume'
                                              : 'Pause',
                                        ),
                                  child: Text(
                                    programme.isPaused ? 'Resume' : 'Pause',
                                  ),
                                ),
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _action(programme, 'End'),
                                  child: const Text('End programme'),
                                ),
                              ],
                            ),
                          ],
                          if (programme.isEnded &&
                              !_programmes.any(
                                (programme) => !programme.isEnded,
                              )) ...[
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: _busy ? null : () => _fields(),
                              child: const Text('Start a new programme'),
                            ),
                          ],
                          _heading(context, 'Recording coverage'),
                          Text(
                            '${facts.expectedFieldCount} expected fields · ${facts.sameDayFieldCount} saved same-day · ${facts.missingFieldCount} missing',
                            style: theme.textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${facts.elapsedCycles} elapsed cycles · ${facts.literallyFullyRecordedCycles} literally fully recorded cycles',
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'A fully recorded cycle has every expected field saved same-day, including explicit zeros. This count is separate from Comfort Window eligibility.',
                            style: theme.textTheme.bodySmall,
                          ),
                          if (widget.legacyPauseUnresolved) ...[
                            const SizedBox(height: 12),
                            const Text(
                              'Earlier diary pause dates still need confirmation. Legacy ratings remain separate, and literal completeness is unresolved.',
                            ),
                          ],
                          _heading(context, 'Saved facts'),
                          Text(
                            'Partial and persistent observations remain visible. Median, peak and distributions describe saved values; missing values stay blank.',
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Before/after comparisons use up to two completed observed cycles. Source support is shown separately for each window.',
                            style: theme.textTheme.bodySmall,
                          ),
                          for (final field in facts.fields)
                            _field(context, field),
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: const Text(
                              'Expected dates and missing fields',
                            ),
                            children: [
                              for (final day in facts.days.reversed)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(_dateLabel(day.date)),
                                  subtitle: Text(
                                    day.paused
                                        ? 'Paused · no fields expected'
                                        : '${day.expectedFieldCount} expected · ${day.sameDayExpectedFields} same-day · ${day.missingFieldCount} missing · Fields version ${day.configurationVersion}',
                                  ),
                                  trailing: widget.onOpenRecord == null
                                      ? null
                                      : const Icon(Icons.chevron_right),
                                  onTap: widget.onOpenRecord == null
                                      ? null
                                      : () => _openRecord(day.date),
                                ),
                            ],
                          ),
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: const Text('Field and pause history'),
                            children: [
                              for (final config in programme.configurations)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    'Fields version ${config.version} · ${_dateLabel(config.effectiveDate)}',
                                  ),
                                  subtitle: Text(
                                    '${config.symptoms.map((symptom) => symptom.label).join(', ')}; daily impact',
                                  ),
                                ),
                              for (final pause in programme.pauses)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    'Paused ${_dateLabel(pause.startDate)}',
                                  ),
                                  subtitle: Text(
                                    pause.resumedDate == null
                                        ? 'Open pause${programme.endDate == null ? '' : ' bounded by programme end'}'
                                        : 'Resumed ${_dateLabel(pause.resumedDate!)}',
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _field(BuildContext context, ProgrammeFieldFacts field) {
    final definition = ObservationCatalog.byId(field.id);
    final label = field.id == 'dailyImpact'
        ? 'Daily impact'
        : definition!.label;
    String stats(ProgrammeLevelFacts values) => values.sourceCount == 0
        ? 'No saved values'
        : '${values.sourceCount} sources · Median ${values.median} · Peak ${values.peak == 0 && field.id == 'dailyImpact' ? 'No impact' : SymptomSeverity.fromScore(values.peak!).label}';
    String coverage(ProgrammeFieldCoverage values) =>
        '${values.expected} expected · ${values.missing} missing · ${values.sameDay} same-day · ${values.laterRecall} later recall · ${values.timingUnknown} timing unknown';
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(
        '${stats(field.overall)}\n${coverage(field.overallCoverage)}',
      ),
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Before: 14 days before observed period starts'),
          subtitle: Text(
            '${stats(field.before)}\n${coverage(field.beforeCoverage)}',
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('After: observed cycle days 1–3'),
          subtitle: Text(
            '${stats(field.after)}\n${coverage(field.afterCoverage)}',
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Timing of saved values'),
          subtitle: Text(
            '${field.overall.sameDayCount} same-day · ${field.overall.laterRecallCount} later recall · ${field.overall.timingUnknownCount} timing unknown',
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Distribution of saved values'),
          subtitle: Text(
            [
              for (var score = 0; score <= 5; score++)
                '${score == 0 && field.id == 'dailyImpact' ? 'No impact' : SymptomSeverity.fromScore(score).label}: ${field.overall.distribution[score]}',
            ].join(' · '),
          ),
        ),
        for (final source in field.overall.sources)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_dateLabel(source.date)),
            subtitle: Text(
              '${source.score == 0 && field.id == 'dailyImpact' ? 'No impact' : SymptomSeverity.fromScore(source.score).label} · ${source.provenance.label}',
            ),
            trailing: widget.onOpenRecord == null
                ? null
                : const Icon(Icons.chevron_right),
            onTap: widget.onOpenRecord == null
                ? null
                : () => _openRecord(source.date, definition?.symptom),
          ),
      ],
    );
  }
}

class _ProgrammeFieldsEditor extends StatefulWidget {
  const _ProgrammeFieldsEditor({
    required this.repository,
    required this.date,
    this.programme,
    this.clock,
  });
  final RecordProgrammeRepository repository;
  final RecordProgramme? programme;
  final LocalDate date;
  final DateTime Function()? clock;
  @override
  State<_ProgrammeFieldsEditor> createState() => _ProgrammeFieldsEditorState();
}

class _ProgrammeFieldsEditorState extends State<_ProgrammeFieldsEditor> {
  late final List<SymptomType> _selected;
  bool _dirty = false;
  bool _saving = false;
  bool _allowPop = false;
  bool _asking = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _selected = [...?widget.programme?.configurations.last.symptoms];
  }

  Future<void> _close(bool saved) async {
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop(saved);
  }

  Future<void> _requestClose() async {
    if (_saving || _asking) return;
    if (!_dirty) {
      await _close(false);
      return;
    }
    _asking = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave without saving?'),
        content: const Text('Your selected fields have not been saved.'),
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
    _asking = false;
    if (discard == true && mounted) await _close(false);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final today = LocalDate.fromDateTime(
        (widget.clock ?? DateTime.now)().toLocal(),
      );
      if (widget.date.isAfter(today)) {
        throw const RecordProgrammeException(RecordProgrammeFailure.futureDate);
      }
      if (widget.programme == null) {
        await widget.repository.enroll(
          startDate: widget.date,
          symptoms: [..._selected],
        );
      } else {
        await widget.repository.updateConfig(
          widget.programme!.id,
          effectiveDate: widget.date,
          symptoms: [..._selected],
        );
      }
      if (mounted) await _close(true);
    } on RecordProgrammeException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.userMessage;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Your private programme could not be saved. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _requestClose();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.programme == null ? 'Choose fields' : 'Change fields',
          ),
          leading: BackButton(onPressed: _requestClose),
          toolbarHeight: _toolbarHeight(
            context,
            widget.programme == null ? 'Choose fields' : 'Change fields',
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                FilledButton(
                  onPressed: _saving || _selected.isEmpty ? null : _save,
                  child: Text(_saving ? 'Saving…' : 'Save fields'),
                ),
              ],
            ),
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              Text(
                'Begins ${MaterialLocalizations.of(context).formatMediumDate(widget.date.asLocalDateTime)}',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'Choose one or more symptoms. Overall daily impact is included separately. Choosing fields creates no ratings.',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 12),
              for (final category in ObservationCategory.values) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 20, bottom: 8),
                  child: Text(
                    category.label,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                for (final definition in ObservationCatalog.symptoms.where(
                  (definition) =>
                      definition.category == category &&
                      definition.symptom.availableForNewRecords,
                ))
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(definition.label),
                    value: _selected.contains(definition.symptom),
                    onChanged: _saving
                        ? null
                        : (selected) => setState(() {
                            _dirty = true;
                            if (selected ?? false) {
                              _selected.add(definition.symptom);
                            } else {
                              _selected.remove(definition.symptom);
                            }
                          }),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
