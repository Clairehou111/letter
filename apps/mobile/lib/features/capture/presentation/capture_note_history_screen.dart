import 'package:flutter/material.dart';

import '../../../../experience/theme/experience_foundation.dart';
import '../domain/capture_models.dart';

/// Every saved note remains reachable, including undated Build17 sources.
/// This archive corrects existing sources; it never guesses an experienced day.
class CaptureNoteHistoryScreen extends StatefulWidget {
  const CaptureNoteHistoryScreen({
    required this.repository,
    this.onChanged,
    super.key,
  });

  final CaptureNoteStore repository;
  final VoidCallback? onChanged;

  @override
  State<CaptureNoteHistoryScreen> createState() =>
      _CaptureNoteHistoryScreenState();
}

class _CaptureNoteHistoryScreenState extends State<CaptureNoteHistoryScreen> {
  List<CaptureNote>? _notes;
  CaptureNote? _undoSource, _undoExpected;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final notes = await widget.repository.getAll();
      if (mounted) {
        setState(() {
          _notes = notes;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Your saved notes could not be opened. Try again.',
        );
      }
    }
  }

  Future<void> _edit(CaptureNote note) async {
    if (_busy) return;
    final saved = await Navigator.push<CaptureNote>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _SavedNoteEditor(repository: widget.repository, source: note),
      ),
    );
    if (!mounted) return;
    if (saved != null && !sameCaptureNoteVersion(saved, note)) {
      _undoSource = note;
      _undoExpected = saved;
      widget.onChanged?.call();
    }
    await _load();
  }

  Future<void> _delete(CaptureNote note) async {
    if (_busy) return;
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this saved note?'),
        content: const Text(
          'The note will also leave your Comfort Kit if you kept it there.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep note'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete note'),
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
      await widget.repository.delete(note, expectedCurrent: note);
      _undoSource = note;
      _undoExpected = null;
      widget.onChanged?.call();
      if (mounted) await _load();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'This note changed or could not be deleted. Refresh and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _undo() async {
    final source = _undoSource;
    if (_busy || source == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.restore(source, expectedCurrent: _undoExpected);
      _undoSource = null;
      _undoExpected = null;
      widget.onChanged?.call();
      if (mounted) await _load();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Undo is no longer available. A newer note will not be overwritten.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      backgroundColor: ExperienceColors.canvas,
      appBar: AppBar(title: const Text('Note history')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'All your saved notes are here. Earlier notes with an unknown date stay undated.',
          ),
          const SizedBox(height: 16),
          if (_undoSource != null)
            TextButton.icon(
              onPressed: _busy ? null : _undo,
              icon: const Icon(Icons.undo),
              label: const Text('Undo last change'),
            ),
          if (_error != null) ...[
            Semantics(liveRegion: true, child: Text(_error!)),
            TextButton(
              onPressed: _busy ? null : _load,
              child: const Text('Refresh'),
            ),
          ],
          if (_notes == null && _error == null)
            const Center(child: CircularProgressIndicator()),
          if (_notes?.isEmpty == true)
            const Text(
              'No saved notes yet. You can write one in Record or Today.',
            ),
          for (final note in _notes ?? <CaptureNote>[]) ...[
            ListTile(
              key: ValueKey('saved-note-${note.id}'),
              contentPadding: EdgeInsets.zero,
              title: Text(note.text),
              subtitle: Text(
                '${_sourceDate(context, note)} · ${note.provenance.label}${note.keepInComfortKit ? '\nKept in Comfort Kit' : ''}',
              ),
              onTap: _busy ? null : () => _edit(note),
              trailing: IconButton(
                tooltip: 'Delete saved note',
                onPressed: _busy ? null : () => _delete(note),
                icon: const Icon(Icons.delete_outline),
              ),
            ),
            const Divider(),
          ],
        ],
      ),
    ),
  );
}

String _sourceDate(BuildContext context, CaptureNote note) =>
    note.experiencedDate == null
    ? 'Date unknown'
    : MaterialLocalizations.of(
        context,
      ).formatFullDate(note.experiencedDate!.asLocalDateTime);

class _SavedNoteEditor extends StatefulWidget {
  const _SavedNoteEditor({required this.repository, required this.source});
  final CaptureNoteStore repository;
  final CaptureNote source;
  @override
  State<_SavedNoteEditor> createState() => _SavedNoteEditorState();
}

class _SavedNoteEditorState extends State<_SavedNoteEditor> {
  late final TextEditingController _text = TextEditingController(
    text: widget.source.text,
  );
  late bool _kept = widget.source.keepInComfortKit;
  bool _busy = false, _allowPop = false, _askingDiscard = false;
  String? _error;
  bool get _dirty =>
      _text.text != widget.source.text ||
      _kept != widget.source.keepInComfortKit;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _leave() async {
    if (_busy || _askingDiscard) return;
    if (_dirty) {
      _askingDiscard = true;
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Keep editing this note?'),
          content: const Text('Your changes have not been saved.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep editing'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard changes'),
            ),
          ],
        ),
      );
      _askingDiscard = false;
      if (discard != true || !mounted) return;
    }
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _save() async {
    if (_busy) return;
    final draft = widget.source.copyWith(
      text: _text.text,
      keepInComfortKit: _kept,
    );
    if (draft.text.trim().isEmpty || draft.text.length > captureTextLimit) {
      setState(
        () => _error =
            'Add a note of up to $captureTextLimit characters before saving.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final store = widget.repository;
      final CaptureNote saved;
      if (store is ConditionalCaptureNoteStore) {
        saved = await store.updateIfUnchanged(
          draft,
          expectedCurrent: widget.source,
        );
      } else {
        final current = (await store.getAll())
            .where((note) => note.id == widget.source.id)
            .firstOrNull;
        if (current == null ||
            !sameCaptureNoteVersion(current, widget.source)) {
          throw StateError('Source changed.');
        }
        saved = await store.update(draft);
      }
      if (mounted) {
        setState(() {
          _busy = false;
          _allowPop = true;
        });
        Navigator.pop(context, saved);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error =
              'This note changed or could not be saved. Your draft is still here. Return to history to refresh the source.';
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
      backgroundColor: ExperienceColors.canvas,
      appBar: AppBar(
        title: const Text('Saved note'),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: _busy ? null : _leave,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            '${_sourceDate(context, widget.source)} · ${widget.source.provenance.label}',
          ),
          const SizedBox(height: 8),
          Text(
            'Originally saved ${MaterialLocalizations.of(context).formatFullDate(widget.source.createdAt.toLocal())} · ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(widget.source.createdAt.toLocal()))}',
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('saved-note-text'),
            controller: _text,
            minLines: 5,
            maxLines: null,
            maxLength: captureTextLimit,
            enabled: !_busy,
            decoration: const InputDecoration(labelText: 'Your note'),
            onChanged: (_) => setState(() {}),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Keep in Comfort Kit'),
            subtitle: const Text(
              'Make these words available in your Comfort Kit.',
            ),
            value: _kept,
            onChanged: _busy
                ? null
                : (value) => setState(() => _kept = value ?? false),
          ),
          if (_error != null) Semantics(liveRegion: true, child: Text(_error!)),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy || !_dirty ? null : _save,
            child: Text(_busy ? 'Saving privately…' : 'Save note changes'),
          ),
        ],
      ),
    ),
  );
}
