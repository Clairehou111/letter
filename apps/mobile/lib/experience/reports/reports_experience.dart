import 'package:flutter/material.dart';

import '../../features/clinical/presentation/twin_matrix_view_model.dart';
import '../../features/cycle/domain/local_date.dart';
import '../../features/summary_export/domain/cycle_care_summary.dart';
import '../../features/summary_export/presentation/twin_matrix_summary_adapter.dart';
import '../experience_release_ports.dart';
import '../plus/plus_experience.dart';
import '../theme/experience_foundation.dart';

/// Reports route: the ledger. A deliberately-entered route hosting the real
/// free artifact — tiered by completed-cycle count — with honest range
/// handling, fixed disclosures, honest missingness, opt-in note selection,
/// the factual boundary with two equal-weight actions, and entitlement-gated
/// PDF/CSV export through [ReportExperiencePort] only.
///
/// This surface never builds files, chooses paths, or infers data. The port
/// owns loading and the native file handoff; the domain owns the summary
/// composition. Presentation owns the range, the cycle-tier derivation, the
/// note selection, the calm four-outcome receipt feedback, post-export
/// continuity, and post-purchase continuation.
///
/// Cycle tiers (presentation-side arithmetic over the loaded input): a
/// completed cycle is the span between two consecutive recorded period
/// starts; the current open span is not counted. Zero completed cycles shows
/// a single calm card; one shows the plain preview sections with a literal
/// "cannot show recurrence" line; two shows two real cycle timelines aligned
/// to bleeding start with no trend claim; three or more renders the full
/// Twin Matrix for Last 3 months. Gaps are never filled.
///
/// Range honesty: Last 3 months is the default and the only free preset.
/// Range ends are always clamped to the shell-provided current date — an
/// estimated future window never appears as a report's end date — and the
/// "All records" start derives from the earliest actual record. The printed
/// range is exactly the range handed to the preview and to the export port.
/// Upper presets remain visible and tappable but are Plus-gated: tapping one
/// without access opens the commitment sheet instead of switching.
///
/// Gating: reading local material here is free forever. Clinician-ready
/// report generation (the export itself) requires the `clinicianReports`
/// capability; after an entitlement lapse everything remains readable.
/// Contextual Plus acquisition is never shown or opened within 24 hours of
/// the latest Care record; existing paid access remains usable.
class ReportsExperience extends StatefulWidget {
  const ReportsExperience({
    super.key,
    required this.port,
    this.canUseClinicianReports = false,
    this.onOpenPlus,
    this.onOpenPlusWithContext,
    this.onOpenSourceRecords,
    this.now,
  });

  /// The only data/export boundary. Implementations adapt the existing
  /// summary, PDF/CSV, and Letter-folder services.
  final ReportExperiencePort port;

  /// Resolved from `EntitlementState.canUse(LetterCapability.clinicianReports)`
  /// by the shell when Reports opens. This is only the initial value: Reports
  /// maintains local access state so a successful commitment continues the
  /// original intent without rebuilding the route. When false, the preview
  /// stays fully readable and the export action is replaced by the honest,
  /// non-pressuring boundary.
  final bool canUseClinicianReports;

  /// Compatibility fallback route to the Plus surface, used when
  /// [onOpenPlusWithContext] is not provided. When both are null, the
  /// boundary offers no navigation.
  final VoidCallback? onOpenPlus;

  /// Typed commitment entry: accepts the exact outcome context the user
  /// asked for and returns the commitment result. When the result reports
  /// activation, Reports unlocks locally and continues the original intent
  /// (applying the requested range, opening the custom-range picker, or
  /// landing on the unlocked export panel). The shell adapts this callback
  /// to `PlusExperience.open`.
  final Future<PlusCommitResult?> Function(PlusOutcomeContext context)?
  onOpenPlusWithContext;

  /// Post-export continuity: a route back to the source records behind this
  /// report. Falls back to popping this route when not provided.
  final VoidCallback? onOpenSourceRecords;

  /// Shell-provided current date/time used to clamp report ranges so no
  /// displayed or exported range ends in the future. Defaults to the device
  /// clock.
  final DateTime Function()? now;

  @override
  State<ReportsExperience> createState() => _ReportsExperienceState();
}

enum _RangePreset {
  lastThreeMonths,
  lastSixMonths,
  lastYear,
  everything,
  custom,
}

final class _ReportBounds {
  const _ReportBounds({required this.start, required this.end});

  /// Earliest actual record date (or today when no records exist).
  final LocalDate start;

  /// Always the current date — never a future estimate.
  final LocalDate end;
}

class _ReportsExperienceState extends State<ReportsExperience> {
  SummaryExportInput? _input;
  Object? _loadError;

  /// Last 3 months is the default and the only free preset.
  _RangePreset _preset = _RangePreset.lastThreeMonths;
  SummaryDateRange? _customRange;

  /// Notes are included only when explicitly selected here. A saved note is
  /// never part of an export until the user chooses it for this export.
  final Set<String> _selectedNoteIds = <String>{};

  /// Local access state: set when the typed commitment reports activation,
  /// so the original range/export intent continues without a route rebuild.
  bool _plusActivated = false;

  bool _exporting = false;
  ReportExportFormat? _lastAttemptedFormat;
  ExperienceFileReceipt? _receipt;
  String? _ackLine;

  DateTime? _lastSuccessAt;
  ExperienceFileOutcome? _lastSuccessOutcome;

