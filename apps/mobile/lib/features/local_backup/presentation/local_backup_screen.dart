import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../design_system/letter_theme.dart';
import '../application/local_backup_service.dart';
import '../domain/local_backup_file_port.dart';
import '../domain/local_backup_import.dart';
import '../domain/local_backup_models.dart';

class LocalBackupScreen extends StatefulWidget {
  const LocalBackupScreen({
    required this.store,
    required this.filePort,
    super.key,
    this.service,
  });

  final LocalBackupStore store;
  final LocalBackupFilePort filePort;
  final LocalBackupService? service;

  @override
  State<LocalBackupScreen> createState() => _LocalBackupScreenState();
}

class _LocalBackupScreenState extends State<LocalBackupScreen> {
  late final LocalBackupService _service;
  var _busy = false;
  StagedLocalBackupImport? _staged;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? LocalBackupService();
  }

  @override
  void dispose() {
    _staged?.discard();
    super.dispose();
  }

  Future<void> _export() async {
    final passphrase = await _askForPassphrase(
      title: 'Protect this backup',
      confirm: true,
    );
    if (passphrase == null) return;
    await _run(() async {
      final snapshot = await widget.store.captureSnapshot();
      final bytes = await _service.encryptSnapshot(
        snapshot: snapshot,
        passphrase: passphrase,
      );
      await widget.filePort.shareEncryptedBackup(Uint8List.fromList(bytes));
      _message('Encrypted backup is ready to save. Keep its password safely.');
    });
  }

  Future<void> _prepareImport(LocalBackupImportPolicy policy) async {
    final package = await widget.filePort.pickEncryptedBackup();
    if (package == null) return;
    final passphrase = await _askForPassphrase(
      title: 'Open encrypted backup',
      confirm: false,
    );
    if (passphrase == null) return;
    await _run(() async {
      final staged = await _service.prepareImport(
        packageBytes: package,
        passphrase: passphrase,
        policy: policy,
        destination: widget.store,
        stager: widget.store,
      );
      await _staged?.discard();
      if (!mounted) return;
      setState(() => _staged = staged);
    });
  }

  Future<void> _commitImport() async {
    final staged = _staged;
    if (staged == null) return;
    await _run(() async {
      await staged.commit();
      if (!mounted) return;
      setState(() => _staged = null);
      _message('Encrypted backup restored on this device.');
    });
  }

  Future<void> _discardImport() async {
    await _staged?.discard();
    if (mounted) setState(() => _staged = null);
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on LocalBackupException catch (error) {
      _message(error.userMessage);
    } on Object {
      _message(
        'Letter could not complete that backup action. Your data is unchanged.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<String?> _askForPassphrase({
    required String title,
    required bool confirm,
  }) => showDialog<String>(
    context: context,
    builder: (context) => _PassphraseDialog(title: title, confirm: confirm),
  );

  @override
  Widget build(BuildContext context) {
    final staged = _staged;
    return Scaffold(
      appBar: AppBar(title: const Text('Encrypted local backup')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
          children: [
            const LetterEyebrow('On this device'),
            const SizedBox(height: LetterSpacing.sm),
            const Text(
              'Move or recover your saved records',
              style: TextStyle(
                fontFamily: 'Newsreader',
                fontSize: 30,
                height: 1.08,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: LetterSpacing.md),
            const Text(
              'Letter encrypts the package before the operating system shares it. '
              'No backup or password goes to Letter servers. Sealed impulse letters '
              'are intentionally excluded.',
              style: TextStyle(color: LetterColors.muted, height: 1.5),
            ),
            const SizedBox(height: LetterSpacing.xl),
            FilledButton.icon(
              key: const Key('local-backup-export'),
              onPressed: _busy ? null : _export,
              icon: const Icon(Icons.lock_outline),
              label: const Text('Create encrypted backup'),
            ),
            const SizedBox(height: LetterSpacing.xl),
            const LetterEyebrow('Restore a backup'),
            const SizedBox(height: LetterSpacing.sm),
            const Text(
              'Choose how incoming records affect this device. Letter shows a '
              'record-count preview before anything changes.',
              style: TextStyle(color: LetterColors.muted, height: 1.5),
            ),
            const SizedBox(height: LetterSpacing.md),
            OutlinedButton.icon(
              key: const Key('local-backup-import-merge'),
              onPressed: _busy
                  ? null
                  : () => _prepareImport(LocalBackupImportPolicy.merge),
              icon: const Icon(Icons.merge_type),
              label: const Text('Preview merge'),
            ),
            const SizedBox(height: LetterSpacing.sm),
            OutlinedButton.icon(
              key: const Key('local-backup-import-replace'),
              onPressed: _busy
                  ? null
                  : () => _prepareImport(LocalBackupImportPolicy.replace),
              icon: const Icon(Icons.sync),
              label: const Text('Preview replace'),
            ),
            if (staged != null) ...[
              const SizedBox(height: LetterSpacing.xl),
              _ImportPreview(preview: staged.preview),
              const SizedBox(height: LetterSpacing.md),
              FilledButton.icon(
                key: const Key('local-backup-confirm-import'),
                onPressed: _busy ? null : _commitImport,
                icon: const Icon(Icons.check),
                label: Text(
                  staged.preview.policy == LocalBackupImportPolicy.replace
                      ? 'Replace this device with previewed records'
                      : 'Merge previewed records',
                ),
              ),
              TextButton(
                key: const Key('local-backup-discard-import'),
                onPressed: _busy ? null : _discardImport,
                child: const Text('Discard preview'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PassphraseDialog extends StatefulWidget {
  const _PassphraseDialog({required this.title, required this.confirm});

  final String title;
  final bool confirm;

  @override
  State<_PassphraseDialog> createState() => _PassphraseDialogState();
}

class _PassphraseDialogState extends State<_PassphraseDialog> {
  final _first = TextEditingController();
  final _second = TextEditingController();

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    super.dispose();
  }

  void _continue() {
    final value = _first.text;
    if (value.trim().isEmpty || (widget.confirm && value != _second.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.confirm
                ? 'Use matching, non-empty passwords.'
                : 'Use the backup password.',
          ),
        ),
      );
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.confirm
                ? 'Letter cannot recover this password. It is never uploaded.'
                : 'Enter the password used to create this backup.',
          ),
          const SizedBox(height: LetterSpacing.md),
          TextField(
            key: const Key('local-backup-passphrase'),
            controller: _first,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(labelText: 'Backup password'),
          ),
          if (widget.confirm) ...[
            const SizedBox(height: LetterSpacing.sm),
            TextField(
              key: const Key('local-backup-passphrase-confirm'),
              controller: _second,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(labelText: 'Repeat password'),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('local-backup-passphrase-continue'),
          onPressed: _continue,
          child: const Text('Continue'),
        ),
      ],
    );
  }
}

class _ImportPreview extends StatelessWidget {
  const _ImportPreview({required this.preview});

  final LocalBackupImportPreview preview;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('local-backup-preview'),
      padding: const EdgeInsets.all(LetterSpacing.md),
      decoration: BoxDecoration(
        color: LetterColors.surface,
        border: Border.all(color: LetterColors.line),
        borderRadius: BorderRadius.circular(LetterRadius.panel),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            preview.policy == LocalBackupImportPolicy.replace
                ? 'Replace preview'
                : 'Merge preview',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: LetterSpacing.sm),
          for (final item in preview.collections)
            Padding(
              padding: const EdgeInsets.only(bottom: LetterSpacing.xs),
              child: Text(
                '${_label(item.name)}: ${item.wouldAdd} added, '
                '${item.wouldReplace} replaced, ${item.wouldKeepDestination} kept, '
                '${item.wouldRemove} removed.',
                style: const TextStyle(color: LetterColors.muted, height: 1.4),
              ),
            ),
        ],
      ),
    );
  }

  String _label(String name) => switch (name) {
    'periods' => 'Periods',
    'care_records' => 'Care records',
    'care_reflections' => 'Care reflections',
    'health_records' => 'Confirmed records',
    'capture_notes' => 'Private notes',
    _ => name,
  };
}
