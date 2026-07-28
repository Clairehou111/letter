import 'package:flutter/material.dart';

import '../../../design_system/letter_theme.dart';
import '../application/personal_patterns_controller.dart';
import '../data/repository_pattern_source.dart';
import 'personal_patterns_screen.dart';

/// Loads the factual patterns view from the device's existing repositories.
///
/// This route deliberately owns no pattern storage. It rebuilds the view from
/// confirmed health records, saved Care check-backs, and period starts.
class PersonalPatternsRoute extends StatefulWidget {
  const PersonalPatternsRoute({required this.source, super.key});

  final RepositoryPatternSource source;

  @override
  State<PersonalPatternsRoute> createState() => _PersonalPatternsRouteState();
}

class _PersonalPatternsRouteState extends State<PersonalPatternsRoute> {
  late final PersonalPatternsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PersonalPatternsController(
      source: widget.source,
      mutations: widget.source,
    );
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() operation) async {
    try {
      await operation();
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Letter could not refresh your observed history.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        if (_controller.isLoading) {
          return const _PatternsLoading();
        }
        if (_controller.error != null) {
          return _PatternsLoadError(onRetry: _controller.load);
        }
        return PersonalPatternsScreen(
          analysis: _controller.analysis,
          onBack: () => Navigator.of(context).pop(),
          onCareModeChanged: (mode) =>
              _run(() => _controller.selectCareMode(mode)),
          onDismissPattern: _controller.dismissPattern,
          onUnpinAction: (careRecordId) => _run(
            () => _controller.setCareActionPinned(careRecordId, pinned: false),
          ),
        );
      },
    );
  }
}

class _PatternsLoading extends StatelessWidget {
  const _PatternsLoading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      key: Key('personal-patterns-loading'),
      body: Center(child: CircularProgressIndicator(color: LetterColors.teal)),
    );
  }
}

class _PatternsLoadError extends StatelessWidget {
  const _PatternsLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(LetterSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, color: LetterColors.teal),
              const SizedBox(height: LetterSpacing.sm),
              const Text('Your observed history could not be opened.'),
              const SizedBox(height: LetterSpacing.sm),
              FilledButton.icon(
                key: const Key('personal-patterns-retry'),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
