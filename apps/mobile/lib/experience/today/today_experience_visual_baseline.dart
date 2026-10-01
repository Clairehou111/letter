import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsService;
import 'package:flutter/services.dart' show HapticFeedback;

import '../../features/capture/domain/capture_models.dart';
import '../../features/check_in/domain/moment_check_in.dart';
import '../../features/cycle/domain/bleeding_flow.dart';
import '../../features/cycle/domain/local_date.dart';
import '../../features/health_records/domain/health_record.dart';
import '../../features/health_records/domain/observation_catalog.dart';
import '../../features/today/today_cycle_context.dart';
import '../comfort/comfort_reminder_sheet.dart';
import '../cycle/cycle_estimate_copy.dart';
import '../degree/degree_graphics.dart';
import '../theme/experience_foundation.dart';
import 'today_visual_port.dart';

/// Letter Within — Today.
///
/// A calm, action-oriented daily surface: quick mood (with a gentle,
/// optional route to Care on heavy days), bleeding with an explicit
/// period-start decision, symptoms one at a time browsed across six
/// semantic groups, each with one named severity explained by a calm
/// visual legend, period start/end, and an optional private note.
/// No forms, no page-level save — every selection acknowledges itself
/// immediately, both visibly and audibly.
///
/// Quiet Dusk: the whole surface lives inside the plum sky — deep warm
/// canvas, lifted plum surfaces, warm off-white ink — with the ember as
/// the single warm light source reserved for actions, memory, and the
/// "you are here" marks. Nothing here renders a daylight world.
class TodayExperienceVisual extends StatefulWidget {
  const TodayExperienceVisual({
    super.key,
    required this.port,
    this.revision = 0,
  });

  final TodayVisualPort port;
  final int revision;

  @override
  State<TodayExperienceVisual> createState() => _TodayExperienceVisualState();
}

// ---------------------------------------------------------------------------
// Palette & type — Quiet Dusk tokens
//
// One plum sky at one depth for this screen: a deep warm-plum canvas, a
// surface one step up, and a single raised surface reserved for the hero —
// the one focal object per viewport. Ink is the warm off-white care family.
// The ember family is the only saturated warm hue: actions, memory, and the
// ember itself. Errors borrow a warm desaturated red, never the light.
// ---------------------------------------------------------------------------

const Color _canvas = ExperienceColors.canvas;
const Color _surface = ExperienceColors.surface;
const Color _surfaceRaised = ExperienceColors.surfaceWarm;
const Color _ink = ExperienceColors.ink;
const Color _inkSoft = ExperienceColors.inkSoft;
const Color _inkFaint = ExperienceColors.inkFaint;
const Color _hairline = ExperienceColors.careGlassBorder;

const Color _ember = ExperienceColors.ember;
const Color _emberBright = ExperienceColors.emberBright;
const Color _emberDeep = ExperienceColors.emberDeep;
const Color _emberSoft = Color(0x24E4573D);

const Color _error = ExperienceColors.error;

/// Minimum accessible touch target. Chips keep their visible size and grow
/// only an invisible hit area to reach it.
const double _minTouchTarget = 48;

/// Above this text scale (or below the width threshold) the masthead stops
/// sitting beside the date and stacks instead, so no word is ever split
/// across lines and the hero stays reachable in the first viewport.
const double _headerStackTextScale = 1.5;
const double _headerStackMinWidth = 380;

TextStyle _serif(
  double size, {
  Color color = _ink,
  FontWeight weight = FontWeight.w700,
  double height = 1.12,
  bool italic = false,
}) {
  return TextStyle(
    fontFamily: 'Georgia',
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
  );
}

TextStyle _sans(
  double size, {
  Color color = _ink,
  FontWeight weight = FontWeight.w500,
  double height = 1.35,
  double spacing = 0,
}) {
  return TextStyle(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: spacing,
  );
}

TextStyle _kicker({Color color = _emberBright}) =>
    _sans(11, color: color, weight: FontWeight.w700, spacing: 2.4);

/// Ordinary surfaces in dusk are flat: a lifted plum fill and a translucent
/// warm hairline. Shadows deepen rather than lighten, and the single focal
/// shadow of the viewport belongs to the hero alone.
BoxDecoration _cardDecoration({Color color = _surface}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: _hairline),
  );
}

/// The quiet ember underline — a short gradient settling from the ember to
/// its deepest note. Used for the masthead rule and the saved-note spine.
BoxDecoration _emberRuleDecoration({double radius = 2}) {
  return BoxDecoration(
    gradient: const LinearGradient(colors: <Color>[_ember, _emberDeep]),
    borderRadius: BorderRadius.circular(radius),
  );
}

/// Motion constitution: the platform reduced-motion flag comes first. When
/// set, every animated surface on Today degrades to an instant, composed
/// transition with identical copy and controls.
Duration _motion(BuildContext context, Duration duration) =>
    ExperienceMotion.reducedMotion(context) ? Duration.zero : duration;

/// Keeps authored masthead words intact at extreme text scale: the line is
/// laid out as one unbroken word sequence and scaled down to fit, never
/// wrapped mid-word and never clipped mid-glyph.
Widget _fitMastheadLine(Text text) {
  return FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: text,
  );
}

/// Display-title resilience, scoped to editorial hero titles only.
///
/// At extreme accessibility text scale a single long word (e.g. "beginning")
/// would otherwise be split across lines mid-glyph, and the title alone
/// could consume the first viewport. This widget measures the title at its
/// authored style and computes the largest text scale at which the longest
/// word still fits the available width whole; if the full title still
/// exceeds [maxLines] at that scale it steps down gently (shrinking text
/// never re-introduces a mid-word split). Normal-scale rendering is
/// untouched: whenever the device scale already fits, the authored style is
/// used exactly as designed. Body copy, controls, and chips are never
/// affected by this clamp.
class _DisplayTitle extends StatelessWidget {
  const _DisplayTitle(this.text, {required this.style, this.maxLines = 3});

  final String text;
  final TextStyle style;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final MediaQueryData media = MediaQuery.of(context);
        final double deviceScale = media.textScaler.scale(1.0);
        double available = constraints.maxWidth;
        if (!available.isFinite || available <= 0) {
          available = media.size.width;
        }
        final TextDirection direction =
            Directionality.maybeOf(context) ?? TextDirection.ltr;

        double measureWordWidth(String word) {
          final TextPainter painter = TextPainter(
            text: TextSpan(text: word, style: style),
            textDirection: direction,
            maxLines: 1,
          )..layout();
          final double width = painter.width;
          painter.dispose();
          return width;
        }

        bool fitsWithinLines(double scale) {
          final TextPainter painter = TextPainter(
            text: TextSpan(text: text, style: style),
            textDirection: direction,
            textScaler: TextScaler.linear(scale),
          )..layout(maxWidth: available);
          final bool fits = painter.computeLineMetrics().length <= maxLines;
          painter.dispose();
          return fits;
        }

        // The no-split ceiling: the largest scale at which the longest word
        // still fits on one line inside the available width (with a small
        // safety margin so rendering rounding can never tip it over).
        double longestWord = 0;
        for (final String word in text.split(RegExp(r'\s+'))) {
          if (word.isEmpty) continue;
          longestWord = math.max(longestWord, measureWordWidth(word));
        }
        final double wordFitScale = longestWord > 0
            ? (available / longestWord) * 0.97
            : deviceScale;

        double scale = math.min(deviceScale, wordFitScale);
        // If the whole title still exceeds the line budget, step down
        // gently. Shrinking only ever shortens lines, so this can never
        // cause a word to split; the floor keeps the type legible.
        for (int i = 0; i < 20 && scale > 0.5 && !fitsWithinLines(scale); i++) {
          scale *= 0.92;
        }

        return Text(text, style: style, textScaler: TextScaler.linear(scale));
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Local visual state
// ---------------------------------------------------------------------------

enum _CycleView { loading, known, learning, empty, error }

class _SymptomEntry {
  const _SymptomEntry({
    required this.id,
    required this.definition,
    required this.severity,
  });

  final String id;
  final ObservationDefinition definition;
  final SymptomSeverity severity;
}

/// A semantic family of symptoms — the browser lets people discover the
/// breadth (body, feelings, mind, energy, sleep, digestion) without ever
/// becoming a long medical catalogue.
class _SymptomGroup {
  const _SymptomGroup(this.name, this.hint, this.symptoms);

  final String name;
  final String hint;
  final List<ObservationDefinition> symptoms;
}

class _TodayExperienceVisualState extends State<TodayExperienceVisual> {
  // Cycle-context hero. Its day number and estimated date range are always
  // read from the shared prediction contract in [TodayVisualSnapshot].
  _CycleView _view = _CycleView.loading;
  TodayCycleContext? _cycleContext;

