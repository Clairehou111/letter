import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../features/patterns/domain/personal_pattern.dart';
import '../../features/preparation/domain/preparation_loop_state.dart';
import '../care/care_animation_port.dart';

// ---------------------------------------------------------------------------
// Color tokens
// ---------------------------------------------------------------------------

/// One warm paper world and one plum-dusk world, sharing a single ember.
///
/// Ember coral is reserved for the ember itself, primary actions, and
/// memory/remembered-help — never a chart accent.
abstract final class ExperienceColors {
  // Light world — warm paper-white, genuine contrast, no beige wash.
  static const Color canvas = Color(0xFFFBF7F3);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceWarm = Color(0xFFF5EDE7);
  static const Color ink = Color(0xFF2A1626);
  static const Color inkSoft = Color(0xFF6E5A68);
  static const Color inkFaint = Color(0xFF9A8A94);
  static const Color hairline = Color(0xFFE9DED7);
  static const Color shadowWarm = Color(0x1F5C3A2E);
  static const Color error = Color(0xFFA43E36);

  // Ember family — coral-red gradient, confident and warm.
  static const Color ember = Color(0xFFE4573D);
  static const Color emberBright = Color(0xFFF2734F);
  static const Color emberDeep = Color(0xFFC23A28);
  static const Color emberSoft = Color(0xFFF7A48C);
  static const Color emberGlow = Color(0x40F2734F);

  // Phase accents — saturated enough to read at ring width; the dashed
  // estimated treatment compensates with stroke weight, never saturation.
  static const Color phasePeriod = Color(0xFFB23A6B); // raspberry-magenta
  static const Color phaseFollicular = Color(0xFF4A7FC9); // clear blue
  static const Color phaseOvulation = Color(0xFF4C9E70); // leaf green
  static const Color phaseLuteal = Color(0xFF7A5AB0); // deep violet

  // Semantic accents — exactly one per chart family. Within any viewport
  // only the expanded family renders at full saturation; others step down.
  static const Color accentGravity = Color(0xFFA85B32); // amber-plum
  static const Color accentSpectrum = Color(0xFF2E8C82); // teal
  static const Color accentTwin = Color(0xFF4B5AA8); // indigo
  static const Color accentMemory = ember; // ember-coral
  static const Color accentSafety = Color(0xFF4A2C4A); // deep plum, no red

  // Dark Care world — plum dusk, one warm light source, red never dominates.
  static const Color careSkyTop = Color(0xFF2E1A33);
  static const Color careSkyBottom = Color(0xFF170D1C);
  static const Color careInk = Color(0xFFF7EEE6);
  static const Color careInkSoft = Color(0xFFCDB6C6);
  static const Color careInkFaint = Color(0xFF9C8496);
  static const Color careGlass = Color(0x14FFFFFF);
  static const Color careGlassBorder = Color(0x33FFFFFF);

  /// The ember gradient used for hero fills, primary actions, and the ember.
  static const LinearGradient emberGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [emberBright, ember, emberDeep],
  );

  /// Coral-red phase hero (Today's phase headline card).
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [emberBright, emberDeep],
  );

  /// Plum-dusk backfield for the Care world.
  static const LinearGradient careBackdrop = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [careSkyTop, careSkyBottom],
  );
}

// ---------------------------------------------------------------------------
// Severity ramp — five restrained, countable steps within the phase/accent
// family. NEVER error red, NEVER ember (both are reserved: error for errors,
// ember for action). Color is reinforcement only — the word and the
// score/glyph remain the primary encoding everywhere this ramp renders.
//
//   1 inkFaint         — barely present
//   2 phaseFollicular  — clear blue
//   3 phaseLuteal      — deep violet
//   4 phasePeriod      — raspberry-magenta
//   5 accentGravity    — amber-plum
//
// This ramp lives here exactly once; the health-record editor (choice cards,
// severity chip, and the bespoke cramp glyph) resolves every severity color
// through [forScore] so no call site can drift into red or ember.
// ---------------------------------------------------------------------------

abstract final class ExperienceSeverityRamp {
  /// Lowest representable severity score.
  static const int minScore = 1;

  /// Highest representable severity score.
  static const int maxScore = 5;

  /// The five steps in ascending severity order, indexed by `score - 1`.
  static const List<Color> steps = <Color>[
    ExperienceColors.inkFaint, // 1
    ExperienceColors.phaseFollicular, // 2
    ExperienceColors.phaseLuteal, // 3
    ExperienceColors.phasePeriod, // 4
    ExperienceColors.accentGravity, // 5
  ];

