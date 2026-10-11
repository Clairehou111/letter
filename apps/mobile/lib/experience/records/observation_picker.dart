import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../features/cycle/domain/local_date.dart';
import '../../features/health_records/domain/health_record.dart';
import '../../features/health_records/domain/health_record_write_policy.dart';
import '../../features/health_records/domain/observation_catalog.dart';
import '../components/interaction_controls.dart';
import '../components/record_option_scale.dart';
import '../degree/degree_graphics.dart';
import '../theme/experience_foundation.dart';

/// Catalog-driven observation entry: quick picks, grouped browse by
/// [ObservationCategory], alias-aware search, explicit 0–5 severity entry,
/// pain-kind and medicalAttention-kind handling, accessible feedback.
///
/// Contract enforced here (design authority):
///  * Everything renders from [ObservationCatalog] only. Drafts persist
///    stable enums/IDs ([SymptomType], [SymptomSeverity]), never display
///    labels.
///  * Entries whose [SymptomType.availableForNewRecords] is false are never
///    offered for new records (quick picks, browse, or search) but remain
///    readable in the on-record history.
///  * Severity offers Not present plus the five present degrees. Zero is a
///    recorded observation; tapping the chosen degree again withdraws it.
///  * Pain-kind observations record the same named 0–5 [SymptomSeverity]
///    degrees as every other observation — pain is a severity, never a
///    numeric score or a location list.
///  * Entries routed to [ObservationSafetyRoute.medicalAttention] surface
///    the fixed medical-boundary list at record time.
///  * Quick picks respect [ObservationQuickPickPriority]: `searchOnly`
///    entries appear only through search.
///
/// The picker is a shrink-wrapped column meant to sit inside a scrolling
/// parent (the Cycle day editor, Today's detail path). The caller owns
/// persistence and create-vs-update resolution (match by symptom +
/// experienced date); typed [HealthRecordException] user messages surface
/// inline — errors are visual + textual, never haptic.
final class ObservationPicker extends StatefulWidget {
  const ObservationPicker({
    super.key,
    required this.experiencedDate,
    required this.provenance,
    this.existingRecords = const <HealthRecord>[],
    this.pinnedSymptoms = const <SymptomType>[],
    this.onSave,
    this.onDelete,
    this.onWithdraw,
    this.onEditImpacts,
    this.onMedicalAttention,
    this.initialSymptom,
    this.onDraftChanged,
    this.careWorld = false,
    this.fullScreenEditor = false,
    this.editorFooterBuilder,
    this.onDetailClosed,
    this.editorBusy = false,
  });

  /// The day these observations belong to.
  final LocalDate experiencedDate;

  /// Same-day vs later recall, recorded on every draft.
  final HealthRecordProvenance provenance;

  /// Records already persisted for this day. Rendered readably in history;
  /// available entries can be edited through the same degree entry.
  final List<HealthRecord> existingRecords;

  /// Shortcuts supplied by Record; the full catalog lives in Browse symptoms.
  final List<SymptomType> pinnedSymptoms;

  /// Persists a validated draft. Throwing [HealthRecordException] surfaces
  /// its `userMessage` inline.
  /// Persists and returns the stable record identity. Returning the saved
  /// record keeps edit and delete affordances consistent for observations
  /// added while this sheet is still open.
  final Future<HealthRecord> Function(HealthRecordDraft draft)? onSave;

  /// Withdraws a persisted observation, including an explicit zero.
  final Future<void> Function(HealthRecord record)? onDelete;

  /// Fallback deselection hook when no [HealthRecord] object is available
  /// yet (a draft saved this session whose parent has not re-supplied
  /// records). When null and no record exists, deselecting only collapses
  /// the entry without claiming removal.
  final Future<void> Function(SymptomType symptom)? onWithdraw;

  /// Opens functional-impact editing for this same record. Keeping the
  /// action inside the on-record row avoids rendering every symptom twice.
  final Future<HealthRecord?> Function(HealthRecord record)? onEditImpacts;

  /// Optional route to the medical-boundary surface. When null, the fixed
  /// boundary list still renders inline at record time.
  final VoidCallback? onMedicalAttention;

  /// Opens a catalog observation for an existing source or a pinned shortcut.
  final SymptomType? initialSymptom;

  /// Whether a changed, unsaved observation needs a navigation guard.
  final ValueChanged<bool>? onDraftChanged;

  final bool careWorld;

  /// Keeps the catalog and its scroll position underneath a focused native
  /// page. The original picker session still owns every persistence callback.
  final bool fullScreenEditor;
  final WidgetBuilder? editorFooterBuilder;
  final VoidCallback? onDetailClosed;

  /// A caller's pending Undo or impact write shares this session's lock.
  final bool editorBusy;

  /// The fixed medical-boundary list — honest, deterministic, never
  /// invented numbers. Shown wherever a `medicalAttention` entry is
  /// recorded.
  static const List<String> medicalBoundaryList = <String>[
    'Letter Within is not a medical service and cannot judge urgency.',
    'Heart palpitations can need medical attention — especially with '
        'chest pain, fainting, or shortness of breath.',
    'If symptoms feel severe, sudden, or frightening, contact a doctor '
        'or emergency services now.',
    'Recording here never replaces care from a clinician.',
  ];

  /// Opens the picker as an experience sheet (28 radius, grab handle).
  static Future<void> show(
    BuildContext context, {
    required LocalDate experiencedDate,
    required HealthRecordProvenance provenance,
    List<HealthRecord> existingRecords = const <HealthRecord>[],
    Future<HealthRecord> Function(HealthRecordDraft draft)? onSave,
    Future<void> Function(HealthRecord record)? onDelete,
    Future<void> Function(SymptomType symptom)? onWithdraw,
    Future<HealthRecord?> Function(HealthRecord record)? onEditImpacts,
    VoidCallback? onMedicalAttention,
    bool careWorld = false,
  }) {
    return showExperienceSheet<void>(
      context,
      careWorld: careWorld,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          ExperienceSpacing.screenMargin,
          0,
          ExperienceSpacing.screenMargin,
          ExperienceSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Close pain and observations',
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(
                  Icons.close,
                  color: careWorld
                      ? ExperienceColors.careInkSoft
                      : ExperienceColors.inkSoft,
                ),
              ),
            ),
            ObservationPicker(
              experiencedDate: experiencedDate,
              provenance: provenance,
              existingRecords: existingRecords,
              onSave: onSave,
              onDelete: onDelete,
              onWithdraw: onWithdraw,
              onEditImpacts: onEditImpacts,
              onMedicalAttention: onMedicalAttention,
              careWorld: careWorld,
            ),
          ],
        ),
      ),
    );
  }

  @override
  State<ObservationPicker> createState() => _ObservationPickerState();
}

