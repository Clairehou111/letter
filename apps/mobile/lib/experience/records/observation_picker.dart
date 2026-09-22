import 'package:flutter/material.dart';

import '../../features/cycle/domain/local_date.dart';
import '../../features/health_records/domain/health_record.dart';
import '../../features/health_records/domain/observation_catalog.dart';
import '../degree/degree_graphics.dart';
import '../theme/experience_foundation.dart';

/// Catalog-driven observation entry: quick picks, grouped browse by
/// [ObservationCategory], alias-aware search, five-degree severity entry,
/// pain-kind and medicalAttention-kind handling, accessible feedback.
///
/// Contract enforced here (design authority):
///  * Everything renders from [ObservationCatalog] only. Drafts persist
///    stable enums/IDs ([SymptomType], [SymptomSeverity]), never display
///    labels.
///  * Entries whose [SymptomType.availableForNewRecords] is false are never
///    offered for new records (quick picks, browse, or search) but remain
///    readable in the on-record history.
///  * Severity offers exactly the five present degrees of [SymptomSeverity];
///    there is no "not at all". Tapping the chosen degree again deselects —
///    deselection means the observation is absent/unrecorded.
///  * Pain-kind observations record the same five named [SymptomSeverity]
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
    this.onSave,
    this.onDelete,
    this.onWithdraw,
    this.onEditImpacts,
    this.onMedicalAttention,
    this.careWorld = false,
  });

  /// The day these observations belong to.
  final LocalDate experiencedDate;

  /// Same-day vs later recall, recorded on every draft.
  final HealthRecordProvenance provenance;

  /// Records already persisted for this day. Rendered readably in history;
  /// available entries can be edited through the same degree entry.
  final List<HealthRecord> existingRecords;

  /// Persists a validated draft. Throwing [HealthRecordException] surfaces
  /// its `userMessage` inline.
  final Future<void> Function(HealthRecordDraft draft)? onSave;

  /// Removes a persisted record when the user deselects it (absence).
  final Future<void> Function(HealthRecord record)? onDelete;

  /// Fallback deselection hook when no [HealthRecord] object is available
  /// yet (a draft saved this session whose parent has not re-supplied
  /// records). When null and no record exists, deselecting only collapses
  /// the entry without claiming removal.
  final Future<void> Function(SymptomType symptom)? onWithdraw;

  /// Opens functional-impact editing for this same record. Keeping the
  /// action inside the on-record row avoids rendering every symptom twice.
  final ValueChanged<HealthRecord>? onEditImpacts;

  /// Optional route to the medical-boundary surface. When null, the fixed
  /// boundary list still renders inline at record time.
  final VoidCallback? onMedicalAttention;

  final bool careWorld;

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
    Future<void> Function(HealthRecordDraft draft)? onSave,
    Future<void> Function(HealthRecord record)? onDelete,
    Future<void> Function(SymptomType symptom)? onWithdraw,
    ValueChanged<HealthRecord>? onEditImpacts,
    VoidCallback? onMedicalAttention,
    bool careWorld = false,
  }) {
    return showExperienceSheet<void>(
      context,
      careWorld: careWorld,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: ExperienceSpacing.screenMargin,
            ),
            child: Align(
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
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                ExperienceSpacing.screenMargin,
                0,
                ExperienceSpacing.screenMargin,
                ExperienceSpacing.lg,
              ),
              child: ObservationPicker(
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
            ),
          ),
        ],
      ),
    );
  }

  @override
  State<ObservationPicker> createState() => _ObservationPickerState();
}

class _ObservationPickerState extends State<ObservationPicker> {
  final TextEditingController _searchController = TextEditingController();

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

  bool _saving = false;
  String? _ackLine;
  String? _errorLine;

  @override
  void dispose() {
    _searchController.dispose();
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
    for (final record in widget.existingRecords) {
      if (record.symptom == symptom) return record;
    }
    return null;
  }

  HealthRecordDraft? _sessionDraftFor(String definitionId) =>
      _sessionDrafts[definitionId];

  bool _isRecorded(ObservationDefinition definition) =>
      _recordFor(definition.symptom) != null ||
      _sessionDrafts.containsKey(definition.id);

  SymptomSeverity? _currentSeverity(ObservationDefinition definition) =>
      _recordFor(definition.symptom)?.severity ??
      _sessionDraftFor(definition.id)?.severity;

  // --- Entry lifecycle ------------------------------------------------------