  bool get _hasClinicianAccess =>
      widget.canUseClinicianReports || _plusActivated;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _input = null;
      _loadError = null;
      _receipt = null;
    });
    try {
      final input = await widget.port.load();
      if (!mounted) return;
      setState(() => _input = input);
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error);
    }
  }

  DateTime _currentTime() => widget.now?.call() ?? DateTime.now();

  LocalDate _today() => LocalDate.fromDateTime(_currentTime());

  /// Honest bounds: the start is the earliest actual record date (period
  /// days, health records, Care events, notes) and the end is always today.
  /// Stored predictions are labeled estimates with future ends — they never
  /// define the report's outer dates.
  _ReportBounds _boundsOf(SummaryExportInput input) {
    final today = _today();
    LocalDate? earliest;
    void consider(LocalDate date) {
      final clamped = date.isAfter(today) ? today : date;
      if (earliest == null || clamped.isBefore(earliest!)) earliest = clamped;
    }

    for (final day in input.periodDays) {
      consider(day.date);
    }
    for (final record in input.healthRecords) {
      consider(record.experiencedDate);
    }
    for (final checkIn in input.checkIns) {
      consider(LocalDate.fromDateTime(checkIn.occurredAt.toLocal()));
    }
    for (final record in input.careRecords) {
      consider(LocalDate.fromDateTime(record.occurredAt.toLocal()));
    }
    for (final note in input.notes) {
      consider(note.date);
    }
    final start = earliest ?? today;
    return _ReportBounds(
      start: start.isAfter(today) ? today : start,
      end: today,
    );
  }

  /// Period days recorded through today. The no-cycle card is a cycle-data
  /// readiness message, so mood, symptom, Care, and note dates must not make
  /// one newly started period read as multiple period days.
  int _recordedDays(SummaryExportInput input) {
    final today = _today();
    final days = <int>{};
    for (final day in input.periodDays) {
      if (!day.date.isAfter(today)) days.add(day.date.epochDay);
    }
    return days.length;
  }

  /// Trust rule: contextual Plus acquisition is never shown or opened within
  /// 24 hours of the latest Care record. Existing paid access stays usable.
  bool _careAdjacent(SummaryExportInput input) {
    if (input.careRecords.isEmpty) return false;
    var latest = input.careRecords.first.occurredAt;
    for (final record in input.careRecords) {
      if (record.occurredAt.isAfter(latest)) latest = record.occurredAt;
    }
    return latest.isAfter(_currentTime().subtract(const Duration(hours: 24)));
  }

  SummaryDateRange _everything(_ReportBounds bounds) {
    return SummaryDateRange(start: bounds.start, end: bounds.end);
  }

  SummaryDateRange _recentRange(_ReportBounds bounds, int days) {
    // The preset window intersected with today: it can begin before any
    // record exists (the missingness list then says exactly what is blank)
    // but it never ends past the current date.
    final start = LocalDate.fromDateTime(
      _currentTime().subtract(Duration(days: days)),
    );
    return SummaryDateRange(start: start, end: bounds.end);
  }

  SummaryDateRange? _clampedCustom(_ReportBounds bounds) {
    final custom = _customRange;
    if (custom == null) return null;
    final today = bounds.end;
    var start = custom.start.isAfter(today) ? today : custom.start;
    final end = custom.end.isAfter(today) ? today : custom.end;
    if (start.isAfter(end)) start = end;
    return SummaryDateRange(start: start, end: end);
  }

  SummaryDateRange _resolveRange(_ReportBounds bounds) {
    return switch (_preset) {
      _RangePreset.lastThreeMonths => _recentRange(bounds, 92),
      _RangePreset.lastSixMonths => _recentRange(bounds, 183),
      _RangePreset.lastYear => _recentRange(bounds, 365),
      _RangePreset.everything => _everything(bounds),
      _RangePreset.custom => _clampedCustom(bounds) ?? _everything(bounds),
    };
  }

  String get _presetLabel {
    return switch (_preset) {
      _RangePreset.lastThreeMonths => 'Last 3 months',
      _RangePreset.lastSixMonths => 'Last 6 months',
      _RangePreset.lastYear => 'Last year',
      _RangePreset.everything => 'All records',
      _RangePreset.custom => 'Custom range',
    };
  }

  Future<void> _pickCustomRange(_ReportBounds bounds) async {
    final first = DateTime(
      bounds.start.year,
      bounds.start.month,
      bounds.start.day,
    );
    // The picker's last selectable date is today — a report range never
    // reaches into the future.
    final last = DateTime(bounds.end.year, bounds.end.month, bounds.end.day);
    final current = _clampedCustom(bounds);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: first,
      lastDate: last,
      initialDateRange: current == null
          ? null
          : DateTimeRange(
              start: DateTime(
                current.start.year,
                current.start.month,
                current.start.day,
              ),
              end: DateTime(
                current.end.year,
                current.end.month,
                current.end.day,
              ),
            ),
      helpText: 'Choose the report range',
      saveText: 'Use this range',
    );
    if (picked == null || !mounted) return;
    await ExperienceHaptics.pick();
    final today = bounds.end;
    var start = LocalDate.fromDateTime(picked.start);
    var end = LocalDate.fromDateTime(picked.end);
    if (end.isAfter(today)) end = today;
    if (start.isAfter(end)) start = end;
    setState(() {
      _preset = _RangePreset.custom;
      _customRange = SummaryDateRange(start: start, end: end);
    });
  }

  // -------------------------------------------------------------------------
  // Commitment — the boundary actions and gated presets open Plus through
  // the typed callback; activation unlocks locally and continues the
  // original intent. Dismissal abandons nothing: preset, custom range, and
  // note selection all live underneath the sheet.
  // -------------------------------------------------------------------------

  PlusOutcomeContext _rangeOutcomeFor(
    _RangePreset preset,
    int completedCycles,
  ) {
    final cycleWord = completedCycles == 1 ? 'cycle' : 'cycles';
    return switch (preset) {
      _RangePreset.lastSixMonths => const PlusOutcomeContext.seeAllCycles(
        headline: 'Compare 6 months of cycle evidence',
        rangeId: 'lastSixMonths',
      ),
      _RangePreset.lastYear => const PlusOutcomeContext.seeAllCycles(
        headline: 'Compare a year of cycle evidence',
        rangeId: 'lastYear',
      ),
      _RangePreset.custom => const PlusOutcomeContext.seeAllCycles(
        headline: 'Choose a report range',
        rangeId: 'custom',
        opensDateRangePicker: true,
      ),
      _RangePreset.everything ||
      _RangePreset.lastThreeMonths => PlusOutcomeContext.seeAllCycles(
        headline: 'Compare all $completedCycles completed $cycleWord',
        rangeId: 'everything',
      ),
    };
  }

  _RangePreset? _presetFromRangeId(String? rangeId) {
    return switch (rangeId) {
      'lastSixMonths' => _RangePreset.lastSixMonths,
      'lastYear' => _RangePreset.lastYear,
      'everything' => _RangePreset.everything,
      'custom' => _RangePreset.custom,
      _ => null,
    };
  }

  Future<void> _openCommitment(PlusOutcomeContext outcomeContext) async {
    final typed = widget.onOpenPlusWithContext;
    if (typed == null) {
      // Compatibility fallback: no typed continuation is possible, so the
      // shell's route opens Plus and nothing underneath changes.
      widget.onOpenPlus?.call();
      return;
    }
    final result = await typed(outcomeContext);
    if (!mounted || result == null || !result.isActivated) return;
    // The sheet already played the Saved Rhythm haptic; Reports sets local
    // access, leaves one factual acknowledgment, and continues the intent.
    setState(() {
      _plusActivated = true;
      _ackLine = 'Plus is active.';
    });
    final intent = result.intent;
    if (intent == null || intent.kind != PlusOutcomeIntentKind.seeAllCycles) {
      // Export intent: the export panel is now unlocked. The export itself
      // still requires the user's deliberate format tap.
      return;
    }
    final preset = _presetFromRangeId(intent.rangeId);
    if (intent.opensDateRangePicker || preset == _RangePreset.custom) {
      final input = _input;
      if (input == null) return;
      // A custom range purchase returns here and then opens the picker.
      await _pickCustomRange(_boundsOf(input));
      return;
    }
    if (preset != null && preset != _preset) {
      setState(() => _preset = preset);
    }
  }

  Future<void> _export(
    SummaryDateRange range,
    ReportExportFormat format,
  ) async {
    if (_exporting) return;
    setState(() {
      _exporting = true;
      _lastAttemptedFormat = format;
      _receipt = null;
      _ackLine = null;
    });
    try {
      final receipt = await widget.port.export(
        range: range,
        selectedNoteIds: Set<String>.unmodifiable(_selectedNoteIds),
        format: format,
      );
      if (!mounted) return;
      String? ack;
      if (receipt.outcome == ExperienceFileOutcome.shared ||
          receipt.outcome == ExperienceFileOutcome.savedOnly) {
        // Saved Rhythm, report kind: light haptic + one concise line under
        // the session silence rule.
        ack = await ExperienceFoundation.savedRhythm(SavedRhythmKind.report);
        if (!mounted) return;
      }
      setState(() {
        _receipt = receipt;
        _ackLine = ack;
        if (receipt.outcome == ExperienceFileOutcome.shared ||
            receipt.outcome == ExperienceFileOutcome.savedOnly) {
          _lastSuccessAt = DateTime.now();
          _lastSuccessOutcome = receipt.outcome;
        }
      });
    } catch (_) {
      // The port reports routine failures as a `failed` receipt; a thrown
      // error gets the same calm treatment. No haptics for errors.
      if (!mounted) return;
      setState(() {
        _receipt = const ExperienceFileReceipt(
          outcome: ExperienceFileOutcome.failed,
          message:
              'The export did not finish. Your records are safe on this device.',
        );
      });
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  void _backToRecords() {
    final callback = widget.onOpenSourceRecords;
    if (callback != null) {
      callback();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: SafeArea(child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    final input = _input;
    final error = _loadError;
    if (input == null && error == null) {
      return const _ReportsSkeleton();
    }
    if (error != null) {
      return _LoadErrorPanel(onRetry: _load);
    }
    return _buildLoaded(context, input!);
  }

  Widget _buildLoaded(BuildContext context, SummaryExportInput input) {
    final bounds = _boundsOf(input);
    // One resolved range feeds the printed label, the preview, and the
    // export port call — the printed range always matches the export.
    final range = _resolveRange(bounds);
    final summary = buildCycleAndCareSummary(
      input: input,
      range: range,
      selectedNoteIds: _selectedNoteIds,
    );
    // One shared evidence contract owns starts, completed spans, in-range
    // counts, cycle days, and pre-period timing across report surfaces.
    final cycleEvidence = SummaryCycleEvidence.fromPeriodDays(input.periodDays);
    final completedSpans = cycleEvidence.completedCycles;
    final completedCycles = cycleEvidence.completedCycleCount;
    final completedSpansInRange = completedSpans
        .where((cycle) => cycle.overlaps(range))
        .toList(growable: false);
    final completedCyclesInRange = completedSpansInRange.length;
    final careAdjacent = _careAdjacent(input);
    final hasAccess = _hasClinicianAccess;
    // Contextual acquisition requires the artifact threshold (3+ completed
    // cycles), no recent Care, and a Plus route to open.
    final canAcquire =
        completedCycles >= 3 &&
        !careAdjacent &&
        (widget.onOpenPlusWithContext != null || widget.onOpenPlus != null);

    final twinMatrix = completedCyclesInRange >= 3
        ? TwinMatrixSummaryAdapter.fromSummary(
            summary: summary,
            exportTimestamp: summaryDateTimeLabel(_currentTime()),
          )
        : null;

    // Unselected notes are a user choice, not a gap in the record: that line
    // lives in the note-selection section, not the missingness card.
    final missingness = summary.missingness
        .where((line) => line != 'No user-selected notes included.')
        .toList();

    final inRangeNotes = input.notes
        .where((note) => range.contains(note.date))
        .toList();

    final cycleWord = completedCycles == 1 ? 'cycle' : 'cycles';

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        ExperienceSpacing.screenMargin,
        ExperienceSpacing.sm,
        ExperienceSpacing.screenMargin,
        ExperienceSpacing.scrollBottomPadding,
      ),
      children: <Widget>[
        Text(
          'A plain summary of what you recorded.',
          style: ExperienceType.title(ExperienceColors.ink),
        ),
        const SizedBox(height: ExperienceSpacing.xs),
        Text(
          'Choose a range, look through what is inside, then export on your '
          'terms. Nothing here is a diagnosis.',
          style: ExperienceType.bodySmall(ExperienceColors.inkSoft),
        ),
        if (_lastSuccessAt != null) ...<Widget>[
          const SizedBox(height: ExperienceSpacing.md),
          _ContinuityLine(
            lastSuccessAt: _lastSuccessAt!,
            outcome: _lastSuccessOutcome ?? ExperienceFileOutcome.savedOnly,
            onBackToRecords: _backToRecords,
          ),
        ],
        const SizedBox(height: ExperienceSpacing.lg),
        if (completedCycles == 0)
          // No range chips at zero completed cycles — the resolved range is
          // informational only.
          Semantics(
            label: 'Report range ${range.label}',
            child: Text(
              range.label,
              style: ExperienceType.data(
                ExperienceColors.inkSoft,
                size: 14,
                weight: FontWeight.w500,
              ),
            ),
          )
        else
          _RangeSection(
            preset: _preset,
            customRange: _customRange,
            rangeLabel: range.label,
            gated: (preset) =>
                !hasAccess && preset != _RangePreset.lastThreeMonths,
            onSelect: (preset) async {
              if (!hasAccess && preset != _RangePreset.lastThreeMonths) {
                // Gated presets stay tappable but never switch the range;
                // below the artifact threshold or near Care they stay quiet.
                if (!canAcquire) return;
                await _openCommitment(
                  _rangeOutcomeFor(preset, completedCycles),
                );
                return;
              }
              if (preset == _RangePreset.custom) {
                await _pickCustomRange(bounds);
                return;
              }
              await ExperienceHaptics.pick();
              setState(() => _preset = preset);
            },
          ),
        const SizedBox(height: ExperienceSpacing.md),
        const _DisclosureCard(),
        const SizedBox(height: ExperienceSpacing.md),
        // The real artifact is tiered by completed cycles inside the exact
        // selected range. Older cycles cannot inflate a narrow-range claim.
        if (completedCyclesInRange == 0)
          _NoCyclesCard(
            recordedDays: _recordedDays(input),
            hasCompletedCyclesOutsideRange: completedCycles > 0,
          )
        else if (completedCyclesInRange == 1) ...<Widget>[
          _PreviewSections(summary: summary),
          Semantics(
            container: true,
            child: Text(
              'One cycle cannot show recurrence.',
              style: ExperienceType.bodySmall(ExperienceColors.inkSoft),
            ),
          ),
        ] else if (completedCyclesInRange == 2) ...<Widget>[
          _TwoCycleComparison(
            spans: completedSpansInRange,
            summary: buildCycleAndCareSummary(
              input: input,
              range: SummaryDateRange(
                start: completedSpansInRange.first.start,
                end: completedSpansInRange.last.end,
              ),
              selectedNoteIds: const <String>{},
            ),
          ),
          const SizedBox(height: ExperienceSpacing.unit),
          Semantics(
            container: true,
            child: Text(
              'A third completed cycle in this range enables comparison.',
              textAlign: TextAlign.center,
              style: ExperienceType.caption(ExperienceColors.inkFaint),
            ),
          ),
        ] else ...<Widget>[
          const _CertaintyLegend(),
          const SizedBox(height: ExperienceSpacing.sm),
          _TwinMatrixSection(viewModel: twinMatrix!),
        ],
        // The boundary: immediately after the artifact, before notes,
        // auxiliary preview sections, and export details.
        if (completedCyclesInRange >= 3 &&
            !hasAccess &&
            canAcquire) ...<Widget>[
          const SizedBox(height: ExperienceSpacing.lg),
          _BoundaryBlock(
            rangePresetLabel: _presetLabel,
            completedCyclesInRange: completedCyclesInRange,
            totalCompletedCycles: completedCycles,
            onSeeAllCycles: () => _openCommitment(
              PlusOutcomeContext.seeAllCycles(
                headline: 'Compare all $completedCycles completed $cycleWord',
                rangeId: 'everything',
              ),
            ),
            onExport: () => _openCommitment(
              const PlusOutcomeContext.export(
                headline: 'Export as PDF for a clinician',
              ),
            ),
          ),
        ],
        if (completedCyclesInRange >= 1 && missingness.isNotEmpty) ...<Widget>[
          const SizedBox(height: ExperienceSpacing.md),
          _MissingnessCard(missingness: missingness),
        ],
        if (completedCyclesInRange >= 2) ...<Widget>[
          const SizedBox(height: ExperienceSpacing.md),
          _PreviewSections(summary: summary),
        ],
        const SizedBox(height: ExperienceSpacing.md),
        _NoteSelection(
          notes: inRangeNotes,
          totalNoteCount: input.notes.length,
          selectedNoteIds: _selectedNoteIds,
          onToggle: (noteId, selected) async {
            await ExperienceHaptics.pick();
            setState(() {
              if (selected) {
                _selectedNoteIds.add(noteId);
              } else {
                _selectedNoteIds.remove(noteId);
              }
            });
          },
        ),
        const SizedBox(height: ExperienceSpacing.lg),
        if (hasAccess)
          _ExportPanel(
            exporting: _exporting,
            onExport: (format) => _export(range, format),
          ),
        if (_receipt != null) ...<Widget>[
          const SizedBox(height: ExperienceSpacing.md),
          _ReceiptCard(
            receipt: _receipt!,
            onRetry: _receipt!.outcome == ExperienceFileOutcome.failed
                ? () => _export(
                    range,
                    _lastAttemptedFormat ?? ReportExportFormat.pdf,
                  )
                : null,
          ),
        ],
        const SizedBox(height: ExperienceSpacing.sm),
        SavedRhythmAckLine(line: _ackLine),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Range selection — the shared foundation selection treatment (warm fill,
// ink hairline, weight change), never a local accent wash. Gated presets
// stay tappable buttons with a "requires Plus" hint — never disabled, so the
// path stays explained.
// ---------------------------------------------------------------------------

class _RangeSection extends StatelessWidget {
  const _RangeSection({
    required this.preset,
    required this.customRange,
    required this.rangeLabel,
    required this.gated,
    required this.onSelect,
  });

  final _RangePreset preset;
  final SummaryDateRange? customRange;
  final String rangeLabel;
  final bool Function(_RangePreset preset) gated;
  final ValueChanged<_RangePreset> onSelect;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, _RangePreset value) {
      final selected = preset == value;
      final isGated = gated(value);
      return Semantics(
        hint: isGated ? 'Requires Letter Within Plus' : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: ExperienceSpacing.minTouchTarget,
          ),
          child: ChoiceChip(
            label: Text(label),
            selected: selected,
            onSelected: (_) => onSelect(value),
            showCheckmark: false,
            backgroundColor: ExperienceColors.surface,
            selectedColor: ExperienceColors.surfaceWarm,
            side: BorderSide(
              color: selected
                  ? ExperienceColors.inkSoft
                  : ExperienceColors.hairline,
              width: selected ? 1.2 : 1,
            ),
            labelStyle: selected
                ? ExperienceType.label(ExperienceColors.ink)
                : ExperienceType.bodySmall(ExperienceColors.inkSoft),
            shape: const RoundedRectangleBorder(
              borderRadius: ExperienceRadius.chipRadius,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Range', style: ExperienceType.headline(ExperienceColors.ink)),
        const SizedBox(height: ExperienceSpacing.xs),
        Wrap(
          spacing: ExperienceSpacing.unit,
          runSpacing: ExperienceSpacing.unit,
          children: <Widget>[
            chip('Last 3 months', _RangePreset.lastThreeMonths),
            chip('Last 6 months', _RangePreset.lastSixMonths),
            chip('Last year', _RangePreset.lastYear),
            chip('All records', _RangePreset.everything),
            chip(
              customRange == null ? 'Custom…' : 'Custom range',
              _RangePreset.custom,
            ),
          ],
        ),
        const SizedBox(height: ExperienceSpacing.unit),
        Semantics(
          label: 'Selected report range $rangeLabel',
          child: Text(
            rangeLabel,
            style: ExperienceType.data(
              ExperienceColors.inkSoft,
              size: 14,
              weight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Cycle tiers 0 and 1 — literal coverage, missingness stays missing. The
// word "pattern" never appears here.
// ---------------------------------------------------------------------------

class _NoCyclesCard extends StatelessWidget {
  const _NoCyclesCard({
    required this.recordedDays,
    required this.hasCompletedCyclesOutsideRange,
  });

  final int recordedDays;
  final bool hasCompletedCyclesOutsideRange;

  @override
  Widget build(BuildContext context) {
    final dayWord = recordedDays == 1 ? 'day' : 'days';
    final message = hasCompletedCyclesOutsideRange
        ? 'No completed cycles fall inside this range. Choose a wider range '
              'to compare earlier cycles.'
        : '$recordedDays period $dayWord recorded. One completed cycle is needed '
              'before this report can show timing.';
    return Semantics(
      container: true,
      label: message,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(ExperienceSpacing.md),
        decoration: BoxDecoration(
          color: ExperienceColors.surface,
          borderRadius: ExperienceRadius.cardRadius,
          border: Border.all(color: ExperienceColors.hairline),
          boxShadow: ExperienceShadows.card,
        ),
        child: ExcludeSemantics(
          child: Text(
            message,
            style: ExperienceType.body(ExperienceColors.ink),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cycle tier 2 — two real cycle timelines aligned to bleeding start. No
// trend, recurrence, or comparison claim is made; the Twin Matrix begins at
// three completed cycles.
// ---------------------------------------------------------------------------

final class _CycleTimelineEntry {
  const _CycleTimelineEntry({
    required this.dayOffset,
    required this.label,
    required this.period,
    this.detail,
  });

  final int dayOffset;
  final String label;
  final String? detail;
  final bool period;
}

class _TwoCycleComparison extends StatelessWidget {
  const _TwoCycleComparison({required this.spans, required this.summary});

  final List<SummaryCompletedCycle> spans;

  /// Summary built over the exact window covering both cycles, so each
  /// timeline shows its full real contents rather than a range-clipped view.
  final CycleAndCareSummary summary;

  List<_CycleTimelineEntry> _entriesFor(SummaryCompletedCycle span) {
    final entries = <_CycleTimelineEntry>[];
    final periodDays = summary.periodDays
        .where((day) => span.contains(day.date))
        .toList();
    for (final range in observedPeriodRanges(periodDays)) {
      final startOffset = range.start.epochDay - span.start.epochDay + 1;
      final endOffset = range.end.epochDay - span.start.epochDay + 1;
      entries.add(
        _CycleTimelineEntry(
          dayOffset: startOffset,
          label: 'Period',
          detail: startOffset == endOffset
              ? 'Day $startOffset'
              : 'Days $startOffset–$endOffset · ${range.dayCount} '
                    '${range.dayCount == 1 ? 'day' : 'days'}',
          period: true,
        ),
      );
    }
    for (final row in summary.healthRows) {
      if (!span.contains(row.date)) continue;
      entries.add(
        _CycleTimelineEntry(
          dayOffset: row.date.epochDay - span.start.epochDay + 1,
          label:
              '${_humanize(row.symptom.name)} · '
              '${_humanize(row.severity.name)}',
          detail: row.provenance.label,
          period: false,
        ),
      );
    }
    for (final row in summary.careRows) {
      if (!span.contains(row.date)) continue;
      entries.add(
        _CycleTimelineEntry(
          dayOffset: row.date.epochDay - span.start.epochDay + 1,
          label: row.actionLabel,
          detail: '${_humanize(row.outcome.name)} · ${row.provenance.label}',
          period: false,
        ),
      );
    }
    entries.sort((left, right) {
      final byDay = left.dayOffset.compareTo(right.dayOffset);
      if (byDay != 0) return byDay;
      if (left.period != right.period) return left.period ? -1 : 1;
      return left.label.compareTo(right.label);
    });
    return entries;
  }

  Widget _cycleCard(SummaryCompletedCycle span) {
    final entries = _entriesFor(span);
    return Semantics(
      container: true,
      label:
          'Cycle starting ${summaryDateLabel(span.start)}, '
          '${span.dayCount} days, ${entries.length} recorded entries',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(ExperienceSpacing.md),
        decoration: BoxDecoration(
          color: ExperienceColors.surface,
          borderRadius: ExperienceRadius.cardRadius,
          border: Border.all(color: ExperienceColors.hairline),
          boxShadow: ExperienceShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Cycle starting ${summaryDateLabel(span.start)}',
              style: ExperienceType.label(ExperienceColors.ink),
            ),
            const SizedBox(height: ExperienceSpacing.xs),
            Text(
              '${span.dayCount} ${span.dayCount == 1 ? 'day' : 'days'}',
              style: ExperienceType.data(
                ExperienceColors.inkSoft,
                size: 13,
                weight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: ExperienceSpacing.sm),
            if (entries.isEmpty)
              Text(
                'Nothing recorded inside this cycle.',
                style: ExperienceType.bodySmall(ExperienceColors.inkFaint),
              )
            else
              for (final entry in entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: ExperienceSpacing.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SizedBox(
                        width: 48,
                        child: Text(
                          'Day ${entry.dayOffset}',
                          style: ExperienceType.data(
                            ExperienceColors.inkSoft,
                            size: 12,
                            weight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: ExperienceSpacing.unit),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                if (entry.period) ...<Widget>[
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: ExperienceColors.phasePeriod,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Flexible(
                                  child: Text(
                                    entry.label,
                                    style: ExperienceType.bodySmall(
                                      ExperienceColors.ink,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (entry.detail != null)
                              Text(
                                entry.detail!,
                                style: ExperienceType.caption(
                                  ExperienceColors.inkFaint,
                                ),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final first = _cycleCard(spans[0]);
    final second = _cycleCard(spans[1]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Two completed cycles in this range',
          style: ExperienceType.headline(ExperienceColors.ink),
        ),
        const SizedBox(height: ExperienceSpacing.xs),
        Text(
          'Aligned to each bleeding start.',
          style: ExperienceType.caption(ExperienceColors.inkSoft),
        ),
        const SizedBox(height: ExperienceSpacing.sm),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 560) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: first),
                  const SizedBox(width: ExperienceSpacing.sm),
                  Expanded(child: second),
                ],
              );
            }
            return Column(
              children: <Widget>[
                first,
                const SizedBox(height: ExperienceSpacing.sm),
                second,
              ],
            );
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Disclosures and missingness — rendered once, plainly, never repeated
// defensively. Note-selection status lives in the note section, not here:
// unselected notes are a choice, not missing health data.
// ---------------------------------------------------------------------------

class _DisclosureCard extends StatelessWidget {
  const _DisclosureCard();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsets.all(ExperienceSpacing.md),
        decoration: BoxDecoration(
          color: ExperienceColors.surface,
          borderRadius: ExperienceRadius.cardRadius,
          border: Border.all(color: ExperienceColors.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'What this report is — and is not',
              style: ExperienceType.label(ExperienceColors.ink),
            ),
            const SizedBox(height: ExperienceSpacing.unit),
            Text(
              CycleAndCareSummary.nonDiagnosticDisclosure,
              style: ExperienceType.bodySmall(ExperienceColors.inkSoft),
            ),
            const SizedBox(height: ExperienceSpacing.unit),
            Text(
              CycleAndCareSummary.exclusionDisclosure,
              style: ExperienceType.bodySmall(ExperienceColors.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}

class _MissingnessCard extends StatelessWidget {
  const _MissingnessCard({required this.missingness});

  final List<String> missingness;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ExperienceSpacing.md),
      decoration: BoxDecoration(
        color: ExperienceColors.surfaceWarm,
        borderRadius: ExperienceRadius.cardRadius,
        border: Border.all(color: ExperienceColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Blank in this range',
            style: ExperienceType.label(ExperienceColors.ink),
          ),
          const SizedBox(height: ExperienceSpacing.unit),
          for (final line in missingness)
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
                        color: ExperienceColors.inkFaint,
                      ),
                    ),
                  ),
                  const SizedBox(width: ExperienceSpacing.unit),
                  Expanded(
                    child: Text(
                      line,
                      style: ExperienceType.bodySmall(ExperienceColors.inkSoft),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Certainty legend — observed solid, estimated dashed, missing dot-grid.
// Neutral ink here: the legend belongs to no chart family. It renders only
// alongside the matrix.
// ---------------------------------------------------------------------------

class _CertaintyLegend extends StatelessWidget {
  const _CertaintyLegend();

  @override
  Widget build(BuildContext context) {
    Widget swatch(ExperienceCertainty certainty) {
      const size = 16.0;
      final texture = CertaintyTexture.of(certainty);
      final Widget box = switch (certainty) {
        ExperienceCertainty.observed => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: ExperienceColors.inkSoft,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: ExperienceColors.inkSoft),
          ),
        ),
        ExperienceCertainty.estimated => CustomPaint(
          painter: _DashedBorderPainter(
            color: ExperienceColors.inkSoft.withValues(
              alpha: texture.borderOpacity,
            ),
            radius: 4,
            dashPattern: texture.dashPattern ?? const <double>[4, 3],
          ),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: ExperienceColors.inkSoft.withValues(
                alpha: texture.fillOpacity * 0.3,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        ExperienceCertainty.unknown => CustomPaint(
          painter: const DotGridPainter(spacing: 5, dotRadius: 0.8),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: ExperienceColors.inkFaint.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
      };
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          box,
          const SizedBox(width: 6),
          Text(
            CertaintyTexture.semanticsLabel(certainty),
            style: ExperienceType.caption(ExperienceColors.inkSoft),
          ),
        ],
      );
    }

    return Wrap(
      spacing: ExperienceSpacing.md,
      runSpacing: ExperienceSpacing.unit,
      children: <Widget>[
        swatch(ExperienceCertainty.observed),
        swatch(ExperienceCertainty.estimated),
        swatch(ExperienceCertainty.unknown),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Twin Matrix — the numerical center of the report, rendered only at three
// or more completed cycles. Bars and scores are cycle-balanced averages of
// confirmed 1–5 ratings on two observed timing windows. Blank means no
// observation; gaps are never filled. Difficult Today check-ins share the
// axis as neutral open rings: timing evidence only, never scored, never
// averaged, never mapped to a symptom cluster, never recolored.
//
// The canvas is a 28-day ledger: cluster labels stack slash-joined domains
// as intentional line breaks (never a trailing-slash truncation), severity
// bars anchor to each row's baseline and read against a faint severity-5
// shelf line, and the period boundary is the one emphatic ink hinge with
// serif caps. Score numerals appear only when day columns are wide enough
// to stay readable; bar heights carry the steps everywhere else. Horizontal
// panning survives as the large-text (and very-narrow-canvas) escape hatch,
// with the axis captions travelling inside the scroll region.
// ---------------------------------------------------------------------------

class _TwinMatrixSection extends StatelessWidget {
  const _TwinMatrixSection({required this.viewModel});

  final TwinMatrixViewModel viewModel;

  /// Large-text escape hatch: beyond ~1.3× text scale — or whenever the day
  /// columns would collapse below readability — the canvas keeps this
  /// minimum width and pans horizontally instead of clipping.
  static const double _scrollCanvasWidth = 560;

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    return Container(
      padding: const EdgeInsets.all(ExperienceSpacing.md),
      decoration: BoxDecoration(
        color: ExperienceColors.surface,
        borderRadius: ExperienceRadius.cardRadius,
        border: Border.all(color: ExperienceColors.hairline),
        boxShadow: ExperienceShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Expanded(
                child: Text(
                  'Cyclical symptom matrix',
                  style: ExperienceType.headline(ExperienceColors.ink),
                ),
              ),
              Text(
                '1–5',
                style: ExperienceType.data(ExperienceColors.inkSoft, size: 14),
              ),
              const SizedBox(width: 4),
              Text(
                'scale',
                style: ExperienceType.caption(ExperienceColors.inkSoft),
              ),
            ],
          ),
          const SizedBox(height: ExperienceSpacing.xs),
          Text(
            'Each bar is a cycle-balanced average of confirmed ratings at '
            'that timing. Blank means no observation; nothing is copied '
            'across the period boundary.',
            style: ExperienceType.caption(ExperienceColors.inkSoft),
          ),
          const SizedBox(height: ExperienceSpacing.unit),
          Text(
            '${vm.mappedObservations} of ${vm.totalObservations} confirmed '
            'records map to these windows · ${vm.cyclesCovered} observed '
            '${vm.cyclesCovered == 1 ? 'cycle' : 'cycles'} · '
            '${vm.sameDayObservations} same-day · '
            '${vm.laterRecallObservations} later recall',
            style: ExperienceType.caption(ExperienceColors.inkFaint),
          ),
          const SizedBox(height: ExperienceSpacing.sm),
          LayoutBuilder(
            builder: (context, constraints) {
              final textScale = MediaQuery.textScalerOf(context).scale(1);
              var width = constraints.maxWidth;
              var labelWidth = (width * 0.22).clamp(74.0, 124.0);
              var dayWidth = (width - labelWidth) / 28;
              // Panning keeps the canvas at a readable fixed width when text
              // is scaled up or the available width would crush the day
              // columns below a legible step.
              final panning =
                  (textScale > 1.3 || dayWidth < 7.5) &&
                  constraints.maxWidth < _scrollCanvasWidth;
              if (panning) {
                width = _scrollCanvasWidth;
                labelWidth = (width * 0.22).clamp(74.0, 124.0);
                dayWidth = (width - labelWidth) / 28;
              }
              // Score numerals drop below readability on narrow widths;
              // bar heights against the shelf line remain, and cells stay
              // blank-honest.
              final paintScores = dayWidth >= 13;
              final height =
                  _TwinMatrixCanvasPainter.axisHeight +
                  _TwinMatrixCanvasPainter.rowHeight *
                      (vm.clusters.isEmpty ? 1 : vm.clusters.length) +
                  _TwinMatrixCanvasPainter.laneHeight;
              final canvasAndCaptions = SizedBox(
                width: width,
                child: Column(
                  children: <Widget>[
                    Semantics(
                      label: vm.accessibilitySummary,
                      child: CustomPaint(
                        painter: _TwinMatrixCanvasPainter(
                          viewModel: vm,
                          labelWidth: labelWidth,
                          paintScores: paintScores,
                        ),
                        size: Size(width, height),
                      ),
                    ),
                    const SizedBox(height: ExperienceSpacing.unit),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            '◂ days before a recorded period',
                            style: ExperienceType.caption(
                              ExperienceColors.inkFaint,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'cycle days after a period starts ▸',
                            textAlign: TextAlign.end,
                            style: ExperienceType.caption(
                              ExperienceColors.inkFaint,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
              if (panning) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: canvasAndCaptions,
                );
              }
              return canvasAndCaptions;
            },
          ),
          if (vm.qualitativeCheckIns.isNotEmpty) ...<Widget>[
            const SizedBox(height: ExperienceSpacing.sm),
            Text(
              'Difficult Today check-ins',
              style: ExperienceType.label(ExperienceColors.ink),
            ),
            const SizedBox(height: ExperienceSpacing.xs),
            Text(
              'Timing evidence only. The open rings above mark when these '
              'happened — they are never scored, never averaged into the '
              'bars, and stay separate from any symptom recorded the same '
              'day.',
              style: ExperienceType.caption(ExperienceColors.inkSoft),
            ),
            const SizedBox(height: ExperienceSpacing.unit),
            for (final marker in vm.qualitativeCheckIns)
              Padding(
                padding: const EdgeInsets.only(bottom: ExperienceSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: ExperienceColors.inkSoft,
                            width: 1.1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: ExperienceSpacing.unit),
                    Expanded(
                      child: Text(
                        _checkInEvidenceLabel(marker),
                        style: ExperienceType.bodySmall(
                          ExperienceColors.inkSoft,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// The shared timing position of a check-in on the matrix axis, or null when
/// it cannot be anchored to an observed period. Check-ins with no anchor are
/// still listed in words; they simply get no ring.
int? _checkInRelativeDay(TwinMatrixCheckInMarker marker) {
  final before = marker.daysBeforeMenses;
  if (before != null && before >= -14 && before <= -1) return before;
  final cycle = marker.cycleDay;
  if (cycle != null && cycle >= 1 && cycle <= 14) return cycle;
  return null;
}

String _checkInTimingLabel(TwinMatrixCheckInMarker marker) {
  final day = _checkInRelativeDay(marker);
  if (day == null) return 'not anchored to an observed period';
  if (day < 0) {
    final count = day.abs();
    return '$count ${count == 1 ? 'day' : 'days'} before a recorded period';
  }
  return 'cycle day $day';
}

String _checkInEvidenceLabel(TwinMatrixCheckInMarker marker) {
  final count = marker.occurrenceCount;
  final occurrence = count > 1 ? ' ×$count' : '';
  final recorded = count > 1
      ? summaryDateLabel(LocalDate.fromDateTime(marker.recordedAt.toLocal()))
      : summaryDateTimeLabel(marker.recordedAt);
  return '${marker.state.label}$occurrence — '
      '${_checkInTimingLabel(marker)} · recorded $recorded';
}

/// Display formatting for matrix cluster labels: slash-joined domain pairs
/// ("mood/irritability") become intentional stacked lines so no trailing
/// slash reads as truncation. The view-model label itself is never touched.
String _matrixLabelText(String label) {
  String capitalize(String text) =>
      text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
  final parts = label
      .split('/')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.length <= 1) return capitalize(label.trim());
  return parts.map(capitalize).join('\n');
}

/// Canvas for the matrix grid, bars, scores, and the neutral check-in ring
/// lane. Defined locally: this surface owns its own compact rendering and
/// shares nothing visual with the printable clinical report.
class _TwinMatrixCanvasPainter extends CustomPainter {
  const _TwinMatrixCanvasPainter({
    required this.viewModel,
    required this.labelWidth,
    this.paintScores = true,
  });

  final TwinMatrixViewModel viewModel;

  /// Width of the cluster-label gutter, resolved by the section so the
  /// widget tree and this canvas never disagree about the day geometry.
  final double labelWidth;

  /// False at narrow widths where a score numeral would no longer be
  /// readable; bars still render against the shelf line and blanks stay
  /// blank.
  final bool paintScores;

  static const double axisHeight = 20;
  static const double rowHeight = 46;
  static const double laneHeight = 22;

  @override
  void paint(Canvas canvas, Size size) {
    final clusters = viewModel.clusters;
    final rowCount = clusters.isEmpty ? 1 : clusters.length;
    final rowsHeight = size.height - axisHeight - laneHeight;
    final perRow = rowsHeight / rowCount;
    final halfWidth = (size.width - labelWidth) / 2;
    final dayWidth = halfWidth / 14;
    final rowsBottom = axisHeight + rowsHeight;

    const barGap = 4.0;
    final barMaxHeight = perRow * 0.56;

    final hairline = Paint()
      ..color = ExperienceColors.hairline
      ..strokeWidth = 1;
    final fineHairline = Paint()
      ..color = ExperienceColors.hairline
      ..strokeWidth = 0.5;

    // Alternating row washes keep long rows scannable without adding lines.
    final altPaint = Paint()..color = ExperienceColors.surfaceWarm;
    for (var row = 0; row < clusters.length; row++) {
      if (row.isOdd) {
        canvas.drawRect(
          Rect.fromLTWH(0, axisHeight + row * perRow, size.width, perRow),
          altPaint,
        );
      }
    }

    // Row structure: a faint severity-5 shelf across the day region gives
    // every bar the same calibration, and each row's baseline is the line
    // its bars stand on.
    final shelfPaint = Paint()
      ..color = ExperienceColors.hairline.withValues(alpha: 0.65)
      ..strokeWidth = 0.5;
    for (var row = 0; row < rowCount; row++) {
      final baseline = axisHeight + (row + 1) * perRow;
      canvas.drawLine(
        Offset(labelWidth + 1, baseline - barGap - barMaxHeight),
        Offset(size.width - 1, baseline - barGap - barMaxHeight),
        shelfPaint,
      );
      canvas.drawLine(
        Offset(0, baseline),
        Offset(size.width, baseline),
        hairline,
      );
    }

    // Day structure: full-height separators every two days, short ticks on
    // the top edge for single days — the axis reads at a glance without
    // filling the cells with lines.
    for (var day = 0; day <= 14; day++) {
      for (final x in <double>[
        labelWidth + day * dayWidth,
        labelWidth + halfWidth + day * dayWidth,
      ]) {
        if (day.isEven) {
          canvas.drawLine(
            Offset(x, axisHeight),
            Offset(x, rowsBottom),
            fineHairline,
          );
        } else {
          canvas.drawLine(
            Offset(x, axisHeight),
            Offset(x, axisHeight + 3),
            fineHairline,
          );
        }
      }
    }

    // Frame: label gutter edge, top edge beneath the axis numerals, and the
    // right edge closing the day region.
    canvas.drawLine(
      Offset(labelWidth, axisHeight),
      Offset(labelWidth, rowsBottom),
      hairline,
    );
    canvas.drawLine(
      Offset(labelWidth, axisHeight),
      Offset(size.width, axisHeight),
      hairline,
    );
    canvas.drawLine(
      Offset(size.width - 0.5, axisHeight),
      Offset(size.width - 0.5, rowsBottom),
      fineHairline,
    );

    void drawCentered(String text, double x, double y, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, Offset(x - painter.width / 2, y));
    }

    final numberStyle = ExperienceType.data(ExperienceColors.inkSoft, size: 9);
    for (var index = 0; index < 14; index += 2) {
      drawCentered(
        '−${14 - index}',
        labelWidth + index * dayWidth + dayWidth / 2,
        5,
        numberStyle,
      );
      drawCentered(
        '${1 + index}',
        labelWidth + halfWidth + index * dayWidth + dayWidth / 2,
        5,
        numberStyle,
      );
    }

    final labelStyle = ExperienceType.caption(
      ExperienceColors.ink,
    ).copyWith(fontWeight: FontWeight.w600, fontSize: 11.5, height: 1.25);
    final scoreStyle = ExperienceType.data(ExperienceColors.ink, size: 8.5);
    final barPaint = Paint()..color = ExperienceColors.ink;
    final barWidth = (dayWidth * 0.58).clamp(3.0, 10.0);

    void drawCell(TwinMatrixCell cell, double x, double barBottom) {
      final severity = cell.severity;
      if (severity == null) return;
      final height = (severity / 5.0).clamp(0.05, 1.0) * barMaxHeight;
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTRB(
            x - barWidth / 2,
            barBottom - height,
            x + barWidth / 2,
            barBottom,
          ),
          topLeft: const Radius.circular(1.5),
          topRight: const Radius.circular(1.5),
        ),
        barPaint,
      );
      if (!paintScores) return;
      final score = TextPainter(
        text: TextSpan(text: severity.toStringAsFixed(1), style: scoreStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      score.paint(
        canvas,
        Offset(x - score.width / 2, barBottom - height - score.height - 1.5),
      );
    }

    for (var row = 0; row < clusters.length; row++) {
      final cluster = clusters[row];
      final centerY = axisHeight + row * perRow + perRow / 2;
      final barBottom = axisHeight + (row + 1) * perRow - barGap;
      final label = TextPainter(
        text: TextSpan(
          text: _matrixLabelText(cluster.label),
          style: labelStyle,
        ),
        textDirection: TextDirection.ltr,
        maxLines: 3,
        ellipsis: '…',
      )..layout(maxWidth: labelWidth - 14);
      label.paint(canvas, Offset(4, centerY - label.height / 2));
      for (var index = 0; index < 14; index++) {
        drawCell(
          cluster.beforePeriodCells[index],
          labelWidth + index * dayWidth + dayWidth / 2,
          barBottom,
        );
        drawCell(
          cluster.cycleCells[index],
          labelWidth + halfWidth + index * dayWidth + dayWidth / 2,
          barBottom,
        );
      }
    }

    // The period boundary is the one emphatic vertical: the matrix's hinge,
    // drawn above the bars with serif caps so the two 14-day windows read as
    // joined but never blended.
    final centerX = labelWidth + halfWidth;
    final boundaryPaint = Paint()
      ..color = ExperienceColors.ink
      ..strokeWidth = 1.4;
    const boundaryTop = axisHeight - 4;
    final boundaryBottom = rowsBottom + laneHeight - 3;
    canvas.drawLine(
      Offset(centerX, boundaryTop),
      Offset(centerX, boundaryBottom),
      boundaryPaint,
    );
    canvas.drawLine(
      Offset(centerX - 5, boundaryTop),
      Offset(centerX + 5, boundaryTop),
      boundaryPaint,
    );
    canvas.drawLine(
      Offset(centerX - 5, boundaryBottom),
      Offset(centerX + 5, boundaryBottom),
      boundaryPaint,
    );

    // Check-in lane: open rings, one per difficult Today check-in, all in the
    // same neutral ink. No numbers, no fills, no state color — position on
    // the shared axis is the whole message.
    final laneCenterY = rowsBottom + laneHeight / 2;
    final ringPaint = Paint()
      ..color = ExperienceColors.inkSoft
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final observedCheckInDays = <int>{
      for (final marker in viewModel.qualitativeCheckIns)
        if (_checkInRelativeDay(marker) case final int day) day,
    };
    for (final day in observedCheckInDays) {
      final column = day < 0 ? day + 14 : day - 1;
      final baseX = day < 0
          ? labelWidth + column * dayWidth + dayWidth / 2
          : labelWidth + halfWidth + column * dayWidth + dayWidth / 2;
      canvas.drawCircle(Offset(baseX, laneCenterY), 4, ringPaint);
    }
  }

  @override
  bool shouldRepaint(_TwinMatrixCanvasPainter oldDelegate) =>
      viewModel != oldDelegate.viewModel ||
      paintScores != oldDelegate.paintScores ||
      labelWidth != oldDelegate.labelWidth;
}

// ---------------------------------------------------------------------------
// Summary preview — counts in sans tabular figures, rows fully readable.
// Long sections cap their visible rows; the export itself is never capped.
// At one completed cycle these sections are the whole artifact.
// ---------------------------------------------------------------------------

class _PreviewSections extends StatelessWidget {
  const _PreviewSections({required this.summary});

  final CycleAndCareSummary summary;

  static const int _visibleRowCap = 8;

  List<Widget> _capped<T>(
    List<T> rows,
    Widget Function(T row) buildRow,
    String moreLabel,
  ) {
    if (rows.length <= _visibleRowCap) {
      return <Widget>[for (final row in rows) buildRow(row)];
    }
    final remaining = rows.length - _visibleRowCap;
    return <Widget>[
      for (final row in rows.take(_visibleRowCap)) buildRow(row),
      Padding(
        padding: const EdgeInsets.only(top: ExperienceSpacing.unit),
        child: Text(
          '+ $remaining more $moreLabel in the export',
          style: ExperienceType.caption(ExperienceColors.inkFaint),
        ),
      ),
    ];
  }

  Widget _blankMark(String semanticsLabel) {
    return Semantics(
      label: semanticsLabel,
      child: CustomPaint(
        painter: const DotGridPainter(),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: ExperienceRadius.chipRadius,
            border: Border.all(
              color: ExperienceColors.inkFaint.withValues(alpha: 0.4),
            ),
          ),
        ),
      ),
    );
  }

  Widget _section({
    required String title,
    required int count,
    required String unit,
    required List<Widget> rows,
    required String emptySemantics,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: ExperienceSpacing.md),
      padding: const EdgeInsets.all(ExperienceSpacing.md),
      decoration: BoxDecoration(
        color: ExperienceColors.surface,
        borderRadius: ExperienceRadius.cardRadius,
        border: Border.all(color: ExperienceColors.hairline),
        boxShadow: ExperienceShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: ExperienceType.headline(ExperienceColors.ink),
                ),
              ),
              Text(
                '$count',
                style: ExperienceType.data(ExperienceColors.inkSoft, size: 14),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: ExperienceType.caption(ExperienceColors.inkSoft),
              ),
            ],
          ),
          const SizedBox(height: ExperienceSpacing.sm),
          if (rows.isEmpty) _blankMark(emptySemantics) else ...rows,
        ],
      ),
    );
  }

  Widget _periodRow(SummaryObservedPeriodRange range) {
    final single = range.start.compareTo(range.end) == 0;
    final label = single
        ? summaryDateLabel(range.start)
        : '${summaryDateLabel(range.start)} – ${summaryDateLabel(range.end)}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ExperienceSpacing.xs),
      child: Row(
        children: <Widget>[
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: ExperienceColors.phasePeriod,
            ),
          ),
          const SizedBox(width: ExperienceSpacing.unit),
          Expanded(
            child: Text(
              label,
              style: ExperienceType.bodySmall(ExperienceColors.ink),
            ),
          ),
          Text(
            '${range.dayCount} ${range.dayCount == 1 ? 'day' : 'days'}',
            style: ExperienceType.data(
              ExperienceColors.inkSoft,
              size: 13,
              weight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _predictionRow(SummaryPredictionRange prediction) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ExperienceSpacing.xs),
      child: CustomPaint(
        painter: const _DashedBorderPainter(
          color: ExperienceColors.accentGravity,
          radius: ExperienceRadius.chip,
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: ExperienceColors.accentGravity.withValues(alpha: 0.08),
            borderRadius: ExperienceRadius.chipRadius,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${summaryDateLabel(prediction.start)} – '
                  '${summaryDateLabel(prediction.end)}\n'
                  '${prediction.sourceLabel}',
                  style: ExperienceType.bodySmall(ExperienceColors.ink),
                ),
              ),
              Text(
                CertaintyTexture.estimated.caption ?? 'est.',
                style: ExperienceType.caption(ExperienceColors.accentGravity),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _healthRow(SummaryHealthRow row) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ExperienceSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${summaryDateLabel(row.date)} · ${_humanize(row.symptom.name)} · '
            '${_humanize(row.severity.name)}',
            style: ExperienceType.bodySmall(ExperienceColors.ink),
          ),
          Text(
            row.provenance.label,
            style: ExperienceType.caption(ExperienceColors.inkFaint),
          ),
        ],
      ),
    );
  }

  Widget _careRow(SummaryCareRow row) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ExperienceSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${summaryDateLabel(row.date)} · ${row.actionLabel}',
            style: ExperienceType.bodySmall(ExperienceColors.ink),
          ),
          Text(
            '${_humanize(row.outcome.name)} · ${row.provenance.label}',
            style: ExperienceType.caption(ExperienceColors.inkFaint),
          ),
        ],
      ),
    );
  }

  Widget _noteRow(SummarySelectableNote note) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ExperienceSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${summaryDateLabel(note.date)} · ${note.label}',
            style: ExperienceType.bodySmall(ExperienceColors.ink),
          ),
          Text(
            note.text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: ExperienceType.caption(ExperienceColors.inkSoft),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final periodRanges = observedPeriodRanges(summary.periodDays);
    return Column(
      children: <Widget>[
        _section(
          title: 'Observed period days',
          count: summary.periodDays.length,
          unit: 'days',
          emptySemantics: 'Missing — no observed period days in this range',
          rows: _capped(periodRanges, _periodRow, 'ranges'),
        ),
        _section(
          title: 'Estimated windows',
          count: summary.predictions.length,
          unit: 'ranges',
          emptySemantics: 'Missing — no estimated windows in this range',
          rows: _capped(summary.predictions, _predictionRow, 'windows'),
        ),
        _section(
          title: 'Health records',
          count: summary.healthRows.length,
          unit: 'records',
          emptySemantics: 'Missing — no confirmed health records in this range',
          rows: _capped(summary.healthRows, _healthRow, 'records'),
        ),
        _section(
          title: 'Care events',
          count: summary.careRows.length,
          unit: 'events',
          emptySemantics: 'Missing — no saved Care events in this range',
          rows: _capped(summary.careRows, _careRow, 'events'),
        ),
        _section(
          title: 'Notes you selected',
          count: summary.notes.length,
          unit: 'notes',
          emptySemantics: 'Missing — no notes selected for this export',
          rows: _capped(summary.notes, _noteRow, 'notes'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Explicit note selection — a saved note is never included until chosen.
// Unselected notes are a user choice, not a gap in the record, so the
// selection state lives here rather than in the missingness card.
// ---------------------------------------------------------------------------

class _NoteSelection extends StatelessWidget {
  const _NoteSelection({
    required this.notes,
    required this.totalNoteCount,
    required this.selectedNoteIds,
    required this.onToggle,
  });

  final List<SummarySelectableNote> notes;
  final int totalNoteCount;
  final Set<String> selectedNoteIds;
  final void Function(String noteId, bool selected) onToggle;

  @override
  Widget build(BuildContext context) {
    final anySelected = notes.any((note) => selectedNoteIds.contains(note.id));
    return Container(
      padding: const EdgeInsets.all(ExperienceSpacing.md),
      decoration: BoxDecoration(
        color: ExperienceColors.surface,
        borderRadius: ExperienceRadius.cardRadius,
        border: Border.all(color: ExperienceColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Notes to yourself',
            style: ExperienceType.headline(ExperienceColors.ink),
          ),
          const SizedBox(height: ExperienceSpacing.xs),
          Text(
            'Notes are never included automatically. Choose any you want '
            'inside this export — everything else stays private.',
            style: ExperienceType.bodySmall(ExperienceColors.inkSoft),
          ),
          const SizedBox(height: ExperienceSpacing.sm),
          if (notes.isEmpty)
            Text(
              totalNoteCount == 0
                  ? 'You have no saved notes yet.'
                  : 'None of your notes fall inside this range.',
              style: ExperienceType.bodySmall(ExperienceColors.inkFaint),
            )
          else ...<Widget>[
            if (!anySelected)
              Padding(
                padding: const EdgeInsets.only(bottom: ExperienceSpacing.unit),
                child: Text(
                  'No notes selected for this export.',
                  style: ExperienceType.caption(ExperienceColors.inkFaint),
                ),
              ),
            for (final note in notes)
              _NoteTile(
                note: note,
                selected: selectedNoteIds.contains(note.id),
                onToggle: (selected) => onToggle(note.id, selected),
              ),
          ],
        ],
      ),
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({
    required this.note,
    required this.selected,
    required this.onToggle,
  });

  final SummarySelectableNote note;
  final bool selected;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: selected,
      label:
          'Include note ${note.label} from '
          '${summaryDateLabel(note.date)} in this export',
      child: InkWell(
        borderRadius: ExperienceRadius.chipRadius,
        onTap: () => onToggle(!selected),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: ExperienceSpacing.degreeTarget,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: ExperienceSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ExcludeSemantics(
                  child: Checkbox(
                    value: selected,
                    onChanged: (value) => onToggle(value ?? false),
                  ),
                ),
                const SizedBox(width: ExperienceSpacing.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        note.label,
                        style: ExperienceType.bodyStrong(ExperienceColors.ink),
                      ),
                      Text(
                        '${summaryDateLabel(note.date)} · ${note.sourceLabel}',
                        style: ExperienceType.caption(ExperienceColors.inkSoft),
                      ),
                      Text(
                        note.text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: ExperienceType.caption(
                          ExperienceColors.inkFaint,
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
}

// ---------------------------------------------------------------------------
// The boundary — the seam between free and Plus. One factual ledger rule in
// tabular numerals between hairlines, then two equal-weight outlined
// actions (identical style, identical height, no ember on either; the ember
// lives only on the commitment sheet's primary CTA), then one quiet
// reassurance line. Rendered only at three or more completed cycles for
// users without access, away from Care.
// ---------------------------------------------------------------------------

class _BoundaryBlock extends StatelessWidget {
  const _BoundaryBlock({
    required this.rangePresetLabel,
    required this.completedCyclesInRange,
    required this.totalCompletedCycles,
    required this.onSeeAllCycles,
    required this.onExport,
  });

  final String rangePresetLabel;
  final int completedCyclesInRange;
  final int totalCompletedCycles;
  final VoidCallback onSeeAllCycles;
  final VoidCallback onExport;

  static final ButtonStyle _actionStyle = OutlinedButton.styleFrom(
    foregroundColor: ExperienceColors.ink,
    side: const BorderSide(color: ExperienceColors.hairline),
    shape: const RoundedRectangleBorder(
      borderRadius: ExperienceRadius.chipRadius,
    ),
    minimumSize: const Size.fromHeight(ExperienceSpacing.degreeTarget),
    textStyle: ExperienceType.label(ExperienceColors.ink),
  );

  @override
  Widget build(BuildContext context) {
    final inRangeWord = completedCyclesInRange == 1 ? 'cycle' : 'cycles';
    final totalWord = totalCompletedCycles == 1 ? 'cycle' : 'cycles';
    final ruleLine =
        'Showing $rangePresetLabel · $completedCyclesInRange completed '
        '$inRangeWord in range';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(height: 1, color: ExperienceColors.hairline),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: ExperienceSpacing.sm),
          child: Semantics(
            container: true,
            label:
                'Showing $rangePresetLabel, $completedCyclesInRange completed '
                '$inRangeWord in range',
            child: ExcludeSemantics(
              child: Text(
                ruleLine,
                textAlign: TextAlign.center,
                style: ExperienceType.data(
                  ExperienceColors.ink,
                  size: 15,
                  weight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        Container(height: 1, color: ExperienceColors.hairline),
        const SizedBox(height: ExperienceSpacing.sm),
        Semantics(
          button: true,
          child: OutlinedButton(
            onPressed: onSeeAllCycles,
            style: _actionStyle,
            child: Text(
              'Compare all $totalCompletedCycles completed $totalWord',
            ),
          ),
        ),
        const SizedBox(height: ExperienceSpacing.unit),
        Semantics(
          button: true,
          child: OutlinedButton(
            onPressed: onExport,
            style: _actionStyle,
            child: const Text('Export this report.'),
          ),
        ),
        const SizedBox(height: ExperienceSpacing.sm),
        Text(
          'Reading your records here is always free.',
          textAlign: TextAlign.center,
          style: ExperienceType.caption(ExperienceColors.inkSoft),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Export — the Letter-folder save is explained before the share sheet opens.
// Entitlement gates generation only; reading local material is free forever.
// ---------------------------------------------------------------------------

class _ExportPanel extends StatelessWidget {
  const _ExportPanel({required this.exporting, required this.onExport});

  final bool exporting;
  final ValueChanged<ReportExportFormat> onExport;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ExperienceSpacing.md),
      decoration: BoxDecoration(
        color: ExperienceColors.surface,
        borderRadius: ExperienceRadius.cardRadius,
        border: Border.all(color: ExperienceColors.hairline),
        boxShadow: ExperienceShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Export this report',
            style: ExperienceType.headline(ExperienceColors.ink),
          ),
          const SizedBox(height: ExperienceSpacing.xs),
          Text(
            'Exporting first saves a copy to your Letter folder on this '
            'device, then opens the share sheet — you decide where it goes '
            'from there.',
            style: ExperienceType.bodySmall(ExperienceColors.inkSoft),
          ),
          const SizedBox(height: ExperienceSpacing.md),
          if (exporting)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(ExperienceSpacing.unit),
                child: EmberLoadingIndicator(
                  semanticLabel: 'Preparing your report',
                ),
              ),
            )
          else ...<Widget>[
            FilledButton.icon(
              onPressed: () => onExport(ReportExportFormat.pdf),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Export PDF'),
            ),
            const SizedBox(height: ExperienceSpacing.unit),
            OutlinedButton.icon(
              onPressed: () => onExport(ReportExportFormat.csv),
              icon: const Icon(Icons.table_chart_outlined),
              label: const Text('Export CSV'),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Receipt — four outcomes, four distinct calm feedbacks. Retry on failure.
// ---------------------------------------------------------------------------

class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({required this.receipt, this.onRetry});

  final ExperienceFileReceipt receipt;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final (icon, color, title, body) = switch (receipt.outcome) {
      ExperienceFileOutcome.shared => (
        Icons.check_circle_outline,
        ExperienceColors.ember,
        'Shared on your terms.',
        'A copy is saved in your Letter folder on this device.',
      ),
      ExperienceFileOutcome.savedOnly => (
        Icons.folder_outlined,
        ExperienceColors.accentGravity,
        'Saved to your Letter folder.',
        'Nothing was shared. The file stays on this device until you '
            'choose otherwise.',
      ),
      ExperienceFileOutcome.cancelled => (
        Icons.close,
        ExperienceColors.inkSoft,
        'Cancelled.',
        'Nothing left this device.',
      ),
      ExperienceFileOutcome.failed => (
        Icons.error_outline,
        ExperienceColors.error,
        'The export didn’t finish.',
        receipt.message ??
            'You can try again — your records are safe on this device.',
      ),
    };

    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(ExperienceSpacing.md),
        decoration: BoxDecoration(
          color: ExperienceColors.surface,
          borderRadius: ExperienceRadius.cardRadius,
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: color, size: 22),
            const SizedBox(width: ExperienceSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: ExperienceType.label(ExperienceColors.ink),
                  ),
                  const SizedBox(height: ExperienceSpacing.xs),
                  Text(
                    body,
                    style: ExperienceType.bodySmall(ExperienceColors.inkSoft),
                  ),
                  if (onRetry != null)
                    TextButton(
                      onPressed: onRetry,
                      child: const Text('Try again'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Post-export continuity — a quiet last-export line and a route back to the
// source records, so returning users never land on a reset form without
// context.
// ---------------------------------------------------------------------------

class _ContinuityLine extends StatelessWidget {
  const _ContinuityLine({
    required this.lastSuccessAt,
    required this.outcome,
    required this.onBackToRecords,
  });

  final DateTime lastSuccessAt;
  final ExperienceFileOutcome outcome;
  final VoidCallback onBackToRecords;

  @override
  Widget build(BuildContext context) {
    final verb = outcome == ExperienceFileOutcome.shared ? 'shared' : 'saved';
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ExperienceSpacing.sm,
        vertical: ExperienceSpacing.unit,
      ),
      decoration: BoxDecoration(
        color: ExperienceColors.surface,
        borderRadius: ExperienceRadius.chipRadius,
        border: Border.all(color: ExperienceColors.hairline),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.history, size: 16, color: ExperienceColors.inkFaint),
          const SizedBox(width: ExperienceSpacing.unit),
          Expanded(
            child: Text(
              'Last $verb ${summaryDateTimeLabel(lastSuccessAt)} · saved to '
              'your Letter folder',
              style: ExperienceType.caption(ExperienceColors.inkSoft),
            ),
          ),
          TextButton(
            onPressed: onBackToRecords,
            child: const Text('Back to your records'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loading skeleton — list shimmer rows plus a dot-grid cell, settled under
// reduced motion. Never a bare spinner over white.
// ---------------------------------------------------------------------------

class _ReportsSkeleton extends StatefulWidget {
  const _ReportsSkeleton();

  @override
  State<_ReportsSkeleton> createState() => _ReportsSkeletonState();
}

class _ReportsSkeletonState extends State<_ReportsSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ExperienceMotion.reducedMotion(context)) {
        _controller.value = 0.5; // settled
      } else {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _bar(double width, double height, double opacity) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ExperienceSpacing.sm),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: ExperienceColors.inkFaint.withValues(alpha: 0.25 * opacity),
          borderRadius: BorderRadius.circular(height / 2),
        ),
      ),
    );
  }

  Widget _card(double height, double opacity) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ExperienceSpacing.md),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: ExperienceColors.surface,
          borderRadius: ExperienceRadius.cardRadius,
          border: Border.all(
            color: ExperienceColors.hairline.withValues(alpha: opacity),
          ),
        ),
        child: CustomPaint(
          painter: DotGridPainter(
            color: ExperienceColors.inkFaint.withValues(alpha: opacity),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading your report preview',
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final opacity = 0.45 + 0.45 * _controller.value;
          return ListView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              ExperienceSpacing.screenMargin,
              ExperienceSpacing.lg,
              ExperienceSpacing.screenMargin,
              ExperienceSpacing.scrollBottomPadding,
            ),
            children: <Widget>[
              _bar(220, 26, opacity),
              _bar(double.infinity, 14, opacity),
              _bar(260, 14, opacity),
              const SizedBox(height: ExperienceSpacing.unit),
              _card(64, opacity),
              _card(120, opacity),
              _card(96, opacity),
              _card(96, opacity),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Load error — visual + textual only, retry first-class, no haptics.
// ---------------------------------------------------------------------------

class _LoadErrorPanel extends StatelessWidget {
  const _LoadErrorPanel({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ExperienceSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.error_outline,
              color: ExperienceColors.error,
              size: 28,
            ),
            const SizedBox(height: ExperienceSpacing.sm),
            Text(
              'Reports couldn’t load.',
              style: ExperienceType.headline(ExperienceColors.ink),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: ExperienceSpacing.unit),
            Text(
              'Your records are still safe on this device.',
              style: ExperienceType.bodySmall(ExperienceColors.inkSoft),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: ExperienceSpacing.md),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Dashed border used for estimated treatments — certainty is a texture,
/// never color alone.
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    this.radius = ExperienceRadius.chip,
    this.dashPattern = const <double>[6, 4],
  });

  static const double _strokeWidth = 1.2;

  final Color color;
  final double radius;
  final List<double> dashPattern;

  void _dashEdge(Canvas canvas, Paint paint, Offset from, Offset to) {
    final delta = to - from;
    final length = delta.distance;
    if (length == 0) return;
    final direction = delta / length;
    var travelled = 0.0;
    var dashIndex = 0;
    while (travelled < length) {
      final dashLength = dashPattern[dashIndex % dashPattern.length];
      final isOn = dashIndex % 2 == 0;
      final end = (travelled + dashLength).clamp(0.0, length).toDouble();
      if (isOn) {
        canvas.drawLine(
          from + direction * travelled,
          from + direction * end,
          paint,
        );
      }
      travelled = end;
      dashIndex++;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = _strokeWidth
      ..style = PaintingStyle.stroke;
    final rect = Offset.zero & size;
    final r = radius;
    // Straight edges dashed; corners drawn as small solid arcs so the
    // texture stays continuous at ring width.
    _dashEdge(
      canvas,
      paint,
      rect.topLeft + Offset(r, 0),
      rect.topRight + Offset(-r, 0),
    );
    _dashEdge(
      canvas,
      paint,
      rect.topRight + Offset(0, r),
      rect.bottomRight + Offset(0, -r),
    );
    _dashEdge(
      canvas,
      paint,
      rect.bottomRight + Offset(-r, 0),
      rect.bottomLeft + Offset(r, 0),
    );
    _dashEdge(
      canvas,
      paint,
      rect.bottomLeft + Offset(0, -r),
      rect.topLeft + Offset(0, r),
    );
    void corner(Offset center, double startAngle) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        startAngle,
        1.5707963, // quarter circle
        false,
        paint,
      );
    }

    corner(rect.topLeft + Offset(r, r), 3.14159265);
    corner(rect.topRight + Offset(-r, r), -1.5707963);
    corner(rect.bottomRight + Offset(-r, -r), 0);
    corner(rect.bottomLeft + Offset(r, -r), 1.5707963);
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}

/// Presentation-side formatting for enum names ("tenderChest" →
/// "Tender chest"). Vocabulary itself always comes from the domain.
String _humanize(String name) {
  final cleaned = name.replaceAll('_', ' ');
  final buffer = StringBuffer();
  for (var i = 0; i < cleaned.length; i++) {
    final ch = cleaned[i];
    final isLetter = ch.toLowerCase() != ch.toUpperCase();
    final isUpper = isLetter && ch == ch.toUpperCase();
    if (isUpper && i > 0 && cleaned[i - 1] != ' ') {
      buffer.write(' ');
    }
    buffer.write(i == 0 ? ch.toUpperCase() : ch.toLowerCase());
  }
  return buffer.toString();
}