  /// Resolves the ramp color for a 1–5 severity [score]. Out-of-range values
  /// clamp to the nearest step so callers never render an unintended hue.
  static Color forScore(int score) {
    final clamped = score.clamp(minScore, maxScore);
    return steps[clamped - 1];
  }

  /// Resolves the ramp color for an optional severity score, or `null` when
  /// no rating exists — blanks stay blank, never a fabricated step.
  static Color? forScoreOrNull(int? score) {
    if (score == null) return null;
    return forScore(score);
  }

  /// A muted wash of the step color for selected fills and glyph backdrops,
  /// keeping the warm daylight material instead of a flat saturated block.
  static Color softFill(int score, {double alpha = 0.14}) {
    return forScore(score).withValues(alpha: alpha);
  }
}

// ---------------------------------------------------------------------------
// Typography
// ---------------------------------------------------------------------------

/// Editorial serif for display; clean humanist sans for body, labels, chips,
/// and data. Pairing rule: serif takeaways never contain numerals adjacent to
/// data — numerals in data contexts always use [ExperienceType.data] (sans,
/// tabular figures) so the two type systems never fight inside a chart.
abstract final class ExperienceType {
  static const List<String> _serifFallback = <String>[
    'Times New Roman',
    'serif',
  ];
  static const List<String> _sansFallback = <String>[
    'SF Pro Text',
    'Roboto',
    'Helvetica Neue',
    'sans-serif',
  ];

  static TextStyle _serif(
    double size,
    double line,
    Color color,
    FontWeight weight,
  ) {
    return TextStyle(
      fontFamily: 'Georgia',
      fontFamilyFallback: _serifFallback,
      fontSize: size,
      height: line / size,
      fontWeight: weight,
      color: color,
      letterSpacing: -0.2,
    );
  }

  static TextStyle _sans(
    double size,
    double line,
    Color color,
    FontWeight weight, {
    double letterSpacing = 0,
    List<FontFeature>? features,
  }) {
    return TextStyle(
      fontFamilyFallback: _sansFallback,
      fontSize: size,
      height: line / size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      fontFeatures: features,
    );
  }

  /// Display 34/40 serif — screen titles, phase headline.
  static TextStyle display(Color color) =>
      _serif(34, 40, color, FontWeight.w600);

  /// Title 24/32 serif — section titles, chart takeaways.
  static TextStyle title(Color color) => _serif(24, 32, color, FontWeight.w600);

  /// Headline 19/28 serif.
  static TextStyle headline(Color color) =>
      _serif(19, 28, color, FontWeight.w600);

  /// Body 16/24 sans.
  static TextStyle body(Color color) => _sans(16, 24, color, FontWeight.w400);

  static TextStyle bodyStrong(Color color) =>
      _sans(16, 24, color, FontWeight.w600);

  /// Body small 14/20 sans.
  static TextStyle bodySmall(Color color) =>
      _sans(14, 20, color, FontWeight.w400);

  /// Caption 13/18 sans.
  static TextStyle caption(Color color) =>
      _sans(13, 18, color, FontWeight.w400);

  /// Label 15/20 sans semibold — chips, buttons.
  static TextStyle label(Color color) => _sans(15, 20, color, FontWeight.w600);

  /// Eyebrow label (e.g. the Care scene eyebrow) — quiet, tracked, uppercase
  /// applied at the call site.
  static TextStyle eyebrow(Color color) =>
      _sans(12, 16, color, FontWeight.w600, letterSpacing: 2.4);

  /// Data numerals — sans tabular figures, always.
  static TextStyle data(
    Color color, {
    double size = 16,
    FontWeight weight = FontWeight.w600,
  }) {
    return _sans(
      size,
      size * 1.3,
      color,
      weight,
      features: const <FontFeature>[FontFeature.tabularFigures()],
    );
  }

  static TextTheme lightTextTheme() {
    return TextTheme(
      displayLarge: display(ExperienceColors.ink),
      headlineMedium: title(ExperienceColors.ink),
      titleLarge: headline(ExperienceColors.ink),
      titleMedium: label(ExperienceColors.ink),
      bodyLarge: body(ExperienceColors.ink),
      bodyMedium: bodySmall(ExperienceColors.inkSoft),
      bodySmall: caption(ExperienceColors.inkSoft),
      labelLarge: label(ExperienceColors.ink),
      labelSmall: caption(ExperienceColors.inkSoft),
    );
  }

