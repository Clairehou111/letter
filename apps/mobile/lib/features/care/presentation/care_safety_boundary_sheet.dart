import 'dart:async';

import 'package:flutter/material.dart';

import '../../../experience/theme/experience_foundation.dart';
import '../data/url_launcher_safety_dialer.dart';
import '../domain/care_mode.dart';
import '../domain/safety_dialer.dart';
import '../domain/safety_resources.dart';
import 'letter_safety_scope.dart';

/// Safety boundary sheet for Care scenes.
///
/// Content is deterministic and region-aware (US 988/911, CA 9-8-8/911,
/// honest fallback elsewhere). Opening or using this sheet creates no record,
/// event, candidate, log, or analytics.
///
/// Chrome (28-pt hero radius, grab handle, daylight scrim, safe area) is
/// supplied by `showExperienceSheet` at the call site; this widget renders
/// the sheet content in the daylight system: plum serif title, deep-plum
/// safety accents, warm hairline contact rows, and a single ember "Leave
/// Care" primary.
class CareSafetyBoundarySheet extends StatelessWidget {
  const CareSafetyBoundarySheet({
    required this.kind,
    required this.onLeaveCare,
    super.key,
  });

  final CareSafetyKind kind;
  final VoidCallback onLeaveCare;

  @override
  Widget build(BuildContext context) {
    final scope = LetterSafetyScope.maybeOf(context);
    final regionCode =
        scope?.regionCode ??
        View.of(context).platformDispatcher.locale.countryCode;
    final dialer = scope?.dialer ?? const UrlLauncherSafetyDialer();

    return Container(
      color: ExperienceColors.surface,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(
          ExperienceSpacing.screenMargin,
          ExperienceSpacing.xs,
          ExperienceSpacing.screenMargin,
          ExperienceSpacing.lg,
        ),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: ExperienceSpacing.xs),
                  child: Text(
                    kind == CareSafetyKind.physical
                        ? 'This needs medical attention, not more interaction.'
                        : 'Immediate safety comes first.',
                    style: ExperienceType.title(ExperienceColors.ink),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
                color: ExperienceColors.inkSoft,
                style: IconButton.styleFrom(
                  minimumSize: const Size(
                    ExperienceSpacing.minTouchTarget,
                    ExperienceSpacing.minTouchTarget,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: ExperienceSpacing.sm),
          if (kind == CareSafetyKind.physical)
            const _MedicalBoundaryBody()
          else
            _CrisisBoundaryBody(
              content: crisisSafetyContentForCode(regionCode),
              dialer: dialer,
            ),
          const SizedBox(height: ExperienceSpacing.lg),
          _LeaveCareButton(onPressed: onLeaveCare),
        ],
      ),
    );
  }
}

/// The single ember primary of this sheet — the boundary exit.
class _LeaveCareButton extends StatelessWidget {
  const _LeaveCareButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: ExperienceColors.emberGradient,
            borderRadius: ExperienceRadius.chipRadius,
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: ExperienceColors.emberGlow,
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: InkWell(
            key: const Key('leave-care-from-safety'),
            borderRadius: ExperienceRadius.chipRadius,
            onTap: onPressed,
            child: Container(
              height: 52,
              alignment: Alignment.center,
              child: Text(
                'Leave Care',
                style: ExperienceType.label(Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CrisisBoundaryBody extends StatelessWidget {
  const _CrisisBoundaryBody({required this.content, required this.dialer});

  final CrisisSafetyContent content;
  final SafetyDialer dialer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Letter Within cannot provide emergency help from this screen. '
          'Reaching out now is the right move — you do not have to handle '
          'this minute alone.',
          style: ExperienceType.bodySmall(ExperienceColors.inkSoft),
        ),
        const SizedBox(height: ExperienceSpacing.md),
        if (content.contacts.isEmpty)
          Text(
            content.fallbackLine ??
                'Contact your local emergency services now.',
            key: const Key('crisis-fallback-line'),
            style: ExperienceType.bodyStrong(ExperienceColors.ink),
          )
        else ...[
          for (final contact in content.contacts)
            Padding(
              padding: const EdgeInsets.only(bottom: ExperienceSpacing.sm),
              child: _SafetyContactButton(contact: contact, dialer: dialer),
            ),
        ],
        const SizedBox(height: ExperienceSpacing.xs),
        Text(
          'If you can, also tell someone you trust that you are not okay.',
          style: ExperienceType.bodySmall(ExperienceColors.inkSoft),
        ),
      ],
    );
  }
}

class _SafetyContactButton extends StatelessWidget {
  const _SafetyContactButton({required this.contact, required this.dialer});

  final SafetyContact contact;
  final SafetyDialer dialer;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: Material(
        color: ExperienceColors.surface,
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: ExperienceColors.hairline),
          borderRadius: ExperienceRadius.chipRadius,
        ),
        child: InkWell(
          key: Key('safety-contact-${contact.number}'),
          borderRadius: ExperienceRadius.chipRadius,
          onTap: () => unawaited(dialer.call(contact.number)),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: ExperienceSpacing.degreeTarget,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.phone_outlined,
                  size: 20,
                  color: ExperienceColors.accentSafety,
                ),
                const SizedBox(width: ExperienceSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.label,
                        style: ExperienceType.bodyStrong(ExperienceColors.ink),
                      ),
                      Text(
                        contact.detail,
                        style: ExperienceType.caption(ExperienceColors.inkSoft),
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

class _MedicalBoundaryBody extends StatelessWidget {
  const _MedicalBoundaryBody();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Get urgent medical care now if you notice:',
          style: ExperienceType.label(ExperienceColors.ink),
        ),
        const SizedBox(height: ExperienceSpacing.xs),
        for (final item in medicalBoundaryContent.urgent) _BulletLine(item),
        const SizedBox(height: ExperienceSpacing.md),
        Text(
          'Book a medical assessment if you notice:',
          style: ExperienceType.label(ExperienceColors.ink),
        ),
        const SizedBox(height: ExperienceSpacing.xs),
        for (final item in medicalBoundaryContent.nonUrgent) _BulletLine(item),
        const SizedBox(height: ExperienceSpacing.md),
        Text(
          'Letter Within cannot assess symptoms or give medical advice. What you '
          'have recorded can be shown to a clinician.',
          style: ExperienceType.bodySmall(ExperienceColors.inkSoft),
        ),
      ],
    );
  }
}

class _BulletLine extends StatelessWidget {
  const _BulletLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '•  ',
            style: ExperienceType.bodySmall(ExperienceColors.accentSafety),
          ),
          Expanded(
            child: Text(
              text,
              style: ExperienceType.bodySmall(ExperienceColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}
