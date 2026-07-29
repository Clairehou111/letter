import 'dart:async';

import 'package:flutter/material.dart';

import '../../../design_system/letter_theme.dart';
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
      decoration: const BoxDecoration(
        color: LetterColors.canvas,
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: SafeArea(
        top: false,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    kind == CareSafetyKind.physical
                        ? 'This needs medical attention, not more interaction.'
                        : 'Immediate safety comes first.',
                    style: const TextStyle(
                      fontFamily: 'Newsreader',
                      fontSize: 25,
                      height: 1.05,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Return to scene',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: LetterSpacing.md),
            if (kind == CareSafetyKind.physical)
              const _MedicalBoundaryBody()
            else
              _CrisisBoundaryBody(
                content: crisisSafetyContentForCode(regionCode),
                dialer: dialer,
              ),
            const SizedBox(height: LetterSpacing.lg),
            FilledButton(
              key: const Key('leave-care-from-safety'),
              onPressed: onLeaveCare,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: LetterColors.teal,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(LetterRadius.control),
                ),
              ),
              child: const Text('Leave Care'),
            ),
            TextButton(
              key: const Key('return-to-care-scene'),
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: LetterColors.muted,
              ),
              child: const Text('Return to scene'),
            ),
          ],
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
        const Text(
          'Letter cannot provide emergency help from this screen. '
          'Reaching out now is the right move — you do not have to handle '
          'this minute alone.',
          style: TextStyle(
            color: LetterColors.muted,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: LetterSpacing.md),
        if (content.contacts.isEmpty)
          Text(
            content.fallbackLine ??
                'Contact your local emergency services now.',
            key: const Key('crisis-fallback-line'),
            style: const TextStyle(
              color: LetterColors.ink,
              fontSize: 15,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          )
        else ...[
          for (final contact in content.contacts)
            Padding(
              padding: const EdgeInsets.only(bottom: LetterSpacing.sm),
              child: _SafetyContactButton(contact: contact, dialer: dialer),
            ),
        ],
        const SizedBox(height: LetterSpacing.sm),
        const Text(
          'If you can, also tell someone you trust that you are not okay.',
          style: TextStyle(
            color: LetterColors.muted,
            fontSize: 14,
            height: 1.5,
          ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          key: Key('safety-contact-${contact.number}'),
          onPressed: () => unawaited(dialer.call(contact.number)),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            alignment: Alignment.centerLeft,
            foregroundColor: LetterColors.ink,
            side: const BorderSide(color: LetterColors.line),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(LetterRadius.control),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          icon: const Icon(Icons.phone_outlined, size: 20),
          label: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                contact.label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                contact.detail,
                style: const TextStyle(
                  color: LetterColors.muted,
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
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
        const Text(
          'Seek urgent medical care now if you have:',
          style: TextStyle(
            color: LetterColors.ink,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: LetterSpacing.xs),
        for (final item in medicalBoundaryContent.urgent) _BulletLine(item),
        const SizedBox(height: LetterSpacing.md),
        const Text(
          'Book a medical assessment if you notice:',
          style: TextStyle(
            color: LetterColors.ink,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: LetterSpacing.xs),
        for (final item in medicalBoundaryContent.nonUrgent) _BulletLine(item),
        const SizedBox(height: LetterSpacing.md),
        const Text(
          'Letter cannot assess symptoms or give medical advice. What you '
          'have recorded can be shown to a clinician.',
          style: TextStyle(
            color: LetterColors.muted,
            fontSize: 14,
            height: 1.5,
          ),
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
          const Text(
            '•  ',
            style: TextStyle(color: LetterColors.muted, fontSize: 14),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: LetterColors.ink,
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
