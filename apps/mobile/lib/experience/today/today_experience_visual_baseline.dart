import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/check_in/domain/moment_check_in.dart';
import '../../features/cycle/domain/bleeding_flow.dart';
import '../../features/cycle/domain/local_date.dart';
import '../../features/health_records/domain/health_record.dart';
import '../../features/health_records/domain/observation_catalog.dart';
import '../../features/today/today_cycle_context.dart';
import '../degree/degree_graphics.dart';
import 'today_visual_port.dart';

/// Letter Within — Today.
///
/// A calm, action-oriented daily surface: quick mood (with a gentle,
/// optional route to Care on heavy days), bleeding with an explicit
/// period-start decision, symptoms one at a time browsed across six
/// semantic groups, each with one named severity explained by a calm
/// visual legend, period start/end, and an optional private note.
/// No forms, no page-level save — every selection acknowledges itself
/// immediately.
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
// Palette & type — quiet editorial tokens
// ---------------------------------------------------------------------------

const Color _bg = Color(0xFFF5F1E8); // warm off-white
const Color _paper = Color(0xFFFFFCF7); // paper white
const Color _ink = Color(0xFF181713); // ink
const Color _inkSoft = Color(0xFF6E675C);
const Color _plum = Color(0xFF3E2A3C); // deep plum display type
const Color _terra = Color(0xFFC95D3A); // terracotta accent
const Color _terraDeep = Color(0xFFA8482C);
const Color _terraTint = Color(0xFFF6E4D8);
const Color _hairline = Color(0xFFE7DFD0);

