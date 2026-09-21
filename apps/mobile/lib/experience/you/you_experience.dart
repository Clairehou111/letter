import 'package:flutter/material.dart';

import '../../features/auth/domain/auth_service.dart';
import '../../features/local_backup/domain/local_backup_models.dart';
import '../../features/privacy/domain/privacy_preferences.dart';
import '../experience_release_ports.dart';
import '../theme/experience_foundation.dart';

class YouExperience extends StatefulWidget {
  const YouExperience({
    super.key,
    required this.port,
    required this.backupPort,
    this.onOpenPlus,
    this.onOpenReports,
    this.onCycleDataChanged,
    this.now,
  });

  /// Account and privacy operations. Health records never cross this
  /// boundary.
  final YouExperiencePort port;

  /// Encrypted backup workflow: export plus the two-phase import
  /// (prepare preview → explicit commit or discard).
  final BackupExperiencePort backupPort;

  /// Route into Plus (a route, never a tab).
  final VoidCallback? onOpenPlus;

  /// Route into Reports.
  final VoidCallback? onOpenReports;

  /// Fired after a committed import so ring, gravity, and charts refresh
  /// coherently across destinations.
  final VoidCallback? onCycleDataChanged;

  /// Clock seam for the header date (tests).
  final DateTime Function()? now;

  @override
  State<YouExperience> createState() => _YouExperienceState();
}

class _YouExperienceState extends State<YouExperience> {
  late PrivacyPreferences _privacy = widget.port.privacy;
  String? _privacyError;

  static const List<String> _weekdays = <String>[
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
  static const List<String> _months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  DateTime _today() => (widget.now ?? DateTime.now)();

  String _formatDate(DateTime date) {
    return '${_weekdays[date.weekday - 1]}, '
        '${_months[date.month - 1]} ${date.day}';
  }

  /// Persists a privacy change optimistically; failure reverts the control
  /// and shows a textual error — never a haptic.
  Future<void> _savePrivacy(PrivacyPreferences next) async {
    if (next == _privacy) return;
    final previous = _privacy;
    setState(() {
      _privacy = next;
      _privacyError = null;
    });
    try {
      await widget.port.savePrivacy(next);
      await ExperienceHaptics.saved();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _privacy = previous;
        _privacyError = 'That change could not be saved. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          ExperienceSpacing.screenMargin,
          ExperienceSpacing.sm,
          ExperienceSpacing.screenMargin,
          ExperienceSpacing.scrollBottomPadding,
        ),
        children: <Widget>[
          _buildHeader(),
          const SizedBox(height: ExperienceSpacing.lg),
          _AccountSection(port: widget.port),
          const SizedBox(height: ExperienceSpacing.md),
          _buildProtectionCard(),
          const SizedBox(height: ExperienceSpacing.md),
          _BackupSection(
            port: widget.backupPort,
            onDataChanged: widget.onCycleDataChanged,
          ),
          if (widget.onOpenReports != null) ...<Widget>[
            const SizedBox(height: ExperienceSpacing.md),
            _RouteRow(
              title: 'Clinician reports',
              body:
                  'Choose a date range, preview exactly what is included, '
                  'and export a PDF or CSV — always with your say over notes.',
              onTap: widget.onOpenReports!,
            ),
          ],
          if (widget.onOpenPlus != null) ...<Widget>[
            const SizedBox(height: ExperienceSpacing.md),
            _RouteRow(
              title: 'Letter Within Plus',
              body:
                  'Care, safety, tracking, predictions, and backup stay '
                  'free forever. Plus adds personal patterns, long-term '
                  'comparisons, and clinician reports.',
              onTap: widget.onOpenPlus!,
            ),
          ],
          const SizedBox(height: ExperienceSpacing.md),
          _buildAboutCard(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Text(
            'Letter Within',
            style: ExperienceType.title(ExperienceColors.ink),
          ),
        ),
        Text(
          _formatDate(_today()),
          style: ExperienceType.caption(ExperienceColors.inkSoft),
        ),
      ],
    );
  }

  Widget _buildProtectionCard() {
    const divider = Padding(
      padding: EdgeInsets.symmetric(vertical: ExperienceSpacing.xs),
      child: Divider(height: 1, color: ExperienceColors.hairline),
    );
    return _SectionCard(
      title: 'Protection & preferences',
      children: <Widget>[
        _ToggleRow(
          title: 'Screen cover',
          description: _privacy.screenCoverEnabled
              ? 'On — the app switcher shows a blank cover instead of '
                    'your records.'
              : 'Off — your content is visible in the app switcher preview.',
          value: _privacy.screenCoverEnabled,
          onChanged: (value) =>
              _savePrivacy(_privacy.copyWith(screenCoverEnabled: value)),
        ),
        divider,
        _ToggleRow(
          title: 'Gentle cycle check-ins',
          description: _privacy.cycleCheckInEnabled
              ? 'On — one private reminder if the estimated period window '
                    'passes without a new period.'
              : 'Off — no check-in nudges.',
          value: _privacy.cycleCheckInEnabled,
          onChanged: (value) =>
              _savePrivacy(_privacy.copyWith(cycleCheckInEnabled: value)),
        ),
        if (_privacyError != null) ...<Widget>[
          const SizedBox(height: ExperienceSpacing.sm),
          Text(
            _privacyError!,
            style: ExperienceType.caption(ExperienceColors.error),
          ),
        ],
      ],
    );
  }

