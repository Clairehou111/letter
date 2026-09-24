import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// Converts provider and transport failures into stable, privacy-safe copy.
///
/// A transport exception cannot tell us whether the cause is the device,
/// network routing, VPN, DNS, or the provider itself, so user-facing messages
/// must not guess at any one of those causes.
abstract final class AuthErrorMessage {
  static const serviceUnreachable =
      'Letter Within could not reach the sign-in service. '
      'Please try again in a moment.';

  static const requestFailed =
      'Letter Within could not start sign-in. Please try again.';

  static String from(Object error) {
    if (error is TimeoutException) return serviceUnreachable;
    if (error is! supabase.AuthException) return requestFailed;

    final status = error.statusCode;
    final code = error.code?.toLowerCase() ?? '';
    final message = error.message.toLowerCase();
    final networkUnavailable =
        code.contains('network') ||
        code.contains('retryable') ||
        message.contains('clientexception') ||
        message.contains('connection') ||
        message.contains('failed host lookup') ||
        message.contains('handshake') ||
        message.contains('socket') ||
        message.contains('timed out') ||
        message.contains('timeout');
    if (networkUnavailable) return serviceUnreachable;

    final invalidCredentials =
        code == 'invalid_credentials' ||
        message.contains('invalid login credentials');
    if (invalidCredentials) {
      return 'That email or password was not accepted. Check both and try again.';
    }

    final rateLimited =
        status == '429' ||
        code.contains('rate') ||
        message.contains('rate limit') ||
        message.contains('too many requests') ||
        message.contains('email rate');
    if (rateLimited) {
      return 'Too many sign-in emails were requested. '
          'Wait a few minutes and try again.';
    }

    final serverUnavailable =
        (int.tryParse(status ?? '') ?? 0) >= 500 ||
        code == 'unexpected_failure';
    if (serverUnavailable) {
      return "Letter Within's email service is temporarily unavailable. "
          'Please try again in a few minutes.';
    }

    final emailUnavailable =
        message.contains('email provider') ||
        message.contains('invalid email') ||
        (code.contains('email') &&
            (code.contains('disabled') || code.contains('invalid')));
    if (emailUnavailable) {
      return 'That email could not be used for sign-in. '
          'Check it and try again.';
    }

    return requestFailed;
  }
}
