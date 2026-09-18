import 'package:flutter/material.dart';

import '../../../experience/theme/experience_foundation.dart';
import '../domain/device_authenticator.dart';
import '../domain/privacy_preferences.dart';

class PrivacyShell extends StatefulWidget {
  const PrivacyShell({
    required this.preferences,
    required this.ready,
    required this.authenticator,
    required this.child,
    super.key,
  });

  final PrivacyPreferences preferences;
  final bool ready;
  final DeviceAuthenticator authenticator;
  final Widget child;

  @override
  State<PrivacyShell> createState() => PrivacyShellState();
}

class PrivacyShellState extends State<PrivacyShell>
    with WidgetsBindingObserver {
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;
  bool _covered = false;
  bool _unlocked = true;
  bool _authenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _unlocked = !widget.ready || !widget.preferences.appLockEnabled;
    if (!_unlocked) {
      _covered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
    }
  }

  @override
  void didUpdateWidget(PrivacyShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.ready && widget.ready) {
      if (widget.preferences.appLockEnabled) {
        setState(() {
          _unlocked = false;
          _covered = true;
        });
        _authenticate();
      }
      return;
    }
    if (!widget.ready) return;
    if (oldWidget.preferences.appLockEnabled ==
            widget.preferences.appLockEnabled &&
        oldWidget.preferences.screenCoverEnabled ==
            widget.preferences.screenCoverEnabled) {
      return;
    }
    if (!widget.preferences.appLockEnabled) {
      setState(() {
        _unlocked = true;
        _covered =
            widget.preferences.screenCoverEnabled &&
            _lifecycleState != AppLifecycleState.resumed;
      });
    } else {
      setState(() {
        _unlocked = true;
        _covered = _lifecycleState != AppLifecycleState.resumed;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    if (state != AppLifecycleState.resumed) {
      setState(() {
        _covered =
            widget.preferences.screenCoverEnabled ||
            widget.preferences.appLockEnabled;
        if (widget.preferences.appLockEnabled) _unlocked = false;
      });
      return;
    }

    if (!widget.preferences.appLockEnabled) {
      setState(() => _covered = false);
      return;
    }
    if (!_authenticating) _authenticate();
  }

  Future<void> _authenticate() async {
    if (_authenticating || !widget.preferences.appLockEnabled) return;
    setState(() {
      _authenticating = true;
      _covered = true;
    });
    final authenticated = await widget.authenticator.authenticate();
    if (!mounted) return;
    setState(() {
      _authenticating = false;
      _unlocked = authenticated;
      _covered = !authenticated || _lifecycleState != AppLifecycleState.resumed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final locked = widget.preferences.appLockEnabled && !_unlocked;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_covered || locked)
          _PrivacyCover(
            locked: locked,
            authenticating: _authenticating,
            onUnlock: _authenticate,
          ),
      ],
    );
  }
}

class _PrivacyCover extends StatelessWidget {
  const _PrivacyCover({
    required this.locked,
    required this.authenticating,
    required this.onUnlock,
  });

  final bool locked;
  final bool authenticating;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const Key('privacy-cover'),
      color: ExperienceColors.canvas,
      child: SafeArea(
        child: Center(
          child: Semantics(
            label: locked
                ? 'Letter Within is locked'
                : 'Letter Within privacy cover',
            child: Padding(
              padding: const EdgeInsets.all(ExperienceSpacing.xl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: ExperienceColors.surfaceWarm,
                        shape: BoxShape.circle,
                        border: Border.all(color: ExperienceColors.hairline),
                      ),
                      child: Icon(
                        locked ? Icons.lock_outline : Icons.mail_outline,
                        color: ExperienceColors.inkSoft,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: ExperienceSpacing.md),
                    Text(
                      'Letter Within',
                      textAlign: TextAlign.center,
                      style: ExperienceType.display(ExperienceColors.ink),
                    ),
                    if (locked) ...[
                      const SizedBox(height: ExperienceSpacing.lg),
                      _UnlockButton(
                        authenticating: authenticating,
                        onUnlock: onUnlock,
                      ),
                    ],
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

class _UnlockButton extends StatelessWidget {
  const _UnlockButton({required this.authenticating, required this.onUnlock});

  final bool authenticating;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final enabled = !authenticating;
    return Opacity(
      opacity: enabled ? 1 : 0.7,
      child: Container(
        key: const Key('unlock-letter'),
        decoration: BoxDecoration(
          gradient: enabled ? ExperienceColors.emberGradient : null,
          color: enabled ? null : ExperienceColors.surfaceWarm,
          borderRadius: ExperienceRadius.chipRadius,
          boxShadow: enabled ? ExperienceShadows.card : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: enabled ? onUnlock : null,
            borderRadius: ExperienceRadius.chipRadius,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: 52,
                minWidth: ExperienceSpacing.minTouchTarget,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: ExperienceSpacing.lg,
                  vertical: ExperienceSpacing.sm,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (authenticating)
                      const Padding(
                        padding: EdgeInsets.only(right: ExperienceSpacing.sm),
                        child: EmberLoadingIndicator(
                          size: 22,
                          semanticLabel: 'Unlocking Letter Within',
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(
                          right: ExperienceSpacing.xs + 4,
                        ),
                        child: Icon(
                          Icons.lock_open,
                          size: 20,
                          color: enabled
                              ? ExperienceColors.surface
                              : ExperienceColors.inkSoft,
                        ),
                      ),
                    Flexible(
                      child: Text(
                        authenticating ? 'Unlocking…' : 'Unlock Letter Within',
                        textAlign: TextAlign.center,
                        style: ExperienceType.label(
                          enabled
                              ? ExperienceColors.surface
                              : ExperienceColors.inkSoft,
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
