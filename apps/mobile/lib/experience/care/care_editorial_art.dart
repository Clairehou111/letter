import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/experience_foundation.dart';
import 'care_animation_port.dart';

abstract final class CareEditorialPalette {
  static const Color paper = Color(0xFFFBF6EC);
  static const Color paperDim = Color(0xFFE2D9DD);
  static const Color paperDeep = Color(0xFFF1E7D7);
  static const Color ink = Color(0xFF2B1028);
  static const Color inkSoft = Color(0xFF6F6070);
  static const Color inkFaint = Color(0xFF998B96);
  static const Color coral = Color(0xFFC94B3E);
  static const Color coralText = Color(0xFF9A302A);
  static const Color saffron = Color(0xFFE9B33E);
  static const Color cyan = Color(0xFF9CC9D0);
  static const Color rule = Color(0xFFCDBDB2);
}

abstract final class CareEditorialAssets {
  static const String bodySideRest =
      'assets/images/care/editorial/body-side-rest-with-cat.png';
  static const String bodyWarmShowerWide =
      'assets/images/care/editorial/body-warm-shower-with-cat-v2.png';
  static const String acupressureSp6 =
      'assets/images/care/editorial/acupressure-sp6-v2.png';
  static const String acupressureLv3 =
      'assets/images/care/editorial/acupressure-lv3-v2.png';
  static const String warmDrinkStillLife =
      'assets/images/care/editorial/warm-drink-with-cat.png';

  static const String guideWarmth =
      'assets/images/care/editorial/guide-warmth-v3.png';
  static const String guideLowerBackRelease =
      'assets/images/care/editorial/guide-lower-back-release-v5.png';
  static const String guideKneesToChest =
      'assets/images/care/editorial/guide-knees-to-chest-v2.png';
  static const String guideSlowHips =
      'assets/images/care/editorial/guide-slow-hips-v6.png';
  static const String guideMassage =
      'assets/images/care/editorial/guide-massage-v4.png';
  static const String guideRest =
      'assets/images/care/editorial/guide-rest-v4.png';

  static const List<String> catPoses = <String>[
    'assets/images/care/editorial/cat-walk.png',
    'assets/images/care/editorial/cat-sit.png',
    'assets/images/care/editorial/cat-stretch.png',
    'assets/images/care/editorial/cat-sleep.png',
  ];
}

class CareEditorialPaper extends StatelessWidget {
  const CareEditorialPaper({
    super.key,
    required this.child,
    this.backgroundColor = CareEditorialPalette.paper,
  });

  final Widget child;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: backgroundColor),
      child: CustomPaint(painter: const _PaperGrainPainter(), child: child),
    );
  }
}

class CareIllustration extends StatelessWidget {
  const CareIllustration({
    super.key,
    required this.asset,
    required this.semanticsLabel,
    this.height = 220,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
  });

  final String asset;
  final String semanticsLabel;
  final double height;
  final BoxFit fit;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Image.asset(
            asset,
            fit: fit,
            alignment: alignment,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
          ),
        ),
      ),
    );
  }
}

class CareAtlasPanel extends StatelessWidget {
  const CareAtlasPanel(
    this.asset,
    this.semanticsLabel,
    this.columns,
    this.rows,
    this.index,
    this.panelAspectRatio, {
    super.key,
  }) : assert(columns > 0),
       assert(rows > 0),
       assert(index >= 0 && index < columns * rows),
       assert(panelAspectRatio > 0);

  final String asset;
  final String semanticsLabel;
  final int columns;
  final int rows;
  final int index;
  final double panelAspectRatio;

