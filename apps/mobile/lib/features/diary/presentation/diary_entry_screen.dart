import 'package:flutter/material.dart';

import '../../../design_system/letter_theme.dart';
import '../../cycle/domain/local_date.dart';
import '../domain/diary_enrollment.dart';
import '../domain/diary_repository.dart';

/// Daily diary entry screen: rate each symptom and functional-impact item
/// on the six-point scale (spec: REQ-003, REQ-004).
///
/// Missed items are absent from the saved entry, never imputed. The screen
/// shows existing ratings when editing a past entry.
class DiaryEntryScreen extends StatefulWidget {
  const DiaryEntryScreen({
    required this.entryRepository,
    required this.enrollmentId,
    required this.experiencedDate,
    super.key,
    this.existingEntry,
    this.onSaved,
    this.onDelete,
  });

  final DiaryEntryRepository entryRepository;
  final String enrollmentId;
  final LocalDate experiencedDate;
  final DiaryEntry? existingEntry;
  final VoidCallback? onSaved;
  final VoidCallback? onDelete;

  @override
  State<DiaryEntryScreen> createState() => _DiaryEntryScreenState();
}

class _DiaryEntryScreenState extends State<DiaryEntryScreen> {
  late final Map<String, int> _symptoms;
  late final Map<String, int> _functionalImpacts;
  bool _saving = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _symptoms = Map.from(widget.existingEntry?.symptoms ?? {});
    _functionalImpacts =
        Map.from(widget.existingEntry?.functionalImpacts ?? {});
  }

  bool get _hasChanges {
    if (widget.existingEntry == null) {
      return _symptoms.isNotEmpty || _functionalImpacts.isNotEmpty;
    }
    return !_mapEquals(_symptoms, widget.existingEntry!.symptoms) ||
        !_mapEquals(_functionalImpacts, widget.existingEntry!.functionalImpacts);
  }

  static bool _mapEquals(Map<String, int> left, Map<String, int> right) {
    if (left.length != right.length) return false;
    for (final key in left.keys) {
      if (left[key] != right[key]) return false;
    }
    return true;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.entryRepository.saveEntry(
        DiaryEntryDraft(
          enrollmentId: widget.enrollmentId,
          experiencedDate: widget.experiencedDate,
          provenance: _isToday
              ? DiaryEntryProvenance.prospective
              : DiaryEntryProvenance.laterRecall,
          symptoms: Map.unmodifiable(_symptoms),
          functionalImpacts: Map.unmodifiable(_functionalImpacts),
        ),
      );
      if (mounted) widget.onSaved?.call();
    } on DiaryException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final entry = widget.existingEntry;
    if (entry == null) return;
    setState(() => _deleting = true);
    try {
      await widget.entryRepository.deleteEntry(entry.id);
      if (mounted) widget.onDelete?.call();
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  bool get _isToday {
    final now = LocalDate.fromDateTime(DateTime.now());
    return widget.experiencedDate == now;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateLabel = _isToday
        ? 'Today'
        : widget.experiencedDate.asLocalDateTime.toIso8601String()
            .substring(0, 10);
    final provenanceNote = _isToday
        ? null
        : 'Recording for $dateLabel (later recall)';

    return Scaffold(
      backgroundColor: LetterColors.canvas,
      appBar: AppBar(
        title: Text('Daily diary — $dateLabel'),
        actions: [
          if (widget.existingEntry != null)
            IconButton(
              key: const Key('diary-delete-entry'),
              tooltip: 'Delete entry',
              icon: _deleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline),
              onPressed: _deleting ? null : _delete,
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                if (provenanceNote != null) ...[
                  Container(
                    padding: const EdgeInsets.all(LetterSpacing.sm),
                    decoration: BoxDecoration(
                      color: LetterColors.amberSoft,
                      borderRadius: BorderRadius.circular(
                        LetterRadius.control,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 16,
                          color: LetterColors.amber,
                        ),
                        const SizedBox(width: LetterSpacing.xs),
                        Expanded(
                          child: Text(
                            provenanceNote,
                            style: const TextStyle(
                              color: LetterColors.amber,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: LetterSpacing.md),
                ],
                _SectionHeader(
                  title: 'Symptoms',
                  subtitle: 'How much did each affect you on this day?',
                ),
                const SizedBox(height: LetterSpacing.sm),
                for (final item in diarySymptomItems)
                  Padding(
                    padding: const EdgeInsets.only(bottom: LetterSpacing.xs),
                    child: _RatingRow(
                      label: item.label,
                      value: _symptoms[item.key],
                      onChanged: (value) {
                        setState(() {
                          if (value == null) {
                            _symptoms.remove(item.key);
                          } else {
                            _symptoms[item.key] = value;
                          }
                        });
                      },
                    ),
                  ),
                const SizedBox(height: LetterSpacing.lg),
                _SectionHeader(
                  title: 'Impact on daily life',
                  subtitle:
                      'Optional — how much did symptoms affect these areas?',
                ),
                const SizedBox(height: LetterSpacing.sm),
                for (final item in diaryFunctionalImpactItems)
                  Padding(
                    padding: const EdgeInsets.only(bottom: LetterSpacing.xs),
                    child: _RatingRow(
                      label: item.label,
                      value: _functionalImpacts[item.key],
                      onChanged: (value) {
                        setState(() {
                          if (value == null) {
                            _functionalImpacts.remove(item.key);
                          } else {
                            _functionalImpacts[item.key] = value;
                          }
                        });
                      },
                    ),
                  ),
                const SizedBox(height: LetterSpacing.xl),
                FilledButton.icon(
                  key: const Key('diary-save-entry'),
                  onPressed:
                      _saving || !_hasChanges ? null : _save,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: LetterColors.teal,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        LetterRadius.control,
                      ),
                    ),
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check),
                  label: Text(
                    widget.existingEntry != null
                        ? 'Update entry'
                        : 'Save entry',
                  ),
                ),
                const SizedBox(height: LetterSpacing.sm),
                Center(
                  child: Text(
                    'Unrated items are saved as absent. '
                    'The diary never fills in what you leave blank.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium!.copyWith(
                      color: LetterColors.muted,
                      fontSize: 12,
                      height: 1.4,
                    ),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
        const SizedBox(height: LetterSpacing.xxs),
        Text(
          subtitle,
          style: const TextStyle(
            color: LetterColors.muted,
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _RatingRow extends StatelessWidget {
  const _RatingRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final anchors = DiarySeverityAnchor.values;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: LetterColors.surface,
        borderRadius: BorderRadius.circular(LetterRadius.panel),
        border: Border.all(
          color: value != null
              ? LetterColors.teal.withValues(alpha: 0.35)
              : LetterColors.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (value != null)
                GestureDetector(
                  onTap: () => onChanged(null),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 14, color: LetterColors.muted),
                  ),
                ),
            ],
          ),
          const SizedBox(height: LetterSpacing.xxs),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: anchors.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(width: LetterSpacing.xxs),
              itemBuilder: (context, index) {
                final anchor = anchors[index];
                final selected = value == anchor.value;
                return Semantics(
                  button: true,
                  selected: selected,
                  label: '${anchor.label} $label',
                  child: GestureDetector(
                    onTap: () {
                      if (selected) {
                        onChanged(null);
                      } else {
                        onChanged(anchor.value);
                      }
                    },
                    child: AnimatedContainer(
                      duration: LetterMotion.responsive,
                      curve: LetterMotion.standard,
                      width: 44,
                      decoration: BoxDecoration(
                        color: selected
                            ? LetterColors.teal
                            : LetterColors.tealSoft,
                        borderRadius: BorderRadius.circular(
                          LetterRadius.control,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        anchor.value.toString(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? Colors.white
                              : LetterColors.tealDark,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (value != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                anchors[value!].label,
                style: const TextStyle(
                  color: LetterColors.tealDark,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