  static TextTheme careTextTheme() {
    return TextTheme(
      displayLarge: display(ExperienceColors.careInk),
      headlineMedium: title(ExperienceColors.careInk),
      titleLarge: headline(ExperienceColors.careInk),
      titleMedium: label(ExperienceColors.careInk),
      bodyLarge: body(ExperienceColors.careInk),
      bodyMedium: bodySmall(ExperienceColors.careInkSoft),
      bodySmall: caption(ExperienceColors.careInkSoft),
      labelLarge: label(ExperienceColors.careInk),
      labelSmall: caption(ExperienceColors.careInkSoft),
    );
  }
}

// ---------------------------------------------------------------------------
// Spacing, shape, elevation
// ---------------------------------------------------------------------------

/// 8-pt base grid; 16/20/24 content rhythm; 24-pt screen margins.
abstract final class ExperienceSpacing {
  static const double unit = 8;
  static const double xs = 4;
  static const double sm = 16;
  static const double md = 20;
  static const double lg = 24;
  static const double xl = 32;
  static const double screenMargin = 24;

  /// Scroll-bottom padding so primary actions always live above the system
  /// navigation inset and tab bar — the clipped "Record today" button is the
  /// reference defect.
  static const double scrollBottomPadding = 96;

  static const double minTouchTarget = 44;
  static const double degreeTarget = 48;
}

abstract final class ExperienceRadius {
  static const double chip = 12;
  static const double card = 20;
  static const double hero = 28;
  static const double full = 999;

  static const BorderRadius chipRadius = BorderRadius.all(
    Radius.circular(chip),
  );
  static const BorderRadius cardRadius = BorderRadius.all(
    Radius.circular(card),
  );
  static const BorderRadius heroRadius = BorderRadius.all(
    Radius.circular(hero),
  );
  static const BorderRadius sheetRadius = BorderRadius.vertical(
    top: Radius.circular(hero),
  );
}

abstract final class ExperienceShadows {
  static const List<BoxShadow> card = <BoxShadow>[
    BoxShadow(
      color: ExperienceColors.shadowWarm,
      blurRadius: 18,
      offset: Offset(0, 6),
    ),
  ];
  static const List<BoxShadow> hero = <BoxShadow>[
    BoxShadow(color: Color(0x335C3A2E), blurRadius: 32, offset: Offset(0, 12)),
  ];
}

// ---------------------------------------------------------------------------
// Certainty texture system
// ---------------------------------------------------------------------------

/// Certainty is a texture system, not color alone. Identical on the ring,
/// Gravity, Spectrum, Twin, and report previews.
enum ExperienceCertainty { observed, estimated, unknown }

/// Texture recipe per certainty level:
///  * observed — solid fill + solid border.
///  * estimated — reduced opacity **plus** dashed/hatched treatment and an
///    "est." caption.
///  * unknown/missing — empty outline with a faint dot grid; blanks are
///    rendered blank, never zero.
final class CertaintyTexture {
  const CertaintyTexture({
    required this.fillOpacity,
    required this.borderOpacity,
    this.dashPattern,
    this.dotGrid = false,
    this.caption,
  });

  final double fillOpacity;
  final double borderOpacity;

  /// Null = solid stroke. Non-null = on/off dash lengths in logical pixels.
  final List<double>? dashPattern;
  final bool dotGrid;

  /// Short certainty caption ("est."), rendered near the mark.
  final String? caption;

  static const CertaintyTexture observed = CertaintyTexture(
    fillOpacity: 1,
    borderOpacity: 1,
  );

  static const CertaintyTexture estimated = CertaintyTexture(
    fillOpacity: 0.55,
    borderOpacity: 0.9,
    dashPattern: <double>[6, 4],
    caption: 'est.',
  );

  static const CertaintyTexture unknown = CertaintyTexture(
    fillOpacity: 0,
    borderOpacity: 0.35,
    dotGrid: true,
  );

  static CertaintyTexture of(ExperienceCertainty certainty) {
    return switch (certainty) {
      ExperienceCertainty.observed => observed,
      ExperienceCertainty.estimated => estimated,
      ExperienceCertainty.unknown => unknown,
    };
  }

