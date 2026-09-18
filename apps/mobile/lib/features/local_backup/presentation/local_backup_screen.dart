import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../design_system/letter_theme.dart';
import '../../../design_system/lovable/health_record_kit.dart' as lovable;
import '../../../design_system/lovable/letter_kit.dart' as lovable_kit;
import '../application/local_backup_service.dart';
import '../domain/local_backup_credential_store.dart';
import '../domain/local_backup_file_port.dart';
import '../domain/local_backup_import.dart';
import '../domain/local_backup_models.dart';

class LocalBackupScreen extends StatefulWidget {
  const LocalBackupScreen({
    required this.store,
    required this.filePort,
    this.credentialStore,
    this.onImportCommitted,
    super.key,
    this.service,
  });

  final LocalBackupStore store;
  final LocalBackupFilePort filePort;
  final LocalBackupCredentialStore? credentialStore;
  final LocalBackupService? service;
  final Future<void> Function()? onImportCommitted;

  @override
  State<LocalBackupScreen> createState() => _LocalBackupScreenState();
}

class _LocalBackupScreenState extends State<LocalBackupScreen> {
  late final LocalBackupService _service;
  var _busy = false;
  StagedLocalBackupImport? _staged;
  String? _lastSavedPath;
  bool _hasStoredPassphrase = false;
  bool _exportComplete = false;
  bool _restoreComplete = false;
  String? _actionError;
  Future<void> Function()? _retryAction;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? LocalBackupService();
    _checkStoredPassphrase();
  }

  Future<void> _checkStoredPassphrase() async {
    final store = widget.credentialStore;
    if (store == null) return;
    final has = await store.hasPassphrase();
    if (mounted) setState(() => _hasStoredPassphrase = has);
  }

  @override
  void dispose() {
    _staged?.discard();
    super.dispose();
  }

  // ── Export ───────────────────────────────────────────────────────────

  Future<void> _export() async {
    final passphrase = await _resolveExportPassphrase();
    if (passphrase == null) return;

    await _run(() async {
      final snapshot = await widget.store.captureSnapshot();
      final bytes = await _service.encryptSnapshot(
        snapshot: snapshot,
        passphrase: passphrase,
      );
      final data = Uint8List.fromList(bytes);

      // Always save a local copy first, then open the share sheet.
      final path = await widget.filePort.saveEncryptedBackupLocally(data);
      await widget.filePort.shareEncryptedBackup(data);

      if (mounted) {
        setState(() {
          _lastSavedPath = path;
          _exportComplete = true;
        });
      }
    });
  }

  /// Returns the passphrase, reusing the stored one when available or
  /// collecting (and optionally saving) a new one.
  Future<String?> _resolveExportPassphrase() async {
    final store = widget.credentialStore;

    // If we have a stored passphrase, confirm reuse.
    if (store != null && _hasStoredPassphrase) {
      final stored = await store.readPassphrase();
      if (stored != null && stored.trim().isNotEmpty) {
        final reuse = await _askReuseStoredPassphrase();
        if (reuse == true) return stored;
        // User chose "use a different password" — fall through to ask.
      }
    }

    final passphrase = await _askForPassphrase(
      title: 'Protect this backup',
      confirm: true,
      hint: 'Choose a password for your backup file.',
    );
    if (passphrase == null) return null;

    // Offer to save for next time if we have a credential store.
    if (store != null) {
      final save = await _askSavePassphrase();
      if (save == true) {
        await store.savePassphrase(passphrase);
        if (mounted) setState(() => _hasStoredPassphrase = true);
      }
    }

    return passphrase;
  }

  Future<bool?> _askReuseStoredPassphrase() => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Use saved backup password?'),
      content: const Text(
        'Letter Within can reuse the password you saved from a previous backup. '
        'You can also enter a different password.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Use different password'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Reuse saved password'),
        ),
      ],
    ),
  );

  Future<bool?> _askSavePassphrase() => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Remember this password?'),
      content: const Text(
        'Letter Within can store this password securely on your device so you '
        'don\'t have to re-enter it for future backups. It stays on this '
        'device and is never uploaded or included in the backup file. You '
        'still need to remember or record it for import on another device.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Save password'),
        ),
      ],
    ),
  );

  // ── Import ───────────────────────────────────────────────────────────

  Future<void> _prepareImport(LocalBackupImportPolicy policy) async {
    final package = await widget.filePort.pickEncryptedBackup();
    if (package == null) return;

    final passphrase = await _resolveImportPassphrase();
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

  Future<String?> _resolveImportPassphrase() async {
    final store = widget.credentialStore;

    // If we have a stored passphrase, offer to try it first.
    if (store != null && _hasStoredPassphrase) {
      final stored = await store.readPassphrase();
      if (stored != null && stored.trim().isNotEmpty) {
        final reuse = await _askReuseStoredPassphrase();
        if (reuse == true) return stored;
      }
    }

    return _askForPassphrase(
      title: 'Open encrypted backup',
      confirm: false,
      hint: 'Enter the password used when this backup was created.',
    );
  }

  Future<void> _commitImport() async {
    final staged = _staged;
    if (staged == null) return;
    await _run(() async {
      await staged.commit();
      await widget.onImportCommitted?.call();
      if (!mounted) return;
      setState(() {
        _staged = null;
        _restoreComplete = true;
      });
    });
  }

  Future<void> _discardImport() async {
    await _staged?.discard();
    if (mounted) setState(() => _staged = null);
  }

  Future<void> _forgetStoredPassphrase() async {
    final store = widget.credentialStore;
    if (store == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Forget saved backup password?'),
        content: const Text(
          'You will need to enter the password manually for future backups '
          'and restores. Your existing backup files are not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Forget password'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await store.deletePassphrase();
    if (mounted) {
      setState(() => _hasStoredPassphrase = false);
      _message('Saved backup password removed.');
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _actionError = null;
      _retryAction = action;
    });
    try {
      await action();
    } on LocalBackupException catch (error) {
      if (mounted) setState(() => _actionError = error.userMessage);
    } on Object {
      if (mounted) {
        setState(
          () => _actionError =
              'Letter Within could not complete that backup action. Your data is unchanged.',
        );
      }
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

  void _showHelp() {
    showDialog<void>(
      context: context,
      builder: (context) => const _BackupHelpDialog(),
    );
  }

  void _goBack() {
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  void _dismissExportCompletion() {
    if (mounted) {
      setState(() {
        _lastSavedPath = null;
        _exportComplete = false;
      });
    }
  }

  void _createAnotherBackup() {
    _dismissExportCompletion();
    _export();
  }

  void _retryLastAction() {
    final action = _retryAction;
    if (action != null) _run(action);
  }

  Future<String?> _askForPassphrase({
    required String title,
    required bool confirm,
    String? hint,
  }) => showDialog<String>(
    context: context,
    builder: (context) =>
        _PassphraseDialog(title: title, confirm: confirm, hint: hint),
  );

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final staged = _staged;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: LetterDimensions.maxContentWidth,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PageTopBar(onBack: _goBack, onHelp: _showHelp),
                  const lovable.SectionHeader(
                    eyebrow: 'ENCRYPTED BACKUP',
                    title: 'Keep a copy you control',
                    support:
                        'Create a password-protected backup or restore one you made earlier.',
                  ),
                  if (_actionError case final message?)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: lovable.FailureState(
                        key: const Key('local-backup-failure'),
                        title: 'That backup action did not finish',
                        cause: message,
                        action: lovable.RetryAction(onRetry: _retryLastAction),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        lovable_kit.LetterCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Create a backup',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: LetterSpacing.xs),
                              Text(
                                widget.filePort.exportLocationDescription,
                                style: const TextStyle(
                                  color: LetterColors.muted,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: LetterSpacing.md),
                              FilledButton.icon(
                                key: const Key('local-backup-export'),
                                onPressed: _busy ? null : _export,
                                style: LetterButtonStyles.filled,
                                icon: const Icon(Icons.lock_outline),
                                label: const Text('Create encrypted backup'),
                              ),
                            ],
                          ),
                        ),
                        if (_exportComplete && _lastSavedPath != null) ...[
                          const SizedBox(height: LetterSpacing.sm),
                          _ExportCompletionCard(
                            path: _lastSavedPath!,
                            onDone: _goBack,
                            onCreateAnother: _createAnotherBackup,
                          ),
                        ],
                        const SizedBox(height: LetterSpacing.md),
                        const _BackupPasswordWarning(),
                        if (widget.credentialStore != null) ...[
                          const SizedBox(height: LetterSpacing.md),
                          _PasswordStatusCard(
                            hasStoredPassphrase: _hasStoredPassphrase,
                            onForget: _forgetStoredPassphrase,
                          ),
                        ],
                        const SizedBox(height: LetterSpacing.xl),
                        const Divider(height: 1),
                        const SizedBox(height: LetterSpacing.xl),
                        const Text(
                          'Restore a backup',
                          style: TextStyle(
                            fontFamily: 'Newsreader',
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: LetterColors.ink,
                          ),
                        ),
                        const SizedBox(height: LetterSpacing.xs),
                        const Text(
                          'Choose a policy first. Letter Within then opens the file, asks for its password, and stages a preview before anything changes.',
                          style: TextStyle(
                            color: LetterColors.muted,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: LetterSpacing.md),
                        _RestorePolicyCard(
                          busy: _busy,
                          onMerge: () =>
                              _prepareImport(LocalBackupImportPolicy.merge),
                          onReplace: () =>
                              _prepareImport(LocalBackupImportPolicy.replace),
                        ),
                        if (staged != null) ...[
                          const SizedBox(height: LetterSpacing.md),
                          _ImportPreview(preview: staged.preview),
                          const SizedBox(height: LetterSpacing.md),
                          FilledButton.icon(
                            key: const Key('local-backup-confirm-import'),
                            onPressed: _busy ? null : _commitImport,
                            style: LetterButtonStyles.filled,
                            icon: const Icon(Icons.check),
                            label: Text(
                              staged.preview.policy ==
                                      LocalBackupImportPolicy.replace
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
                        if (_restoreComplete) ...[
                          const SizedBox(height: LetterSpacing.md),
                          _RestoreCompletionCard(onDone: _goBack),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PageTopBar extends StatelessWidget {
  const _PageTopBar({required this.onBack, required this.onHelp});

  final VoidCallback onBack;
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          TextButton.icon(
            key: const Key('local-backup-back'),
            onPressed: onBack,
            style: TextButton.styleFrom(
              minimumSize: const Size(LetterDimensions.tapTarget, 44),
              foregroundColor: LetterColors.ink,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            icon: const Icon(Icons.arrow_back, size: 20),
            label: const Text('Back'),
          ),
          const Spacer(),
          IconButton(
            key: const Key('local-backup-help'),
            tooltip: 'Backup help',
            onPressed: onHelp,
            constraints: const BoxConstraints(
              minWidth: LetterDimensions.tapTarget,
              minHeight: LetterDimensions.tapTarget,
            ),
            icon: const Icon(Icons.help_outline),
          ),
        ],
      ),
    );
  }
}

class _RestorePolicyCard extends StatelessWidget {
  const _RestorePolicyCard({
    required this.busy,
    required this.onMerge,
    required this.onReplace,
  });

  final bool busy;
  final VoidCallback onMerge;
  final VoidCallback onReplace;

  @override
  Widget build(BuildContext context) {
    return lovable_kit.LetterCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Choose how this device should change',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: LetterSpacing.xs),
          const Text(
            'Merge keeps records that only exist here. Replace makes the selected collections match the backup and removes records that are not in it.',
            style: TextStyle(color: LetterColors.muted, height: 1.45),
          ),
          const SizedBox(height: LetterSpacing.md),
          OutlinedButton.icon(
            key: const Key('local-backup-import-merge'),
            onPressed: busy ? null : onMerge,
            style: LetterButtonStyles.outlined,
            icon: const Icon(Icons.merge_type),
            label: const Text('Preview merge'),
          ),
          const SizedBox(height: LetterSpacing.xs),
          OutlinedButton.icon(
            key: const Key('local-backup-import-replace'),
            onPressed: busy ? null : onReplace,
            style: LetterButtonStyles.outlined,
            icon: const Icon(Icons.sync),
            label: const Text('Preview replace'),
          ),
        ],
      ),
    );
  }
}

class _ExportCompletionCard extends StatelessWidget {
  const _ExportCompletionCard({
    required this.path,
    required this.onDone,
    required this.onCreateAnother,
  });

  final String path;
  final VoidCallback onDone;
  final VoidCallback onCreateAnother;

  @override
  Widget build(BuildContext context) {
    return lovable_kit.LetterCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle, color: LetterColors.teal),
              SizedBox(width: LetterSpacing.xs),
              Expanded(
                child: Text(
                  'Encrypted backup created',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: LetterSpacing.xs),
          const Text(
            'Saved in Letter Within’s local letter folder. If you chose another destination, the system copied it there too.',
            style: TextStyle(color: LetterColors.muted, height: 1.45),
          ),
          const SizedBox(height: LetterSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.folder_outlined,
                size: 18,
                color: LetterColors.muted,
              ),
              const SizedBox(width: LetterSpacing.xs),
              Expanded(
                child: SelectableText(
                  path,
                  style: const TextStyle(
                    fontSize: 12,
                    color: LetterColors.muted,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: LetterSpacing.sm),
          Wrap(
            spacing: LetterSpacing.xs,
            runSpacing: LetterSpacing.xs,
            children: [
              TextButton(onPressed: onDone, child: const Text('Done')),
              OutlinedButton(
                onPressed: onCreateAnother,
                style: LetterButtonStyles.outlined,
                child: const Text('Create another'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RestoreCompletionCard extends StatelessWidget {
  const _RestoreCompletionCard({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return lovable_kit.LetterCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: LetterColors.teal),
          const SizedBox(width: LetterSpacing.xs),
          const Expanded(
            child: Text(
              'Encrypted backup restored on this device.',
              style: TextStyle(height: 1.45),
            ),
          ),
          TextButton(onPressed: onDone, child: const Text('Done')),
        ],
      ),
    );
  }
}

class _BackupPasswordWarning extends StatelessWidget {
  const _BackupPasswordWarning();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: LetterColors.amberSoft,
        borderRadius: BorderRadius.circular(LetterRadius.panel),
        border: Border.all(color: LetterColors.amber.withValues(alpha: 0.35)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: LetterColors.amber),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Remember this password. Letter Within cannot reset or recover it. '
              'Saving it on this device will not help when importing on a '
              'new device, so record it in a password manager.',
              style: TextStyle(height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackupHelpDialog extends StatelessWidget {
  const _BackupHelpDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Backup help'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _HelpHeading('Where is my backup?'),
              Text(
                'Letter Within saves a copy in a dedicated letter folder using a '
                'timestamped name such as '
                'letter-backup-2026-08-04-18-49-25-123.letter. The share sheet '
                'uses that same saved file so you can recognize this export.',
                style: TextStyle(height: 1.45),
              ),
              SizedBox(height: LetterSpacing.md),
              _HelpHeading('Do I have to choose another destination?'),
              Text(
                'No. After the local save, the system destination sheet shows '
                'the providers installed on your device. Choose iCloud Drive, '
                'Google Drive, Dropbox, another destination, or cancel. Letter Within '
                'does not send the backup to every provider.',
                style: TextStyle(height: 1.45),
              ),
              SizedBox(height: LetterSpacing.md),
              _HelpHeading('How do I restore it?'),
              Text(
                'Open You → Encrypted backup. Choose Preview merge to '
                'keep this device’s records, or Preview replace to make the '
                'selected collections match the backup. Select the .letter '
                'file, enter the exact password, review the record counts, and '
                'confirm only when the preview is correct.',
                style: TextStyle(height: 1.45),
              ),
              SizedBox(height: LetterSpacing.md),
              _HelpHeading('Password warning'),
              Text(
                'Letter Within cannot recover a forgotten backup password. Write it '
                'down or save it in a password manager before exporting. A '
                'password saved in Letter Within’s secure storage stays on this '
                'device and is never included in the file, so it will not '
                'travel with the backup.',
                style: TextStyle(height: 1.45),
              ),
              SizedBox(height: LetterSpacing.md),
              Text(
                'After moving a backup through email, cloud storage, or a '
                'messaging app, keep the encrypted file private and delete '
                'extra copies when they are no longer needed.',
                style: TextStyle(color: LetterColors.muted, height: 1.45),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: Navigator.of(context).pop,
          child: const Text('Done'),
        ),
      ],
    );
  }
}

class _HelpHeading extends StatelessWidget {
  const _HelpHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontWeight: FontWeight.w800,
      color: LetterColors.ink,
    ),
  );
}

/// Inline card showing whether a backup password is saved.
class _PasswordStatusCard extends StatelessWidget {
  const _PasswordStatusCard({
    required this.hasStoredPassphrase,
    required this.onForget,
  });

  final bool hasStoredPassphrase;
  final VoidCallback onForget;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: LetterColors.tealSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: LetterColors.line),
      ),
      child: Row(
        children: [
          Icon(
            hasStoredPassphrase ? Icons.vpn_key : Icons.vpn_key_off,
            size: 20,
            color: hasStoredPassphrase ? LetterColors.teal : LetterColors.muted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hasStoredPassphrase
                  ? 'Backup password is saved on this device.'
                  : 'No backup password saved. You will be asked each time.',
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          ),
          if (hasStoredPassphrase)
            TextButton(
              onPressed: onForget,
              child: const Text('Forget', style: TextStyle(fontSize: 13)),
            ),
        ],
      ),
    );
  }
}

// ── Passphrase dialog ──────────────────────────────────────────────────

class _PassphraseDialog extends StatefulWidget {
  const _PassphraseDialog({
    required this.title,
    required this.confirm,
    this.hint,
  });

  final String title;
  final bool confirm;
  final String? hint;

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
            widget.hint ??
                (widget.confirm
                    ? 'Letter Within cannot recover this password. Write it down in '
                          'a password manager before continuing.'
                    : 'Enter the exact password used to create this backup. '
                          'Letter Within cannot reset it.'),
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
    return lovable_kit.LetterCard(
      key: const Key('local-backup-preview'),
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
          Text(
            preview.policy == LocalBackupImportPolicy.replace
                ? 'Replace removes device records that are not present in the backup. Matching IDs use the backup record.'
                : 'Merge keeps device-only records. For matching IDs, the newer updated record wins; equal timestamps keep the device record.',
            style: const TextStyle(color: LetterColors.muted, height: 1.45),
          ),
          const SizedBox(height: LetterSpacing.md),
          for (final item in preview.collections) ...[
            _CollectionPreviewTile(item: item),
            if (item != preview.collections.last)
              const SizedBox(height: LetterSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _CollectionPreviewTile extends StatelessWidget {
  const _CollectionPreviewTile({required this.item});

  final LocalBackupCollectionPreview item;

  @override
  Widget build(BuildContext context) {
    final hasChanges =
        item.wouldAdd > 0 || item.wouldReplace > 0 || item.wouldRemove > 0;
    if (!hasChanges && item.changes.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          minTileHeight: LetterDimensions.tapTarget,
          title: Text(
            _collectionSummary(item),
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: LetterColors.ink,
              height: 1.4,
            ),
          ),
          children: [
            if (item.changes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: LetterSpacing.xs),
                child: Column(
                  children: item.changes
                      .map(_changeRow)
                      .toList(growable: false),
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.only(bottom: LetterSpacing.xs),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'No record-level changes.',
                    style: TextStyle(color: LetterColors.muted),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  String _collectionSummary(LocalBackupCollectionPreview item) {
    final counts = <String>[];
    if (item.wouldAdd > 0) counts.add('${item.wouldAdd} added');
    if (item.wouldReplace > 0) counts.add('${item.wouldReplace} replaced');
    if (item.wouldKeepDestination > 0) {
      counts.add('${item.wouldKeepDestination} kept');
    }
    if (item.wouldRemove > 0) counts.add('${item.wouldRemove} removed');
    if (counts.isEmpty) counts.add('No changes');
    return '${_collectionLabel(item.name)} · ${counts.join(' · ')}';
  }

  Widget _changeRow(LocalBackupRecordChange change) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _changeIcon(change.kind),
            size: 14,
            color: _changeColor(change.kind),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: change.label,
                    style: const TextStyle(
                      color: LetterColors.ink,
                      height: 1.35,
                    ),
                  ),
                  if (change.reason != null) ...[
                    const TextSpan(text: ' — '),
                    TextSpan(
                      text: change.reason,
                      style: const TextStyle(
                        color: LetterColors.muted,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  TextSpan(
                    text: ' (${change.actionLabel})',
                    style: TextStyle(
                      color: _changeColor(change.kind),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              style: const TextStyle(fontSize: 12, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  static String _collectionLabel(String name) => switch (name) {
    'periods' => 'Periods',
    'care_records' => 'Care records',
    'care_reflections' => 'Care reflections',
    'cycle_reflections' => 'Cycle reflections',
    'health_records' => 'Confirmed records',
    'capture_notes' => 'Private notes',
    'moment_check_ins' => 'Check-ins',
    _ => name,
  };

  static IconData _changeIcon(LocalBackupRecordChangeKind kind) =>
      switch (kind) {
        LocalBackupRecordChangeKind.add => Icons.add_circle_outline,
        LocalBackupRecordChangeKind.replace => Icons.swap_horiz,
        LocalBackupRecordChangeKind.keep => Icons.check_circle_outline,
        LocalBackupRecordChangeKind.remove => Icons.remove_circle_outline,
      };

  static Color _changeColor(LocalBackupRecordChangeKind kind) => switch (kind) {
    LocalBackupRecordChangeKind.add => LetterColors.teal,
    LocalBackupRecordChangeKind.replace => LetterColors.amber,
    LocalBackupRecordChangeKind.keep => LetterColors.muted,
    LocalBackupRecordChangeKind.remove => LetterColors.coral,
  };
}
