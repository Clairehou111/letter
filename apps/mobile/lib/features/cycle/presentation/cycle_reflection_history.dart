import 'package:flutter/material.dart';

import '../../../experience/theme/experience_foundation.dart';
import '../../care/domain/care_memory.dart';
import '../../care/domain/care_memory_repository.dart';
import '../domain/local_date.dart';
import '../domain/period_record.dart';

/// Saved originals which cannot be opened through a completed cycle's detail.
/// The original anchor is displayed without inventing a replacement period.
class CycleReflectionHistory extends StatefulWidget {
  const CycleReflectionHistory({
    required this.repository,
    required this.completedPeriods,
    required this.revision,
    required this.onChanged,
    super.key,
  });

  final CareMemoryRepository repository;
  final List<PeriodRecord> completedPeriods;
  final int revision;
  final VoidCallback onChanged;

  @override
  State<CycleReflectionHistory> createState() => _CycleReflectionHistoryState();
}

class _CycleReflectionHistoryState extends State<CycleReflectionHistory> {
  List<CycleReflection> _sources = const [];
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(CycleReflectionHistory oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision ||
        oldWidget.repository != widget.repository) {
      _load();
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    try {
      final sources = await widget.repository.getCycleReflections();
      // Use the same resolver as Cycle details. An unlinked original may be
      // reachable by date, while a second preserved original is not.
      final linked = await Future.wait(
        widget.completedPeriods.map(
          (period) => widget.repository.getCycleReflection(
            period.startDate.epochDay,
            startingPeriodId: period.id,
          ),
        ),
      );
      final reachableIds = linked
          .whereType<CycleReflection>()
          .map((s) => s.id)
          .toSet();
      if (!mounted || generation != _generation) return;
      setState(() {
        _sources = sources.where((s) => !reachableIds.contains(s.id)).toList();
        _error = null;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(
          () => _error = 'Saved reflections could not be loaded. Try again.',
        );
      }
    }
  }

  Future<void> _edit(CycleReflection source) async {
    final changed = await showExperienceSheet<bool>(
      context,
      // Protect a writing draft from dismissal and from parent read refreshes.
      dominant: true,
      child: _SavedReflectionEditor(
        repository: widget.repository,
        source: source,
      ),
    );
    if (changed == true) widget.onChanged();
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_sources.isEmpty && _error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: ExperienceSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Saved reflections',
              style: ExperienceType.headline(ExperienceColors.ink),
            ),
          ),
          const SizedBox(height: ExperienceSpacing.xs),
          Text(
            'Your original dates and words stay here when periods change.',
            style: ExperienceType.caption(ExperienceColors.inkSoft),
          ),
          if (_error != null) ...[
            Semantics(liveRegion: true, child: Text(_error!)),
            TextButton(onPressed: _load, child: const Text('Try again')),
          ],
          for (final source in _sources)
            ExpansionTile(
              key: ValueKey('saved-cycle-reflection-${source.id}'),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(
                bottom: ExperienceSpacing.sm,
              ),
              title: Text(
                'Original cycle date: ${LocalDate.fromEpochDay(source.cycleStartDay)}',
                style: ExperienceType.body(ExperienceColors.ink),
              ),
              children: [
                for (final field in [
                  ('What was hard', source.observation),
                  (
                    'What I needed',
                    source.need == null
                        ? null
                        : cycleReflectionNeedLabel(source.need!),
                  ),
                  ('What helped', source.whatHelped),
                  ('A note to future you', source.futureSelfNote),
                ])
                  if (field.$2 != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: ExperienceSpacing.xs,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${field.$1}\n${field.$2}',
                          style: ExperienceType.bodySmall(ExperienceColors.ink),
                        ),
                      ),
                    ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    key: ValueKey('edit-cycle-reflection-${source.id}'),
                    onPressed: () => _edit(source),
                    child: const Text('Edit reflection'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

String cycleReflectionNeedLabel(ReflectionNeed need) => switch (need) {
  ReflectionNeed.boundaries => 'Boundaries',
  ReflectionNeed.connection => 'Connection',
  ReflectionNeed.autonomy => 'Autonomy',
  ReflectionNeed.restOrPhysicalCapacity => 'Rest or physical capacity',
  ReflectionNeed.somethingElse => 'Something else',
  ReflectionNeed.notSure => 'Not sure',
};

class _SavedReflectionEditor extends StatefulWidget {
  const _SavedReflectionEditor({
    required this.repository,
    required this.source,
  });
  final CareMemoryRepository repository;
  final CycleReflection source;

  @override
  State<_SavedReflectionEditor> createState() => _SavedReflectionEditorState();
}

class _SavedReflectionEditorState extends State<_SavedReflectionEditor> {
  late final _hard = TextEditingController(
    text: widget.source.observation ?? '',
  );
  late final _helped = TextEditingController(
    text: widget.source.whatHelped ?? '',
  );
  late final _future = TextEditingController(
    text: widget.source.futureSelfNote ?? '',
  );
  bool _busy = false;
  bool _allowPop = false;
  String? _error;

  String? _word(String value) => value.trim().isEmpty ? null : value.trim();
  bool get _dirty =>
      _word(_hard.text) != widget.source.observation ||
      _word(_helped.text) != widget.source.whatHelped ||
      _word(_future.text) != widget.source.futureSelfNote;

  @override
  void dispose() {
    _hard.dispose();
    _helped.dispose();
    _future.dispose();
    super.dispose();
  }

  Future<void> _close({bool changed = false}) async {
    if (_busy) return;
    if (!changed && _dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard this reflection draft?'),
          content: const Text('Your saved reflection will stay as it was.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep editing'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard draft'),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    if (!mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context, changed);
    });
  }

  Future<bool> _sourceStillCurrent() async {
    final originals = await widget.repository.getCycleReflections();
    final current = originals
        .where((s) => s.id == widget.source.id)
        .firstOrNull;
    final source = widget.source;
    return current != null &&
        current.startingPeriodId == source.startingPeriodId &&
        current.cycleStartDay == source.cycleStartDay &&
        current.need == source.need &&
        current.observation == source.observation &&
        current.whatHelped == source.whatHelped &&
        current.futureSelfNote == source.futureSelfNote &&
        current.createdAt == source.createdAt &&
        current.updatedAt == source.updatedAt;
  }

  Future<void> _write({bool delete = false}) async {
    if (_busy || (!delete && !_dirty)) return;
    if (delete) {
      final remove = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete this reflection?'),
          content: const Text(
            'Only this reflection will be removed. Your periods and other records stay saved.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep reflection'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete reflection'),
            ),
          ],
        ),
      );
      if (remove != true || !mounted) return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!await _sourceStillCurrent()) {
        if (mounted) {
          setState(() {
            _busy = false;
            _error =
                'This saved reflection changed. Close and reopen it before making changes. Your draft is still here.';
          });
        }
        return;
      }
      if (delete) {
        await widget.repository.deleteCycleReflection(widget.source.id);
      } else {
        await widget.repository.saveCycleReflection(
          widget.source.cycleStartDay,
          CycleReflectionDraft(
            observation: _hard.text,
            need: widget.source.need,
            whatHelped: _helped.text,
            futureSelfNote: _future.text,
          ),
          startingPeriodId: widget.source.startingPeriodId,
        );
      }
      if (!mounted) return;
      setState(() => _busy = false);
      await _close(changed: true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = delete
              ? 'Your reflection could not be deleted. Try again.'
              : 'Your reflection could not be saved. Your draft is still here.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _close();
    },
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(ExperienceSpacing.screenMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Letter to future you',
            style: ExperienceType.headline(ExperienceColors.ink),
          ),
          const SizedBox(height: ExperienceSpacing.xs),
          Text(
            'Original cycle date: ${LocalDate.fromEpochDay(widget.source.cycleStartDay)}',
            style: ExperienceType.caption(ExperienceColors.inkSoft),
          ),
          if (widget.source.need case final need?) ...[
            const SizedBox(height: ExperienceSpacing.sm),
            Text(
              'What I needed: ${cycleReflectionNeedLabel(need)}',
              style: ExperienceType.bodySmall(ExperienceColors.ink),
            ),
          ],
          for (final field in [
            (_hard, 'What was hard'),
            (_helped, 'What helped'),
            (_future, 'A note to future you'),
          ]) ...[
            const SizedBox(height: ExperienceSpacing.sm),
            TextField(
              controller: field.$1,
              enabled: !_busy,
              minLines: 3,
              maxLines: 8,
              style: ExperienceType.body(ExperienceColors.ink),
              decoration: InputDecoration(
                labelText: field.$2,
                filled: true,
                fillColor: ExperienceColors.surface,
              ),
              onChanged: (_) => setState(() => _error = null),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: ExperienceSpacing.sm),
            Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                style: ExperienceType.bodySmall(ExperienceColors.error),
              ),
            ),
          ],
          const SizedBox(height: ExperienceSpacing.sm),
          FilledButton(
            onPressed: _busy || !_dirty ? null : () => _write(),
            child: Text(_busy ? 'Saving…' : 'Save letter'),
          ),
          Wrap(
            spacing: ExperienceSpacing.sm,
            children: [
              TextButton(
                onPressed: _busy ? null : () => _write(delete: true),
                child: const Text('Delete reflection'),
              ),
              TextButton(
                onPressed: _busy ? null : () => _close(),
                child: const Text('Close'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