  // Today's quick captures.
  MomentCheckInState? _mood;
  BleedingFlow? _bleeding;
  BleedingColor? _bleedingColor;
  final List<_SymptomEntry> _symptoms = <_SymptomEntry>[];
  bool _periodActive = false;
  bool _canRecordFlow = false;

  // The Care doorway is repository truth. The mood chip may be optimistic,
  // but the route stays hidden while a save is in flight and never appears
  // from a failed save.
  int _moodSavesInFlight = 0;

  // A line the app remembers from earlier Care check-backs. Composed
  // upstream through the factual evidence gate; shown verbatim, never
  // summarized, rewritten, or inferred. Null means intentional silence.
  String? _rememberedHelpLine;

  // Comfort Window is already reliability-gated by the non-visual port.
  // Null means intentional silence, never a loading placeholder.
  TodayComfortWindowState? _comfortWindow;
  bool _comfortWindowSaveInFlight = false;

  // Optional Quick notes. The local row identity survives edits so Reports
  // and Comfort Kit never retain a stale duplicate after a correction.
  bool _noteOpen = false;
  String? _note;
  final List<CaptureNote> _quickNotes = <CaptureNote>[];
  String? _editingNoteId;
  bool _keepNoteInComfortKit = false;
  final TextEditingController _noteController = TextEditingController();

  // Acknowledgement toast.
  String? _ack;
  Timer? _ackTimer;

  static const List<MomentCheckInState> _primaryMoods = <MomentCheckInState>[
    MomentCheckInState.good,
    MomentCheckInState.calm,
    MomentCheckInState.steady,
    MomentCheckInState.low,
    MomentCheckInState.irritable,
    MomentCheckInState.anxious,
  ];

  static const List<MomentCheckInState> _moreMoods = <MomentCheckInState>[
    MomentCheckInState.energized,
    MomentCheckInState.tender,
    MomentCheckInState.hopeful,
    MomentCheckInState.overwhelmed,
    MomentCheckInState.exhausted,
    MomentCheckInState.physical,
  ];

  /// Moods that may want extra gentleness. Selecting one reveals — never
  /// forces — a route to Care.
  static const Set<MomentCheckInState> _heavyMoods = <MomentCheckInState>{
    MomentCheckInState.low,
    MomentCheckInState.irritable,
    MomentCheckInState.anxious,
    MomentCheckInState.tender,
    MomentCheckInState.overwhelmed,
    MomentCheckInState.exhausted,
  };

  static const List<BleedingFlow?> _bleedingOptions = <BleedingFlow?>[
    null,
    BleedingFlow.spotting,
    BleedingFlow.light,
    BleedingFlow.medium,
    BleedingFlow.heavy,
  ];

  static const List<BleedingColor> _colorOptions = <BleedingColor>[
    BleedingColor.pink,
    BleedingColor.brightRed,
    BleedingColor.darkRed,
    BleedingColor.brown,
  ];

  /// The same canonical six-category catalog used by Cycle. Only the UI
  /// grouping language lives here; persistence always receives stable enums.
  static final List<_SymptomGroup> _symptomGroups = <_SymptomGroup>[
    _group(
      'Body',
      'aches and physical sensations',
      ObservationCategory.physical,
    ),
    _group('Emotional', 'the weather of feelings', ObservationCategory.mood),
    _group(
      'Cognitive',
      'how the mind is moving',
      ObservationCategory.cognitive,
    ),
    _group('Energy', 'fuel in the tank', ObservationCategory.energy),
    _group('Sleep', 'the night before', ObservationCategory.sleep),
    _group('Digestion', 'appetite and gut', ObservationCategory.digestion),
  ];

  static _SymptomGroup _group(
    String name,
    String hint,
    ObservationCategory category,
  ) => _SymptomGroup(
    name,
    hint,
    ObservationCatalog.symptoms
        .where(
          (definition) =>
              definition.category == category &&
              definition.symptom.availableForNewRecords,
        )
        .toList(growable: false),
  );

  static const List<(SymptomSeverity, String)> _severities =
      <(SymptomSeverity, String)>[
        (SymptomSeverity.minimal, 'barely there'),
        (SymptomSeverity.mild, 'noticeable, easy to carry'),
        (SymptomSeverity.moderate, 'asking for attention'),
        (SymptomSeverity.severe, 'hard to move through'),
        (SymptomSeverity.extreme, 'all-consuming'),
      ];

  /// Warm ramp for the severity legend — five steps from a whisper of
  /// warmth to its deepest note.
  static const List<Color> _severityRamp = DegreeGraphics.severityRamp;

  bool get _moodSaveInFlight => _moodSavesInFlight > 0;

