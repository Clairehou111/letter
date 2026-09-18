import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../design_system/lovable/letter_kit.dart';
import '../../../design_system/letter_theme.dart';
import '../../onboarding/presentation/privacy_protection_screen.dart';
import '../domain/auth_service.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({required this.service, super.key});

  final AuthService service;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _working = false;

  Uri? get _subscriptionManagementUrl => switch (defaultTargetPlatform) {
    TargetPlatform.iOS => Uri.parse(
      'https://apps.apple.com/account/subscriptions',
    ),
    TargetPlatform.android => Uri.parse(
      'https://play.google.com/store/account/subscriptions',
    ),
    _ => null,
  };

  Future<void> _manageSubscription() async {
    final url = _subscriptionManagementUrl;
    if (url == null) return;
    final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      _showError('Subscription settings could not be opened.');
    }
  }

  Future<void> _signOut() async {
    if (_working) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'Your records stay on this device. To open them again, sign back in '
          'with this same Letter Within account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm-sign-out'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || _working) return;
    setState(() => _working = true);
    try {
      await widget.service.signOut();
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } on Object {
      if (mounted) _showError('Letter Within could not sign out. Try again.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Letter Within account?'),
        content: const Text(
          'This permanently deletes the server account used for sign-in and '
          'its Letter Within purchase profile. If you have an active '
          'subscription, Apple or Google billing continues until you cancel '
          'it in your store account. '
          'It does not delete health records stored on this device; they remain '
          'available offline. Export anything you want to keep before deleting '
          'the app, which erases its local records.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          if (_subscriptionManagementUrl != null)
            TextButton(
              key: const Key('delete-manage-subscription'),
              onPressed: _manageSubscription,
              child: const Text('Manage subscription'),
            ),
          FilledButton(
            key: const Key('confirm-delete-account'),
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: LetterColors.safetyRed,
            ),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
    if (confirmed != true || _working) return;
    setState(() => _working = true);
    try {
      await widget.service.deleteAccount();
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } on Object {
      if (mounted) {
        _showError(
          'Letter Within could not delete the account. Reconnect, sign in again, and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.service.current;
    return Scaffold(
      appBar: const PageTopBar(title: 'Account'),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                LetterCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const LetterEyebrow('SIGN-IN'),
                      const SizedBox(height: LetterSpacing.xs),
                      Text(
                        state.hasDeletedServerAccount
                            ? 'Local records only'
                            : state.email ?? 'Apple account',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: LetterSpacing.xs),
                      Text(
                        state.hasDeletedServerAccount
                            ? 'Account deleted. Records that never left this device remain available until you delete the app.'
                            : state.requiresServerReauthentication
                            ? 'Offline or session expired. Your local records are still available.'
                            : 'Signed in. Account and purchase data stay separate from health records.',
                        style: const TextStyle(
                          color: LetterColors.muted,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: LetterSpacing.lg),
                if (!state.hasDeletedServerAccount) ...[
                  OutlinedButton(
                    key: const Key('account-sign-out'),
                    onPressed: _working ? null : _signOut,
                    child: const Text('Sign out'),
                  ),
                  const SizedBox(height: LetterSpacing.md),
                  TextButton(
                    key: const Key('account-delete'),
                    onPressed: _working ? null : _deleteAccount,
                    style: TextButton.styleFrom(
                      foregroundColor: LetterColors.safetyRed,
                    ),
                    child: const Text('Delete account'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
