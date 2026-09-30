import 'package:flutter/material.dart';

import '../../../experience/theme/experience_foundation.dart';
import '../domain/privacy_preferences.dart';

class PrivacyShell extends StatefulWidget {
  const PrivacyShell({
    required this.preferences,
    required this.child,
    super.key,
  });

  final PrivacyPreferences preferences;
  final Widget child;

  @override
  State<PrivacyShell> createState() => PrivacyShellState();
}

class PrivacyShellState extends State<PrivacyShell>
    with WidgetsBindingObserver {
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;
  bool _covered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(PrivacyShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.preferences.screenCoverEnabled ==
        widget.preferences.screenCoverEnabled) {
      return;
    }
    setState(() {
      _covered =
          widget.preferences.screenCoverEnabled &&
          _lifecycleState != AppLifecycleState.resumed;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    setState(() {
      _covered =
          widget.preferences.screenCoverEnabled &&
          state != AppLifecycleState.resumed;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [widget.child, if (_covered) const _PrivacyCover()],
    );
  }
}

class _PrivacyCover extends StatelessWidget {
  const _PrivacyCover();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const Key('privacy-cover'),
      color: ExperienceColors.canvas,
      child: SafeArea(
        child: Center(
          child: Semantics(
            label: 'Letter Within privacy cover',
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
                        Icons.mail_outline,
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