  bool get _showCareRoute =>
      !_moodSaveInFlight && _mood != null && _heavyMoods.contains(_mood);

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant TodayExperienceVisual oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision ||
        oldWidget.port != widget.port) {
      _reload();
    }
  }

  Future<void> _reload() async {
    try {
      final snapshot = await widget.port.load();
      if (!mounted) return;
      _applySnapshot(snapshot);
    } on Object {
      // Honesty under every condition: a failed read is a failed read, not a
      // lifecycle state. The error hero is visually distinct from learning.
      if (mounted) setState(() => _view = _CycleView.error);
    }
  }

  Future<void> _retryLoad() async {
    setState(() => _view = _CycleView.loading);
    await _reload();
  }

  @override
  void dispose() {
    _ackTimer?.cancel();
    _noteController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Acknowledgement — visible toast, live-region announcement, and a
  // restrained haptic only for meaningful successful saves.
  // -------------------------------------------------------------------------

  void _acknowledge(String message, {bool saved = false}) {
    if (!mounted) return;
    _ackTimer?.cancel();
    setState(() => _ack = message);
    final view = View.maybeOf(context);
    if (view != null) {
      SemanticsService.sendAnnouncement(
        view,
        message,
        Directionality.maybeOf(context) ?? TextDirection.ltr,
      );
    }
    if (saved) HapticFeedback.selectionClick();
    _ackTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _ack = null);
    });
  }

  // -------------------------------------------------------------------------
  // Hero transitions — a brief crossfade between honest states, synchronized
  // with the real state change. No fabricated latency.
  // -------------------------------------------------------------------------

  void _transitionHero(_CycleView target) {
    setState(() => _view = target);
  }

  /// Reduced-motion-safe state swap. When the platform asks for no motion,
  /// Today does not build an AnimatedSwitcher at all: the new state simply
  /// exists, composed and complete, with identical copy and controls.
  Widget _swap(
    Widget child, {
    required Duration duration,
    Widget Function(Widget child, Animation<double> animation)?
    transitionBuilder,
  }) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return child;
    }
    if (transitionBuilder == null) {
      return AnimatedSwitcher(duration: duration, child: child);
    }
    return AnimatedSwitcher(
      duration: duration,
      transitionBuilder: transitionBuilder,
      child: child,
    );
  }

  // -------------------------------------------------------------------------
  // Mood
  // -------------------------------------------------------------------------

  Future<void> _selectMood(MomentCheckInState mood) async {
    setState(() {
      _mood = mood;
      _moodSavesInFlight++;
    });
    try {
      final snapshot = await widget.port.saveMood(mood);
      if (!mounted) return;
      await _reloadFrom(snapshot);
      _acknowledge('Mood noted — ${mood.label}', saved: true);
    } on Object {
      if (mounted) {
        await _reload();
        _acknowledge("Letter Within couldn't save that. Try again.");
      }
    } finally {
      if (mounted) {
        setState(() => _moodSavesInFlight--);
      }
    }
  }

  Future<void> _reloadFrom(TodayVisualSnapshot snapshot) async {
    if (!mounted) return;
    _applySnapshot(snapshot);
  }

  void _applySnapshot(TodayVisualSnapshot snapshot) {
    if (!mounted) return;
    setState(() {
      _mood = snapshot.mood;
      _bleeding = snapshot.flowRecord?.flow;
      _bleedingColor = snapshot.flowRecord?.color;
      _symptoms
        ..clear()
        ..addAll(
          snapshot.symptoms.map(
            (record) => _SymptomEntry(
              id: record.id,
              definition: ObservationCatalog.definitionFor(record.symptom),
              severity: record.severity,
            ),
          ),
        );
      _periodActive = snapshot.canEndPeriod;
      _canRecordFlow = snapshot.canRecordFlow;
      _note = snapshot.note;
      _quickNotes
        ..clear()
        ..addAll(snapshot.quickNotes);
      _rememberedHelpLine = snapshot.rememberedHelpLine;
      _comfortWindow = snapshot.comfortWindow;
      _cycleContext = snapshot.cycleContext;
      _view = _cycleViewFor(snapshot.cycleContext);
    });
  }

  _CycleView _cycleViewFor(TodayCycleContext context) {
    if (context.kind == TodayCycleKind.noHistory) return _CycleView.empty;
    // A period start begins the current cycle. Whether bleeding is still open
    // changes its phase, not whether the person has a current cycle. Keep the
    // current day visible even while there is not yet enough history to
    // calculate a personalized next-period range.
    return _CycleView.known;
  }

  Future<void> _openMoreMoods() async {
    final MomentCheckInState? picked =
        await showModalBottomSheet<MomentCheckInState>(
          context: context,
          backgroundColor: _surface,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          builder: (BuildContext ctx) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const _SheetHandle(),
                    const SizedBox(height: 14),
                    Text('More ways this moment could feel', style: _serif(20)),
                    const SizedBox(height: 4),
                    Text(
                      'Still one tap. Still no wrong answers.',
                      style: _sans(13.5, color: _inkSoft),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _moreMoods
                          .map(
                            (MomentCheckInState m) => _Chip(
                              label: m.label,
                              selected: _mood == m,
                              onTap: () => Navigator.of(ctx).pop(m),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            );
          },
        );
    if (picked != null) await _selectMood(picked);
  }

  /// The optional Care route — opened only by the user, never automatically.
  Future<void> _openCare() => widget.port.openCare();

  Future<void> _saveComfortReminder({
    required bool enabled,
    required int leadDays,
  }) async {
    if (_comfortWindowSaveInFlight) return;
    setState(() => _comfortWindowSaveInFlight = true);
    try {
      final snapshot = await widget.port.saveComfortReminder(
        enabled: enabled,
        leadDays: leadDays,
      );
      if (!mounted) return;
      await _reloadFrom(snapshot);
      _acknowledge(
        enabled
            ? 'Reminder preference saved — ${comfortReminderLeadLabel(leadDays)} at 09:00'
            : 'Comfort reminder is off',
        saved: true,
      );
    } on Object {
      if (mounted) {
        _acknowledge("Letter Within couldn't save that reminder. Try again.");
      }
    } finally {
      if (mounted) setState(() => _comfortWindowSaveInFlight = false);
    }
  }

  Future<void> _chooseComfortReminder() async {
    final comfort = _comfortWindow;
    if (comfort == null) return;
    final result = await showComfortReminderSheet(
      context,
      enabled: comfort.reminderEnabled,
      configured: comfort.reminderConfigured,
      leadDays: comfort.reminderLeadDays,
    );
    if (!mounted || result == null) return;
    await _saveComfortReminder(
      enabled: result.enabled,
      leadDays: result.leadDays,
    );
  }

  // -------------------------------------------------------------------------
  // Bleeding — with an explicit period-start decision
  // -------------------------------------------------------------------------

  Future<void> _selectBleeding(BleedingFlow? flow) async {
    if (flow == BleedingFlow.spotting && !_canRecordFlow) {
      _acknowledge('Spotting does not start a period. No flow was saved.');
      return;
    }
    if (flow != null && !_canRecordFlow) {
      await _askPeriodStart(flow);
      return;
    }
    try {
      final snapshot = await widget.port.setFlow(flow);
      if (!mounted) return;
      await _reloadFrom(snapshot);
      _acknowledge('Bleeding noted — ${flow?.label ?? 'None'}', saved: true);
    } on Object {
      if (mounted) {
        await _reload();
        _acknowledge("Letter Within couldn't save that. Try again.");
      }
    }
  }

  /// Bleeding was noted while no period is active: ask plainly whether this
  /// is day one, and let either answer stand without judgement.
  Future<void> _askPeriodStart(BleedingFlow flow) async {
    final bool? started = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _SheetHandle(),
                const SizedBox(height: 16),
                Text('Did your period start?', style: _serif(22)),
                const SizedBox(height: 6),
                Text(
                  'You noted ${flow.label.toLowerCase()} '
                  'while no period is active. Either answer is fine — this '
                  'just keeps day one honest.',
                  style: _sans(13.5, color: _inkSoft, height: 1.5),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: TextButton.styleFrom(
                      foregroundColor: _canvas,
                      backgroundColor: _ember,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Yes — today is day one',
                      style: _sans(14, weight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _ink,
                      side: const BorderSide(color: _hairline),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'No — just noting bleeding',
                      style: _sans(14, weight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted) return;
    if (started == true) {
      try {
        await widget.port.startPeriod();
        final snapshot = await widget.port.setFlow(flow);
        if (!mounted) return;
        await _reloadFrom(snapshot);
        _acknowledge('Period started — day 1 noted', saved: true);
      } on Object {
        if (mounted) {
          await _reload();
          _acknowledge("Letter Within couldn't save that. Try again.");
        }
      }
    } else {
      await _reload();
      _acknowledge('No flow was saved. Start a period to record bleeding.');
    }
  }

  Future<void> _selectBleedingColor(BleedingColor color) async {
    try {
      final snapshot = await widget.port.setColor(color);
      if (!mounted) return;
      await _reloadFrom(snapshot);
      _acknowledge('Color noted — ${color.label}', saved: true);
    } on Object {
      if (mounted) {
        await _reload();
        _acknowledge("Letter Within couldn't save that. Try again.");
      }
    }
  }

  // -------------------------------------------------------------------------
  // Symptoms — one at a time, browsed by where they live, one severity each
  // -------------------------------------------------------------------------

  Future<void> _addSymptom() async {
    final ObservationDefinition? symptom =
        await showModalBottomSheet<ObservationDefinition>(
          context: context,
          backgroundColor: _surface,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          builder: (BuildContext ctx) {
            return _SymptomBrowserSheet(groups: _symptomGroups);
          },
        );
    if (symptom == null || !mounted) return;

    final SymptomSeverity? severity = await _pickSeverity(symptom.label);
    if (severity == null) return;

    try {
      final snapshot = await widget.port.saveSymptom(symptom.symptom, severity);
      if (!mounted) return;
      await _reloadFrom(snapshot);
      _acknowledge(
        'Symptom noted — ${symptom.label}, ${severity.label.toLowerCase()}',
        saved: true,
      );
    } on Object {
      if (mounted) {
        await _reload();
        _acknowledge("Letter Within couldn't save that. Try again.");
      }
    }
  }

  Future<void> _editSymptom(int index) async {
    final _SymptomEntry entry = _symptoms[index];
    final SymptomSeverity? severity = await _pickSeverity(
      entry.definition.label,
      current: entry.severity,
    );
    if (severity == null) return;
    try {
      final snapshot = await widget.port.saveSymptom(
        entry.definition.symptom,
        severity,
      );
      if (!mounted) return;
      await _reloadFrom(snapshot);
      _acknowledge(
        '${entry.definition.label} updated — ${severity.label.toLowerCase()}',
        saved: true,
      );
    } on Object {
      if (mounted) {
        await _reload();
        _acknowledge("Letter Within couldn't save that. Try again.");
      }
    }
  }

  Future<void> _removeSymptom(int index) async {
    try {
      final snapshot = await widget.port.removeSymptom(_symptoms[index].id);
      if (!mounted) return;
      await _reloadFrom(snapshot);
      _acknowledge('Symptom removed', saved: true);
    } on Object {
      if (mounted) {
        await _reload();
        _acknowledge("Letter Within couldn't save that. Try again.");
      }
    }
  }

  /// The severity decision. A small rising legend names the five levels at a
  /// glance; each choice beneath pairs its step on that scale with plain
  /// words. The sheet grows and scrolls gracefully on small phones and with
  /// larger text — nothing essential is ever clipped.
  ///
  /// The content height budget subtracts the device's safe-area insets (and
  /// any keyboard inset) from the full screen height before the sheet's own
  /// padding is applied, so the constrained list plus the SafeArea padding
  /// can never exceed the viewport — fixing the bottom overflow seen at
  /// phone-like sizes when the legend is open.
  Future<SymptomSeverity?> _pickSeverity(
    String symptom, {
    SymptomSeverity? current,
  }) {
    return showModalBottomSheet<SymptomSeverity>(
      context: context,
      backgroundColor: _surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext ctx) {
        final MediaQueryData media = MediaQuery.of(ctx);
        // Budget for the scrollable content alone: the whole screen minus
        // the safe-area insets the wrapper re-adds, the sheet's vertical
        // padding (12 top + 18 bottom), and a small breathing margin. This
        // keeps the sheet strictly inside the viewport on narrow phones
        // (e.g. 390×844 with a notch) and under large text scaling.
        final double maxContentHeight =
            media.size.height -
            media.padding.top -
            media.padding.bottom -
            media.viewInsets.bottom -
            44;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              22,
              12,
              22,
              18 + media.viewInsets.bottom,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxContentHeight),
              child: ListView(
                shrinkWrap: true,
                children: <Widget>[
                  const _SheetHandle(),
                  const SizedBox(height: 14),
                  Text(symptom, style: _serif(20)),
                  const SizedBox(height: 4),
                  Text(
                    'How strong is it right now?',
                    style: _sans(13.5, color: _inkSoft),
                  ),
                  const SizedBox(height: 16),
                  const _SeverityLegend(),
                  const SizedBox(height: 16),
                  for (int i = 0; i < _severities.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _SeverityChoice(
                        index: i,
                        name: _severities[i].$1.label,
                        desc: _severities[i].$2,
                        color: _severityRamp[i],
                        selected: current == _severities[i].$1,
                        onTap: () => Navigator.of(ctx).pop(_severities[i].$1),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------------------
  // Period start / end — intentional, confirmed, and quiet
  // -------------------------------------------------------------------------

  Future<void> _startPeriodFromStrip() async {
    try {
      final snapshot = await widget.port.startPeriod();
      if (!mounted) return;
      await _reloadFrom(snapshot);
      _transitionHero(_cycleViewFor(snapshot.cycleContext));
      _acknowledge('Period started — day 1 noted', saved: true);
    } on Object {
      if (mounted) {
        await _reload();
        _acknowledge("Letter Within couldn't save that. Try again.");
      }
    }
  }

  Future<void> _confirmEndPeriod() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: _surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text('End this period?', style: _serif(20)),
          content: Text(
            'Today’s notes stay exactly as they are. You can start a new '
            'period whenever one begins.',
            style: _sans(14, color: _inkSoft, height: 1.5),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              style: TextButton.styleFrom(foregroundColor: _inkSoft),
              child: Text(
                'Keep going',
                style: _sans(13.5, weight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: _canvas,
                backgroundColor: _ember,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'End period',
                style: _sans(13.5, weight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    try {
      final snapshot = await widget.port.endOpenPeriodToday();
      if (!mounted) return;
      await _reloadFrom(snapshot);
      _transitionHero(_cycleViewFor(snapshot.cycleContext));
      _acknowledge('Period ended — noted', saved: true);
    } on Object {
      if (mounted) {
        await _reload();
        _acknowledge("Letter Within couldn't save that. Try again.");
      }
    }
  }

  // -------------------------------------------------------------------------
  // Quick notes
  // -------------------------------------------------------------------------

  void _beginNewNote() {
    _noteController.clear();
    setState(() {
      _editingNoteId = null;
      _keepNoteInComfortKit = false;
      _noteOpen = true;
    });
  }

  void _beginEditingNote(CaptureNote note) {
    _noteController.text = note.text;
    setState(() {
      _editingNoteId = note.id;
      _keepNoteInComfortKit = note.keepInComfortKit;
      _noteOpen = true;
    });
  }

  void _cancelNoteEditing() {
    _noteController.clear();
    setState(() {
      _noteOpen = false;
      _editingNoteId = null;
      _keepNoteInComfortKit = false;
    });
  }

  Future<void> _saveNote() async {
    final String text = _noteController.text.trim();
    if (text.isEmpty) {
      _cancelNoteEditing();
      return;
    }
    try {
      final editingId = _editingNoteId;
      final snapshot = editingId == null
          ? await widget.port.saveQuickNote(
              text,
              keepInComfortKit: _keepNoteInComfortKit,
            )
          : await widget.port.updateQuickNote(
              editingId,
              text: text,
              keepInComfortKit: _keepNoteInComfortKit,
            );
      if (!mounted) return;
      await _reloadFrom(snapshot);
      _noteController.clear();
      setState(() {
        _noteOpen = false;
        _editingNoteId = null;
        _keepNoteInComfortKit = false;
      });
      _acknowledge(
        editingId == null
            ? 'Quick note kept — only you can read it'
            : 'Quick note updated',
        saved: true,
      );
    } on Object {
      if (mounted) {
        _acknowledge("Letter Within couldn't save that. Try again.");
      }
    }
  }

  Future<void> _deleteNote(CaptureNote note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _surface,
        title: Text('Delete this quick note?', style: _serif(20)),
        content: Text(
          'It will also leave your Comfort Kit and future reports.',
          style: _sans(14, color: _inkSoft, height: 1.5),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep note'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: _error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final snapshot = await widget.port.deleteQuickNote(note.id);
      if (!mounted) return;
      await _reloadFrom(snapshot);
      if (_editingNoteId == note.id) _cancelNoteEditing();
      _acknowledge('Quick note deleted', saved: true);
    } on Object {
      if (mounted) {
        _acknowledge("Letter Within couldn't delete that. Try again.");
      }
    }
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _canvas,
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            const _DuskAmbient(),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool wide = constraints.maxWidth >= 760;
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    wide ? 32 : 22,
                    6,
                    wide ? 32 : 22,
                    100,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: wide ? 1040 : 560),
                      child: wide ? _buildWide() : _buildPhone(),
                    ),
                  ),
                );
              },
            ),
            _buildAckToast(),
          ],
        ),
      ),
    );
  }

  Widget _buildPhone() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildHeader(),
        _buildHero(),
        if (!_periodActive && !_canRecordFlow) ...<Widget>[
          const SizedBox(height: 14),
          _buildStartPeriodStrip(),
        ] else if (!_periodActive) ...<Widget>[
          const SizedBox(height: 14),
          _buildRecordedTodayStrip(),
        ],
        if (_showComfortWindow) ...<Widget>[
          const SizedBox(height: 18),
          _buildComfortWindow(),
        ],
        const SizedBox(height: 30),
        _buildMoodSection(),
        _buildRememberedHelpLine(),
        const SizedBox(height: 38),
        _buildBleedingSection(),
        const SizedBox(height: 38),
        _buildSymptomsSection(),
        const SizedBox(height: 38),
        _buildNoteSection(),
        const SizedBox(height: 34),
        _buildFooter(),
      ],
    );
  }

  Widget _buildWide() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildHeader(),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              flex: 11,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _buildHero(),
                  if (!_periodActive && !_canRecordFlow) ...<Widget>[
                    const SizedBox(height: 14),
                    _buildStartPeriodStrip(),
                  ] else if (!_periodActive) ...<Widget>[
                    const SizedBox(height: 14),
                    _buildRecordedTodayStrip(),
                  ],
                  if (_showComfortWindow) ...<Widget>[
                    const SizedBox(height: 18),
                    _buildComfortWindow(),
                  ],
                  const SizedBox(height: 30),
                  _buildMoodSection(),
                  _buildRememberedHelpLine(),
                ],
              ),
            ),
            const SizedBox(width: 32),
            Expanded(
              flex: 13,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _buildBleedingSection(),
                  const SizedBox(height: 38),
                  _buildSymptomsSection(),
                  const SizedBox(height: 38),
                  _buildNoteSection(),
                  const SizedBox(height: 34),
                  _buildFooter(),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Header — editorial masthead, no preview controls
  //
  // Text-scale resilience: above [_headerStackTextScale] or below
  // [_headerStackMinWidth] the row collapses into a stacked column — title
  // block first, date beneath — and each masthead line is fitted as one
  // unbroken line so no word is ever split across lines and the masthead
  // never consumes the first viewport on its own.
  // -------------------------------------------------------------------------

  Widget _buildHeaderTitleBlock({required bool compact}) {
    final Text kicker = Text(
      'TODAY',
      style: _kicker(),
      maxLines: 1,
      softWrap: false,
    );
    final Text title = Text(
      'Letter Within',
      style: _serif(30, weight: FontWeight.w600, height: 1.15),
      maxLines: 1,
      softWrap: false,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        compact ? _fitMastheadLine(kicker) : kicker,
        const SizedBox(height: 7),
        compact ? _fitMastheadLine(title) : title,
        const SizedBox(height: 9),
        Container(width: 30, height: 2, decoration: _emberRuleDecoration()),
      ],
    );
  }

  Widget _buildHeader() {
    final MediaQueryData media = MediaQuery.of(context);
    final bool stacked =
        media.textScaler.scale(1.0) > _headerStackTextScale ||
        media.size.width < _headerStackMinWidth;
    if (stacked) {
      final Text date = Text(
        _headerDateLabel(_cycleContext?.today),
        style: _sans(14.5, color: _inkSoft),
        maxLines: 1,
        softWrap: false,
      );
      return Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildHeaderTitleBlock(compact: true),
            const SizedBox(height: 8),
            _fitMastheadLine(date),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(child: _buildHeaderTitleBlock(compact: false)),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              _headerDateLabel(_cycleContext?.today),
              style: _sans(14.5, color: _inkSoft),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Cycle-context hero — the raised focal surface, honest states
  // -------------------------------------------------------------------------

  Widget _buildHero() {
    final cycle = _cycleContext;
    final isPeriodToday = cycle?.kind == TodayCycleKind.periodInProgress;
    final Widget heroChild = switch (_view) {
      _CycleView.loading => const _StatusLoadingCard(
        key: ValueKey<String>('loading'),
      ),
      _CycleView.known => _StatusCard(
        key: ValueKey<String>('known-$_periodActive'),
        title: isPeriodToday
            ? 'Period day ${cycle?.dayNumber ?? 1}'
            : 'Cycle day ${cycle?.dayNumber ?? 1}',
        middle: _KnownCycleMiddle(context: cycle),
        action: _periodActive
            ? TextButton(
                onPressed: _confirmEndPeriod,
                style: TextButton.styleFrom(
                  foregroundColor: _emberBright,
                  side: BorderSide(color: _ember.withValues(alpha: 0.7)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'End period',
                  style: _sans(12.5, weight: FontWeight.w700),
                ),
              )
            : null,
      ),
      _CycleView.learning => _StatusCard(
        key: const ValueKey<String>('learning'),
        kicker: 'LEARNING YOUR RHYTHM',
        title: 'Getting to know you',
        footnote: 'Patterns begin to emerge after a few more days.',
        middle: Text(
          'A few days logged so far. Each note today helps this space '
          'become more yours.',
          style: _sans(14.5, color: _ink.withValues(alpha: 0.88), height: 1.45),
        ),
      ),
      _CycleView.empty => _StatusCard(
        key: const ValueKey<String>('empty'),
        kicker: 'NO HISTORY YET',
        title: 'A quiet beginning',
        footnote: 'Private on this device.',
        middle: Text(
          _note == null
              ? 'No notes yet — and nothing to catch up on. Begin with how '
                    'this moment feels.'
              : 'Your note is here — and there is nothing else to catch up '
                    'on. Begin with how this moment feels.',
          style: _sans(14.5, color: _ink.withValues(alpha: 0.88), height: 1.45),
        ),
      ),
      _CycleView.error => _StatusErrorCard(
        key: const ValueKey<String>('error'),
        onRetry: _retryLoad,
      ),
    };
    return _swap(heroChild, duration: const Duration(milliseconds: 320));
  }

  /// Slim, quiet start-period surface — appears only when no period is
  /// active, so period status is never repeated across large cards.
  Widget _buildStartPeriodStrip() {
    final Widget startButton = OutlinedButton(
      onPressed: _startPeriodFromStrip,
      style: OutlinedButton.styleFrom(
        foregroundColor: _emberBright,
        side: const BorderSide(color: _ember, width: 1.3),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        'Start period',
        textAlign: TextAlign.center,
        style: _sans(13, weight: FontWeight.w700),
      ),
    );
    final Widget copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Has your period started?',
          style: _serif(16.5, weight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          'Marking day one sets the rhythm.',
          style: _sans(12.5, color: _inkSoft),
        ),
      ],
    );
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool compact =
              MediaQuery.textScalerOf(context).scale(1.0) >
                  _headerStackTextScale ||
              constraints.maxWidth < 320;
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                copy,
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, child: startButton),
              ],
            );
          }
          return Row(
            children: <Widget>[
              Expanded(child: copy),
              const SizedBox(width: 12),
              startButton,
            ],
          );
        },
      ),
    );
  }

  /// A period ended today still contains today, so its flow and color remain
  /// editable. Starting another period would necessarily overlap it.
  Widget _buildRecordedTodayStrip() {
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Period recorded today',
            style: _serif(16.5, weight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            'You can still update flow and color below.',
            style: _sans(12.5, color: _inkSoft),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Mood — one tap, plus a More sheet, plus an optional Care route
  // -------------------------------------------------------------------------

  Widget _buildMoodSection() {
    final List<MomentCheckInState> chips = List<MomentCheckInState>.of(
      _primaryMoods,
    );
    if (_mood != null && !chips.contains(_mood)) {
      chips.add(_mood!);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _SectionHeader(
          kicker: 'One tap — no wrong answers',
          title: 'How is this moment?',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            for (final MomentCheckInState m in chips)
              _Chip(
                label: m.label,
                selected: _mood == m,
                onTap: () => _selectMood(m),
              ),
            _Chip(
              label: 'More',
              selected: false,
              icon: Icons.add_rounded,
              onTap: _openMoreMoods,
            ),
          ],
        ),
        _swap(
          _showCareRoute
              ? Padding(
                  key: const ValueKey<String>('care'),
                  padding: const EdgeInsets.only(top: 14),
                  child: _buildCareNudge(),
                )
              : const SizedBox.shrink(key: ValueKey<String>('no-care')),
          duration: const Duration(milliseconds: 260),
          transitionBuilder: (Widget child, Animation<double> anim) {
            return SizeTransition(
              sizeFactor: CurvedAnimation(parent: anim, curve: Curves.easeOut),
              alignment: AlignmentDirectional.topStart,
              child: FadeTransition(opacity: anim, child: child),
            );
          },
        ),
      ],
    );
  }

  /// A gentle, optional doorway to Care — visible only when the day sounds
  /// heavy, and never opened on the user's behalf.
  Widget _buildCareNudge() {
    final Widget icon = Container(
      width: 34,
      height: 34,
      decoration: const BoxDecoration(
        color: _surfaceRaised,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.favorite_rounded, size: 16, color: _ember),
    );
    final Widget copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'This one sounds heavy.',
          style: _sans(14, weight: FontWeight.w700, color: _emberBright),
        ),
        const SizedBox(height: 2),
        Text(
          'Care is here if you’d like company with it.',
          style: _sans(12.5, color: _inkSoft, height: 1.4),
        ),
      ],
    );
    final TextButton action = TextButton(
      onPressed: _openCare,
      style: TextButton.styleFrom(
        foregroundColor: _emberBright,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text('Open Care', style: _sans(13, weight: FontWeight.w700)),
          const SizedBox(width: 3),
          const Icon(Icons.arrow_forward_rounded, size: 15),
        ],
      ),
    );
    return Container(
      decoration: BoxDecoration(
        color: _emberSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _ember.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool compact =
              MediaQuery.textScalerOf(context).scale(1.0) >
                  _headerStackTextScale ||
              constraints.maxWidth < 340;
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    icon,
                    const SizedBox(width: 12),
                    Expanded(child: copy),
                  ],
                ),
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: action),
              ],
            );
          }
          return Row(
            children: <Widget>[
              icon,
              const SizedBox(width: 12),
              Expanded(child: copy),
              const SizedBox(width: 8),
              action,
            ],
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Remembered help — a quiet memory, not an alert or a doorway
  // -------------------------------------------------------------------------

  /// One optional line the app remembers from earlier Care check-backs. It is
  /// composed upstream through the factual evidence gate and rendered here
  /// exactly as supplied — never summarized, rewritten, or inferred. There is
  /// no CTA and no navigation; it simply sits near the mood check-in like a
  /// margin note. Absent (intentional silence) whenever the line is null or
  /// empty, entering with a restrained fade/size when it appears.
  Widget _buildRememberedHelpLine() {
    final String? line = _rememberedHelpLine;
    final bool show = line != null && line.trim().isNotEmpty;
    return _swap(
      show
          ? Padding(
              key: const ValueKey<String>('remembered-help'),
              padding: const EdgeInsets.only(top: 18),
              child: Semantics(
                container: true,
                label: 'Remembered from before: $line',
                child: ExcludeSemantics(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: _ember.withValues(alpha: 0.5),
                          width: 2,
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.only(left: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'REMEMBERED',
                          style: _sans(
                            10,
                            color: _inkFaint,
                            weight: FontWeight.w700,
                            spacing: 2.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          line,
                          style: _serif(
                            14.5,
                            color: _ink,
                            weight: FontWeight.w500,
                            italic: true,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(key: ValueKey<String>('no-remembered-help')),
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (Widget child, Animation<double> anim) {
        return SizeTransition(
          sizeFactor: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          alignment: AlignmentDirectional.topStart,
          child: FadeTransition(opacity: anim, child: child),
        );
      },
    );
  }

  bool get _showComfortWindow {
    final comfort = _comfortWindow;
    return comfort != null &&
        (comfort.preparationVisible || comfort.reminderInvitationVisible);
  }

  Widget _buildComfortWindow() {
    final comfort = _comfortWindow!;
    if (!comfort.preparationVisible) {
      return _buildComfortReminderInvitation(comfort);
    }
    final range = _dateRangeLabel(comfort.forecastStart, comfort.forecastEnd);
    final reminderLine = comfort.reminderEnabled
        ? 'Reminder preference · ${comfortReminderLeadLabel(comfort.reminderLeadDays)} at 09:00'
        : 'Reminder is off';
    return Semantics(
      container: true,
      label:
          'Comfort Window. Estimated harder days $range. ${comfort.kitFormed ? 'Your Comfort Kit is ready.' : 'Care is available.'} $reminderLine.',
      child: Container(
        key: const ValueKey<String>('comfort-window-preparation'),
        decoration: _cardDecoration(color: _surfaceRaised),
        padding: const EdgeInsets.fromLTRB(18, 18, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _ember.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.nightlight_round,
                    color: _emberBright,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'A gentler plan for these days',
                        style: _serif(18, weight: FontWeight.w600),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Estimated harder days · $range',
                        style: _sans(
                          13,
                          color: _emberBright,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Your local pattern suggests this may be a harder stretch. '
              'It is an estimate, not a diagnosis.',
              style: _sans(13.5, color: _inkSoft, height: 1.5),
            ),
            const SizedBox(height: 12),
            Text(
              comfort.kitFormed
                  ? 'Your Comfort Kit is ready when you want it.'
                  : 'Care is here if a little company would help.',
              style: _sans(13.5, color: _ink, weight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final compact =
                    constraints.maxWidth < 340 ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.35;
                final careAction = OutlinedButton.icon(
                  onPressed: _openCare,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _emberBright,
                    minimumSize: const Size(0, _minTouchTarget),
                    side: BorderSide(color: _ember.withValues(alpha: 0.55)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: Icon(
                    comfort.kitFormed
                        ? Icons.inventory_2_outlined
                        : Icons.favorite_border_rounded,
                    size: 18,
                  ),
                  label: Text(
                    comfort.kitFormed ? 'Open Comfort Kit' : 'Open Care',
                    style: _sans(13.5, weight: FontWeight.w700),
                  ),
                );
                if (compact) {
                  return SizedBox(width: double.infinity, child: careAction);
                }
                return Align(
                  alignment: Alignment.centerLeft,
                  child: careAction,
                );
              },
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: _hairline),
            const SizedBox(height: 4),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final reminderAction = TextButton(
                  onPressed: _comfortWindowSaveInFlight
                      ? null
                      : _chooseComfortReminder,
                  style: TextButton.styleFrom(
                    foregroundColor: _inkSoft,
                    minimumSize: const Size(0, _minTouchTarget),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Text(
                    comfort.reminderEnabled
                        ? 'Change reminder'
                        : comfort.reminderConfigured
                        ? 'Reminder options'
                        : 'Choose reminder',
                    style: _sans(13, weight: FontWeight.w600),
                  ),
                );
                final compact =
                    constraints.maxWidth < 300 ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.35;
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          reminderLine,
                          style: _sans(11.5, color: _inkFaint),
                        ),
                      ),
                      reminderAction,
                    ],
                  );
                }
                return Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        reminderLine,
                        style: _sans(11.5, color: _inkFaint),
                      ),
                    ),
                    reminderAction,
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComfortReminderInvitation(TodayComfortWindowState comfort) {
    final cycleCount = comfort.sourceCycleCount;
    return Container(
      key: const ValueKey<String>('comfort-reminder-invitation'),
      decoration: _cardDecoration(),
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('A pattern is ready', style: _serif(17.5)),
          const SizedBox(height: 7),
          Text(
            'Your records show a clearer recurring window across '
            '$cycleCount ${cycleCount == 1 ? 'cycle' : 'cycles'}. Choose '
            'whether one quiet reminder would help.',
            style: _sans(13.5, color: _inkSoft, height: 1.5),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              TextButton(
                onPressed: _comfortWindowSaveInFlight
                    ? null
                    : _chooseComfortReminder,
                style: TextButton.styleFrom(
                  foregroundColor: _emberBright,
                  minimumSize: const Size(0, _minTouchTarget),
                ),
                child: Text(
                  'Choose reminder',
                  style: _sans(13.5, weight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: _comfortWindowSaveInFlight
                    ? null
                    : () => _saveComfortReminder(
                        enabled: false,
                        leadDays: comfort.reminderLeadDays,
                      ),
                style: TextButton.styleFrom(
                  foregroundColor: _inkSoft,
                  minimumSize: const Size(0, _minTouchTarget),
                ),
                child: Text(
                  'Not now',
                  style: _sans(13.5, weight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Bleeding — illustrated droplets, then color
  // -------------------------------------------------------------------------

  Widget _buildBleedingSection() {
    final bool showColor = _bleeding != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _SectionHeader(kicker: 'Right now', title: 'Any bleeding today?'),
        const SizedBox(height: 14),
        Container(
          decoration: _cardDecoration(),
          padding: const EdgeInsets.all(14),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  for (int i = 0; i < _bleedingOptions.length; i++)
                    Expanded(
                      child: DegreeGraphics.flowChoice(
                        _bleedingOptions[i],
                        selected: _bleeding == _bleedingOptions[i],
                        onTap: () => _selectBleeding(_bleedingOptions[i]),
                      ),
                    ),
                ],
              ),
              _swap(
                showColor
                    ? Padding(
                        key: const ValueKey<String>('color'),
                        padding: const EdgeInsets.only(top: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Divider(height: 1, color: _hairline),
                            const SizedBox(height: 14),
                            Text(
                              'Color — only if you want to say',
                              style: _sans(12.5, color: _inkSoft),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: <Widget>[
                                for (int i = 0; i < _colorOptions.length; i++)
                                  Expanded(
                                    child: DegreeGraphics.bleedingColorChoice(
                                      _colorOptions[i],
                                      selected:
                                          _bleedingColor == _colorOptions[i],
                                      onTap: () => _selectBleedingColor(
                                        _colorOptions[i],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey<String>('no-color')),
                duration: const Duration(milliseconds: 260),
                transitionBuilder: (Widget child, Animation<double> anim) {
                  return SizeTransition(
                    sizeFactor: anim,
                    alignment: AlignmentDirectional.topStart,
                    child: FadeTransition(opacity: anim, child: child),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Symptoms — concise editable entries
  // -------------------------------------------------------------------------

  Widget _buildSymptomsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _SectionHeader(
          kicker: 'One at a time',
          title: 'What else is present?',
        ),
        const SizedBox(height: 14),
        Container(
          decoration: _cardDecoration(),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
          child: Column(
            children: <Widget>[
              if (_symptoms.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    'Nothing added yet — add one at a time, only if it helps.',
                    style: _serif(
                      14.5,
                      color: _inkSoft,
                      weight: FontWeight.w500,
                      italic: true,
                      height: 1.4,
                    ),
                  ),
                )
              else
                for (int i = 0; i < _symptoms.length; i++) ...<Widget>[
                  if (i > 0) const Divider(height: 1, color: _hairline),
                  _SymptomRow(
                    entry: _symptoms[i],
                    onTap: () => _editSymptom(i),
                    onRemove: () => _removeSymptom(i),
                  ),
                ],
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _addSymptom,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add a symptom'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _emberBright,
                    side: BorderSide(color: _ember.withValues(alpha: 0.45)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: _sans(14.5, weight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Quick note — optional, low priority
  // -------------------------------------------------------------------------

  Widget _buildNoteSection() {
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    final Widget firstChild = InkWell(
      key: const ValueKey<String>('quick-note-add'),
      onTap: _beginNewNote,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: <Widget>[
            const Icon(Icons.edit_note_rounded, size: 20, color: _inkSoft),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _quickNotes.isEmpty
                    ? 'Write a line for future you'
                    : 'Add another quick note',
                style: _sans(14, color: _inkSoft),
              ),
            ),
            const Icon(Icons.add_rounded, size: 18, color: _inkSoft),
          ],
        ),
      ),
    );
    final Widget secondChild = Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextField(
            key: const ValueKey<String>('quick-note-field'),
            controller: _noteController,
            autofocus: true,
            maxLines: 6,
            minLines: 2,
            cursorColor: _ember,
            style: _serif(
              15,
              color: _ink,
              weight: FontWeight.w500,
              italic: true,
              height: 1.45,
            ),
            decoration: InputDecoration(
              hintText: 'Whatever you want to remember…',
              hintStyle: _serif(
                15,
                color: _inkFaint,
                weight: FontWeight.w400,
                italic: true,
              ),
              border: InputBorder.none,
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Material(
            color: Colors.transparent,
            child: SwitchListTile.adaptive(
              key: const ValueKey<String>('quick-note-comfort-kit-toggle'),
              contentPadding: EdgeInsets.zero,
              value: _keepNoteInComfortKit,
              activeTrackColor: _ember,
              onChanged: (value) =>
                  setState(() => _keepNoteInComfortKit = value),
              title: Text(
                'Keep in Comfort Kit',
                style: _sans(14, weight: FontWeight.w600),
              ),
              subtitle: Text(
                'Make this line easy to find when you need care.',
                style: _sans(12.5, color: _inkSoft),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              TextButton(
                onPressed: _cancelNoteEditing,
                style: TextButton.styleFrom(foregroundColor: _inkSoft),
                child: Text(
                  'Not now',
                  style: _sans(13.5, weight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 6),
              TextButton(
                onPressed: _saveNote,
                style: TextButton.styleFrom(
                  foregroundColor: _canvas,
                  backgroundColor: _ember,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _editingNoteId == null ? 'Keep note' : 'Update note',
                  style: _sans(13.5, weight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _SectionHeader(kicker: 'Optional', title: 'Quick note'),
        const SizedBox(height: 14),
        Container(
          decoration: _cardDecoration(),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (_quickNotes.isNotEmpty && !_noteOpen) ...<Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Text(
                    '${_quickNotes.length} saved ${_quickNotes.length == 1 ? 'note' : 'notes'}',
                    style: _sans(12.5, color: _inkSoft),
                  ),
                ),
                for (var index = 0; index < _quickNotes.length; index++) ...[
                  if (index > 0) const Divider(color: _hairline, height: 1),
                  _QuickNoteRow(
                    key: ValueKey<String>(
                      'quick-note-${_quickNotes[index].id}',
                    ),
                    note: _quickNotes[index],
                    onEdit: () => _beginEditingNote(_quickNotes[index]),
                    onDelete: () => _deleteNote(_quickNotes[index]),
                  ),
                ],
              ],
              if (reduced)
                (_noteOpen ? secondChild : firstChild)
              else
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 220),
                  crossFadeState: _noteOpen
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: firstChild,
                  secondChild: secondChild,
                ),
            ],
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Footer + acknowledgement toast
  // -------------------------------------------------------------------------

  Widget _buildFooter() {
    return Center(
      child: Text(
        'Everything here stays on this device.',
        style: _serif(
          12.5,
          color: _inkFaint,
          weight: FontWeight.w500,
          italic: true,
        ),
      ),
    );
  }

  Widget _buildAckToast() {
    final Widget toast = Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: _surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _hairline),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: _ember,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              _ack ?? '',
              style: _sans(13.5, color: _ink, weight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    return Positioned(
      left: 0,
      right: 0,
      bottom: 22,
      child: IgnorePointer(
        child: Center(
          child: reduced
              ? Opacity(opacity: _ack == null ? 0 : 1, child: toast)
              : AnimatedOpacity(
                  duration: _motion(context, const Duration(milliseconds: 220)),
                  opacity: _ack == null ? 0 : 1,
                  child: AnimatedSlide(
                    duration: _motion(
                      context,
                      const Duration(milliseconds: 220),
                    ),
                    offset: _ack == null ? const Offset(0, 0.4) : Offset.zero,
                    child: toast,
                  ),
                ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ambient field — static, non-semantic, and anchored behind cycle context.
// ---------------------------------------------------------------------------

class _DuskAmbient extends StatelessWidget {
  const _DuskAmbient();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: Stack(
            children: <Widget>[
              Positioned(
                top: 105,
                left: -155,
                width: 440,
                height: 440,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: <Color>[
                        _ember.withValues(alpha: 0.075),
                        _canvas.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section header — kicker + editorial serif question
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.kicker, required this.title});

  final String kicker;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(kicker.toUpperCase(), style: _kicker()),
        const SizedBox(height: 7),
        Text(title, style: _serif(21, weight: FontWeight.w600, height: 1.24)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Hero variants
// ---------------------------------------------------------------------------

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    super.key,
    this.kicker,
    required this.title,
    required this.middle,
    this.footnote,
    this.action,
  });

  final String? kicker;
  final String title;
  final Widget middle;
  final String? footnote;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[_surfaceRaised, _surface],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _hairline),
        // The viewport's single focal shadow: plum-black, low and warm —
        // in dusk, shadows deepen rather than lighten.
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.34),
            blurRadius: 36,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (kicker != null) ...<Widget>[
            Text(
              kicker!,
              style: _sans(
                10.5,
                color: _emberBright.withValues(alpha: 0.85),
                weight: FontWeight.w700,
                spacing: 2.2,
              ),
            ),
            const SizedBox(height: 8),
          ],
          // Display-type resilience: the hero title keeps its authored serif
          // voice at every scale, but it is measured and clamped so no word
          // ever splits mid-glyph and the title never fills the first
          // viewport on its own. Normal-scale rendering is unchanged.
          _DisplayTitle(
            title,
            style: _serif(
              29,
              color: _ink,
              weight: FontWeight.w600,
              height: 1.12,
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          middle,
          if (footnote != null || action != null) ...<Widget>[
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                if (footnote != null)
                  Expanded(
                    child: Text(
                      footnote!,
                      style: _sans(12.5, color: _inkSoft, height: 1.4),
                    ),
                  )
                else
                  const Spacer(),
                if (action != null) ...<Widget>[
                  if (footnote != null) const SizedBox(width: 12),
                  action!,
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The honest load-failure state. A failed read is never dressed up as a
/// lifecycle state: this calm plum card says plainly that today's notes
/// could not be read, reassures that nothing written is lost, and offers a
/// single quiet retry.
class _StatusErrorCard extends StatelessWidget {
  const _StatusErrorCard({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      label: "We couldn't read today's notes. Try again.",
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          decoration: _cardDecoration(),
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('A QUIET PAUSE', style: _kicker(color: _error)),
              const SizedBox(height: 8),
              _DisplayTitle(
                "We couldn’t read today’s notes",
                style: _serif(26),
              ),
              const SizedBox(height: 10),
              Text(
                'Nothing you have written is lost — this page simply could '
                'not reach it just now.',
                style: _sans(14.5, color: _inkSoft, height: 1.5),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _emberBright,
                  side: const BorderSide(color: _ember, width: 1.3),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Try again',
                  style: _sans(14, weight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KnownCycleMiddle extends StatelessWidget {
  const _KnownCycleMiddle({required this.context});

  final TodayCycleContext? context;

  @override
  Widget build(BuildContext context) {
    final currentContext = this.context;
    if (currentContext == null) return const SizedBox.shrink();
    final prediction = currentContext.prediction;
    final isPeriod = currentContext.kind == TodayCycleKind.periodInProgress;
    final day = currentContext.dayNumber ?? 1;
    final double? progress = isPeriod || prediction == null
        ? null
        : (day / prediction.medianCycleDays).clamp(0.0, 1.0);
    final String caption = prediction == null
        ? isPeriod
              ? 'Started ${_shortDateLabel(currentContext.latestStart!)}'
              : 'Record one more period to see an estimate'
        : 'Estimated next period ${_dateRangeLabel(prediction.predictedMensesStart, prediction.predictedMensesEnd)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(caption, style: _sans(13, color: _inkSoft)),
        if (prediction != null) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            cycleEstimateContextLabel(prediction, currentContext.today),
            style: _sans(12.5, color: _inkSoft),
          ),
        ],
        if (progress != null) ...<Widget>[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: _ink.withValues(alpha: 0.14),
              valueColor: const AlwaysStoppedAnimation<Color>(_ember),
            ),
          ),
        ],
      ],
    );
  }
}

const List<String> _shortMonths = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _shortDateLabel(LocalDate date) =>
    '${_shortMonths[date.month - 1]} ${date.day}';

String _dateRangeLabel(LocalDate start, LocalDate end) {
  if (start == end) return _shortDateLabel(start);
  if (start.year != end.year) {
    return '${_shortDateLabel(start)}, ${start.year}–${_shortDateLabel(end)}, ${end.year}';
  }
  return '${_shortDateLabel(start)}–${_shortDateLabel(end)}';
}

String _headerDateLabel(LocalDate? date) {
  if (date == null) return 'Today';
  const weekdays = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final weekday = date.asLocalDateTime.weekday;
  return '${weekdays[weekday - 1]}, ${_shortDateLabel(date)}';
}

class _StatusLoadingCard extends StatefulWidget {
  const _StatusLoadingCard({super.key});

  @override
  State<_StatusLoadingCard> createState() => _StatusLoadingCardState();
}

class _StatusLoadingCardState extends State<_StatusLoadingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _reducedMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    _reducedMotion = reduced;
    if (reduced) {
      // Reduced motion: no continuous shimmer — the placeholder rests at a
      // single composed opacity instead.
      if (_controller.isAnimating) _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _bar(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _ink,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget bars = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _bar(96, 10),
        const SizedBox(height: 16),
        _bar(210, 26),
        const SizedBox(height: 16),
        _bar(150, 12),
        const SizedBox(height: 8),
        _bar(230, 12),
      ],
    );
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _surfaceRaised,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _hairline),
      ),
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
      child: _reducedMotion
          ? Opacity(opacity: 0.4, child: bars)
          : FadeTransition(
              opacity: Tween<double>(begin: 0.2, end: 0.55).animate(
                CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
              ),
              child: bars,
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chips (mood, symptom groups)
// ---------------------------------------------------------------------------

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    // The visible chip keeps its exact normal-scale size; only the invisible
    // hit area grows to meet the minimum accessible touch target. At extreme
    // text scale the label is allowed to wrap inside the width its parent can
    // truly offer, so every word remains fully visible instead of overflowing.
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            double maxWidth = constraints.maxWidth;
            if (!maxWidth.isFinite) {
              final double screenWidth = MediaQuery.sizeOf(context).width;
              maxWidth = screenWidth - 64;
            }
            if (maxWidth < _minTouchTarget) maxWidth = _minTouchTarget;
            final Widget content = Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (selected) ...<Widget>[
                  const Icon(
                    Icons.check_rounded,
                    size: 15,
                    color: _emberBright,
                  ),
                  const SizedBox(width: 6),
                ] else if (icon != null) ...<Widget>[
                  Icon(icon, size: 15, color: _inkSoft),
                  const SizedBox(width: 5),
                ],
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: _sans(15, weight: FontWeight.w600, color: _ink),
                  ),
                ),
              ],
            );
            final BoxDecoration decoration = BoxDecoration(
              color: selected
                  ? _ember.withValues(alpha: 0.17)
                  : _surface.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected
                    ? _ember.withValues(alpha: 0.8)
                    : _ink.withValues(alpha: 0.16),
                width: selected ? 1.2 : 1,
              ),
            );
            const EdgeInsets padding = EdgeInsets.symmetric(
              horizontal: 17,
              vertical: 11,
            );
            final Widget chip = reduced
                ? Container(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    padding: padding,
                    decoration: decoration,
                    child: content,
                  )
                : AnimatedContainer(
                    duration: _motion(
                      context,
                      const Duration(milliseconds: 180),
                    ),
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    padding: padding,
                    decoration: decoration,
                    child: content,
                  );
            return ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: _minTouchTarget,
                minHeight: _minTouchTarget,
              ),
              child: Center(widthFactor: 1, heightFactor: 1, child: chip),
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Symptom browser — six semantic groups behind a compact chip rail
// ---------------------------------------------------------------------------

class _SymptomBrowserSheet extends StatefulWidget {
  const _SymptomBrowserSheet({required this.groups});

  final List<_SymptomGroup> groups;

  @override
  State<_SymptomBrowserSheet> createState() => _SymptomBrowserSheetState();
}

class _SymptomBrowserSheetState extends State<_SymptomBrowserSheet> {
  int _group = 0;

  @override
  Widget build(BuildContext context) {
    final _SymptomGroup group = widget.groups[_group];
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    final Widget hint = Text(
      '${group.name} — ${group.hint}',
      key: ValueKey<int>(_group),
      style: _serif(
        13,
        color: _inkSoft,
        weight: FontWeight.w500,
        italic: true,
        height: 1.3,
      ),
    );
    final Widget list = ListView.separated(
      key: ValueKey<int>(_group),
      itemCount: group.symptoms.length,
      separatorBuilder: (_, _) => const Divider(height: 1, color: _hairline),
      itemBuilder: (BuildContext context, int i) {
        return InkWell(
          onTap: () => Navigator.of(context).pop(group.symptoms[i]),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(group.symptoms[i].label, style: _sans(15.5)),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: _inkFaint,
                ),
              ],
            ),
          ),
        );
      },
    );
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.68,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const _SheetHandle(),
              const SizedBox(height: 14),
              Text('Choose one symptom', style: _serif(20)),
              const SizedBox(height: 4),
              Text(
                'One at a time — browse wherever it lives.',
                style: _sans(13.5, color: _inkSoft),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: _minTouchTarget,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.groups.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (BuildContext context, int i) {
                    return Center(
                      child: _Chip(
                        label: widget.groups[i].name,
                        selected: _group == i,
                        onTap: () => setState(() => _group = i),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              reduced
                  ? hint
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: hint,
                    ),
              const SizedBox(height: 6),
              Expanded(
                child: reduced
                    ? list
                    : AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder:
                            (Widget child, Animation<double> anim) {
                              return FadeTransition(
                                opacity: anim,
                                child: child,
                              );
                            },
                        child: list,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Severity legend — five rising steps that name the scale at a glance
// ---------------------------------------------------------------------------

class _SeverityLegend extends StatelessWidget {
  const _SeverityLegend();

  static const List<double> _barHeights = <double>[5, 9, 13, 17, 21];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _canvas,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _hairline),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              for (int i = 0; i < 5; i++)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      SizedBox(
                        height: 21,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            width: 14,
                            height: _barHeights[i],
                            decoration: BoxDecoration(
                              color:
                                  _TodayExperienceVisualState._severityRamp[i],
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _TodayExperienceVisualState._severities[i].$1.label,
                          maxLines: 1,
                          softWrap: false,
                          style: _sans(
                            10,
                            weight: FontWeight.w600,
                            color: i == 4 ? _emberBright : _inkSoft,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'A gentle scale — from barely there to all-consuming.',
              textAlign: TextAlign.center,
              style: _serif(
                12,
                color: _inkSoft,
                weight: FontWeight.w500,
                italic: true,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One tappable severity row: its step on the legend scale (filled pips in
/// the step's own color) beside the name and a plain-words meaning.
class _SeverityChoice extends StatelessWidget {
  const _SeverityChoice({
    required this.index,
    required this.name,
    required this.desc,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final String name;
  final String desc;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    final BoxDecoration decoration = BoxDecoration(
      color: selected ? _emberSoft : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: selected ? _ember : _hairline,
        width: selected ? 1.4 : 1,
      ),
    );
    const EdgeInsets padding = EdgeInsets.symmetric(
      horizontal: 14,
      vertical: 12,
    );
    final Widget body = Row(
      children: <Widget>[
        SizedBox(
          width: 34,
          child: Row(
            children: <Widget>[
              for (int p = 0; p < 5; p++)
                Padding(
                  padding: const EdgeInsets.only(right: 2.5),
                  child: Container(
                    width: 4,
                    height: 4 + (p * 1.5),
                    decoration: BoxDecoration(
                      color: p <= index ? color : _ink.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                name,
                style: _sans(
                  15,
                  weight: FontWeight.w600,
                  color: selected ? _emberBright : _ink,
                ),
              ),
              Text(desc, style: _sans(12.5, color: _inkSoft)),
            ],
          ),
        ),
        if (selected) const Icon(Icons.check_rounded, size: 18, color: _ember),
      ],
    );
    return Semantics(
      button: true,
      selected: selected,
      label: '$name — $desc',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: reduced
            ? Container(padding: padding, decoration: decoration, child: body)
            : AnimatedContainer(
                duration: _motion(context, const Duration(milliseconds: 160)),
                padding: padding,
                decoration: decoration,
                child: body,
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Quick note history row — stable identity, explicit edit/delete controls
// ---------------------------------------------------------------------------

class _QuickNoteRow extends StatelessWidget {
  const _QuickNoteRow({
    super.key,
    required this.note,
    required this.onEdit,
    required this.onDelete,
  });

  final CaptureNote note;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  note.text,
                  style: _serif(
                    14.5,
                    color: _ink,
                    weight: FontWeight.w500,
                    italic: true,
                    height: 1.45,
                  ),
                ),
                if (note.keepInComfortKit) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    'In Comfort Kit',
                    style: _sans(
                      12,
                      color: _emberBright,
                      weight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            key: ValueKey<String>('quick-note-edit-${note.id}'),
            onPressed: onEdit,
            tooltip: 'Edit quick note',
            constraints: const BoxConstraints(
              minWidth: _minTouchTarget,
              minHeight: _minTouchTarget,
            ),
            icon: const Icon(Icons.edit_outlined, size: 19),
            color: _inkSoft,
          ),
          IconButton(
            key: ValueKey<String>('quick-note-delete-${note.id}'),
            onPressed: onDelete,
            tooltip: 'Delete quick note',
            constraints: const BoxConstraints(
              minWidth: _minTouchTarget,
              minHeight: _minTouchTarget,
            ),
            icon: const Icon(Icons.delete_outline_rounded, size: 19),
            color: _inkSoft,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Symptom entry row — editable + removable
// ---------------------------------------------------------------------------

class _SymptomRow extends StatelessWidget {
  const _SymptomRow({
    required this.entry,
    required this.onTap,
    required this.onRemove,
  });

  final _SymptomEntry entry;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    entry.definition.label,
                    style: _sans(15, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.severity.label,
                    style: _serif(
                      13,
                      color: _emberBright,
                      weight: FontWeight.w600,
                      italic: true,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.edit_outlined, size: 16, color: _inkFaint),
            const SizedBox(width: 4),
            IconButton(
              onPressed: onRemove,
              tooltip: 'Remove ${entry.definition.label}',
              icon: const Icon(Icons.close_rounded, size: 18),
              color: _inkSoft,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(
                minWidth: _minTouchTarget,
                minHeight: _minTouchTarget,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sheet handle
// ---------------------------------------------------------------------------

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: _ink.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
