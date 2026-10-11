import 'package:flutter/material.dart';

import '../../../experience/theme/experience_foundation.dart';
import '../../care/domain/care_memory.dart';
import '../../care/domain/care_memory_repository.dart';
import '../../cycle/domain/local_date.dart';

/// Original letters stay reachable even if an owning period was removed or
/// its dates changed. Their original anchors are source metadata, not guesses.
class CycleLetterArchiveScreen extends StatefulWidget {
  const CycleLetterArchiveScreen({
    required this.repository,
    this.onChanged,
    super.key,
  });
  final CareMemoryRepository repository;
  final VoidCallback? onChanged;
  @override
  State<CycleLetterArchiveScreen> createState() =>
      _CycleLetterArchiveScreenState();
}

class _CycleLetterArchiveScreenState extends State<CycleLetterArchiveScreen> {
  List<CycleReflection>? _letters;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final letters = await widget.repository.getCycleReflections();
      if (mounted) {
        setState(() {
          _letters = letters;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'Your original letters could not be opened. Try again.',
        );
      }
    }
  }

  Future<void> _open(CycleReflection letter) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => _CycleLetterSourceEditor(
          repository: widget.repository,
          source: letter,
          onChanged: widget.onChanged,
        ),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ExperienceColors.canvas,
    appBar: AppBar(title: const Text('Cycle letter archive')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Original dates and words are kept when period dates change or episodes are merged or removed.',
        ),
        const SizedBox(height: 16),
        if (_error != null) ...[
          Text(_error!),
          TextButton(onPressed: _load, child: const Text('Try again')),
        ],
        if (_letters == null && _error == null)
          const Center(child: CircularProgressIndicator()),
        if (_letters?.isEmpty == true)
          const Text('No saved cycle letters yet.'),
        for (final letter in _letters ?? <CycleReflection>[])
          ListTile(
            key: ValueKey('cycle-letter-${letter.id}'),
            title: Text(
              'Original cycle date: ${LocalDate.fromEpochDay(letter.cycleStartDay)}',
            ),
            subtitle: Text(
              '${letter.startingPeriodId == null ? 'Saved original reference' : 'Saved cycle letter'}\n${letter.observation ?? letter.futureSelfNote ?? letter.whatHelped ?? 'Open saved letter'}',
            ),
            isThreeLine: true,
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _open(letter),
          ),
      ],
    ),
  );
}

class _CycleLetterSourceEditor extends StatefulWidget {
  const _CycleLetterSourceEditor({
    required this.repository,
    required this.source,
    this.onChanged,
  });
  final CareMemoryRepository repository;
  final CycleReflection source;
  final VoidCallback? onChanged;
  @override
  State<_CycleLetterSourceEditor> createState() =>
      _CycleLetterSourceEditorState();
}

class _CycleLetterSourceEditorState extends State<_CycleLetterSourceEditor> {
  late final _observation = TextEditingController(
    text: widget.source.observation ?? '',
  );
  late final _helped = TextEditingController(
    text: widget.source.whatHelped ?? '',
  );
  late final _future = TextEditingController(
    text: widget.source.futureSelfNote ?? '',
  );
  bool _dirty = false, _busy = false, _allowPop = false;
  String? _error;
  @override
  void dispose() {
    _observation.dispose();
    _helped.dispose();
    _future.dispose();
    super.dispose();
  }

  Future<void> _leave() async {
    if (_busy) return;
    if (_dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Keep editing your letter?'),
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
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.saveCycleReflection(
        widget.source.cycleStartDay,
        CycleReflectionDraft(
          observation: _observation.text,
          need: widget.source.need,
          whatHelped: _helped.text,
          futureSelfNote: _future.text,
        ),
        startingPeriodId: widget.source.startingPeriodId,
      );
      widget.onChanged?.call();
      if (mounted) {
        setState(() {
          _dirty = false;
          _busy = false;
        });
        await _leave();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Your letter could not be saved. Your draft is still here.';
        });
      }
    }
  }

  Future<void> _delete() async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this original letter?'),
        content: const Text(
          'This removes only this letter. Other records stay saved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep letter'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete letter'),
          ),
        ],
      ),
    );
    if (remove != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.deleteCycleReflection(widget.source.id);
      widget.onChanged?.call();
      if (mounted) {
        setState(() {
          _dirty = false;
          _busy = false;
        });
        await _leave();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Your letter could not be deleted. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _leave();
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          'Letter · ${LocalDate.fromEpochDay(widget.source.cycleStartDay)}',
        ),
        leading: IconButton(
          onPressed: _leave,
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (widget.source.startingPeriodId == null)
            const Text(
              'Saved original reference. Its owning period was changed or removed; its original date remains.',
            ),
          for (final field in [
            (_observation, 'What I noticed'),
            (_helped, 'What helped'),
            (_future, 'For my future self'),
          ]) ...[
            const SizedBox(height: 16),
            TextField(
              controller: field.$1,
              enabled: !_busy,
              maxLines: 4,
              maxLength: 280,
              decoration: InputDecoration(labelText: field.$2),
              onChanged: (_) => setState(() => _dirty = true),
            ),
          ],
          if (_error != null) Semantics(liveRegion: true, child: Text(_error!)),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: const Text('Save letter'),
          ),
          TextButton(
            onPressed: _busy ? null : _delete,
            child: const Text('Delete letter'),
          ),
        ],
      ),
    ),
  );
}
