import 'package:flutter/material.dart';

import '../../../experience/theme/experience_foundation.dart';
import '../../check_in/domain/moment_check_in.dart';
import '../../check_in/domain/moment_check_in_repository.dart';

/// Corrections of existing sources only. There is no historical-entry or date
/// picker here, and Moment remains absent from the dated Record taxonomy.
class MomentSourceHistoryScreen extends StatefulWidget {
  const MomentSourceHistoryScreen({
    required this.repository,
    this.onChanged,
    super.key,
  });
  final MomentCheckInRepository repository;
  final VoidCallback? onChanged;
  @override
  State<MomentSourceHistoryScreen> createState() =>
      _MomentSourceHistoryScreenState();
}

class _MomentSourceHistoryScreenState extends State<MomentSourceHistoryScreen> {
  List<MomentCheckIn>? _sources;
  MomentCheckIn? _deleted;
  String? _error;
  bool _busy = false;
  CorrectableMomentRepository? get _mutations =>
      widget.repository is CorrectableMomentRepository
      ? widget.repository as CorrectableMomentRepository
      : null;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final sources = await widget.repository.getAll();
      if (mounted) {
        setState(() {
          _sources = sources;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Your saved Moments could not be opened. Try again.',
        );
      }
    }
  }

  Future<void> _edit(MomentCheckIn source) async {
    final mutations = _mutations;
    if (_busy || mutations == null) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => _MomentSourceEditor(
          repository: mutations,
          source: source,
          onChanged: widget.onChanged,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _delete(MomentCheckIn source) async {
    final mutations = _mutations;
    if (_busy || mutations == null) return;
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this Moment?'),
        content: const Text(
          'Symptom records and other saved facts stay unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Moment'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete Moment'),
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
      if (!await mutations.deleteIfUnchanged(source)) {
        throw const MomentCheckInException(MomentCheckInFailure.staleWrite);
      }
      _deleted = source;
      widget.onChanged?.call();
      if (mounted) {
        await _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Moment deleted from this device.'),
              action: SnackBarAction(label: 'Undo', onPressed: _undo),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'This source changed or could not be deleted. Refresh and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _undo() async {
    final source = _deleted, mutations = _mutations;
    if (source == null || mutations == null || _busy) return;
    setState(() => _busy = true);
    try {
      await mutations.restoreDeleted(source);
      _deleted = null;
      widget.onChanged?.call();
      if (mounted) await _load();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Undo is no longer available. A newer source will not be overwritten.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ExperienceColors.canvas,
    appBar: AppBar(title: const Text('Moment history')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'These are your saved Moments. A positive Moment is not a whole-day symptom absence. Corrections preserve the original source and date.',
        ),
        const SizedBox(height: 16),
        if (_error != null) ...[
          Semantics(liveRegion: true, child: Text(_error!)),
          TextButton(
            onPressed: _busy ? null : _load,
            child: const Text('Refresh'),
          ),
        ],
        if (_sources == null && _error == null)
          const Center(child: CircularProgressIndicator()),
        if (_sources?.isEmpty == true)
          const Text(
            'No saved Moments yet. New Moments are recorded only on Today.',
          ),
        for (final source in _sources ?? <MomentCheckIn>[])
          ListTile(
            key: ValueKey('moment-source-${source.id}'),
            title: Text(source.state.label),
            subtitle: Text(
              '${source.experiencedDate ?? 'Date unknown'} · ${source.provenance.label}',
            ),
            onTap: _busy || _mutations == null ? null : () => _edit(source),
            trailing: _mutations == null
                ? null
                : IconButton(
                    tooltip: 'Delete saved Moment',
                    onPressed: _busy ? null : () => _delete(source),
                    icon: const Icon(Icons.delete_outline),
                  ),
          ),
      ],
    ),
  );
}

class _MomentSourceEditor extends StatefulWidget {
  const _MomentSourceEditor({
    required this.repository,
    required this.source,
    this.onChanged,
  });
  final CorrectableMomentRepository repository;
  final MomentCheckIn source;
  final VoidCallback? onChanged;
  @override
  State<_MomentSourceEditor> createState() => _MomentSourceEditorState();
}

class _MomentSourceEditorState extends State<_MomentSourceEditor> {
  late MomentCheckInState _state = widget.source.state;
  bool _busy = false, _allowPop = false;
  String? _error;
  Future<void> _leave() async {
    if (_busy) return;
    if (_state != widget.source.state) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Keep editing this Moment?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep editing'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard change'),
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
      await widget.repository.update(
        widget.source.id,
        _state,
        expected: widget.source,
      );
      widget.onChanged?.call();
      if (mounted) {
        setState(() {
          _busy = false;
          _allowPop = true;
        });
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error =
              'This source changed or could not be saved. Your choice is still here. Refresh the source before retrying.';
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
        title: const Text('Saved Moment'),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: _leave,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            '${widget.source.experiencedDate ?? 'Date unknown'} · ${widget.source.provenance.label}',
          ),
          const SizedBox(height: 16),
          const Text(
            'The original date and recording time stay unchanged. A change to an earlier known day is labeled Later recall.',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final state in MomentCheckInState.values)
                ChoiceChip(
                  label: Text(state.label),
                  selected: _state == state,
                  onSelected: _busy
                      ? null
                      : (_) => setState(() => _state = state),
                ),
            ],
          ),
          if (_error != null) Semantics(liveRegion: true, child: Text(_error!)),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Saving privately…' : 'Save correction'),
          ),
        ],
      ),
    ),
  );
}
