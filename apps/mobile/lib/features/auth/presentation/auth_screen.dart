import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../design_system/letter_brand_mark.dart';
import '../../../experience/theme/experience_foundation.dart';
import '../domain/auth_service.dart';
import 'auth_error_message.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    required this.service,
    this.appleSignInEnabled = false,
    super.key,
  });

  final AuthService service;
  final bool appleSignInEnabled;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  bool _working = false;
  bool _linkSent = false;
  String? _error;

  bool get _showApple =>
      widget.appleSignInEnabled &&
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _apple() async {
    await _run(widget.service.signInWithApple);
  }

  Future<void> _magicLink() async {
    if (_working || _linkSent) return;
    final email = _email.text.trim();
    await _run(() => widget.service.sendMagicLink(email));
    if (mounted && _error == null) setState(() => _linkSent = true);
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_working) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await action();
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on supabase.AuthException catch (error) {
      if (kDebugMode) {
        debugPrint(
          'Letter Within auth request failed (status: ${error.statusCode ?? 'unknown'}).',
        );
      }
      if (mounted) setState(() => _error = AuthErrorMessage.from(error));
    } on Object catch (error) {
      if (mounted) setState(() => _error = AuthErrorMessage.from(error));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool magicLinkEnabled = !_working && !_linkSent;
    return Scaffold(
      backgroundColor: ExperienceColors.canvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(ExperienceSpacing.screenMargin),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const LetterBrandLockup(),
                  const SizedBox(height: ExperienceSpacing.xl),
                  Text(
                    'A private space for what you’re going through.',
                    style: ExperienceType.display(ExperienceColors.ink),
                  ),
                  const SizedBox(height: ExperienceSpacing.sm),
                  Text(
                    'Create one account for purchases and account recovery. '
                    'Your cycle, symptoms, Letters, and Care records stay on this device.',
                    style: ExperienceType.body(ExperienceColors.inkSoft),
                  ),
                  if (widget.service.current.hasLocalDataAccountMismatch) ...[
                    const SizedBox(height: ExperienceSpacing.md),
                    Semantics(
                      container: true,
                      child: Container(
                        padding: const EdgeInsets.all(ExperienceSpacing.sm),
                        decoration: BoxDecoration(
                          color: ExperienceColors.surface,
                          borderRadius: ExperienceRadius.cardRadius,
                          border: Border.all(color: ExperienceColors.hairline),
                          boxShadow: ExperienceShadows.card,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.lock_outline,
                              color: ExperienceColors.error,
                            ),
                            const SizedBox(width: ExperienceSpacing.sm),
                            Expanded(
                              child: Text(
                                'These on-device records were created while signed in to a different Letter Within account. '
                                'Sign in with that account to open them.',
                                key: const Key('auth-local-account-mismatch'),
                                style: ExperienceType.bodySmall(
                                  ExperienceColors.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: ExperienceSpacing.xl),
                  if (_showApple) ...[
                    FilledButton.icon(
                      key: const Key('auth-apple'),
                      onPressed: _working ? null : _apple,
                      icon: const Icon(Icons.apple),
                      label: Text(
                        'Continue with Apple',
                        style: ExperienceType.label(Colors.white),
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: ExperienceColors.surfaceWarm,
                        disabledForegroundColor: ExperienceColors.inkSoft
                            .withValues(alpha: 0.6),
                        shape: const RoundedRectangleBorder(
                          borderRadius: ExperienceRadius.chipRadius,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: ExperienceSpacing.md,
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Divider(color: ExperienceColors.hairline),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'or',
                              style: ExperienceType.bodySmall(
                                ExperienceColors.inkSoft,
                              ),
                            ),
                          ),
                          const Expanded(
                            child: Divider(color: ExperienceColors.hairline),
                          ),
                        ],
                      ),
                    ),
                  ],
                  TextField(
                    key: const Key('auth-email'),
                    controller: _email,
                    enabled: !_working,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.done,
                    style: ExperienceType.body(ExperienceColors.ink),
                    cursorColor: ExperienceColors.ember,
                    onSubmitted: (_) => _magicLink(),
                    onChanged: (_) {
                      if (_linkSent || _error != null) {
                        setState(() {
                          _linkSent = false;
                          _error = null;
                        });
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Email',
                      hintText: 'you@example.com',
                      labelStyle: ExperienceType.bodySmall(
                        ExperienceColors.inkSoft,
                      ),
                      hintStyle: ExperienceType.body(ExperienceColors.inkFaint),
                      filled: true,
                      fillColor: ExperienceColors.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: ExperienceSpacing.sm,
                        vertical: ExperienceSpacing.sm,
                      ),
                      border: const OutlineInputBorder(
                        borderRadius: ExperienceRadius.chipRadius,
                        borderSide: BorderSide(
                          color: ExperienceColors.hairline,
                        ),
                      ),
                      enabledBorder: const OutlineInputBorder(
                        borderRadius: ExperienceRadius.chipRadius,
                        borderSide: BorderSide(
                          color: ExperienceColors.hairline,
                        ),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: ExperienceRadius.chipRadius,
                        borderSide: BorderSide(
                          color: ExperienceColors.ember,
                          width: 1.6,
                        ),
                      ),
                      disabledBorder: const OutlineInputBorder(
                        borderRadius: ExperienceRadius.chipRadius,
                        borderSide: BorderSide(
                          color: ExperienceColors.hairline,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: ExperienceSpacing.sm),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: magicLinkEnabled
                          ? ExperienceColors.emberGradient
                          : null,
                      color: magicLinkEnabled
                          ? null
                          : ExperienceColors.surfaceWarm,
                      borderRadius: ExperienceRadius.chipRadius,
                    ),
                    child: FilledButton(
                      key: const Key('auth-magic-link'),
                      onPressed: magicLinkEnabled ? _magicLink : null,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        disabledBackgroundColor: Colors.transparent,
                        disabledForegroundColor: ExperienceColors.inkSoft
                            .withValues(alpha: 0.6),
                        shape: const RoundedRectangleBorder(
                          borderRadius: ExperienceRadius.chipRadius,
                        ),
                      ),
                      child: Text(
                        _linkSent
                            ? 'Sign-in link sent'
                            : 'Email me a sign-in link',
                        style: ExperienceType.label(
                          magicLinkEnabled
                              ? Colors.white
                              : ExperienceColors.inkSoft,
                        ),
                      ),
                    ),
                  ),
                  if (_working) ...[
                    const SizedBox(height: ExperienceSpacing.md),
                    const Center(
                      child: EmberLoadingIndicator(
                        semanticLabel: 'Sending sign-in link',
                      ),
                    ),
                  ],
                  if (_linkSent) ...[
                    const SizedBox(height: ExperienceSpacing.md),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        'Check your email, then return to Letter Within. The link signs you in or creates your account.',
                        key: const Key('auth-link-sent'),
                        style: ExperienceType.bodySmall(
                          ExperienceColors.inkSoft,
                        ),
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: ExperienceSpacing.md),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        key: const Key('auth-error'),
                        style: ExperienceType.bodySmall(ExperienceColors.error),
                      ),
                    ),
                  ],
                  const SizedBox(height: ExperienceSpacing.xl),
                  Container(
                    padding: const EdgeInsets.all(ExperienceSpacing.sm),
                    decoration: BoxDecoration(
                      color: ExperienceColors.surface,
                      borderRadius: ExperienceRadius.cardRadius,
                      border: Border.all(color: ExperienceColors.hairline),
                      boxShadow: ExperienceShadows.card,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.phone_android,
                          color: ExperienceColors.inkSoft,
                        ),
                        const SizedBox(width: ExperienceSpacing.sm),
                        Expanded(
                          child: Text(
                            'Signing in does not upload your health history. '
                            'If another account previously created records on '
                            'this device, those records stay closed—not '
                            'deleted—until that account signs in again.',
                            style: ExperienceType.bodySmall(
                              ExperienceColors.ink,
                            ),
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
      ),
    );
  }
}