  /// Screen-reader wording — certainty is never conveyed by color alone.
  static String semanticsLabel(ExperienceCertainty certainty) {
    return switch (certainty) {
      ExperienceCertainty.observed => 'Observed',
      ExperienceCertainty.estimated => 'Estimated',
      ExperienceCertainty.unknown => 'Missing',
    };
  }
}

/// Faint dot grid used for unknown/missing cells and chart skeletons.
final class DotGridPainter extends CustomPainter {
  const DotGridPainter({
    this.color = ExperienceColors.inkFaint,
    this.spacing = 10,
    this.dotRadius = 1,
  });

  final Color color;
  final double spacing;
  final double dotRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: 0.35);
    for (var y = spacing / 2; y < size.height; y += spacing) {
      for (var x = spacing / 2; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(DotGridPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.spacing != spacing ||
        oldDelegate.dotRadius != dotRadius;
  }
}

// ---------------------------------------------------------------------------
// Haptics — light on save, clicks on picks, double-tick on Care steps.
// Errors NEVER haptic: errors are visual + textual; vibration punishes.
// ---------------------------------------------------------------------------

abstract final class ExperienceHaptics {
  /// Step 2 of the Saved Rhythm.
  static Future<void> saved() => HapticFeedback.lightImpact();

  /// Selection clicks during picking.
  static Future<void> pick() => HapticFeedback.selectionClick();

  /// Soft double-tick on Care step completion.
  static Future<void> careStepCompleted() async {
    await HapticFeedback.lightImpact();
    await Future<void>.delayed(const Duration(milliseconds: 90));
    await HapticFeedback.selectionClick();
  }
}

// ---------------------------------------------------------------------------
// Motion — reduced motion resolves from the platform accessibility setting
// ONLY (owner decision). No in-app toggle exists in this release.
// ---------------------------------------------------------------------------

abstract final class ExperienceMotion {
  static const Duration worldCrossing = Duration(milliseconds: 450);
  static const Duration worldCrossingReduced = Duration(milliseconds: 250);
  static const Duration savedPulse = Duration(milliseconds: 300);
  static const Duration chipSelect = Duration(milliseconds: 150);
  static const Duration sheetUp = Duration(milliseconds: 300);
  static const Duration chartDrawOn = Duration(milliseconds: 600);
  static const Duration emberBreath = Duration(seconds: 4);

  static const Curve crossingCurve = Curves.easeInOut;
  static const Curve sheetCurve = Curves.easeOut;

  /// Platform accessibility setting only.
  static bool reducedMotion(BuildContext context) {
    return MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }

  /// Maps the platform setting onto the animation port seam:
  /// platform reduced → [CareSceneMotionPreference.reduced] (crossfades
  /// replace travel/breathing; world crossing becomes a simple fade).
  /// [performanceConstrained] is the sanctioned jank escape hatch: when the
  /// world-crossing frame budget cannot hold, scenes degrade to
  /// [CareSceneMotionPreference.staticFallback] — composed statics with
  /// identical copy, steps, and controls, never a degraded afterthought.
  static CareSceneMotionPreference scenePreference(
    BuildContext context, {
    bool performanceConstrained = false,
  }) {
    if (performanceConstrained) {
      return CareSceneMotionPreference.staticFallback;
    }
    return reducedMotion(context)
        ? CareSceneMotionPreference.reduced
        : CareSceneMotionPreference.full;
  }

  static Duration crossingDuration(BuildContext context) {
    return reducedMotion(context) ? worldCrossingReduced : worldCrossing;
  }
}

// ---------------------------------------------------------------------------
// Saved Rhythm — one primitive for every successful save.
// (1) immediate visual change + ember pulse, (2) one light haptic,
// (3) one concise acknowledgment line, (4) at most one optional next action.
// Silence rule: rapid repeat saves within a session degrade to visual+haptic
// only, so the rhythm never becomes greeting-card noise.
// ---------------------------------------------------------------------------

enum SavedRhythmKind { checkIn, record, reflection, outcome, backup, report }

abstract final class SavedRhythm {
  /// Window during which repeat saves of the same kind stay silent.
  static const Duration silenceWindow = Duration(seconds: 45);

  /// The constrained, tone-controlled copy set. Adult, warm, exact. No
  /// streaks, points, guilt, or productivity language.
  static const Map<SavedRhythmKind, List<String>> _lines =
      <SavedRhythmKind, List<String>>{
        SavedRhythmKind.checkIn: <String>[
          'Noted, just as it is.',
          'That moment is held.',
          'Checked in — thank you.',
        ],
        SavedRhythmKind.record: <String>[
          'Saved to your record.',
          "That's on today's record.",
          'Recorded.',
        ],
        SavedRhythmKind.reflection: <String>[
          'Kept for future you.',
          'Your words are saved.',
        ],
        SavedRhythmKind.outcome: <String>[
          'Thank you for checking back.',
          'That check-back builds your memory.',
        ],
        SavedRhythmKind.backup: <String>[
          'Your records are safe.',
          'Backup saved to your Letter folder.',
        ],
        SavedRhythmKind.report: <String>[
          'Your report is ready.',
          'Shared on your terms.',
        ],
      };

  static final Map<SavedRhythmKind, DateTime> _lastShownAt =
      <SavedRhythmKind, DateTime>{};
  static final Map<SavedRhythmKind, int> _cursor = <SavedRhythmKind, int>{};

  /// Performs the haptic and returns the acknowledgment line, or `null` when
  /// the silence rule suppresses it (visual + haptic only).
  static Future<String?> acknowledge(
    SavedRhythmKind kind, {
    DateTime? now,
  }) async {
    await ExperienceHaptics.saved();
    return lineFor(kind, now: now);
  }

  /// Pure acknowledgment resolution — haptic-free, for tests and previews.
  static String? lineFor(SavedRhythmKind kind, {DateTime? now}) {
    final at = now ?? DateTime.now();
    final last = _lastShownAt[kind];
    if (last != null && at.difference(last) < silenceWindow) {
      return null;
    }
    final options = _lines[kind]!;
    final index = (_cursor[kind] ?? 0) % options.length;
    _cursor[kind] = index + 1;
    _lastShownAt[kind] = at;
    return options[index];
  }

  /// Clears session silence state (app restart, tests).
  static void resetSession() {
    _lastShownAt.clear();
    _cursor.clear();
  }
}

// ---------------------------------------------------------------------------
// Memory-evidence gating — THE single render gate for all remembered-help and
// preparation copy. The prototype's broken "Last cycle, ____ helped you
// most." line is the canonical anti-pattern: memory copy renders only when
// real outcome evidence exists; otherwise the surface stays silent — and
// accumulating evidence gets its own honest intermediate line.
// ---------------------------------------------------------------------------

enum MemoryEvidenceVerdict {
  /// Passive remembered-help line is permitted (saved/privateReference loops
  /// or real SupportActionPattern evidence).
  remembered,

  /// A dismissible proposal may be offered (proposed loop with evidence).
  proposal,

  /// Evidence exists but the loop has not closed — render the honest
  /// intermediate line ("recorded once — each check-back builds your memory").
  accumulating,

  /// Render nothing. Withdrawn, dismissed, unavailable, or zero evidence.
  silent,
}

abstract final class ExperienceMemoryGate {
  /// The one gate every memory surface calls before rendering copy.
  ///
  /// Rules (owner-settled):
  ///  * `saved` / `privateReference` loops justify passive remembered-help.
  ///  * `proposed` justifies an optional, dismissible proposal.
  ///  * `withdrawn` / `dismissed` render silence, always.
  ///  * `stale` or unavailable (null loop) fall back to raw evidence:
  ///    ≥2 deliberate records → remembered; exactly 1 → accumulating;
  ///    0 → silence.
  /// Premium depth gates the durable layer without ever fabricating the
  /// free line — this helper knows nothing about entitlement.
  static MemoryEvidenceVerdict gate({
    required PreparationLoopKind? loopKind,
    List<SupportActionPattern> evidence = const <SupportActionPattern>[],
  }) {
    final recorded = evidence.fold<int>(0, (sum, item) => sum + item.count);
    switch (loopKind) {
      case PreparationLoopKind.saved:
      case PreparationLoopKind.privateReference:
        return MemoryEvidenceVerdict.remembered;
      case PreparationLoopKind.proposed:
        return recorded > 0
            ? MemoryEvidenceVerdict.proposal
            : MemoryEvidenceVerdict.silent;
      case PreparationLoopKind.withdrawn:
      case PreparationLoopKind.dismissed:
        return MemoryEvidenceVerdict.silent;
      case PreparationLoopKind.stale:
      case null:
        if (recorded >= 2) return MemoryEvidenceVerdict.remembered;
        if (recorded == 1) return MemoryEvidenceVerdict.accumulating;
        return MemoryEvidenceVerdict.silent;
    }
  }

  /// The honest intermediate line for early evidence — early silence never
  /// reads as brokenness.
  static String accumulatingLine(List<SupportActionPattern> evidence) {
    final strongest = _strongest(evidence);
    final label = strongest?.actionLabel ?? 'That';
    return '$label recorded once — each check-back builds your memory.';
  }

  /// Factual remembered-help copy, composed only from real outcome counts.
  /// Returns null under zero evidence.
  static String? rememberedLine(List<SupportActionPattern> evidence) {
    final action = _strongest(evidence);
    if (action == null) return null;
    if (action.betterCount >= 2) {
      return '${action.actionLabel} helped ${action.betterCount} times '
          'before — your check-backs say so.';
    }
    if (action.betterCount == 1) {
      return '${action.actionLabel} helped once before — '
          'one recorded check-back.';
    }
    return '${action.actionLabel}: ${action.factualOutcomeSummary}.';
  }

  static SupportActionPattern? _strongest(List<SupportActionPattern> evidence) {
    if (evidence.isEmpty) return null;
    final ranked = List<SupportActionPattern>.of(evidence)
      ..sort((a, b) {
        final byBetter = b.betterCount.compareTo(a.betterCount);
        return byBetter != 0 ? byBetter : b.count.compareTo(a.count);
      });
    return ranked.first;
  }
}

// ---------------------------------------------------------------------------
// Motif widgets — the Ember in Orbit.
// ---------------------------------------------------------------------------

/// The ember: one warm coral gradient circle with a soft inner glow. The
/// "you are here" marker, the held orb in Care, the saved-pulse origin.
/// Decorative by default — callers place semantics on meaningful ancestors.
class EmberOrb extends StatelessWidget {
  const EmberOrb({
    super.key,
    this.size = 120,
    this.breathing = false,
    this.motion = CareSceneMotionPreference.full,
  });

  final double size;

  /// Care ambient breathing: 4 s cycle, ±3% scale, ±8% glow. Honored only
  /// under [CareSceneMotionPreference.full]; reduced and static render the
  /// same composed orb at rest.
  final bool breathing;
  final CareSceneMotionPreference motion;

  @override
  Widget build(BuildContext context) {
    final Widget core = ExcludeSemantics(
      child: breathing && motion == CareSceneMotionPreference.full
          ? _BreathingEmber(size: size)
          : _EmberCore(size: size, glow: 1),
    );
    return SizedBox(
      width: size,
      height: size,
      child: Center(child: core),
    );
  }
}

class _BreathingEmber extends StatefulWidget {
  const _BreathingEmber({required this.size});

  final double size;

  @override
  State<_BreathingEmber> createState() => _BreathingEmberState();
}

class _BreathingEmberState extends State<_BreathingEmber>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: ExperienceMotion.emberBreath,
  );
  late final Animation<double> _breath = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );

  @override
  void initState() {
    super.initState();
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _breath,
      builder: (context, _) {
        final t = _breath.value;
        return Transform.scale(
          scale: 0.97 + 0.06 * t, // ±3%
          child: _EmberCore(size: widget.size, glow: 0.92 + 0.16 * t), // ±8%
        );
      },
    );
  }
}