class _ObservationPickerState extends State<ObservationPicker>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey _compositionAnchor = GlobalKey();
  final GlobalKey _changeAnchor = GlobalKey();
  final Map<String, GlobalKey> _itemAnchors = {};
  late final AnimationController _focusMotion;
  Rect? _focusOrigin;
  bool _closingFocus = false;
  int _focusGeneration = 0;

  /// Definition currently expanded for degree entry (accordion: one at a
  /// time).
  String? _activeId;

  /// Working degree state for the active entry. Cancel discards it — an
  /// unfinished entry never persists.
  SymptomSeverity? _workingSeverity;

  /// Drafts saved this session, keyed by definition id, so the UI reflects
  /// saves even before the parent re-supplies [existingRecords].
  final Map<String, HealthRecordDraft> _sessionDrafts =
      <String, HealthRecordDraft>{};

  /// Stable records returned by persistence during this open session.
  final Map<SymptomType, HealthRecord> _sessionRecords =
      <SymptomType, HealthRecord>{};

  /// Records removed while this picker is open. Some callers provide a
  /// snapshot of [ObservationPicker.existingRecords], so successful removals
  /// must be reflected locally until the sheet closes.
  final Set<SymptomType> _sessionRemoved = <SymptomType>{};

  bool _saving = false;
  bool get _entryBusy => _saving || widget.editorBusy;
  int _operationGeneration = 0;
  String? _ackLine;
  String? _errorLine;

  bool _hasUnsavedDraft = false;
  bool _editorOpen = false;
  bool _closingEditor = false;
  bool _editingImpacts = false;
  final ValueNotifier<int> _editorRevision = ValueNotifier(0);

  void _update(VoidCallback change) {
    setState(change);
    if (_editorOpen) _editorRevision.value++;
  }

  @override
  void initState() {
    super.initState();
    _focusMotion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    final symptom = widget.initialSymptom;
    if (symptom == null || !symptom.availableForNewRecords) return;
    final definition = ObservationCatalog.symptoms.firstWhere(
      (definition) => definition.symptom == symptom,
    );
    if (widget.fullScreenEditor) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openDefinition(definition);
      });
      return;
    }
    _activeId = definition.id;
    _workingSeverity = _currentSeverity(definition);
    // Deep links have no visible originating item: use the working face's top.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _animateFocus(open: true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ExperienceMotion.reducedMotion(context)) {
      _focusMotion.value = _activeId != null && !_closingFocus ? 1 : 0;
      if (_closingFocus) {
        _focusGeneration++;
        _activeId = null;
        _closingFocus = false;
      }
    }
  }

  @override
  void didUpdateWidget(covariant ObservationPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previous = {
      for (final record in oldWidget.existingRecords) record.symptom: record,
    };
    final changed =
        widget.existingRecords.length != previous.length ||
        widget.existingRecords.any(
          (record) =>
              previous[record.symptom] == null ||
              !sameHealthRecordVersion(previous[record.symptom]!, record),
        );
    // Parent refreshes after Undo or an external correction are authoritative.
    // A pending own callback supplies its exact committed record separately.
    if (changed && !_saving) {
      _sessionDrafts.clear();
      _sessionRecords.clear();
      _sessionRemoved.clear();
      _ackLine = null;
      if (!_hasUnsavedDraft && _activeId != null) {
        final definition = _definitionFor(_activeId!);
        if (definition != null) _workingSeverity = _currentSeverity(definition);
      }
    }
    // Parent reads (including guarded Undo) remain authoritative inside the
    // retained page. Defer notification until the parent has finished building.
    if (_editorOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _editorOpen) _editorRevision.value++;
      });
    }
  }

  void _notifyDraft(bool hasDraft) {
    if (_hasUnsavedDraft == hasDraft) return;
    _hasUnsavedDraft = hasDraft;
    widget.onDraftChanged?.call(hasDraft);
  }

  @override
  void dispose() {
    _focusMotion.dispose();
    _searchController.dispose();
    _editorRevision.dispose();
    super.dispose();
  }

  // --- Catalog views --------------------------------------------------------

  bool _available(ObservationDefinition definition) =>
      definition.symptom.availableForNewRecords;

  List<ObservationDefinition> get _quickPicks => ObservationCatalog.symptoms
      .where(
        (d) =>
            _available(d) &&
            d.quickPickPriority == ObservationQuickPickPriority.defaultPick,
      )
      .toList(growable: false);

  List<ObservationDefinition> _browseFor(ObservationCategory category) =>
      ObservationCatalog.symptoms
          .where(
            (d) =>
                _available(d) &&
                d.category == category &&
                d.quickPickPriority != ObservationQuickPickPriority.searchOnly,
          )
          .toList(growable: false);

  List<ObservationDefinition> get _searchResults => ObservationCatalog.search(
    _searchController.text,
  ).where(_available).toList(growable: false);

  bool get _searching => _searchController.text.trim().isNotEmpty;

  // --- Record state ---------------------------------------------------------

  HealthRecord? _recordFor(SymptomType symptom) {
    if (_sessionRemoved.contains(symptom)) return null;
    final sessionRecord = _sessionRecords[symptom];
    if (sessionRecord != null) return sessionRecord;
    for (final record in widget.existingRecords) {
      if (record.symptom == symptom) return record;
    }
    return null;
  }

  HealthRecordDraft? _sessionDraftFor(String definitionId) =>
      _sessionDrafts[definitionId];

  bool _isRecorded(ObservationDefinition definition) =>
      !_sessionRemoved.contains(definition.symptom) &&
      (_recordFor(definition.symptom) != null ||
          _sessionDrafts.containsKey(definition.id));

  SymptomSeverity? _currentSeverity(ObservationDefinition definition) =>
      _sessionRemoved.contains(definition.symptom)
      ? null
      : _sessionDraftFor(definition.id)?.severity ??
            _recordFor(definition.symptom)?.severity;

  // --- Entry lifecycle ------------------------------------------------------

  Rect _viewportRect() {
    final viewport = Scrollable.maybeOf(context)?.context.findRenderObject();
    if (viewport is RenderBox && viewport.hasSize) {
      return viewport.localToGlobal(Offset.zero) & viewport.size;
    }
    return Offset.zero & MediaQuery.sizeOf(context);
  }

  Rect _fallbackOrigin() {
    final face = _compositionAnchor.currentContext?.findRenderObject();
    final top = face is RenderBox && face.hasSize
        ? face
              .globalToLocal(_viewportRect().topLeft)
              .dy
              .clamp(0.0, double.infinity)
        : 0.0;
    return Rect.fromLTWH(0, top, 220, 44);
  }

  Rect? _measureOrigin(String id) {
    final item = _itemAnchors[id]?.currentContext?.findRenderObject();
    final face = _compositionAnchor.currentContext?.findRenderObject();
    if (item is! RenderBox || face is! RenderBox || !item.hasSize) return null;
    final global = item.localToGlobal(Offset.zero);
    final viewport = _viewportRect();
    if (!viewport.overlaps(global & item.size)) return null;
    return face.globalToLocal(global) & item.size;
  }

  void _animateFocus({required bool open}) {
    if (ExperienceMotion.reducedMotion(context)) {
      _focusMotion.value = open ? 1 : 0;
    } else if (open) {
      _focusMotion.forward();
    } else {
      _focusMotion.reverse();
    }
  }

  Future<void> _requestEditorClose() async {
    if (_entryBusy || _closingEditor || !_editorOpen) return;
    _closingEditor = true;
    try {
      if (_hasUnsavedDraft) {
        final discard = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog.adaptive(
            title: const Text('Keep your unfinished observation?'),
            content: const Text(
              'Your saved records stay. Only the unfinished change will be discarded.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Keep editing'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Discard change'),
              ),
            ],
          ),
        );
        if (discard != true || !mounted) return;
      }
      _notifyDraft(false);
      Navigator.of(context).pop();
    } finally {
      _closingEditor = false;
    }
  }

  Future<void> _openFullScreenDefinition(
    ObservationDefinition definition,
  ) async {
    ExperienceHaptics.pick();
    _update(() {
      _editorOpen = true;
      _activeId = definition.id;
      _workingSeverity = _currentSeverity(definition);
      _ackLine = null;
      _errorLine = null;
    });
    Widget page(BuildContext pageContext) => InheritedTheme.captureAll(
      context,
      ValueListenableBuilder<int>(
        valueListenable: _editorRevision,
        builder: (context, revision, _) {
          final record = _recordFor(definition.symptom);
          return PopScope<void>(
            canPop: !_entryBusy && !_hasUnsavedDraft,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) _requestEditorClose();
            },
            child: Scaffold(
              key: const Key('observation-fullscreen-editor'),
              body: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 20, 0),
                      child: Row(
                        children: [
                          IconButton(
                            key: const Key('observation-editor-close'),
                            tooltip: 'Close symptom',
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                            onPressed: _entryBusy ? null : _requestEditorClose,
                            icon: Icon(Icons.close_rounded, color: _inkSoft),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              MaterialLocalizations.of(context).formatFullDate(
                                widget.experiencedDate.asLocalDateTime,
                              ),
                              key: const Key('observation-editor-date'),
                              style: ExperienceType.caption(_inkFaint),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
                            child: _EditorEntrance(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildActiveDetail(
                                    headingStyle: ExperienceType.title(_ink),
                                    immersive: true,
                                  ),
                                  if (record != null) ...[
                                    const SizedBox(height: 28),
                                    Divider(
                                      height: 1,
                                      color: ExperienceColors.hairline
                                          .withValues(alpha: .3),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      record.functionalImpacts.isEmpty
                                          ? 'Daily impact not marked'
                                          : 'Daily impact: ${record.functionalImpacts.map((impact) => impact.label).join(', ')}',
                                      style: ExperienceType.bodySmall(_inkSoft),
                                    ),
                                    if (widget.onEditImpacts != null)
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: TextButton.icon(
                                          key: const Key(
                                            'observation-editor-impact',
                                          ),
                                          onPressed: _entryBusy
                                              ? null
                                              : () => _editImpacts(record),
                                          icon: const Icon(Icons.edit_outlined),
                                          label: const Text(
                                            'Edit daily impact',
                                          ),
                                        ),
                                      ),
                                    if (widget.onDelete != null)
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: TextButton.icon(
                                          key: const Key(
                                            'observation-editor-remove',
                                          ),
                                          onPressed: _entryBusy
                                              ? null
                                              : () => _deselect(definition),
                                          icon: const Icon(
                                            Icons.delete_outline,
                                          ),
                                          label: const Text(
                                            'Remove from this day',
                                          ),
                                        ),
                                      ),
                                  ],
                                  if (widget.editorFooterBuilder != null) ...[
                                    const SizedBox(height: 8),
                                    widget.editorFooterBuilder!(context),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    final reduced = ExperienceMotion.reducedMotion(context);
    final platform = Theme.of(context).platform;
    final route = reduced
        ? PageRouteBuilder<void>(
            pageBuilder: (context, _, _) => page(context),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          )
        : platform == TargetPlatform.iOS
        ? CupertinoPageRoute<void>(fullscreenDialog: true, builder: page)
        : MaterialPageRoute<void>(fullscreenDialog: true, builder: page);
    await Navigator.of(context).push<void>(route);
    if (!mounted) return;
    _notifyDraft(false);
    _update(() {
      _editorOpen = false;
      _activeId = null;
      _workingSeverity = null;
      _errorLine = null;
    });
    widget.onDetailClosed?.call();
  }

  Future<void> _editImpacts(HealthRecord record) async {
    if (_entryBusy || _editingImpacts) return;
    _editingImpacts = true;
    try {
      final updated = await widget.onEditImpacts?.call(record);
      if (!mounted || updated == null) return;
      _update(() => _sessionRecords[updated.symptom] = updated);
    } finally {
      _editingImpacts = false;
    }
  }

  void _openDefinition(ObservationDefinition definition) {
    if (_entryBusy || _editorOpen) return;
    if (_hasUnsavedDraft) {
      _update(() => _errorLine = 'Save or cancel the open observation first.');
      return;
    }
    if (widget.fullScreenEditor) {
      _openFullScreenDefinition(definition);
      return;
    }
    if (_activeId == definition.id && !_closingFocus) {
      _closeFocus();
      return;
    }
    ExperienceHaptics.pick();
    final origin = _measureOrigin(definition.id);
    _focusGeneration++;
    _update(() {
      _focusOrigin = origin;
      _closingFocus = false;
      _errorLine = null;
      _ackLine = null;
      _searchController.clear();
      _activeId = definition.id;
      final record = _recordFor(definition.symptom);
      final session = _sessionDraftFor(definition.id);
      _workingSeverity = session?.severity ?? record?.severity;
    });
    _animateFocus(open: true);
  }

  Future<void> _closeFocus() async {
    if (_editorOpen) {
      await _requestEditorClose();
      return;
    }
    if (_entryBusy || _activeId == null || _closingFocus) return;
    ExperienceHaptics.pick();
    final generation = ++_focusGeneration;
    // A saved shortcut can disappear from the chooser. In that case retreat
    // to the stable top anchor rather than flying to an absent/offscreen item.
    final face = _compositionAnchor.currentContext?.findRenderObject();
    final origin = _focusOrigin;
    if (_itemAnchors[_activeId]?.currentContext == null ||
        (face is RenderBox &&
            origin != null &&
            !_viewportRect().overlaps(
              face.localToGlobal(origin.topLeft) & origin.size,
            ))) {
      _focusOrigin = null;
    }
    _update(() {
      _closingFocus = true;
      _errorLine = null;
    });
    _notifyDraft(false);
    if (ExperienceMotion.reducedMotion(context)) {
      _focusMotion.value = 0;
    } else {
      try {
        await _focusMotion.reverse().orCancel;
      } on TickerCanceled {
        return;
      }
    }
    if (!mounted || generation != _focusGeneration) return;
    _update(() {
      _activeId = null;
      _closingFocus = false;
    });
  }

  HealthRecordDraft _composeDraft(
    ObservationDefinition definition, {
    required SymptomSeverity severity,
  }) {
    // Validation is part of composition so failures surface before
    // persistence is ever attempted.
    return validateHealthRecordDraft(
      HealthRecordDraft(
        symptom: definition.symptom,
        severity: severity,
        experiencedDate: widget.experiencedDate,
        provenance: widget.provenance,
      ),
    );
  }

  Future<void> _persist(
    ObservationDefinition definition,
    HealthRecordDraft draft,
  ) async {
    if (_entryBusy) return;
    final operation = ++_operationGeneration;
    _notifyDraft(true);
    _update(() {
      _saving = true;
      _errorLine = null;
      _ackLine = null;
    });
    try {
      final save = widget.onSave;
      if (save == null) {
        _update(() => _ackLine = 'Selected · not saved');
        return;
      }
      final saved = await save(draft);
      if (!mounted || operation != _operationGeneration) return;
      _update(() {
        _sessionRemoved.remove(definition.symptom);
        _sessionDrafts[definition.id] = draft;
        _sessionRecords[definition.symptom] = saved;
        _workingSeverity = draft.severity;
        _ackLine = 'Saved locally';
      });
      _notifyDraft(false);
      // Best effort haptics do not gate the durable visual result.
      SavedRhythm.acknowledge(SavedRhythmKind.record);
    } catch (error) {
      if (!mounted || operation != _operationGeneration) return;
      _update(
        () => _errorLine = error is HealthRecordException
            ? error.userMessage
            : 'This observation could not be saved. Try the degree again.',
      );
      _notifyDraft(true);
    } finally {
      if (mounted && operation == _operationGeneration) {
        _update(() => _saving = false);
      }
    }
  }

  /// Severity fast path: one tap on a degree saves immediately; tapping the
  /// chosen degree again withdraws the observation. Zero persists absence. Pain-kind
  /// observations take the same path: pain is a severity degree.
  Future<void> _onSeverityDegreeTapped(
    ObservationDefinition definition,
    SymptomSeverity severity,
  ) async {
    if (_entryBusy) return;
    ExperienceHaptics.pick();
    final current = _currentSeverity(definition);
    if (current == severity) {
      await _deselect(definition);
      return;
    }
    _update(() {
      _workingSeverity = severity;
      _ackLine = null;
      _errorLine = null;
    });
    if (definition.recordingKind == ObservationRecordingKind.medicalAttention) {
      _notifyDraft(severity != current);
    }
    if (definition.recordingKind != ObservationRecordingKind.medicalAttention) {
      try {
        final draft = _composeDraft(definition, severity: severity);
        await _persist(definition, draft);
      } on HealthRecordException catch (error) {
        if (!mounted) return;
        _update(() => _errorLine = error.userMessage);
        _notifyDraft(true);
      }
    }
  }

  Future<void> _deselect(ObservationDefinition definition) async {
    if (_entryBusy) return;
    final record = _recordFor(definition.symptom);
    final previous = _currentSeverity(definition);
    final operation = ++_operationGeneration;
    _update(() {
      _saving = true;
      _workingSeverity = null;
      _errorLine = null;
      _ackLine = null;
    });
    try {
      final remove = widget.onDelete;
      final withdraw = widget.onWithdraw;
      if (record != null && remove != null) {
        await remove(record);
      } else if (_sessionDrafts.containsKey(definition.id) &&
          withdraw != null) {
        await withdraw(definition.symptom);
      } else {
        if (mounted) _update(() => _workingSeverity = previous);
        return;
      }
      if (!mounted || operation != _operationGeneration) return;
      _update(() {
        _sessionRemoved.add(definition.symptom);
        _sessionDrafts.remove(definition.id);
        _sessionRecords.remove(definition.symptom);
        _ackLine = 'Removed from this record.';
      });
      _notifyDraft(false);
    } catch (error) {
      if (!mounted || operation != _operationGeneration) return;
      _update(() {
        _workingSeverity = previous;
        _errorLine = error is HealthRecordException
            ? error.userMessage
            : 'This observation could not be removed. Try again.';
      });
      _notifyDraft(true);
    } finally {
      if (mounted && operation == _operationGeneration) {
        _update(() => _saving = false);
      }
    }
  }

  /// Explicit save for medicalAttention-kind entries — the
  /// boundary-acknowledged severity commits with the save button.
  Future<void> _saveActive(ObservationDefinition definition) async {
    final severity = _workingSeverity;
    if (severity == null || _entryBusy) return;
    try {
      final draft = _composeDraft(definition, severity: severity);
      await _persist(definition, draft);
    } on HealthRecordException catch (error) {
      if (!mounted) return;
      _update(() => _errorLine = error.userMessage);
      _notifyDraft(true);
    }
  }

  // --- Build ----------------------------------------------------------------

  Color get _ink =>
      widget.careWorld ? ExperienceColors.careInk : ExperienceColors.ink;
  Color get _inkSoft => widget.careWorld
      ? ExperienceColors.careInkSoft
      : ExperienceColors.inkSoft;
  Color get _inkFaint => widget.careWorld
      ? ExperienceColors.careInkFaint
      : ExperienceColors.inkFaint;

  @override
  Widget build(BuildContext context) {
    final pinned = widget.pinnedSymptoms.isEmpty
        ? _quickPicks.take(4)
        : widget.pinnedSymptoms
              .where((s) => s.availableForNewRecords)
              .map(ObservationCatalog.definitionFor);
    final shortcuts = pinned.where((d) => !_isRecorded(d));
    return AnimatedBuilder(
      animation: _focusMotion,
      builder: (context, _) {
        final focused = _activeId != null && !widget.fullScreenEditor;
        final progress = focused
            ? Curves.easeInOutCubic.transform(_focusMotion.value)
            : 0.0;
        final reveal = ((progress - .28) / .55).clamp(0.0, 1.0);
        final headingReveal = progress == 1
            ? 1.0
            : ((progress - .55) / .45).clamp(0.0, 1.0);
        final definition = focused ? _definitionFor(_activeId!) : null;
        final source = _focusOrigin ?? _fallbackOrigin();
        final changeBox = _changeAnchor.currentContext?.findRenderObject();
        final targetTop =
            (changeBox is RenderBox && changeBox.hasSize
                ? changeBox.size.height
                : 48.0) +
            ExperienceSpacing.sm * 2;
        final target = Rect.fromLTWH(0, targetTop, source.width, source.height);
        final titleRect = Rect.lerp(source, target, progress)!;
        return Stack(
          key: _compositionAnchor,
          clipBehavior: Clip.none,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Offstage(
                  offstage: focused && progress == 1,
                  child: ClipRect(
                    child: Align(
                      alignment: Alignment.topLeft,
                      heightFactor: 1 - progress,
                      child: IgnorePointer(
                        ignoring: focused,
                        child: ExcludeSemantics(
                          excluding: focused,
                          child: Opacity(
                            opacity: (1 - progress * 2).clamp(0.0, 1.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!_searching && shortcuts.isNotEmpty) ...[
                                  Wrap(
                                    spacing: ExperienceSpacing.xs * 2,
                                    runSpacing: ExperienceSpacing.xs * 2,
                                    children: [
                                      for (final definition in shortcuts)
                                        _buildSymptomChip(definition),
                                    ],
                                  ),
                                  const SizedBox(height: ExperienceSpacing.sm),
                                ],
                                _buildSearchField(),
                                if (_searching) _buildSearchResults(),
                                TextButton.icon(
                                  key: const Key('observation-browse-symptoms'),
                                  onPressed: _entryBusy ? null : _openBrowse,
                                  icon: const Icon(Icons.list_rounded),
                                  label: const Text('Browse symptoms'),
                                  style: TextButton.styleFrom(
                                    alignment: Alignment.centerLeft,
                                  ),
                                ),
                                if (!focused) ...[
                                  if (_errorLine != null) _buildErrorLine(),
                                  if (_ackLine != null)
                                    SavedRhythmAckLine(
                                      line: _ackLine,
                                      careWorld: widget.careWorld,
                                    ),
                                ],
                                if (!_searching && _hasVisibleHistory)
                                  _buildHistory(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (focused)
                  ClipRect(
                    child: Align(
                      alignment: Alignment.topLeft,
                      heightFactor: progress,
                      child: IgnorePointer(
                        ignoring: _closingFocus,
                        child: ExcludeSemantics(
                          excluding: _closingFocus,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Align(
                                key: _changeAnchor,
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  key: const Key('observation-change-symptom'),
                                  onPressed: _entryBusy ? null : _closeFocus,
                                  icon: const Icon(
                                    Icons.arrow_back_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Change symptom'),
                                ),
                              ),
                              Opacity(
                                key: const Key('observation-focus-reveal'),
                                opacity: ExperienceMotion.reducedMotion(context)
                                    ? 1
                                    : reveal,
                                alwaysIncludeSemantics: true,
                                child: Transform.translate(
                                  offset:
                                      ExperienceMotion.reducedMotion(context)
                                      ? Offset.zero
                                      : Offset(0, (1 - progress) * 12),
                                  child: _buildActiveDetail(
                                    headingReveal: headingReveal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (definition != null &&
                headingReveal < 1 &&
                !ExperienceMotion.reducedMotion(context))
              Positioned(
                left: titleRect.left,
                top: titleRect.top,
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: Opacity(
                      opacity: 1 - headingReveal,
                      child: Text(
                        definition.label,
                        key: const Key('observation-origin-title'),
                        style: ExperienceType.label(_ink),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _openBrowse() async {
    if (_entryBusy) return;
    final chosen = await showModalBottomSheet<ObservationDefinition>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .75,
          child: Column(
            children: [
              ListTile(
                title: Text(
                  'Browse symptoms',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                trailing: IconButton(
                  tooltip: 'Close symptoms',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(sheetContext),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ExperienceSpacing.sm,
                  ),
                  children: [
                    for (final category in ObservationCategory.values)
                      if (_browseFor(category).isNotEmpty)
                        ExpansionTile(
                          key: Key('observation-category-${category.name}'),
                          title: Text(category.label),
                          children: [
                            for (final definition in _browseFor(category))
                              ListTile(
                                title: Text(definition.label),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () =>
                                    Navigator.pop(sheetContext, definition),
                              ),
                          ],
                        ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (mounted && chosen != null) _openDefinition(chosen);
  }

  Widget _buildSearchField() {
    final border = widget.careWorld
        ? ExperienceColors.careGlassBorder
        : ExperienceColors.hairline;
    return Semantics(
      textField: true,
      label: 'Search symptoms by name or a word you would use',
      child: TextField(
        controller: _searchController,
        onChanged: (_) => _update(() {}),
        style: ExperienceType.body(_ink),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: "Search — try 'swelling' or 'worry'",
          hintStyle: ExperienceType.body(_inkFaint),
          prefixIcon: Icon(Icons.search, color: _inkSoft),
          suffixIcon: _searching
              ? IconButton(
                  tooltip: 'Clear search',
                  icon: Icon(Icons.close, color: _inkSoft),
                  onPressed: () {
                    ExperienceHaptics.pick();
                    _searchController.clear();
                    _update(() {});
                  },
                )
              : null,
          filled: false,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: ExperienceSpacing.sm,
            vertical: 14,
          ),
          border: UnderlineInputBorder(borderSide: BorderSide(color: border)),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: border),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: ExperienceColors.ember, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorLine() {
    return Padding(
      padding: const EdgeInsets.only(top: ExperienceSpacing.xs * 2),
      child: Semantics(
        liveRegion: true,
        child: Text(
          _errorLine!,
          style: ExperienceType.caption(
            widget.careWorld
                ? ExperienceColors.emberSoft
                : ExperienceColors.error,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, {String? caption}) {
    return Padding(
      padding: const EdgeInsets.only(
        top: ExperienceSpacing.md,
        bottom: ExperienceSpacing.xs * 2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: ExperienceType.bodyStrong(_ink)),
          if (caption != null)
            Padding(
              padding: const EdgeInsets.only(top: ExperienceSpacing.xs),
              child: Text(caption, style: ExperienceType.caption(_inkSoft)),
            ),
        ],
      ),
    );
  }

  ObservationDefinition? _definitionFor(String id) =>
      ObservationCatalog.byId(id);

  Widget _buildSearchResults() {
    final results = _searchResults;
    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: ExperienceSpacing.lg),
        child: Text(
          'No matches in the vocabulary. Try another word you would use.',
          style: ExperienceType.body(_inkSoft),
          textAlign: TextAlign.center,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _buildSectionTitle('Matches'),
        for (final definition in results)
          Padding(
            padding: const EdgeInsets.only(bottom: ExperienceSpacing.xs * 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(child: _buildSymptomChip(definition)),
                    Text(
                      definition.category.label,
                      style: ExperienceType.caption(_inkFaint),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSymptomChip(ObservationDefinition definition) {
    final recorded = _isRecorded(definition);
    final selected = recorded || _activeId == definition.id;
    final severity = _currentSeverity(definition);
    return Semantics(
      button: true,
      selected: selected,
      label: recorded
          ? 'Symptom: ${definition.label}, recorded${severity != null ? ', ${severity.label}' : ''}'
          : 'Symptom: ${definition.label}, not recorded',
      child: InteractionSurface(
        key: Key('observation-symptom-${definition.id}'),
        selected: selected,
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        borderRadius: ExperienceRadius.chipRadius,
        onTap: _entryBusy ? null : () => _openDefinition(definition),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              recorded ? Icons.check : Icons.add_rounded,
              size: 16,
              color: _inkSoft,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                definition.label,
                key: _itemAnchors.putIfAbsent(definition.id, GlobalKey.new),
                style: ExperienceType.label(_ink),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveDetail({
    double headingReveal = 1,
    bool showHeading = true,
    TextStyle? headingStyle,
    bool immersive = false,
  }) {
    final definition = _definitionFor(_activeId!);
    if (definition == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: ExperienceSpacing.sm),
      child: _ObservationDetailCard(
        definition: definition,
        headingReveal: headingReveal,
        showHeading: showHeading,
        headingStyle: headingStyle,
        immersive: immersive,
        careWorld: widget.careWorld,
        saving: _entryBusy,
        acknowledgment: _ackLine,
        error: _errorLine,
        severity: _workingSeverity,
        // Severity and pain kinds save on degree tap; only the
        // medicalAttention route commits through the save button.
        canSave:
            definition.recordingKind ==
                ObservationRecordingKind.medicalAttention &&
            _workingSeverity != null,
        showSaveButton:
            definition.recordingKind ==
            ObservationRecordingKind.medicalAttention,
        onSeverityTapped: (severity) =>
            _onSeverityDegreeTapped(definition, severity),
        onSave: () => _saveActive(definition),
        onCancel: _closeFocus,
        onMedicalAttention: widget.onMedicalAttention,
      ),
    );
  }

  Widget _buildHistory() {
    final visibleExisting = widget.existingRecords
        .where((record) => !_sessionRemoved.contains(record.symptom))
        .toList(growable: false);
    final newDrafts = _sessionDrafts.entries.where((entry) {
      final definition = _definitionFor(entry.key);
      if (definition == null || _sessionRemoved.contains(definition.symptom)) {
        return false;
      }
      return !widget.existingRecords.any(
        (record) => record.symptom == definition.symptom,
      );
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _buildSectionTitle(
          'On record for this day',
          caption: widget.provenance.label,
        ),
        for (final record in visibleExisting)
          _buildHistoryRow(
            record,
            severityOverride: _sessionDraftFor(
              ObservationCatalog.definitionFor(record.symptom).id,
            )?.severity,
          ),
        for (final entry in newDrafts)
          _buildSessionHistoryRow(entry.key, entry.value),
      ],
    );
  }

  bool get _hasVisibleHistory {
    if (widget.existingRecords.any(
      (record) => !_sessionRemoved.contains(record.symptom),
    )) {
      return true;
    }
    return _sessionDrafts.entries.any((entry) {
      final definition = _definitionFor(entry.key);
      return definition != null &&
          !_sessionRemoved.contains(definition.symptom);
    });
  }

  Widget _buildSessionHistoryRow(String definitionId, HealthRecordDraft draft) {
    final definition = _definitionFor(definitionId);
    if (definition == null) return const SizedBox.shrink();
    final record = _sessionRecords[definition.symptom];
    return _buildHistoryEntry(
      definition: definition,
      severity: draft.severity,
      impactLabels: draft.functionalImpacts
          .map((impact) => impact.label)
          .toList(growable: false),
      record: record,
    );
  }

  Widget _buildHistoryRow(
    HealthRecord record, {
    SymptomSeverity? severityOverride,
  }) {
    final current = _sessionRecords[record.symptom] ?? record;
    final definition = ObservationCatalog.definitionFor(current.symptom);
    final impactLabels =
        current.functionalImpacts
            .map((impact) => impact.label)
            .toList(growable: false)
          ..sort();
    return _buildHistoryEntry(
      definition: definition,
      severity: severityOverride ?? current.severity,
      impactLabels: impactLabels,
      record: current,
    );
  }

  Widget _buildHistoryEntry({
    required ObservationDefinition definition,
    required SymptomSeverity severity,
    required List<String> impactLabels,
    HealthRecord? record,
  }) {
    impactLabels.sort();
    final available = definition.symptom.availableForNewRecords;
    final impactSummary = impactLabels.isEmpty
        ? 'Daily impact not marked'
        : 'Daily impact: ${impactLabels.join(', ')}';

    final row = Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: ExperienceSpacing.xs * 2),
      padding: const EdgeInsets.symmetric(
        horizontal: ExperienceSpacing.sm,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(definition.label, style: ExperienceType.bodyStrong(_ink)),
                const SizedBox(height: ExperienceSpacing.xs),
                Text(severity.label, style: ExperienceType.caption(_inkSoft)),
                if (record != null && widget.onEditImpacts != null) ...<Widget>[
                  const SizedBox(height: ExperienceSpacing.xs),
                  Text(impactSummary, style: ExperienceType.caption(_inkFaint)),
                ],
                if (!available)
                  Padding(
                    padding: const EdgeInsets.only(top: ExperienceSpacing.xs),
                    child: Text(
                      'Kept from your history — no longer offered for new records.',
                      style: ExperienceType.caption(_inkFaint),
                    ),
                  ),
              ],
            ),
          ),
          if (record != null && widget.onEditImpacts != null)
            IconButton(
              tooltip: 'Edit daily impact for ${definition.label}',
              onPressed: _entryBusy ? null : () => _editImpacts(record),
              icon: const Icon(
                Icons.edit_outlined,
                size: 18,
                color: ExperienceColors.ember,
              ),
            ),
          if ((record != null && widget.onDelete != null) ||
              (record == null && widget.onWithdraw != null))
            IconButton(
              tooltip: 'Remove ${definition.label} from this day',
              onPressed: _entryBusy ? null : () => _deselect(definition),
              icon: const Icon(
                Icons.delete_outline,
                size: 18,
                color: ExperienceColors.inkFaint,
              ),
            ),
        ],
      ),
    );

    if (!available) {
      // Readable in history, never offered for new entry.
      return Semantics(
        label:
            'Recorded: ${definition.label}. ${severity.label}. '
            '$impactSummary. No longer offered for '
            'new records.',
        child: row,
      );
    }
    return Semantics(
      button: true,
      label:
          'Recorded: ${definition.label}. ${severity.label}. '
          '$impactSummary. Activate to edit severity.',
      child: InkWell(
        onTap: _entryBusy ? null : () => _openDefinition(definition),
        borderRadius: ExperienceRadius.chipRadius,
        child: row,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Detail card — degree entry for the active definition.
// ---------------------------------------------------------------------------

class _ObservationDetailCard extends StatelessWidget {
  const _ObservationDetailCard({
    required this.definition,
    required this.careWorld,
    required this.saving,
    required this.severity,
    required this.canSave,
    required this.showSaveButton,
    required this.onSeverityTapped,
    required this.onSave,
    required this.onCancel,
    this.onMedicalAttention,
    this.acknowledgment,
    this.error,
    this.headingReveal = 1,
    this.showHeading = true,
    this.headingStyle,
    this.immersive = false,
  });

  final double headingReveal;
  final bool showHeading;
  final TextStyle? headingStyle;
  final bool immersive;
  final String? acknowledgment;
  final String? error;
  final ObservationDefinition definition;
  final bool careWorld;
  final bool saving;
  final SymptomSeverity? severity;
  final bool canSave;
  final bool showSaveButton;
  final ValueChanged<SymptomSeverity> onSeverityTapped;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final VoidCallback? onMedicalAttention;

  bool get _isMedical =>
      definition.safetyRoute == ObservationSafetyRoute.medicalAttention;

  @override
  Widget build(BuildContext context) {
    final ink = careWorld ? ExperienceColors.careInk : ExperienceColors.ink;
    final inkSoft = careWorld
        ? ExperienceColors.careInkSoft
        : ExperienceColors.inkSoft;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: ExperienceSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (showHeading)
            Opacity(
              opacity: headingReveal,
              alwaysIncludeSemantics: true,
              child: Text(
                definition.label,
                style:
                    headingStyle ??
                    Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: ink),
              ),
            ),
          if (showHeading)
            SizedBox(
              height: immersive ? ExperienceSpacing.sm : ExperienceSpacing.xs,
            ),
          Text(
            'Tap a degree to record. Tap the saved degree again to remove.',
            style: ExperienceType.caption(inkSoft),
          ),
          if (_isMedical) ...<Widget>[
            const SizedBox(height: ExperienceSpacing.sm),
            _MedicalBoundaryList(
              careWorld: careWorld,
              onOpenRoute: onMedicalAttention,
            ),
          ],
          const SizedBox(height: ExperienceSpacing.sm),
          if (immersive) const SizedBox(height: ExperienceSpacing.sm),
          RecordOptionScale<SymptomSeverity>(
            options: [
              for (final degree in DegreeGraphics.severityDegrees)
                RecordScaleOption<SymptomSeverity>(
                  value: degree,
                  label: degree.label,
                  key: Key('observation-degree-${degree.score}'),
                  semanticLabel:
                      '${definition.label}, ${DegreeGraphics.severitySemanticsLabel(degree)}',
                  marker: DegreeGraphics.severity(
                    degree,
                    showWord: false,
                    selected: severity == degree,
                    careWorld: careWorld,
                  ),
                ),
            ],
            selected: severity,
            onSelected: saving ? null : onSeverityTapped,
            showCurrentLabel: false,
          ),
          SizedBox(height: immersive ? 20 : ExperienceSpacing.xs * 2),
          Semantics(
            liveRegion: true,
            child: Text(
              severity?.label ?? 'Not recorded',
              key: const Key('observation-current-degree'),
              style: immersive
                  ? ExperienceType.headline(ink)
                  : ExperienceType.bodyStrong(ink),
            ),
          ),
          if (saving)
            Semantics(
              liveRegion: true,
              child: Text('Saving…', style: ExperienceType.caption(inkSoft)),
            ),
          if (error != null)
            Semantics(
              liveRegion: true,
              child: Text(
                error!,
                style: ExperienceType.caption(
                  Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          if (!saving && acknowledgment != null)
            Semantics(
              liveRegion: true,
              child: Text(
                acknowledgment!,
                style: ExperienceType.caption(inkSoft),
              ),
            ),
          if (showSaveButton) ...<Widget>[
            const SizedBox(height: ExperienceSpacing.sm),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton(
                    onPressed: canSave && !saving ? onSave : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: ExperienceColors.ember,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(
                        0,
                        ExperienceSpacing.degreeTarget,
                      ),
                      shape: const RoundedRectangleBorder(
                        borderRadius: ExperienceRadius.chipRadius,
                      ),
                    ),
                    child: Text(
                      saving ? 'Saving…' : 'Save to record',
                      style: ExperienceType.label(Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: ExperienceSpacing.xs * 2),
                TextButton(
                  onPressed: saving ? null : onCancel,
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ] else if (!immersive) ...<Widget>[
            const SizedBox(height: ExperienceSpacing.xs * 2),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: saving ? null : onCancel,
                key: const Key('observation-close-symptom'),
                child: const Text('Close symptom'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The fixed medical-boundary list rendered at record time for
/// `medicalAttention`-routed entries. Deterministic copy; no invented
/// numbers, no diagnosis.
class _MedicalBoundaryList extends StatelessWidget {
  const _MedicalBoundaryList({required this.careWorld, this.onOpenRoute});

  final bool careWorld;
  final VoidCallback? onOpenRoute;

  @override
  Widget build(BuildContext context) {
    final ink = careWorld ? ExperienceColors.careInk : ExperienceColors.ink;
    final inkSoft = careWorld
        ? ExperienceColors.careInkSoft
        : ExperienceColors.inkSoft;
    const accent = ExperienceColors.accentSafety;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ExperienceSpacing.sm),
      decoration: BoxDecoration(
        color: careWorld
            ? ExperienceColors.careGlass
            : accent.withValues(alpha: 0.06),
        borderRadius: ExperienceRadius.chipRadius,
        border: Border.all(
          color: careWorld
              ? ExperienceColors.careGlassBorder
              : accent.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'When to seek medical care',
            style: ExperienceType.bodyStrong(ink),
          ),
          const SizedBox(height: ExperienceSpacing.xs * 2),
          for (final line in ObservationPicker.medicalBoundaryList)
            Padding(
              padding: const EdgeInsets.only(bottom: ExperienceSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: ExperienceSpacing.xs * 2),
                  Expanded(
                    child: Text(line, style: ExperienceType.caption(inkSoft)),
                  ),
                ],
              ),
            ),
          if (onOpenRoute != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onOpenRoute,
                child: const Text('Open medical guidance'),
              ),
            ),
        ],
      ),
    );
  }
}

/// One-shot arrival for the full-screen symptom editor: the working block
/// rises 16px and fades in over 300ms with easeOutCubic. Reduce Motion keeps
/// a bare ≤150ms opacity fade with no travel. The animation runs once when
/// the editor opens; later session updates (severity, acknowledgment) do not
/// replay it.
class _EditorEntrance extends StatefulWidget {
  const _EditorEntrance({required this.child});

  final Widget child;

  @override
  State<_EditorEntrance> createState() => _EditorEntranceState();
}

class _EditorEntranceState extends State<_EditorEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final reduced = ExperienceMotion.reducedMotion(context);
      _controller.duration = reduced
          ? const Duration(milliseconds: 150)
          : const Duration(milliseconds: 300);
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = ExperienceMotion.reducedMotion(context);
    final animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    return AnimatedBuilder(
      animation: animation,
      child: widget.child,
      builder: (context, child) {
        final progress = animation.value;
        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: reduced || progress >= 1
                ? Offset.zero
                : Offset(0, 16 * (1 - progress)),
            child: child,
          ),
        );
      },
    );
  }
}