  Widget _buildAboutCard() {
    return const _SectionCard(
      title: 'About & support',
      children: <Widget>[
        _AboutRow(
          title: 'Local-first',
          body:
              'Everything you record is stored on this device. Nothing '
              'leaves it unless you export a backup or a report yourself.',
        ),
        SizedBox(height: ExperienceSpacing.sm),
        _AboutRow(
          title: 'Honest estimates',
          body:
              'Estimated days are always labeled as estimates, and '
              'missing days are shown as missing — never smoothed over.',
        ),
        SizedBox(height: ExperienceSpacing.sm),
        _AboutRow(
          title: 'If something is not working',
          body:
              'Restarting the app is safe at any point — your records '
              'stay on this device.',
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Account — every auth status rendered as a readable state. Edge states are
// explained as sealed, not lost.
// ---------------------------------------------------------------------------

class _AccountSection extends StatefulWidget {
  const _AccountSection({required this.port});

  final YouExperiencePort port;

  @override
  State<_AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends State<_AccountSection> {
  String? _error;
  bool _busy = false;

  Future<void> _run(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await operation();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'That did not go through. Nothing was changed.';
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Sign out?',
          style: ExperienceType.headline(ExperienceColors.ink),
        ),
        content: Text(
          'Your records on this device close until this account signs in '
          'again. Nothing is deleted, and no other account can read what '
          'is here.',
          style: ExperienceType.body(ExperienceColors.ink),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Stay signed in'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _run(widget.port.signOut);
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Delete server account?',
          style: ExperienceType.headline(ExperienceColors.ink),
        ),
        content: Text(
          'This permanently deletes your Letter Within account on the '
          'server. Records that never left this device remain here, '
          'available offline, until the app itself is deleted.',
          style: ExperienceType.body(ExperienceColors.ink),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep account'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Delete account',
              style: ExperienceType.label(ExperienceColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _run(widget.port.deleteServerAccount);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: widget.port.watchAccount(),
      initialData: widget.port.account,
      builder: (context, snapshot) {
        final auth =
            (snapshot.hasError ? null : snapshot.data) ?? widget.port.account;
        return _SectionCard(
          title: 'Account',
          children: <Widget>[
            ..._statusContent(auth),
            if (_error != null) ...<Widget>[
              const SizedBox(height: ExperienceSpacing.sm),
              Text(
                _error!,
                style: ExperienceType.caption(ExperienceColors.error),
              ),
            ],
          ],
        );
      },
    );
  }

  List<Widget> _statusContent(AuthState auth) {
    switch (auth.status) {
      case AuthStatus.authenticated:
        return <Widget>[
          _statusLine('Signed in', ExperienceColors.phaseOvulation),
          const SizedBox(height: ExperienceSpacing.xs),
          Text(
            auth.email ?? 'This device is connected to your account.',
            style: ExperienceType.bodySmall(ExperienceColors.inkSoft),
          ),
          const SizedBox(height: ExperienceSpacing.xs),
          Text(
            'Your records are stored on this device first.',
            style: ExperienceType.caption(ExperienceColors.inkSoft),
          ),
          const SizedBox(height: ExperienceSpacing.sm),
          Wrap(
            spacing: ExperienceSpacing.sm,
            children: <Widget>[
              TextButton(
                onPressed: _busy ? null : _confirmSignOut,
                child: const Text('Sign out'),
              ),
              TextButton(
                onPressed: _busy ? null : _confirmDeleteAccount,
                child: Text(
                  'Delete server account',
                  style: ExperienceType.label(ExperienceColors.error),
                ),
              ),
            ],
          ),
        ];
      case AuthStatus.offlineOrExpired:
        return <Widget>[
          _statusLine('Signed in — offline', ExperienceColors.accentGravity),
          const SizedBox(height: ExperienceSpacing.xs),
          Text(
            'This session cannot reach the server right now. Everything on '
            'this device stays open — keep recording as usual.',
            style: ExperienceType.bodySmall(ExperienceColors.inkSoft),
          ),
          const SizedBox(height: ExperienceSpacing.sm),
          TextButton(
            onPressed: _busy ? null : _confirmSignOut,
            child: const Text('Sign out'),
          ),
        ];
      case AuthStatus.signedOut:
        return <Widget>[
          _statusLine('No account connected', ExperienceColors.inkFaint),
          const SizedBox(height: ExperienceSpacing.xs),
          Text(
            'Letter Within is local-first: everything you record lives on '
            'this device and works without an account.',
            style: ExperienceType.bodySmall(ExperienceColors.inkSoft),
          ),
        ];
      case AuthStatus.localDataAccountMismatch:
        return <Widget>[
          _statusLine(
            'These records are sealed, not lost',
            ExperienceColors.accentSafety,
          ),
          const SizedBox(height: ExperienceSpacing.xs),
          Text(
            'The records on this device belong to the account that created '
            'them. They stay closed until that account signs in again — '
            'nothing has been deleted.',
            style: ExperienceType.bodySmall(ExperienceColors.inkSoft),
          ),
        ];
      case AuthStatus.localOnlyAfterAccountDeletion:
        return <Widget>[
          _statusLine(
            'Your records stayed on this device',
            ExperienceColors.accentSafety,
          ),
          const SizedBox(height: ExperienceSpacing.xs),
          Text(
            'The server account was deleted. The records that never left '
            'this device remain here until the app itself is deleted.',
            style: ExperienceType.bodySmall(ExperienceColors.inkSoft),
          ),
        ];
    }
  }

  Widget _statusLine(String label, Color dotColor) {
    return Row(
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
        ),
        const SizedBox(width: ExperienceSpacing.xs),
        Expanded(
          child: Text(
            label,
            style: ExperienceType.bodyStrong(ExperienceColors.ink),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Backup & restore — export plus the two-phase import. Copy explains the
// Letter-folder save before the share sheet, passphrase loss, and overwrite
// vs merge consequences in user language.
// ---------------------------------------------------------------------------

class _BackupSection extends StatelessWidget {
  const _BackupSection({required this.port, this.onDataChanged});

  final BackupExperiencePort port;
  final VoidCallback? onDataChanged;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Backup & restore',
      children: <Widget>[
        Text(
          'Your records live on this device. A backup is an encrypted copy '
          'you keep for yourself — protected by a password you choose.',
          style: ExperienceType.body(ExperienceColors.ink),
        ),
        const SizedBox(height: ExperienceSpacing.sm),
        Text(
          'Creating a backup saves it to '
          '${port.localDestinationDescription} first, then opens the share '
          'sheet so you can keep a copy wherever you like.',
          style: ExperienceType.caption(ExperienceColors.inkSoft),
        ),
        const SizedBox(height: ExperienceSpacing.sm),
        _PrimaryButton(
          label: 'Create a backup',
          onPressed: () => showExperienceSheet<void>(
            context,
            child: _BackupExportSheet(port: port),
          ),
        ),
        const SizedBox(height: ExperienceSpacing.sm),
        _SecondaryButton(
          label: 'Restore from a backup',
          onPressed: () => showExperienceSheet<void>(
            context,
            child: _BackupImportSheet(port: port, onDataChanged: onDataChanged),
          ),
        ),
        const SizedBox(height: ExperienceSpacing.sm),
        Text(
          'Restoring always shows you exactly what would change — record '
          'by record — before anything is written.',
          style: ExperienceType.caption(ExperienceColors.inkSoft),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Backup export sheet — entry → working → result (shared / saved-only /
// cancelled / failed with retry).
// ---------------------------------------------------------------------------

enum _ExportStep { entry, working, result }

class _BackupExportSheet extends StatefulWidget {
  const _BackupExportSheet({required this.port});

  final BackupExperiencePort port;

  @override
  State<_BackupExportSheet> createState() => _BackupExportSheetState();
}

class _BackupExportSheetState extends State<_BackupExportSheet> {
  final TextEditingController _passphrase = TextEditingController();

  _ExportStep _step = _ExportStep.entry;
  bool _remember = false;
  bool? _hasStored;
  ExperienceFileReceipt? _receipt;
  String? _failureMessage;
  String? _ackLine;

  @override
  void initState() {
    super.initState();
    widget.port
        .hasStoredPassphrase()
        .then((value) {
          if (mounted) {
            setState(() => _hasStored = value);
          }
        })
        .catchError((_) {});
  }

  @override
  void dispose() {
    _passphrase.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    final passphrase = _passphrase.text;
    if (passphrase.isEmpty || _step == _ExportStep.working) return;
    setState(() {
      _step = _ExportStep.working;
      _failureMessage = null;
      _receipt = null;
      _ackLine = null;
    });
    try {
      final receipt = await widget.port.exportEncrypted(
        passphrase: passphrase,
        rememberPassphrase: _remember,
      );
      String? ack;
      if (receipt.outcome == ExperienceFileOutcome.shared ||
          receipt.outcome == ExperienceFileOutcome.savedOnly) {
        ack = await SavedRhythm.acknowledge(SavedRhythmKind.backup);
      }
      if (!mounted) return;
      setState(() {
        _receipt = receipt;
        _ackLine = ack;
        _step = _ExportStep.result;
      });
    } on LocalBackupException catch (error) {
      if (!mounted) return;
      setState(() {
        _failureMessage = error.userMessage;
        _step = _ExportStep.result;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failureMessage =
            'The backup could not be created. Your records are unchanged.';
        _step = _ExportStep.result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        ExperienceSpacing.screenMargin,
        0,
        ExperienceSpacing.screenMargin,
        ExperienceSpacing.lg,
      ),
      child: switch (_step) {
        _ExportStep.entry => _buildEntry(),
        _ExportStep.working => _buildWorking(),
        _ExportStep.result => _buildResult(),
      },
    );
  }

  Widget _buildEntry() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          'Create an encrypted backup',
          style: ExperienceType.headline(ExperienceColors.ink),
        ),
        const SizedBox(height: ExperienceSpacing.sm),
        Text(
          'Letter Within saves the backup to '
          '${widget.port.localDestinationDescription} first, then opens '
          'the share sheet so you can keep a copy wherever you like.',
          style: ExperienceType.body(ExperienceColors.ink),
        ),
        const SizedBox(height: ExperienceSpacing.sm),
        Text(
          'Choose a password you can keep. If it is lost, no one can open '
          'this backup — not even Letter Within.',
          style: ExperienceType.body(ExperienceColors.ink),
        ),
        const SizedBox(height: ExperienceSpacing.sm),
        TextField(
          controller: _passphrase,
          obscureText: true,
          enableSuggestions: false,
          autocorrect: false,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _export(),
          decoration: InputDecoration(
            labelText: 'Backup password',
            labelStyle: ExperienceType.caption(ExperienceColors.inkSoft),
            filled: true,
            fillColor: ExperienceColors.surface,
            border: const OutlineInputBorder(
              borderRadius: ExperienceRadius.chipRadius,
              borderSide: BorderSide(color: ExperienceColors.hairline),
            ),
            enabledBorder: const OutlineInputBorder(
              borderRadius: ExperienceRadius.chipRadius,
              borderSide: BorderSide(color: ExperienceColors.hairline),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: ExperienceRadius.chipRadius,
              borderSide: BorderSide(color: ExperienceColors.ember),
            ),
          ),
        ),
        if (_hasStored == true) ...<Widget>[
          const SizedBox(height: ExperienceSpacing.xs),
          Text(
            'A backup password is already saved on this device.',
            style: ExperienceType.caption(ExperienceColors.inkSoft),
          ),
        ],
        const SizedBox(height: ExperienceSpacing.xs),
        InkWell(
          borderRadius: ExperienceRadius.chipRadius,
          onTap: () {
            ExperienceHaptics.pick();
            setState(() => _remember = !_remember);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: ExperienceSpacing.xs),
            child: Row(
              children: <Widget>[
                Checkbox(
                  value: _remember,
                  onChanged: (value) {
                    ExperienceHaptics.pick();
                    setState(() => _remember = value ?? false);
                  },
                ),
                Expanded(
                  child: Text(
                    'Remember this password on this device',
                    style: ExperienceType.bodySmall(ExperienceColors.ink),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: ExperienceSpacing.sm),
        _PrimaryButton(
          label: 'Save encrypted backup',
          onPressed: _passphrase.text.isEmpty ? null : _export,
        ),
      ],
    );
  }

  Widget _buildWorking() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ExperienceSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const EmberLoadingIndicator(
            semanticLabel: 'Creating encrypted backup',
          ),
          const SizedBox(height: ExperienceSpacing.sm),
          Text(
            'Encrypting and saving…',
            style: ExperienceType.caption(ExperienceColors.inkSoft),
          ),
        ],
      ),
    );
  }

  Widget _buildResult() {
    if (_failureMessage != null) {
      return _SheetResult(
        title: 'Backup not created',
        body: _failureMessage!,
        bodyColor: ExperienceColors.error,
        primaryLabel: 'Try again',
        onPrimary: () => setState(() {
          _step = _ExportStep.entry;
          _failureMessage = null;
        }),
        secondaryLabel: 'Close',
        onSecondary: () => Navigator.of(context).pop(),
      );
    }
    final receipt = _receipt;
    switch (receipt?.outcome) {
      case ExperienceFileOutcome.shared:
        return _SheetResult(
          title: 'Backup shared',
          body:
              receipt?.message ??
              'Your encrypted backup was saved and shared on your terms.',
          ackLine: _ackLine,
          primaryLabel: 'Done',
          onPrimary: () => Navigator.of(context).pop(),
          showPulse: true,
        );
      case ExperienceFileOutcome.savedOnly:
        return _SheetResult(
          title: 'Saved to your Letter folder',
          body:
              receipt?.message ??
              'Your encrypted backup is in '
                  '${widget.port.localDestinationDescription}.',
          ackLine: _ackLine,
          primaryLabel: 'Done',
          onPrimary: () => Navigator.of(context).pop(),
          showPulse: true,
        );
      case ExperienceFileOutcome.cancelled:
        return _SheetResult(
          title: 'Cancelled',
          body: receipt?.localPath != null
              ? 'The file was saved to '
                    '${widget.port.localDestinationDescription} before the '
                    'share sheet closed. Nothing was shared.'
              : 'Nothing was shared or changed.',
          primaryLabel: 'Close',
          onPrimary: () => Navigator.of(context).pop(),
        );
      case ExperienceFileOutcome.failed:
      case null:
        return _SheetResult(
          title: 'Backup not created',
          body:
              receipt?.message ??
              'The backup could not be created. Your records are unchanged.',
          bodyColor: ExperienceColors.error,
          primaryLabel: 'Try again',
          onPrimary: () => setState(() => _step = _ExportStep.entry),
          secondaryLabel: 'Close',
          onSecondary: () => Navigator.of(context).pop(),
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Backup import sheet — entry (password + policy) → working → per-collection
// and per-record preview → explicit commit or discard. Progress, success,
// cancel, failure, and retry are all surfaced.
// ---------------------------------------------------------------------------

enum _ImportStep { entry, working, preview, committing, result }

class _BackupImportSheet extends StatefulWidget {
  const _BackupImportSheet({required this.port, this.onDataChanged});

  final BackupExperiencePort port;
  final VoidCallback? onDataChanged;

  @override
  State<_BackupImportSheet> createState() => _BackupImportSheetState();
}

class _BackupImportSheetState extends State<_BackupImportSheet> {
  final TextEditingController _passphrase = TextEditingController();

  LocalBackupImportPolicy _policy = LocalBackupImportPolicy.merge;
  _ImportStep _step = _ImportStep.entry;
  String? _notice;
  String? _failureMessage;
  LocalBackupImportPreview? _preview;
  String? _ackLine;
  bool _committed = false;

  @override
  void dispose() {
    // Best-effort release of a staged import the user never committed —
    // covering sheet dismissal by drag or system back.
    if (_preview != null && !_committed) {
      widget.port.discardPreparedImport().catchError((_) {});
    }
    _passphrase.dispose();
    super.dispose();
  }

  Future<void> _prepare() async {
    if (_passphrase.text.isEmpty || _step == _ImportStep.working) return;
    setState(() {
      _step = _ImportStep.working;
      _notice = null;
      _failureMessage = null;
    });
    try {
      // Release any earlier staging before preparing again.
      if (_preview != null && !_committed) {
        try {
          await widget.port.discardPreparedImport();
        } catch (_) {}
        _preview = null;
      }
      final preview = await widget.port.prepareImport(
        passphrase: _passphrase.text,
        policy: _policy,
      );
      if (!mounted) return;
      if (preview == null) {
        // Native file picker cancelled — surfaced quietly, nothing changed.
        setState(() {
          _step = _ImportStep.entry;
          _notice = 'No file was chosen — nothing changed.';
        });
      } else {
        setState(() {
          _preview = preview;
          _step = _ImportStep.preview;
        });
      }
    } on LocalBackupException catch (error) {
      if (!mounted) return;
      setState(() {
        _failureMessage = error.userMessage;
        _step = _ImportStep.result;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failureMessage =
            'The backup could not be read. Your records are unchanged.';
        _step = _ImportStep.result;
      });
    }
  }

  Future<void> _commit() async {
    if (_step == _ImportStep.committing) return;
    setState(() => _step = _ImportStep.committing);
    try {
      await widget.port.commitPreparedImport();
      final ack = await SavedRhythm.acknowledge(SavedRhythmKind.backup);
      if (!mounted) return;
      _committed = true;
      widget.onDataChanged?.call();
      setState(() {
        _ackLine = ack;
        _step = _ImportStep.result;
      });
    } on LocalBackupException catch (error) {
      if (!mounted) return;
      setState(() {
        _failureMessage = error.userMessage;
        _step = _ImportStep.result;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failureMessage =
            'The import could not finish. Your records are unchanged.';
        _step = _ImportStep.result;
      });
    }
  }

  Future<void> _discardAndClose() async {
    if (_preview != null && !_committed) {
      try {
        await widget.port.discardPreparedImport();
      } catch (_) {}
      _preview = null;
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  int get _totalChanges {
    final preview = _preview;
    if (preview == null) return 0;
    return preview.collections.fold<int>(
      0,
      (sum, collection) =>
          sum +
          collection.wouldAdd +
          collection.wouldReplace +
          collection.wouldRemove,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          ExperienceSpacing.screenMargin,
          0,
          ExperienceSpacing.screenMargin,
          ExperienceSpacing.lg,
        ),
        child: switch (_step) {
          _ImportStep.entry => _buildEntry(),
          _ImportStep.working => _buildWorking('Reading your backup…'),
          _ImportStep.preview => _buildPreview(),
          _ImportStep.committing => _buildWorking('Writing your records…'),
          _ImportStep.result => _buildResult(),
        },
      ),
    );
  }

  Widget _buildEntry() {
    return ListView(
      shrinkWrap: true,
      children: <Widget>[
        Text(
          'Restore from a backup',
          style: ExperienceType.headline(ExperienceColors.ink),
        ),
        const SizedBox(height: ExperienceSpacing.sm),
        Text(
          'Enter the password you chose for this backup, pick how to '
          'combine it, then choose your backup file. You will review every '
          'change before anything is written.',
          style: ExperienceType.body(ExperienceColors.ink),
        ),
        const SizedBox(height: ExperienceSpacing.sm),
        TextField(
          controller: _passphrase,
          obscureText: true,
          enableSuggestions: false,
          autocorrect: false,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _prepare(),
          decoration: InputDecoration(
            labelText: 'Backup password',
            labelStyle: ExperienceType.caption(ExperienceColors.inkSoft),
            filled: true,
            fillColor: ExperienceColors.surface,
            border: const OutlineInputBorder(
              borderRadius: ExperienceRadius.chipRadius,
              borderSide: BorderSide(color: ExperienceColors.hairline),
            ),
            enabledBorder: const OutlineInputBorder(
              borderRadius: ExperienceRadius.chipRadius,
              borderSide: BorderSide(color: ExperienceColors.hairline),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: ExperienceRadius.chipRadius,
              borderSide: BorderSide(color: ExperienceColors.ember),
            ),
          ),
        ),
        const SizedBox(height: ExperienceSpacing.sm),
        Semantics(
          container: true,
          explicitChildNodes: true,
          label: 'How to combine the backup with records on this device',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _PolicyOption(
                title: 'Merge',
                description:
                    'Combine the backup with what is on this '
                    'device. Where both have the same record, the newer '
                    'version is kept.',
                selected: _policy == LocalBackupImportPolicy.merge,
                onSelect: () {
                  if (_policy == LocalBackupImportPolicy.merge) return;
                  ExperienceHaptics.pick();
                  setState(() => _policy = LocalBackupImportPolicy.merge);
                },
              ),
              const SizedBox(height: ExperienceSpacing.xs),
              _PolicyOption(
                title: 'Replace',
                description:
                    'Make this device match the backup. Records '
                    'that exist only on this device are removed — the '
                    'preview shows exactly which ones before you decide.',
                selected: _policy == LocalBackupImportPolicy.replace,
                onSelect: () {
                  if (_policy == LocalBackupImportPolicy.replace) return;
                  ExperienceHaptics.pick();
                  setState(() => _policy = LocalBackupImportPolicy.replace);
                },
              ),
            ],
          ),
        ),
        if (_notice != null) ...<Widget>[
          const SizedBox(height: ExperienceSpacing.xs),
          Text(
            _notice!,
            style: ExperienceType.caption(ExperienceColors.inkSoft),
          ),
        ],
        const SizedBox(height: ExperienceSpacing.sm),
        _PrimaryButton(
          label: 'Choose backup file',
          onPressed: _passphrase.text.isEmpty ? null : _prepare,
        ),
      ],
    );
  }

  Widget _buildWorking(String label) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          EmberLoadingIndicator(semanticLabel: label),
          const SizedBox(height: ExperienceSpacing.sm),
          Text(label, style: ExperienceType.caption(ExperienceColors.inkSoft)),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    final preview = _preview!;
    final policyLine = preview.policy == LocalBackupImportPolicy.merge
        ? 'Merging: the backup combines with what is on this device. Where '
              'both have the same record, the newer version is kept.'
        : 'Replacing: this device will match the backup. Records that '
              'exist only here are removed.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Review before anything is written',
          style: ExperienceType.headline(ExperienceColors.ink),
        ),
        const SizedBox(height: ExperienceSpacing.xs),
        Text(
          policyLine,
          style: ExperienceType.caption(ExperienceColors.inkSoft),
        ),
        const SizedBox(height: ExperienceSpacing.sm),
        Expanded(
          child: _totalChanges == 0
              ? Center(
                  child: Text(
                    'This backup matches what is already here — nothing '
                    'would change.',
                    style: ExperienceType.body(ExperienceColors.inkSoft),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  itemCount: preview.collections.length,
                  itemBuilder: (context, index) =>
                      _collectionBlock(preview.collections[index]),
                ),
        ),
        const SizedBox(height: ExperienceSpacing.sm),
        if (_totalChanges == 0)
          _PrimaryButton(label: 'Close', onPressed: _discardAndClose)
        else ...<Widget>[
          Text(
            'Nothing is written until you confirm.',
            style: ExperienceType.caption(ExperienceColors.inkSoft),
          ),
          const SizedBox(height: ExperienceSpacing.sm),
          _PrimaryButton(label: 'Confirm import', onPressed: _commit),
          const SizedBox(height: ExperienceSpacing.xs),
          Center(
            child: TextButton(
              onPressed: _discardAndClose,
              child: const Text('Discard'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildResult() {
    if (_committed) {
      return _SheetResult(
        title: 'Import complete',
        body:
            'Your restored records are written. Today, Cycle, and '
            'Patterns reflect the changes.',
        ackLine: _ackLine,
        primaryLabel: 'Done',
        onPrimary: () => Navigator.of(context).pop(),
        showPulse: true,
      );
    }
    return _SheetResult(
      title: 'Import not finished',
      body:
          _failureMessage ??
          'The import could not finish. Your records are unchanged.',
      bodyColor: ExperienceColors.error,
      primaryLabel: 'Try again',
      onPrimary: () => setState(() {
        _step = _ImportStep.entry;
        _failureMessage = null;
      }),
      secondaryLabel: 'Cancel',
      onSecondary: _discardAndClose,
    );
  }

  Widget _collectionBlock(LocalBackupCollectionPreview collection) {
    final hasCounts =
        collection.wouldAdd > 0 ||
        collection.wouldReplace > 0 ||
        collection.wouldRemove > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: ExperienceSpacing.sm),
      padding: const EdgeInsets.all(ExperienceSpacing.sm),
      decoration: BoxDecoration(
        color: ExperienceColors.surfaceWarm,
        borderRadius: ExperienceRadius.cardRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _humanize(collection.name),
            style: ExperienceType.bodyStrong(ExperienceColors.ink),
          ),
          const SizedBox(height: ExperienceSpacing.xs),
          Text(
            _summaryLine(collection),
            style: ExperienceType.caption(ExperienceColors.inkSoft),
          ),
          if (collection.changes.isEmpty) ...<Widget>[
            const SizedBox(height: ExperienceSpacing.xs),
            Text(
              hasCounts
                  ? 'Individual record detail is not available for this '
                        'collection.'
                  : 'No changes in this collection.',
              style: ExperienceType.caption(ExperienceColors.inkFaint),
            ),
          ] else
            ...collection.changes.map(_changeRow),
        ],
      ),
    );
  }

  String _summaryLine(LocalBackupCollectionPreview collection) {
    final parts = <String>[
      if (collection.wouldAdd > 0) '${collection.wouldAdd} added',
      if (collection.wouldReplace > 0) '${collection.wouldReplace} replaced',
      if (collection.wouldKeepDestination > 0)
        '${collection.wouldKeepDestination} kept',
      if (collection.wouldRemove > 0) '${collection.wouldRemove} removed',
    ];
    return parts.isEmpty ? 'No changes' : parts.join(' · ');
  }

  Widget _changeRow(LocalBackupRecordChange change) {
    return Padding(
      padding: const EdgeInsets.only(top: ExperienceSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _ChangeBadge(kind: change.kind),
          const SizedBox(width: ExperienceSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  change.label,
                  style: ExperienceType.bodySmall(ExperienceColors.ink),
                ),
                if (change.reason != null)
                  Text(
                    change.reason!,
                    style: ExperienceType.caption(ExperienceColors.inkSoft),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _humanize(String collectionName) {
    final spaced = collectionName.replaceAll('_', ' ');
    if (spaced.isEmpty) return spaced;
    return spaced[0].toUpperCase() + spaced.substring(1);
  }
}

/// Single-select import-policy option. The chosen state carries shape +
/// fill + text emphasis, never color alone, and is exposed through
/// `Semantics(checked:)` with a 44-pt minimum touch target.
class _PolicyOption extends StatelessWidget {
  const _PolicyOption({
    required this.title,
    required this.description,
    required this.selected,
    required this.onSelect,
  });

  final String title;
  final String description;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      checked: selected,
      label: '$title. $description',
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: ExperienceRadius.chipRadius,
          onTap: onSelect,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: ExperienceSpacing.minTouchTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: ExperienceSpacing.xs,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? ExperienceColors.ember
                              : ExperienceColors.inkFaint,
                          width: selected ? 6 : 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: ExperienceSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          style: ExperienceType.bodyStrong(
                            ExperienceColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          description,
                          style: ExperienceType.caption(
                            ExperienceColors.inkSoft,
                          ),
                        ),
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

/// Per-record change badge — the action word is always written out, so the
/// kind never relies on color alone.
class _ChangeBadge extends StatelessWidget {
  const _ChangeBadge({required this.kind});

  final LocalBackupRecordChangeKind kind;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (kind) {
      LocalBackupRecordChangeKind.add => (
        'Added',
        ExperienceColors.phaseOvulation,
      ),
      LocalBackupRecordChangeKind.replace => (
        'Replaced',
        ExperienceColors.accentGravity,
      ),
      LocalBackupRecordChangeKind.keep => ('Kept', ExperienceColors.inkFaint),
      LocalBackupRecordChangeKind.remove => ('Removed', ExperienceColors.error),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: ExperienceRadius.chipRadius,
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label, style: ExperienceType.caption(color)),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared sheet result view and small building blocks.
// ---------------------------------------------------------------------------

class _SheetResult extends StatelessWidget {
  const _SheetResult({
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.ackLine,
    this.bodyColor,
    this.showPulse = false,
  });

  final String title;
  final String body;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final String? ackLine;
  final Color? bodyColor;
  final bool showPulse;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (showPulse)
            const SizedBox(
              height: 96,
              child: Center(child: EmberPulse(diameter: 96)),
            ),
          Text(
            title,
            style: ExperienceType.headline(ExperienceColors.ink),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: ExperienceSpacing.sm),
          Text(
            body,
            style: ExperienceType.body(bodyColor ?? ExperienceColors.inkSoft),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: ExperienceSpacing.sm),
          SavedRhythmAckLine(line: ackLine),
          const SizedBox(height: ExperienceSpacing.sm),
          _PrimaryButton(label: primaryLabel, onPressed: onPrimary),
          if (secondaryLabel != null && onSecondary != null) ...<Widget>[
            const SizedBox(height: ExperienceSpacing.xs),
            TextButton(onPressed: onSecondary, child: Text(secondaryLabel!)),
          ],
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ExperienceSpacing.md),
      decoration: BoxDecoration(
        color: ExperienceColors.surface,
        borderRadius: ExperienceRadius.cardRadius,
        border: Border.all(color: ExperienceColors.hairline),
        boxShadow: ExperienceShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: ExperienceType.headline(ExperienceColors.ink)),
          const SizedBox(height: ExperienceSpacing.sm),
          ...children,
        ],
      ),
    );
  }
}

/// A real persisted toggle with visible state — the switch position and the
/// state caption always agree.
class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ExperienceSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: ExperienceType.bodyStrong(ExperienceColors.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: ExperienceType.caption(ExperienceColors.inkSoft),
                ),
              ],
            ),
          ),
          const SizedBox(width: ExperienceSpacing.sm),
          Semantics(
            label: title,
            toggled: value,
            child: Switch(
              value: value,
              onChanged: (next) {
                ExperienceHaptics.pick();
                onChanged(next);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  const _RouteRow({
    required this.title,
    required this.body,
    required this.onTap,
  });

  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      child: Container(
        decoration: BoxDecoration(
          color: ExperienceColors.surface,
          borderRadius: ExperienceRadius.cardRadius,
          border: Border.all(color: ExperienceColors.hairline),
          boxShadow: ExperienceShadows.card,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: ExperienceRadius.cardRadius,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(ExperienceSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          style: ExperienceType.headline(ExperienceColors.ink),
                        ),
                        const SizedBox(height: ExperienceSpacing.xs),
                        Text(
                          body,
                          style: ExperienceType.caption(
                            ExperienceColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: ExperienceSpacing.sm),
                  const Icon(
                    Icons.chevron_right,
                    color: ExperienceColors.inkSoft,
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

class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: ExperienceType.bodyStrong(ExperienceColors.ink)),
        const SizedBox(height: 2),
        Text(body, style: ExperienceType.caption(ExperienceColors.inkSoft)),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: ExperienceSpacing.degreeTarget,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: ExperienceColors.ember,
          foregroundColor: Colors.white,
          disabledBackgroundColor: ExperienceColors.hairline,
          disabledForegroundColor: ExperienceColors.inkFaint,
          shape: const RoundedRectangleBorder(
            borderRadius: ExperienceRadius.chipRadius,
          ),
          textStyle: ExperienceType.label(Colors.white),
        ),
        child: Text(label),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: ExperienceSpacing.degreeTarget,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: ExperienceColors.ink,
          side: const BorderSide(color: ExperienceColors.hairline),
          shape: const RoundedRectangleBorder(
            borderRadius: ExperienceRadius.chipRadius,
          ),
          textStyle: ExperienceType.label(ExperienceColors.ink),
        ),
        child: Text(label),
      ),
    );
  }
}
