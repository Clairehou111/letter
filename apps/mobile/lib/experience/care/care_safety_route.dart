import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../features/care/domain/safety_resources.dart';
import '../theme/experience_foundation.dart';

/// The sober, deterministic safety surface.
///
/// Every word of safety content on this route comes from
/// [crisisSafetyContentForCode] and [medicalBoundaryContent] — region-mapped
/// crisis contacts (988/911 for US/CA), the honest no-invented-number
/// fallback everywhere else, and the fixed urgent/non-urgent medical-boundary
/// list. No network, no randomness, no invented numbers.
///
/// Self-harm and suicidal signals route directly here and never become
/// symptom severity data. Presentation is calm and non-alarmist: deep plum,
/// no red dominance, no timers, no guilt. Care scenes keep a quiet,
/// persistent line that opens this surface via [CareSafetyRoute.show]; the
/// surface can also be pushed as a full route.
class CareSafetyRoute extends StatelessWidget {
  const CareSafetyRoute({super.key, this.regionCode, this.careWorld = true});

  /// Optional region/locale override (e.g. `US`, `CA`). When null, the route
  /// uses the device locale's country code. Any unsupported or missing device
  /// country receives the honest fallback and never an invented number.
  final String? regionCode;

  /// True inside the plum-dusk Care world; false when surfaced from the
  /// light world (e.g. a medical-boundary entry at record time). Material
  /// differs; content and behavior are identical.
  final bool careWorld;

  /// Quiet, persistent presentation from Care scenes: a bottom sheet whose
  /// scrim never fully hides the world behind — exit always remains visible.
  static Future<void> show(
    BuildContext context, {
    String? regionCode,
    bool careWorld = true,
  }) {
    return showExperienceSheet<void>(
      context,
      careWorld: careWorld,
      child: CareSafetySheetBody(regionCode: regionCode, careWorld: careWorld),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = CareSafetySheetBody(
      regionCode: regionCode,
      careWorld: careWorld,
    );
    if (!careWorld) {
      return Scaffold(
        backgroundColor: ExperienceColors.canvas,
        appBar: AppBar(
          title: const Text('Support and safety'),
          leading: const BackButton(),
        ),
        body: SafeArea(child: content),
      );
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: ExperienceColors.careBackdrop,
        ),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(
                    right: ExperienceSpacing.sm,
                    top: ExperienceSpacing.xs,
                  ),
                  child: IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      Icons.close,
                      color: ExperienceColors.careInk,
                    ),
                  ),
                ),
              ),
              Expanded(child: content),
            ],
          ),
        ),
      ),
    );
  }
}

/// The shared scrollable safety content, used by the full route and by the
/// quiet sheet presentation. Deterministic: rebuilds always render identical
/// content for the same region code.
class CareSafetySheetBody extends StatelessWidget {
  const CareSafetySheetBody({
    super.key,
    this.regionCode,
    this.careWorld = true,
  });

  final String? regionCode;
  final bool careWorld;

  Color get _ink => careWorld ? ExperienceColors.careInk : ExperienceColors.ink;
  Color get _inkSoft =>
      careWorld ? ExperienceColors.careInkSoft : ExperienceColors.inkSoft;
  Color get _inkFaint =>
      careWorld ? ExperienceColors.careInkFaint : ExperienceColors.inkFaint;

  @override
  Widget build(BuildContext context) {
    final resolvedRegionCode =
        regionCode ?? View.of(context).platformDispatcher.locale.countryCode;
    final crisis = crisisSafetyContentForCode(resolvedRegionCode);
    const boundary = medicalBoundaryContent;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        ExperienceSpacing.screenMargin,
        ExperienceSpacing.sm,
        ExperienceSpacing.screenMargin,
        ExperienceSpacing.scrollBottomPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'SUPPORT, RIGHT NOW',
            style: ExperienceType.eyebrow(
              careWorld
                  ? ExperienceColors.emberSoft
                  : ExperienceColors.accentSafety,
            ),
          ),
          const SizedBox(height: ExperienceSpacing.sm),
          Semantics(
            header: true,
            child: Text(
              'You deserve support right now.',
              style: ExperienceType.title(_ink),
            ),
          ),
          const SizedBox(height: ExperienceSpacing.xs),
          Text(
            'If hurting yourself feels close, reach out now. '
            'You do not have to carry this alone.',
            style: ExperienceType.body(_inkSoft),
          ),
          const SizedBox(height: ExperienceSpacing.lg),
          _SafetyCard(
            careWorld: careWorld,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (var i = 0; i < crisis.contacts.length; i++) ...<Widget>[
                  if (i > 0)
                    Divider(
                      height: ExperienceSpacing.lg,
                      color: careWorld
                          ? ExperienceColors.careGlassBorder
                          : ExperienceColors.hairline,
                    ),
                  _SafetyContactTile(
                    contact: crisis.contacts[i],
                    careWorld: careWorld,
                  ),
                ],
                if (crisis.fallbackLine != null)
                  Text(
                    crisis.fallbackLine!,
                    style: ExperienceType.bodyStrong(_ink),
                  ),
              ],
            ),
          ),
          const SizedBox(height: ExperienceSpacing.xl),
          Semantics(
            header: true,
            child: Text(
              'Some things belong with a clinician',
              style: ExperienceType.headline(_ink),
            ),
          ),
          const SizedBox(height: ExperienceSpacing.xs),
          Text(
            'Letter Within records and reflects. It cannot diagnose or treat.',
            style: ExperienceType.bodySmall(_inkSoft),
          ),
          const SizedBox(height: ExperienceSpacing.md),
          _BoundarySection(
            title: 'Get urgent medical care now if you notice:',
            items: boundary.urgent,
            careWorld: careWorld,
            urgent: true,
          ),
          const SizedBox(height: ExperienceSpacing.md),
          _BoundarySection(
            title: 'Book a medical assessment if you notice:',
            items: boundary.nonUrgent,
            careWorld: careWorld,
            urgent: false,
          ),
          const SizedBox(height: ExperienceSpacing.lg),
          Text(
            'This list never changes based on what you record. '
            'Nothing you log here becomes a diagnosis.',
            style: ExperienceType.caption(_inkFaint),
          ),
        ],
      ),
    );
  }
}