  @override
  Widget build(BuildContext context) {
    final column = index % columns;
    final row = index ~/ columns;
    return Semantics(
      image: true,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: AspectRatio(
          aspectRatio: panelAspectRatio,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final panelWidth = constraints.maxWidth;
              final panelHeight = constraints.maxHeight;
              return ClipRect(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    Positioned(
                      left: -column * panelWidth,
                      top: -row * panelHeight,
                      width: panelWidth * columns,
                      height: panelHeight * rows,
                      child: Image.asset(
                        asset,
                        fit: BoxFit.fill,
                        filterQuality: FilterQuality.high,
                        gaplessPlayback: true,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class CareCompanionClock extends StatefulWidget {
  const CareCompanionClock({
    super.key,
    required this.startedAt,
    required this.companionName,
    this.now,
  });

  final DateTime startedAt;
  final String? companionName;
  final DateTime Function()? now;

  @override
  State<CareCompanionClock> createState() => _CareCompanionClockState();
}

class _CareCompanionClockState extends State<CareCompanionClock> {
  Timer? _timer;
  late Duration _elapsed;

  @override
  void initState() {
    super.initState();
    _elapsed = _readElapsed();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      setState(() => _elapsed = _readElapsed());
    });
  }

  @override
  void didUpdateWidget(covariant CareCompanionClock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startedAt != widget.startedAt ||
        oldWidget.now != widget.now) {
      _elapsed = _readElapsed();
    }
  }

  Duration _readElapsed() {
    final elapsed = (widget.now?.call() ?? DateTime.now()).difference(
      widget.startedAt,
    );
    return elapsed.isNegative ? Duration.zero : elapsed;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.companionName?.trim();
    final companion = name == null || name.isEmpty ? 'Your cat' : name;
    final minutes = _elapsed.inMinutes;
    final presence = minutes < 1
        ? '$companion is here with you.'
        : '$companion has been here with you for $minutes '
              '${minutes == 1 ? 'minute' : 'minutes'}.';
    return Semantics(
      container: true,
      liveRegion: false,
      label: presence,
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            const Icon(
              Icons.pets_outlined,
              color: CareEditorialPalette.inkSoft,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                presence,
                style: ExperienceType.bodyStrong(CareEditorialPalette.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A scene-grounded companion that can sit in the page flow or an illustration
/// corner. Pose changes never control page progress.
enum CareCompanionSetting {
  room,
  matEdge,
  footSide,
  tableSide,
  quietCorner,
  bathMat,
}

class CareInlineCat extends StatefulWidget {
  const CareInlineCat({
    super.key,
    required this.motion,
    this.setting = CareCompanionSetting.room,
    this.compact = false,
  });

  final CareSceneMotionPreference motion;
  final CareCompanionSetting setting;
  final bool compact;

  @override
  State<CareInlineCat> createState() => _CareInlineCatState();
}

class _CareInlineCatState extends State<CareInlineCat>
    with WidgetsBindingObserver {
  final math.Random _random = math.Random();
  Timer? _timer;
  Timer? _settleTimer;
  int _pose = 1;
  late double _right;
  bool _tickerEnabled = false;
  bool _appResumed = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _right = _fixedRight();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final enabled = TickerMode.valuesOf(context).enabled;
    if (enabled == _tickerEnabled) return;
    _tickerEnabled = enabled;
    if (enabled) {
      _schedule();
    } else {
      _timer?.cancel();
      _settleTimer?.cancel();
    }
  }

  @override
  void didUpdateWidget(CareInlineCat oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.motion != widget.motion ||
        oldWidget.setting != widget.setting ||
        oldWidget.compact != widget.compact) {
      _right = _fixedRight();
      _schedule();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _settleTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _appResumed = true;
      _schedule();
    } else {
      _appResumed = false;
      _timer?.cancel();
      _settleTimer?.cancel();
    }
  }

  void _schedule() {
    _timer?.cancel();
    _settleTimer?.cancel();
    if (!_tickerEnabled ||
        !_appResumed ||
        widget.motion != CareSceneMotionPreference.full) {
      _pose = 1;
      _right = _fixedRight();
      return;
    }
    _timer = Timer(Duration(seconds: 16 + _random.nextInt(16)), () {
      if (!mounted || !_tickerEnabled || !_appResumed) return;
      final relocate = _random.nextInt(3) == 0;
      if (relocate) {
        setState(() {
          _pose = 0;
          _right = _right == _fixedRight() ? _alternateRight() : _fixedRight();
        });
        _settleTimer = Timer(const Duration(milliseconds: 1300), () {
          if (!mounted || !_tickerEnabled || !_appResumed) return;
          setState(() => _pose = 1 + _random.nextInt(3));
          _schedule();
        });
        return;
      }
      var next = 1 + _random.nextInt(3);
      if (next == _pose) next = next == 3 ? 1 : next + 1;
      setState(() => _pose = next);
      _schedule();
    });
  }

  double _fixedRight() => switch (widget.setting) {
    CareCompanionSetting.room => 28.0,
    CareCompanionSetting.matEdge => 20.0,
    CareCompanionSetting.footSide => 16.0,
    CareCompanionSetting.tableSide => 24.0,
    CareCompanionSetting.quietCorner => 42.0,
    CareCompanionSetting.bathMat => 24.0,
  };

  double _alternateRight() => switch (widget.setting) {
    CareCompanionSetting.room => 74.0,
    CareCompanionSetting.matEdge => 86.0,
    CareCompanionSetting.footSide => 62.0,
    CareCompanionSetting.tableSide => 68.0,
    CareCompanionSetting.quietCorner => 82.0,
    CareCompanionSetting.bathMat => 70.0,
  };

  @override
  Widget build(BuildContext context) {
    final reduced = widget.motion != CareSceneMotionPreference.full;
    final groundBottom = widget.compact ? 12.0 : 20.0;
    final catHeight = widget.compact ? 78.0 : 104.0;
    final catWidth = widget.compact ? 92.0 : 122.0;
    return ExcludeSemantics(
      child: SizedBox(
        height: widget.compact ? 92 : 132,
        width: double.infinity,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: CustomPaint(
                painter: _CareCompanionSettingPainter(
                  setting: widget.setting,
                  groundBottom: groundBottom,
                ),
              ),
            ),
            AnimatedPositioned(
              duration: reduced
                  ? Duration.zero
                  : const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              right: reduced ? _fixedRight() : _right,
              // Every source pose meets the bottom edge of its canvas. Keep
              // that edge on the same illustrated floor line so a pose never
              // appears to hover when it changes.
              bottom: groundBottom,
              width: catWidth,
              height: catHeight,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: <Widget>[
                  Positioned(
                    left: 18,
                    right: 18,
                    bottom: -3,
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: CareEditorialPalette.ink.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: CareEditorialPalette.ink.withValues(
                              alpha: 0.07,
                            ),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: reduced
                        ? Duration.zero
                        : const Duration(milliseconds: 420),
                    layoutBuilder: (currentChild, previousChildren) => Stack(
                      alignment: Alignment.bottomCenter,
                      children: <Widget>[...previousChildren, ?currentChild],
                    ),
                    child: Image.asset(
                      CareEditorialAssets.catPoses[_pose],
                      key: ValueKey<int>(_pose),
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
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
}

class _CareCompanionSettingPainter extends CustomPainter {
  const _CareCompanionSettingPainter({
    required this.setting,
    required this.groundBottom,
  });

  final CareCompanionSetting setting;
  final double groundBottom;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height - groundBottom;
    final rule = Paint()
      ..color = CareEditorialPalette.rule
      ..strokeWidth = 1;
    canvas.drawLine(Offset.zero.translate(0, y), Offset(size.width, y), rule);

    switch (setting) {
      case CareCompanionSetting.room:
        break;
      case CareCompanionSetting.matEdge:
        final mat = Paint()
          ..color = CareEditorialPalette.cyan.withValues(alpha: 0.22);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(8, y - 13, size.width * 0.62, 14),
            const Radius.circular(7),
          ),
          mat,
        );
        break;
      case CareCompanionSetting.footSide:
        final blanket = Paint()
          ..color = CareEditorialPalette.saffron.withValues(alpha: 0.18);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(10, y - 20, size.width * 0.34, 21),
            const Radius.circular(10),
          ),
          blanket,
        );
        break;
      case CareCompanionSetting.tableSide:
        final wood = Paint()
          ..color = const Color(0xFF9A6C43).withValues(alpha: 0.38)
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke;
        canvas.drawLine(Offset(24, y - 38), Offset(20, y), wood);
        canvas.drawLine(Offset(74, y - 38), Offset(79, y), wood);
        canvas.drawLine(Offset(14, y - 39), Offset(86, y - 39), wood);
        break;
      case CareCompanionSetting.quietCorner:
        final cushion = Paint()
          ..color = CareEditorialPalette.cyan.withValues(alpha: 0.16);
        canvas.drawOval(
          Rect.fromLTWH(14, y - 15, size.width * 0.28, 16),
          cushion,
        );
        break;
      case CareCompanionSetting.bathMat:
        final tile = Paint()
          ..color = CareEditorialPalette.ink.withValues(alpha: 0.08)
          ..strokeWidth = 1;
        for (var x = 0.0; x < size.width; x += 44) {
          canvas.drawLine(Offset(x, y - 26), Offset(x, y), tile);
        }
        final mat = Paint()
          ..color = CareEditorialPalette.cyan.withValues(alpha: 0.22);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(12, y - 9, size.width * 0.56, 10),
            const Radius.circular(5),
          ),
          mat,
        );
        break;
    }
  }

  @override
  bool shouldRepaint(_CareCompanionSettingPainter oldDelegate) =>
      oldDelegate.setting != setting ||
      oldDelegate.groundBottom != groundBottom;
}

class CareEditorialBackButton extends StatelessWidget {
  const CareEditorialBackButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: IconButton(
        tooltip: 'Back',
        onPressed: onPressed,
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
        color: CareEditorialPalette.ink,
      ),
    );
  }
}

class CareCoralButton extends StatelessWidget {
  const CareCoralButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: CareEditorialPalette.coral,
          foregroundColor: Colors.white,
          disabledBackgroundColor: CareEditorialPalette.coral.withValues(
            alpha: 0.45,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: ExperienceType.bodyStrong(Colors.white),
        ),
        child: loading
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(label),
      ),
    );
  }
}

class CareQuietRule extends StatelessWidget {
  const CareQuietRule({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 64,
      child: Divider(height: 1, thickness: 1, color: CareEditorialPalette.ink),
    );
  }
}

class _PaperGrainPainter extends CustomPainter {
  const _PaperGrainPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final fleck = Paint()..color = const Color(0x0D7F654F);
    for (var y = 17.0; y < size.height; y += 31) {
      final shift = (y ~/ 31).isEven ? 9.0 : 23.0;
      for (var x = shift; x < size.width; x += 47) {
        canvas.drawCircle(Offset(x, y), 0.55, fleck);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