class _EmberCore extends StatelessWidget {
  const _EmberCore({required this.size, required this.glow});

  final double size;
  final double glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: ExperienceColors.emberGradient,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: ExperienceColors.emberGlow.withValues(alpha: 0.9 * glow),
            blurRadius: size * 0.45 * glow,
            spreadRadius: size * 0.05 * glow,
          ),
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.4, -0.45),
            radius: 1,
            colors: <Color>[
              Colors.white.withValues(alpha: 0.35),
              Colors.white.withValues(alpha: 0),
            ],
            stops: const <double>[0, 0.65],
          ),
        ),
      ),
    );
  }
}

/// Step 1 of the Saved Rhythm: an ember pulse emanates once (300 ms).
class EmberPulse extends StatefulWidget {
  const EmberPulse({super.key, this.diameter = 96, this.onComplete});

  final double diameter;
  final VoidCallback? onComplete;

  @override
  State<EmberPulse> createState() => _EmberPulseState();
}

class _EmberPulseState extends State<EmberPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: ExperienceMotion.savedPulse,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ExperienceMotion.reducedMotion(context)) {
        // Reduced motion: a brief settled glow, no travel.
        _controller.duration = const Duration(milliseconds: 120);
      }
      _controller.forward().whenComplete(() => widget.onComplete?.call());
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _curve,
        builder: (context, _) {
          final t = _curve.value;
          final d = widget.diameter * (0.25 + 0.75 * t);
          return SizedBox(
            width: widget.diameter,
            height: widget.diameter,
            child: Center(
              child: Container(
                width: d,
                height: d,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: ExperienceColors.ember.withValues(
                      alpha: 0.85 * (1 - t),
                    ),
                    width: 2 + 2 * (1 - t),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The loading indicator: an ember traveling a small orbit. Used only for
/// short waits — repositories computing render surface skeletons instead.
/// Under reduced motion the ember rests at the top of its orbit.
class EmberLoadingIndicator extends StatefulWidget {
  const EmberLoadingIndicator({
    super.key,
    this.size = 40,
    this.semanticLabel = 'Loading',
  });

  final double size;
  final String semanticLabel;

  @override
  State<EmberLoadingIndicator> createState() => _EmberLoadingIndicatorState();
}

class _EmberLoadingIndicatorState extends State<EmberLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!ExperienceMotion.reducedMotion(context)) {
        _controller.repeat();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = widget.size * 0.22;
    final orbit = widget.size - dot;
    final radius = orbit / 2;
    return Semantics(
      label: widget.semanticLabel,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final angle = _controller.value * 2 * math.pi - math.pi / 2;
            final center = widget.size / 2;
            return Stack(
              children: <Widget>[
                Center(
                  child: Container(
                    width: orbit,
                    height: orbit,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: ExperienceColors.hairline,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: center + radius * math.cos(angle) - dot / 2,
                  top: center + radius * math.sin(angle) - dot / 2,
                  child: Container(
                    width: dot,
                    height: dot,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: ExperienceColors.emberGradient,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Step 3 of the Saved Rhythm: one concise acknowledgment line. Paired with
/// the silence rule — a null [line] renders nothing (visual + haptic only).
class SavedRhythmAckLine extends StatelessWidget {
  const SavedRhythmAckLine({
    super.key,
    required this.line,
    this.careWorld = false,
    this.textAlign = TextAlign.center,
  });

  final String? line;
  final bool careWorld;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final style = ExperienceType.caption(
      careWorld ? ExperienceColors.careInkSoft : ExperienceColors.inkSoft,
    );
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: line == null
          ? const SizedBox(key: ValueKey<String>('silent'), height: 0)
          : Semantics(
              key: ValueKey<String>(line!),
              liveRegion: true,
              child: Text(line!, style: style, textAlign: textAlign),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sheets — 28 radius, grab handle; in Care the scrim never fully hides the
// world behind (exit must remain visible).
// ---------------------------------------------------------------------------

Future<T?> showExperienceSheet<T>(
  BuildContext context, {
  required Widget child,
  bool careWorld = false,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: careWorld
        ? ExperienceColors.careSkyBottom
        : ExperienceColors.surface,
    barrierColor: careWorld ? const Color(0x59000000) : const Color(0x40000000),
    shape: const RoundedRectangleBorder(
      borderRadius: ExperienceRadius.sheetRadius,
    ),
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: careWorld
                      ? ExperienceColors.careGlassBorder
                      : ExperienceColors.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Flexible(child: child),
            ],
          ),
        ),
      );
    },
  );
}

// ---------------------------------------------------------------------------
// ExperienceFoundation — facade preserving the public API and housing the
// two world themes plus the system-level guarantees.
// ---------------------------------------------------------------------------

abstract final class ExperienceFoundation {
  /// Contrast floors (design authority): body text in both worlds.
  static const double minBodyContrastRatio = 4.5;

  /// Contrast floor for large display type and graphic boundaries.
  static const double minLargeGraphicContrastRatio = 3.0;

  /// Warm paper world: Today, Cycle, Patterns, You, Reports.
  static ThemeData lightTheme() {
    final scheme = ColorScheme(
      brightness: Brightness.light,
      primary: ExperienceColors.ember,
      onPrimary: Colors.white,
      primaryContainer: ExperienceColors.emberSoft,
      onPrimaryContainer: ExperienceColors.ink,
      secondary: ExperienceColors.phaseFollicular,
      onSecondary: Colors.white,
      tertiary: ExperienceColors.phaseLuteal,
      onTertiary: Colors.white,
      surface: ExperienceColors.surface,
      onSurface: ExperienceColors.ink,
      surfaceContainerHighest: ExperienceColors.surfaceWarm,
      onSurfaceVariant: ExperienceColors.inkSoft,
      error: ExperienceColors.error,
      onError: Colors.white,
      outline: ExperienceColors.hairline,
      outlineVariant: ExperienceColors.inkFaint,
      shadow: ExperienceColors.shadowWarm,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: ExperienceColors.canvas,
      textTheme: ExperienceType.lightTextTheme(),
      dividerColor: ExperienceColors.hairline,
      appBarTheme: AppBarTheme(
        backgroundColor: ExperienceColors.canvas,
        foregroundColor: ExperienceColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: ExperienceType.title(ExperienceColors.ink),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: ExperienceColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: ExperienceRadius.sheetRadius,
        ),
        showDragHandle: false,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: ExperienceColors.surface,
        selectedColor: ExperienceColors.surfaceWarm,
        side: const BorderSide(color: ExperienceColors.hairline),
        shape: const RoundedRectangleBorder(
          borderRadius: ExperienceRadius.chipRadius,
        ),
        labelStyle: ExperienceType.label(ExperienceColors.ink),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ExperienceColors.ink,
        contentTextStyle: ExperienceType.bodySmall(ExperienceColors.surface),
        shape: const RoundedRectangleBorder(
          borderRadius: ExperienceRadius.chipRadius,
        ),
      ),
    );
  }

  /// Plum-dusk Care world. Same behavior, different material: translucent
  /// plum glass controls with visible borders, warm off-white text.
  static ThemeData careTheme() {
    final scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: ExperienceColors.emberBright,
      onPrimary: const Color(0xFF241019),
      primaryContainer: ExperienceColors.emberDeep,
      onPrimaryContainer: ExperienceColors.careInk,
      secondary: ExperienceColors.emberSoft,
      onSecondary: const Color(0xFF241019),
      surface: ExperienceColors.careSkyBottom,
      onSurface: ExperienceColors.careInk,
      surfaceContainerHighest: ExperienceColors.careGlass,
      onSurfaceVariant: ExperienceColors.careInkSoft,
      error: ExperienceColors.emberSoft,
      onError: const Color(0xFF241019),
      outline: ExperienceColors.careGlassBorder,
      outlineVariant: ExperienceColors.careInkFaint,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: ExperienceColors.careSkyBottom,
      textTheme: ExperienceType.careTextTheme(),
      dividerColor: ExperienceColors.careGlassBorder,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: ExperienceColors.careInk,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: ExperienceType.title(ExperienceColors.careInk),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: ExperienceColors.careSkyBottom,
        shape: RoundedRectangleBorder(
          borderRadius: ExperienceRadius.sheetRadius,
        ),
        showDragHandle: false,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: ExperienceColors.careGlass,
        selectedColor: const Color(0x29FFFFFF),
        side: const BorderSide(color: ExperienceColors.careGlassBorder),
        shape: const RoundedRectangleBorder(
          borderRadius: ExperienceRadius.chipRadius,
        ),
        labelStyle: ExperienceType.label(ExperienceColors.careInk),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ExperienceColors.careGlass,
        contentTextStyle: ExperienceType.bodySmall(ExperienceColors.careInk),
        shape: const RoundedRectangleBorder(
          borderRadius: ExperienceRadius.chipRadius,
        ),
      ),
    );
  }

  /// Platform-setting-only reduced-motion resolution, mapped onto the
  /// animation port seam. See [ExperienceMotion.scenePreference].
  static CareSceneMotionPreference motionPreference(
    BuildContext context, {
    bool performanceConstrained = false,
  }) {
    return ExperienceMotion.scenePreference(
      context,
      performanceConstrained: performanceConstrained,
    );
  }

  /// The single memory-evidence gate. Every remembered-help / preparation
  /// surface renders through this — there is no ungated render path.
  static MemoryEvidenceVerdict gateMemoryEvidence({
    required PreparationLoopKind? loopKind,
    List<SupportActionPattern> evidence = const <SupportActionPattern>[],
  }) {
    return ExperienceMemoryGate.gate(loopKind: loopKind, evidence: evidence);
  }

  /// Saved Rhythm entry point: haptic + acknowledgment line under the
  /// session silence rule.
  static Future<String?> savedRhythm(SavedRhythmKind kind, {DateTime? now}) {
    return SavedRhythm.acknowledge(kind, now: now);
  }
}
