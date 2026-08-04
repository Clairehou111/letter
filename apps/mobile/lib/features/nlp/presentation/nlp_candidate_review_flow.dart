import 'package:flutter/material.dart';

import '../../../design_system/letter_theme.dart';
import '../../cycle/domain/local_date.dart';
import '../../health_records/domain/health_record.dart';
import '../application/nlp_review_controller.dart';
import '../domain/nlp_candidate.dart';

class NlpCandidateReviewFlow extends StatefulWidget {
  const NlpCandidateReviewFlow({
    required this.controller,
    required this.fallbackDate,
    super.key,
    this.onConfirmed,
  });

  final NlpReviewController controller;
  final LocalDate fallbackDate;
  final ValueChanged<List<HealthRecordDraft>>? onConfirmed;

  @override
  State<NlpCandidateReviewFlow> createState() => _NlpCandidateReviewFlowState();
}

class _NlpCandidateReviewFlowState extends State<NlpCandidateReviewFlow> {
  final Map<String, TextEditingController> _painControllers = {};
  final Map<String, int?> _painRatings = {};

  NlpReviewController get _review => widget.controller;

  @override
  void initState() {
    super.initState();
    _review.addListener(_onReviewChanged);
  }

  @override
  void dispose() {
    _review.removeListener(_onReviewChanged);
    for (final controller in _painControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onReviewChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _edit(NlpCandidate candidate) async {
    final result = await showModalBottomSheet<_NlpEditValues>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _NlpEditSheet(candidate: candidate),
    );
    if (result == null) {
      return;
    }
    _review.edit(
      candidate.id,
      symptom: result.symptom,
      isPresent: result.isPresent,
      severity: result.severity,
      clearSeverity: result.severity == null,
      painLocations: result.painLocations,
    );
  }

  void _confirm() {
    final drafts = _review.confirmedDrafts(
      fallbackDate: widget.fallbackDate,
      painRatings: _painRatings,
    );
    if (drafts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Confirm a present symptom and choose its severity first.',
          ),
        ),
      );
      return;
    }
    widget.onConfirmed?.call(drafts);
  }

  @override
  Widget build(BuildContext context) {
    final error = _review.errorMessage;
    return Scaffold(
      key: const Key('nlp-candidate-review-flow'),
      backgroundColor: LetterColors.canvas,
      appBar: AppBar(title: const Text('Review your words')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
          children: [
            const LetterEyebrow('A closer read', color: LetterColors.teal),
            const SizedBox(height: LetterSpacing.xs),
            const Text(
              'These are suggestions, not a diagnosis.',
              style: TextStyle(
                fontFamily: 'Newsreader',
                fontSize: 28,
                height: 1.08,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: LetterSpacing.xs),
            const Text(
              'Nothing becomes a health record until you confirm or edit it. '
              'Letter never estimates severity from emotion, writing, voice, or taps.',
              style: TextStyle(color: LetterColors.muted, height: 1.45),
            ),
            if (error != null) ...[
              const SizedBox(height: LetterSpacing.sm),
              MaterialBanner(
                content: Text(error),
                actions: [
                  TextButton(
                    onPressed: _review.clearError,
                    child: const Text('Dismiss'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: LetterSpacing.lg),
            if (_review.candidates.isEmpty)
              const _EmptyNlpReview()
            else
              ..._review.candidates.map(_candidateCard),
            const SizedBox(height: LetterSpacing.md),
            FilledButton.icon(
              key: const Key('nlp-confirm-health-records'),
              onPressed: _confirm,
              icon: const Icon(Icons.check),
              label: const Text('Add confirmed records'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _candidateCard(NlpCandidate candidate) {
    final painController = candidate.painLocations.isEmpty
        ? null
        : (_painControllers[candidate.id] ??= TextEditingController());
    final statusLabel = switch (candidate.status) {
      NlpCandidateStatus.unresolved => 'Needs your read',
      NlpCandidateStatus.accepted => 'Accepted by you',
      NlpCandidateStatus.edited => 'Edited by you',
      NlpCandidateStatus.rejected => 'Rejected',
    };
    final canAccept = candidate.isPresent && candidate.severity != null;
    return Card(
      key: Key('nlp-candidate-${candidate.id}'),
      margin: const EdgeInsets.only(bottom: LetterSpacing.sm),
      color: LetterColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(LetterSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    candidate.symptom.label,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  statusLabel,
                  style: const TextStyle(
                    color: LetterColors.teal,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: LetterSpacing.xs),
            Text(
              '“${candidate.evidence.excerpt}”',
              style: const TextStyle(
                color: LetterColors.muted,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
            const SizedBox(height: LetterSpacing.xs),
            Text(
              '${candidate.confidence.label} · ${candidate.source.label}',
              style: const TextStyle(color: LetterColors.muted, fontSize: 12),
            ),
            const SizedBox(height: LetterSpacing.sm),
            Text(
              candidate.isPresent
                  ? 'Your words describe this as present.'
                  : 'Your words say this was not present.',
              style: TextStyle(
                color: candidate.isPresent
                    ? LetterColors.ink
                    : LetterColors.muted,
              ),
            ),
            Text(
              candidate.severity == null
                  ? 'Severity: not stated; choose it yourself.'
                  : 'Severity you can review: ${candidate.severity!.label}',
              style: const TextStyle(color: LetterColors.muted, fontSize: 13),
            ),
            if (candidate.painLocations.isNotEmpty) ...[
              const SizedBox(height: LetterSpacing.xs),
              Text(
                'Pain location: ${candidate.painLocations.map((location) => location.label).join(', ')}',
                style: const TextStyle(color: LetterColors.muted, fontSize: 13),
              ),
              const SizedBox(height: LetterSpacing.xs),
              TextField(
                key: Key('nlp-pain-rating-${candidate.id}'),
                controller: painController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Pain score, 0-10',
                  helperText: 'Required before this pain entry can be added.',
                ),
                onChanged: (value) {
                  final rating = int.tryParse(value);
                  _painRatings[candidate.id] =
                      rating != null && rating >= 0 && rating <= 10
                      ? rating
                      : null;
                },
              ),
            ],
            const SizedBox(height: LetterSpacing.sm),
            Wrap(
              spacing: LetterSpacing.xs,
              runSpacing: LetterSpacing.xs,
              children: [
                OutlinedButton(
                  key: Key('nlp-edit-${candidate.id}'),
                  onPressed: () => _edit(candidate),
                  child: const Text('Edit'),
                ),
                OutlinedButton(
                  key: Key('nlp-reject-${candidate.id}'),
                  onPressed: () => _review.reject(candidate.id),
                  child: const Text('Reject'),
                ),
                if (candidate.status != NlpCandidateStatus.unresolved)
                  TextButton(
                    key: Key('nlp-unresolve-${candidate.id}'),
                    onPressed: () => _review.leaveUnresolved(candidate.id),
                    child: const Text('Leave for later'),
                  ),
                FilledButton(
                  key: Key('nlp-accept-${candidate.id}'),
                  onPressed: canAccept
                      ? () => _review.accept(candidate.id)
                      : null,
                  child: const Text('Accept'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyNlpReview extends StatelessWidget {
  const _EmptyNlpReview();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: LetterSpacing.xl),
      child: Text(
        'No known symptom phrase was found. Your original words stay yours; '
        'you can record a symptom yourself later.',
        textAlign: TextAlign.center,
        style: TextStyle(color: LetterColors.muted, height: 1.45),
      ),
    );
  }
}

final class _NlpEditValues {
  const _NlpEditValues({
    required this.symptom,
    required this.isPresent,
    required this.severity,
    required this.painLocations,
  });

  final SymptomType symptom;
  final bool isPresent;
  final SymptomSeverity? severity;
  final Set<PainLocation> painLocations;
}

class _NlpEditSheet extends StatefulWidget {
  const _NlpEditSheet({required this.candidate});

  final NlpCandidate candidate;

  @override
  State<_NlpEditSheet> createState() => _NlpEditSheetState();
}

class _NlpEditSheetState extends State<_NlpEditSheet> {
  late SymptomType _symptom = widget.candidate.symptom;
  late bool _isPresent = widget.candidate.isPresent;
  SymptomSeverity? _severity;
  late final Set<PainLocation> _locations;

  @override
  void initState() {
    super.initState();
    _severity = widget.candidate.severity;
    _locations = {...widget.candidate.painLocations};
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          18,
          18,
          18 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            const Text(
              'Correct this suggestion',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: LetterSpacing.md),
            DropdownButtonFormField<SymptomType>(
              initialValue: _symptom,
              decoration: const InputDecoration(labelText: 'What was present?'),
              items: SymptomType.values
                  .where((symptom) => symptom.availableForNewRecords)
                  .map(
                    (symptom) => DropdownMenuItem(
                      value: symptom,
                      child: Text(symptom.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _symptom = value);
                }
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('I experienced this'),
              value: _isPresent,
              onChanged: (value) => setState(() => _isPresent = value),
            ),
            DropdownButtonFormField<String>(
              initialValue: _severity?.name,
              decoration: const InputDecoration(
                labelText: 'Severity you choose',
                hintText: 'Choose one, or leave unresolved',
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Leave unresolved'),
                ),
                ...SymptomSeverity.values.map(
                  (severity) => DropdownMenuItem(
                    value: severity.name,
                    child: Text(severity.label),
                  ),
                ),
              ],
              onChanged: (value) => setState(
                () => _severity = value == null
                    ? null
                    : SymptomSeverity.values.byName(value),
              ),
            ),
            const SizedBox(height: LetterSpacing.md),
            FilledButton(
              key: const Key('nlp-save-edit'),
              onPressed: () => Navigator.pop(
                context,
                _NlpEditValues(
                  symptom: _symptom,
                  isPresent: _isPresent,
                  severity: _severity,
                  painLocations: _locations,
                ),
              ),
              child: const Text('Use this correction'),
            ),
          ],
        ),
      ),
    );
  }
}