TextStyle _serif(
  double size, {
  Color color = _plum,
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

TextStyle _kicker({Color color = _terra}) =>
    _sans(11, color: color, weight: FontWeight.w700, spacing: 2.4);

BoxDecoration _cardDecoration({Color color = _paper, bool shadow = true}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: _hairline),
    boxShadow: shadow
        ? [
            BoxShadow(
              color: const Color(0xFF3A2A1E).withValues(alpha: 0.07),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ]
        : null,
  );
}

// ---------------------------------------------------------------------------
// Local visual state
// ---------------------------------------------------------------------------

enum _CycleView { loading, known, learning, empty }

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
  Timer? _viewTimer;
  TodayCycleContext? _cycleContext;

  // Today's quick captures.
  MomentCheckInState? _mood;
  BleedingFlow? _bleeding;
  BleedingColor? _bleedingColor;
  final List<_SymptomEntry> _symptoms = <_SymptomEntry>[];
  bool _periodActive = false;
  bool _canRecordFlow = false;

  // A line the app remembers from earlier Care check-backs. Composed
  // upstream through the factual evidence gate; shown verbatim, never
  // summarized, rewritten, or inferred. Null means intentional silence.
  String? _rememberedHelpLine;

  // Optional note to self.
  bool _noteOpen = false;
  String? _note;
  final TextEditingController _noteController = TextEditingController();

  // Acknowledgement toast.
  String? _ack;
  Timer? _ackTimer;

  static const List<MomentCheckInState> _primaryMoods = <MomentCheckInState>[
    MomentCheckInState.good,
    MomentCheckInState.calm,
    MomentCheckInState.steady,
    MomentCheckInState.energized,
    MomentCheckInState.low,
    MomentCheckInState.irritable,
    MomentCheckInState.anxious,
    MomentCheckInState.tender,
  ];

  static const List<MomentCheckInState> _moreMoods = <MomentCheckInState>[
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
  /// terracotta to its deepest note.
  static const List<Color> _severityRamp = DegreeGraphics.severityRamp;

  bool get _showCareRoute => _mood != null && _heavyMoods.contains(_mood);

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
      if (mounted) setState(() => _view = _CycleView.learning);
    }
  }

  @override
  void dispose() {
    _viewTimer?.cancel();
    _ackTimer?.cancel();
    _noteController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Acknowledgement
  // -------------------------------------------------------------------------

  void _acknowledge(String message) {
    _ackTimer?.cancel();
    setState(() => _ack = message);
    _ackTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _ack = null);
    });
  }

  // -------------------------------------------------------------------------
  // Hero transitions — a brief shimmer between honest states
  // -------------------------------------------------------------------------

  void _transitionHero(_CycleView target) {
    _viewTimer?.cancel();
    setState(() => _view = _CycleView.loading);
    _viewTimer = Timer(const Duration(milliseconds: 650), () {
      if (mounted) setState(() => _view = target);
    });
  }

  // -------------------------------------------------------------------------
  // Mood
  // -------------------------------------------------------------------------

  Future<void> _selectMood(MomentCheckInState mood) async {
    try {
      setState(() => _mood = mood);
      final snapshot = await widget.port.saveMood(mood);
      if (!mounted) return;
      await _reloadFrom(snapshot);
      _acknowledge('Mood noted — ${mood.label}');
    } on Object {
      if (mounted) {
        await _reload();
        _acknowledge("Letter Within couldn't save that. Try again.");
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
      _rememberedHelpLine = snapshot.rememberedHelpLine;
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
          backgroundColor: _paper,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
      _acknowledge('Bleeding noted — ${flow?.label ?? 'None'}');
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
      backgroundColor: _paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                      foregroundColor: Colors.white,
                      backgroundColor: _terra,
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
        _acknowledge('Period started — day 1 noted');
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
      _acknowledge('Color noted — ${color.label}');
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
          backgroundColor: _paper,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
      _acknowledge('Symptom removed');
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
      backgroundColor: _paper,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
      _acknowledge('Period started — day 1 noted');
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
          backgroundColor: _paper,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
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
                foregroundColor: Colors.white,
                backgroundColor: _terra,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
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
      _acknowledge('Period ended — noted');
    } on Object {
      if (mounted) {
        await _reload();
        _acknowledge("Letter Within couldn't save that. Try again.");
      }
    }
  }

  // -------------------------------------------------------------------------
  // Note to self
  // -------------------------------------------------------------------------

  Future<void> _saveNote() async {
    final String text = _noteController.text.trim();
    if (text.isEmpty) {
      setState(() => _noteOpen = false);
      return;
    }
    try {
      final snapshot = await widget.port.saveNote(text);
      if (!mounted) return;
      await _reloadFrom(snapshot);
      setState(() => _noteOpen = false);
      _acknowledge('Note kept — only you can read it');
    } on Object {
      if (mounted) {
        _acknowledge("Letter Within couldn't save that. Try again.");
      }
    }
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Stack(
          children: <Widget>[
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
        const SizedBox(height: 32),
        _buildMoodSection(),
        _buildRememberedHelpLine(),
        const SizedBox(height: 32),
        _buildBleedingSection(),
        const SizedBox(height: 32),
        _buildSymptomsSection(),
        const SizedBox(height: 32),
        _buildNoteSection(),
        const SizedBox(height: 28),
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
                  const SizedBox(height: 32),
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
                  const SizedBox(height: 32),
                  _buildSymptomsSection(),
                  const SizedBox(height: 32),
                  _buildNoteSection(),
                  const SizedBox(height: 28),
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
  // -------------------------------------------------------------------------

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('TODAY', style: _kicker()),
                const SizedBox(height: 6),
                Text('Letter Within', style: _serif(34)),
                const SizedBox(height: 8),
                Container(width: 34, height: 2, color: _terra),
              ],
            ),
          ),
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
  // Cycle-context hero — coral, honest states, no cycle ring
  // -------------------------------------------------------------------------

  Widget _buildHero() {
    final context = _cycleContext;
    final isPeriodToday = context?.kind == TodayCycleKind.periodInProgress;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      child: switch (_view) {
        _CycleView.loading => const _StatusLoadingCard(
          key: ValueKey<String>('loading'),
        ),
        _CycleView.known => _StatusCard(
          key: ValueKey<String>('known-$_periodActive'),
          kicker: 'TODAY’S PLACE IN THE CYCLE',
          title: isPeriodToday ? 'Period phase' : 'Between periods',
          footnote: context == null
              ? 'Loading your recorded dates.'
              : 'Based on your recorded period starts.',
          middle: _KnownCycleMiddle(context: context),
          action: _periodActive
              ? TextButton(
                  onPressed: _confirmEndPeriod,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
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
            style: _sans(
              14.5,
              color: Colors.white.withValues(alpha: 0.92),
              height: 1.45,
            ),
          ),
        ),
        _CycleView.empty => _StatusCard(
          key: const ValueKey<String>('empty'),
          kicker: 'NO HISTORY YET',
          title: 'A quiet beginning',
          footnote: 'Private by default. Always yours.',
          middle: Text(
            'No notes yet — and nothing to catch up on. Begin with how '
            'this moment feels.',
            style: _sans(
              14.5,
              color: Colors.white.withValues(alpha: 0.92),
              height: 1.45,
            ),
          ),
        ),
      },
    );
  }

  /// Slim, quiet start-period surface — appears only when no period is
  /// active, so period status is never repeated across large cards.
  Widget _buildStartPeriodStrip() {
    return Container(
      decoration: _cardDecoration(shadow: false),
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
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
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: _startPeriodFromStrip,
            style: OutlinedButton.styleFrom(
              foregroundColor: _terraDeep,
              side: const BorderSide(color: _terra, width: 1.3),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
            child: Text(
              'Start period',
              style: _sans(13, weight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  /// A period ended today still contains today, so its flow and color remain
  /// editable. Starting another period would necessarily overlap it.
  Widget _buildRecordedTodayStrip() {
    return Container(
      decoration: _cardDecoration(shadow: false),
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
        const SizedBox(height: 14),
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
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          transitionBuilder: (Widget child, Animation<double> anim) {
            return SizeTransition(
              sizeFactor: CurvedAnimation(parent: anim, curve: Curves.easeOut),
              alignment: AlignmentDirectional.topStart,
              child: FadeTransition(opacity: anim, child: child),
            );
          },
          child: _showCareRoute
              ? Padding(
                  key: const ValueKey<String>('care'),
                  padding: const EdgeInsets.only(top: 14),
                  child: _buildCareNudge(),
                )
              : const SizedBox.shrink(key: ValueKey<String>('no-care')),
        ),
      ],
    );
  }

  /// A gentle, optional doorway to Care — visible only when the day sounds
  /// heavy, and never opened on the user's behalf.
  Widget _buildCareNudge() {
    return Container(
      decoration: BoxDecoration(
        color: _terraTint.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _terra.withValues(alpha: 0.35)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: _paper,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.favorite_rounded, size: 16, color: _terra),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'This one sounds heavy.',
                  style: _sans(14, weight: FontWeight.w700, color: _terraDeep),
                ),
                const SizedBox(height: 2),
                Text(
                  'Care is here if you’d like company with it.',
                  style: _sans(12.5, color: _inkSoft, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _openCare,
            style: TextButton.styleFrom(
              foregroundColor: _terraDeep,
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
          ),
        ],
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
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (Widget child, Animation<double> anim) {
        return SizeTransition(
          sizeFactor: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          alignment: AlignmentDirectional.topStart,
          child: FadeTransition(opacity: anim, child: child),
        );
      },
      child: show
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
                          color: _terra.withValues(alpha: 0.45),
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
                            color: _inkSoft.withValues(alpha: 0.85),
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
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                transitionBuilder: (Widget child, Animation<double> anim) {
                  return SizeTransition(
                    sizeFactor: anim,
                    alignment: AlignmentDirectional.topStart,
                    child: FadeTransition(opacity: anim, child: child),
                  );
                },
                child: showColor
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
                    foregroundColor: _terraDeep,
                    side: const BorderSide(color: _hairline),
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
  // Note to self — optional, low priority
  // -------------------------------------------------------------------------

  Widget _buildNoteSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _SectionHeader(kicker: 'Optional', title: 'A note to self'),
        const SizedBox(height: 14),
        Container(
          decoration: _cardDecoration(shadow: false),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (_note != null && !_noteOpen)
                InkWell(
                  onTap: () {
                    _noteController.text = _note!;
                    setState(() => _noteOpen = true);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          width: 3,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _terra,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _note!,
                            style: _serif(
                              14.5,
                              color: _ink,
                              weight: FontWeight.w500,
                              italic: true,
                              height: 1.45,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.edit_outlined,
                          size: 16,
                          color: _inkSoft,
                        ),
                      ],
                    ),
                  ),
                ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 220),
                crossFadeState: _noteOpen
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: InkWell(
                  onTap: () {
                    if (_note != null) _noteController.text = _note!;
                    setState(() => _noteOpen = true);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      children: <Widget>[
                        const Icon(
                          Icons.edit_note_rounded,
                          size: 20,
                          color: _inkSoft,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _note == null
                                ? 'Write a line for future you'
                                : 'Add another line',
                            style: _sans(14, color: _inkSoft),
                          ),
                        ),
                        const Icon(
                          Icons.add_rounded,
                          size: 18,
                          color: _inkSoft,
                        ),
                      ],
                    ),
                  ),
                ),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      TextField(
                        controller: _noteController,
                        autofocus: true,
                        maxLines: 3,
                        minLines: 2,
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
                            color: _inkSoft.withValues(alpha: 0.6),
                            weight: FontWeight.w400,
                            italic: true,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
                          TextButton(
                            onPressed: () => setState(() => _noteOpen = false),
                            style: TextButton.styleFrom(
                              foregroundColor: _inkSoft,
                            ),
                            child: Text(
                              'Not now',
                              style: _sans(13.5, weight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 6),
                          TextButton(
                            onPressed: _saveNote,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: _terra,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              'Keep note',
                              style: _sans(13.5, weight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ],
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
  // Footer + acknowledgement toast
  // -------------------------------------------------------------------------

  Widget _buildFooter() {
    return Center(
      child: Text(
        'Everything here stays on this device.',
        style: _serif(
          12.5,
          color: _inkSoft.withValues(alpha: 0.8),
          weight: FontWeight.w500,
          italic: true,
        ),
      ),
    );
  }

  Widget _buildAckToast() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 22,
      child: IgnorePointer(
        child: Center(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            opacity: _ack == null ? 0 : 1,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 220),
              offset: _ack == null ? const Offset(0, 0.4) : Offset.zero,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _ink.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: _ink.withValues(alpha: 0.25),
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
                        color: _terra,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        _ack ?? '',
                        style: _sans(
                          13.5,
                          color: _paper,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
        const SizedBox(height: 6),
        Text(title, style: _serif(22)),
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
    required this.kicker,
    required this.title,
    required this.middle,
    required this.footnote,
    this.action,
  });

  final String kicker;
  final String title;
  final Widget middle;
  final String footnote;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFE0703F), Color(0xFFC3432C)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFFC3432C).withValues(alpha: 0.32),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            kicker,
            style: _sans(
              10.5,
              color: Colors.white.withValues(alpha: 0.75),
              weight: FontWeight.w700,
              spacing: 2.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(title, style: _serif(30, color: Colors.white, height: 1.05)),
          const SizedBox(height: 12),
          middle,
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: Text(
                  footnote,
                  style: _sans(
                    12.5,
                    color: Colors.white.withValues(alpha: 0.8),
                    height: 1.4,
                  ),
                ),
              ),
              if (action != null) ...<Widget>[
                const SizedBox(width: 12),
                action!,
              ],
            ],
          ),
        ],
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
    final String lead = 'Day $day ';
    final String rest = isPeriod
        ? 'of your recorded period'
        : prediction == null
        ? 'of your current cycle'
        : 'of a typical ${prediction.medianCycleDays}-day cycle';
    final double? progress = isPeriod || prediction == null
        ? null
        : (day / prediction.medianCycleDays).clamp(0.0, 1.0);
    final String caption = prediction == null
        ? isPeriod
              ? 'This period began ${_shortDateLabel(currentContext.latestStart!)}'
              : 'One more recorded period start will add a personalized estimate'
        : prediction.isEarlyEstimate
        ? 'Early estimate: next period ${_dateRangeLabel(prediction.predictedMensesStart, prediction.predictedMensesEnd)} · based on 1 recorded cycle'
        : 'Estimated next period ${_dateRangeLabel(prediction.predictedMensesStart, prediction.predictedMensesEnd)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        RichText(
          text: TextSpan(
            children: <TextSpan>[
              TextSpan(
                text: lead,
                style: _serif(22, color: Colors.white),
              ),
              TextSpan(
                text: rest,
                style: _sans(
                  14.5,
                  color: Colors.white.withValues(alpha: 0.88),
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (progress != null) ...<Widget>[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: Colors.white.withValues(alpha: 0.28),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
        const SizedBox(height: 6),
        Text(
          caption,
          style: _sans(11.5, color: Colors.white.withValues(alpha: 0.72)),
        ),
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

String _dateRangeLabel(LocalDate start, LocalDate end) => start == end
    ? _shortDateLabel(start)
    : '${_shortDateLabel(start)}–${_shortDateLabel(end)}';

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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            const Color(0xFFE0703F).withValues(alpha: 0.85),
            const Color(0xFFC3432C).withValues(alpha: 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.3, end: 0.75).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
        ),
        child: Column(
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
        ),
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
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? _terra : _paper,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? _terra : _hairline,
              width: selected ? 1.4 : 1,
            ),
            boxShadow: selected
                ? <BoxShadow>[
                    BoxShadow(
                      color: _terra.withValues(alpha: 0.28),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (selected) ...<Widget>[
                const Icon(Icons.check_rounded, size: 15, color: Colors.white),
                const SizedBox(width: 6),
              ] else if (icon != null) ...<Widget>[
                Icon(icon, size: 15, color: _inkSoft),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: _sans(
                  15,
                  weight: FontWeight.w600,
                  color: selected ? Colors.white : _ink,
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
                height: 40,
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
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Text(
                  '${group.name} — ${group.hint}',
                  key: ValueKey<int>(_group),
                  style: _serif(
                    13,
                    color: _inkSoft,
                    weight: FontWeight.w500,
                    italic: true,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (Widget child, Animation<double> anim) {
                    return FadeTransition(opacity: anim, child: child);
                  },
                  child: ListView.separated(
                    key: ValueKey<int>(_group),
                    itemCount: group.symptoms.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: _hairline),
                    itemBuilder: (BuildContext context, int i) {
                      return InkWell(
                        onTap: () =>
                            Navigator.of(context).pop(group.symptoms[i]),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 13,
                            horizontal: 4,
                          ),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  group.symptoms[i].label,
                                  style: _sans(15.5),
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                                color: _inkSoft,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
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
// Severity legend — five rising steps that name the scale at a glance
// ---------------------------------------------------------------------------

class _SeverityLegend extends StatelessWidget {
  const _SeverityLegend();

  static const List<double> _barHeights = <double>[5, 9, 13, 17, 21];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _bg,
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
                            color: i == 4 ? _terraDeep : _inkSoft,
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
    return Semantics(
      button: true,
      selected: selected,
      label: '$name — $desc',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? _terraTint : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? _terra : _hairline,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
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
                            color: p <= index ? color : _hairline,
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
                        color: selected ? _terraDeep : _ink,
                      ),
                    ),
                    Text(desc, style: _sans(12.5, color: _inkSoft)),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_rounded, size: 18, color: _terra),
            ],
          ),
        ),
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
                      color: _terraDeep,
                      weight: FontWeight.w600,
                      italic: true,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.edit_outlined, size: 16, color: _inkSoft),
            const SizedBox(width: 4),
            IconButton(
              onPressed: onRemove,
              tooltip: 'Remove ${entry.definition.label}',
              icon: const Icon(Icons.close_rounded, size: 18),
              color: _inkSoft,
              visualDensity: VisualDensity.compact,
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
          color: _ink.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