  void _openDefinition(ObservationDefinition definition) {
    ExperienceHaptics.pick();
    setState(() {
      _errorLine = null;
      if (_activeId == definition.id) {
        _activeId = null;
        return;
      }
      _activeId = definition.id;
      final record = _recordFor(definition.symptom);
      final session = _sessionDraftFor(definition.id);
      _workingSeverity = record?.severity ?? session?.severity;
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
    setState(() {
      _saving = true;
      _errorLine = null;
    });
    try {
      await widget.onSave?.call(draft);
      final line = await SavedRhythm.acknowledge(SavedRhythmKind.record);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _sessionDrafts[definition.id] = draft;
        _workingSeverity = draft.severity;
        _ackLine = line;
      });
    } on HealthRecordException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorLine = error.userMessage;
      });
    }
  }

  /// Severity fast path: one tap on a degree saves immediately; tapping the
  /// chosen degree again deselects — absence, not "not at all". Pain-kind
  /// observations take the same path: pain is a severity degree.
  Future<void> _onSeverityDegreeTapped(
    ObservationDefinition definition,
    SymptomSeverity severity,
  ) async {
    if (_saving) return;
    ExperienceHaptics.pick();
    final current = _currentSeverity(definition);
    if (current == severity) {
      await _deselect(definition);
      return;
    }
    setState(() => _workingSeverity = severity);
    if (definition.recordingKind != ObservationRecordingKind.medicalAttention) {
      try {
        final draft = _composeDraft(definition, severity: severity);
        await _persist(definition, draft);
      } on HealthRecordException catch (error) {
        if (!mounted) return;
        setState(() => _errorLine = error.userMessage);
      }
    }
  }

  Future<void> _deselect(ObservationDefinition definition) async {
    final record = _recordFor(definition.symptom);
    setState(() {
      _workingSeverity = null;
      _errorLine = null;
    });
    try {
      if (record != null) {
        await widget.onDelete?.call(record);
        if (!mounted) return;
        setState(() {
          _sessionDrafts.remove(definition.id);
          _ackLine = 'Removed from this record.';
        });
      } else if (_sessionDrafts.containsKey(definition.id) &&
          widget.onWithdraw != null) {
        await widget.onWithdraw!(definition.symptom);
        if (!mounted) return;
        setState(() {
          _sessionDrafts.remove(definition.id);
          _ackLine = 'Removed from this record.';
        });
      }
    } on HealthRecordException catch (error) {
      if (!mounted) return;
      setState(() => _errorLine = error.userMessage);
    }
  }

  /// Explicit save for medicalAttention-kind entries — the
  /// boundary-acknowledged severity commits with the save button.
  Future<void> _saveActive(ObservationDefinition definition) async {
    final severity = _workingSeverity;
    if (severity == null || _saving) return;
    try {
      final draft = _composeDraft(definition, severity: severity);
      await _persist(definition, draft);
    } on HealthRecordException catch (error) {
      if (!mounted) return;
      setState(() => _errorLine = error.userMessage);
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _buildSearchField(),
        const SizedBox(height: ExperienceSpacing.sm),
        SavedRhythmAckLine(line: _ackLine, careWorld: widget.careWorld),
        if (_errorLine != null) _buildErrorLine(),
        if (_searching)
          _buildSearchResults()
        else ...<Widget>[
          if (widget.existingRecords.isNotEmpty) _buildHistory(),
          _buildQuickPicks(),
          _buildBrowse(),
        ],
      ],
    );
  }

  Widget _buildSearchField() {
    final border = widget.careWorld
        ? ExperienceColors.careGlassBorder
        : ExperienceColors.hairline;
    final fill = widget.careWorld
        ? ExperienceColors.careGlass
        : ExperienceColors.surface;
    return Semantics(
      textField: true,
      label: 'Search symptoms by name or a word you would use',
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
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
                    setState(() {});
                  },
                )
              : null,
          filled: true,
          fillColor: fill,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: ExperienceSpacing.sm,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: ExperienceRadius.chipRadius,
            borderSide: BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: ExperienceRadius.chipRadius,
            borderSide: BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: ExperienceRadius.chipRadius,
            borderSide: const BorderSide(
              color: ExperienceColors.ember,
              width: 1.5,
            ),
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
          Text(title, style: ExperienceType.headline(_ink)),
          if (caption != null)
            Padding(
              padding: const EdgeInsets.only(top: ExperienceSpacing.xs),
              child: Text(caption, style: ExperienceType.caption(_inkSoft)),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickPicks() {
    if (_quickPicks.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _buildSectionTitle(
          'Quick picks',
          caption: 'One tap opens its degree. Choosing a degree saves it here.',
        ),
        Wrap(
          spacing: ExperienceSpacing.xs * 2,
          runSpacing: ExperienceSpacing.xs * 2,
          children: <Widget>[
            for (final definition in _quickPicks) _buildSymptomChip(definition),
          ],
        ),
        if (_activeId != null) _buildActiveDetail(),
      ],
    );
  }

  Widget _buildBrowse() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final category in ObservationCategory.values)
          if (_browseFor(category).isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _buildSectionTitle(category.label),
                Wrap(
                  spacing: ExperienceSpacing.xs * 2,
                  runSpacing: ExperienceSpacing.xs * 2,
                  children: <Widget>[
                    for (final definition in _browseFor(category))
                      _buildSymptomChip(definition),
                  ],
                ),
                if (_activeId != null &&
                    _definitionFor(_activeId!)?.category == category &&
                    !_quickPicks.any((d) => d.id == _activeId))
                  _buildActiveDetail(),
              ],
            ),
      ],
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
                if (_activeId == definition.id) _buildActiveDetail(),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSymptomChip(ObservationDefinition definition) {
    final recorded = _isRecorded(definition);
    final active = _activeId == definition.id;
    final selected = recorded || active;
    final background = selected
        ? (widget.careWorld
              ? const Color(0x29FFFFFF)
              : ExperienceColors.surfaceWarm)
        : (widget.careWorld
              ? ExperienceColors.careGlass
              : ExperienceColors.surface);
    final border = selected
        ? ExperienceColors.ember
        : (widget.careWorld
              ? ExperienceColors.careGlassBorder
              : ExperienceColors.hairline);
    final severity = _currentSeverity(definition);

    return Semantics(
      button: true,
      selected: selected,
      label: recorded
          ? 'Symptom: ${definition.label}, recorded'
                '${severity != null ? ', ${severity.label}' : ''}'
          : 'Symptom: ${definition.label}, not recorded',
      child: InkWell(
        onTap: _saving ? null : () => _openDefinition(definition),
        borderRadius: ExperienceRadius.chipRadius,
        child: AnimatedContainer(
          duration: ExperienceMotion.chipSelect,
          constraints: const BoxConstraints(
            minHeight: ExperienceSpacing.minTouchTarget,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: background,
            borderRadius: ExperienceRadius.chipRadius,
            border: Border.all(color: border, width: selected ? 1.5 : 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (recorded) ...<Widget>[
                const Icon(
                  Icons.check,
                  size: 16,
                  color: ExperienceColors.ember,
                ),
                const SizedBox(width: ExperienceSpacing.xs),
              ],
              Flexible(
                child: Text(
                  definition.label,
                  style: ExperienceType.label(_ink),
                  overflow: TextOverflow.visible,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveDetail() {
    final definition = _definitionFor(_activeId!);
    if (definition == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: ExperienceSpacing.sm),
      child: _ObservationDetailCard(
        definition: definition,
        careWorld: widget.careWorld,
        saving: _saving,
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
        onCancel: () {
          ExperienceHaptics.pick();
          // Destructive exit of the working entry: the unfinished degree is
          // discarded rather than persisted invalid.
          setState(() {
            _activeId = null;
            _errorLine = null;
          });
        },
        onMedicalAttention: widget.onMedicalAttention,
      ),
    );
  }

  Widget _buildHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _buildSectionTitle(
          'On record for this day',
          caption:
              '${widget.provenance.label} · stable identifiers, never words.',
        ),
        for (final record in widget.existingRecords) _buildHistoryRow(record),
      ],
    );
  }

  Widget _buildHistoryRow(HealthRecord record) {
    final definition = ObservationCatalog.definitionFor(record.symptom);
    final available = record.symptom.availableForNewRecords;
    final impactLabels =
        record.functionalImpacts
            .map((impact) => impact.label)
            .toList(growable: false)
          ..sort();
    final impactSummary = impactLabels.isEmpty
        ? 'Daily impact not marked'
        : 'Daily impact: ${impactLabels.join(', ')}';

    final decoration = widget.careWorld
        ? BoxDecoration(
            color: ExperienceColors.careGlass,
            borderRadius: ExperienceRadius.chipRadius,
            border: Border.all(color: ExperienceColors.careGlassBorder),
          )
        : BoxDecoration(
            color: ExperienceColors.surface,
            borderRadius: ExperienceRadius.chipRadius,
            border: Border.all(color: ExperienceColors.hairline),
          );

    final row = Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: ExperienceSpacing.xs * 2),
      padding: const EdgeInsets.symmetric(
        horizontal: ExperienceSpacing.sm,
        vertical: 12,
      ),
      decoration: decoration,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(definition.label, style: ExperienceType.bodyStrong(_ink)),
                const SizedBox(height: ExperienceSpacing.xs),
                Text(
                  record.severity.label,
                  style: ExperienceType.caption(_inkSoft),
                ),
                if (widget.onEditImpacts != null) ...<Widget>[
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
          if (widget.onEditImpacts != null)
            IconButton(
              tooltip: 'Edit daily impact for ${definition.label}',
              onPressed: _saving
                  ? null
                  : () => widget.onEditImpacts?.call(record),
              icon: const Icon(
                Icons.edit_outlined,
                size: 18,
                color: ExperienceColors.ember,
              ),
            ),
        ],
      ),
    );

    if (!available) {
      // Readable in history, never offered for new entry.
      return Semantics(
        label:
            'Recorded: ${definition.label}. ${record.severity.label}. '
            '$impactSummary. No longer offered for '
            'new records.',
        child: row,
      );
    }
    return Semantics(
      button: true,
      label:
          'Recorded: ${definition.label}. ${record.severity.label}. '
          '$impactSummary. Activate to edit severity.',
      child: InkWell(
        onTap: _saving ? null : () => _openDefinition(definition),
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
  });

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

    final decoration = careWorld
        ? BoxDecoration(
            color: ExperienceColors.careGlass,
            borderRadius: ExperienceRadius.cardRadius,
            border: Border.all(color: ExperienceColors.careGlassBorder),
          )
        : BoxDecoration(
            color: ExperienceColors.surface,
            borderRadius: ExperienceRadius.cardRadius,
            border: Border.all(color: ExperienceColors.hairline),
            boxShadow: ExperienceShadows.card,
          );

    return Container(
      width: double.infinity,
      decoration: decoration,
      padding: const EdgeInsets.all(ExperienceSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(definition.label, style: ExperienceType.headline(ink)),
          const SizedBox(height: ExperienceSpacing.xs),
          Text(
            'Choose the closest degree, or leave it unrecorded. '
            'Choosing the same degree again removes it.',
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
          Text('How strong is it', style: ExperienceType.bodyStrong(ink)),
          const SizedBox(height: ExperienceSpacing.xs * 2),
          Wrap(
            spacing: ExperienceSpacing.xs * 2,
            runSpacing: ExperienceSpacing.xs * 2,
            children: <Widget>[
              // Exactly the five present degrees. No "not at all" exists;
              // deselection (absence) is handled by tapping the chosen
              // degree again.
              for (final degree in DegreeGraphics.severityDegrees)
                _SeverityOption(
                  definition: definition,
                  degree: degree,
                  selected: severity == degree,
                  careWorld: careWorld,
                  enabled: !saving,
                  onTap: () => onSeverityTapped(degree),
                ),
            ],
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
          ] else ...<Widget>[
            const SizedBox(height: ExperienceSpacing.xs * 2),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: saving ? null : onCancel,
                child: const Text('Done'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SeverityOption extends StatelessWidget {
  const _SeverityOption({
    required this.definition,
    required this.degree,
    required this.selected,
    required this.careWorld,
    required this.enabled,
    required this.onTap,
  });

  final ObservationDefinition definition;
  final SymptomSeverity degree;
  final bool selected;
  final bool careWorld;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final border = selected
        ? ExperienceColors.ember
        : (careWorld
              ? ExperienceColors.careGlassBorder
              : ExperienceColors.hairline);
    final background = selected
        ? (careWorld ? const Color(0x29FFFFFF) : ExperienceColors.surfaceWarm)
        : Colors.transparent;

    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label:
          '${definition.label}, ${DegreeGraphics.severitySemanticsLabel(degree)}',
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: ExperienceRadius.chipRadius,
        child: AnimatedContainer(
          duration: ExperienceMotion.chipSelect,
          constraints: const BoxConstraints(
            minHeight: ExperienceSpacing.degreeTarget,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: background,
            borderRadius: ExperienceRadius.chipRadius,
            border: Border.all(color: border, width: selected ? 1.5 : 1),
          ),
          child: DegreeGraphics.severity(
            degree,
            selected: selected,
            careWorld: careWorld,
          ),
        ),
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