/// One tappable emergency contact line. Tapping copies the dialable digits
/// so the number is one paste away in the phone app — an honest, quiet
/// action with no network and no permissions. The copied state is confirmed
/// visually and textually; errors are never possible here and no haptic
/// punishment exists anywhere on this surface.
class _SafetyContactTile extends StatefulWidget {
  const _SafetyContactTile({required this.contact, required this.careWorld});

  final SafetyContact contact;
  final bool careWorld;

  @override
  State<_SafetyContactTile> createState() => _SafetyContactTileState();
}

class _SafetyContactTileState extends State<_SafetyContactTile> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.contact.number));
    await ExperienceHaptics.pick();
    if (!mounted) return;
    setState(() => _copied = true);
    Future<void>.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ink = widget.careWorld
        ? ExperienceColors.careInk
        : ExperienceColors.ink;
    final inkSoft = widget.careWorld
        ? ExperienceColors.careInkSoft
        : ExperienceColors.inkSoft;
    final accent = widget.careWorld
        ? ExperienceColors.emberSoft
        : ExperienceColors.accentSafety;

    return Semantics(
      button: true,
      label:
          '${widget.contact.label}. ${widget.contact.detail}. '
          'Double-tap to copy the number.',
      child: InkWell(
        onTap: _copy,
        borderRadius: ExperienceRadius.chipRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: ExperienceSpacing.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      widget.contact.label,
                      style: ExperienceType.bodyStrong(ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.contact.detail,
                      style: ExperienceType.caption(inkSoft),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _copied
                          ? Text(
                              'Number copied — paste it into your phone app.',
                              key: const ValueKey<String>('copied'),
                              style: ExperienceType.caption(accent),
                            )
                          : const SizedBox(
                              key: ValueKey<String>('idle'),
                              height: 0,
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: ExperienceSpacing.sm),
              ExcludeSemantics(
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: ExperienceSpacing.minTouchTarget,
                    minHeight: ExperienceSpacing.minTouchTarget,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: ExperienceSpacing.sm,
                    vertical: ExperienceSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: ExperienceRadius.chipRadius,
                    border: Border.all(
                      color: widget.careWorld
                          ? ExperienceColors.careGlassBorder
                          : ExperienceColors.hairline,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      widget.contact.number,
                      style: ExperienceType.data(accent, size: 22),
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

/// A translucent plum-glass (Care) or warm white (light world) container for
/// the crisis contacts. Deep plum accent, never red-dominant.
class _SafetyCard extends StatelessWidget {
  const _SafetyCard({required this.careWorld, required this.child});

  final bool careWorld;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ExperienceSpacing.md),
      decoration: BoxDecoration(
        color: careWorld
            ? ExperienceColors.careGlass
            : ExperienceColors.surface,
        borderRadius: ExperienceRadius.cardRadius,
        border: Border.all(
          color: careWorld
              ? ExperienceColors.careGlassBorder
              : ExperienceColors.accentSafety.withValues(alpha: 0.35),
        ),
        boxShadow: careWorld ? null : ExperienceShadows.card,
      ),
      child: child,
    );
  }
}

/// One half of the fixed medical-boundary list. Item text comes verbatim
/// from [MedicalBoundaryContent]; markers are shape + text, never color
/// alone.
class _BoundarySection extends StatelessWidget {
  const _BoundarySection({
    required this.title,
    required this.items,
    required this.careWorld,
    required this.urgent,
  });

  final String title;
  final List<String> items;
  final bool careWorld;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final ink = careWorld ? ExperienceColors.careInk : ExperienceColors.ink;
    final inkSoft = careWorld
        ? ExperienceColors.careInkSoft
        : ExperienceColors.inkSoft;
    final markerColor = urgent
        ? (careWorld
              ? ExperienceColors.emberSoft
              : ExperienceColors.accentSafety)
        : (careWorld
              ? ExperienceColors.careInkFaint
              : ExperienceColors.inkFaint);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(title, style: ExperienceType.bodyStrong(ink)),
        const SizedBox(height: ExperienceSpacing.xs),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: ExperienceSpacing.xs / 2,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ExcludeSemantics(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    // Urgent items carry a filled square marker, non-urgent a
                    // hollow circle — urgency reads by shape, not hue.
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: urgent ? BoxShape.rectangle : BoxShape.circle,
                        borderRadius: urgent ? BorderRadius.circular(2) : null,
                        color: urgent ? markerColor : Colors.transparent,
                        border: urgent
                            ? null
                            : Border.all(color: markerColor, width: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: ExperienceSpacing.sm),
                Expanded(
                  child: Text(item, style: ExperienceType.bodySmall(inkSoft)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
