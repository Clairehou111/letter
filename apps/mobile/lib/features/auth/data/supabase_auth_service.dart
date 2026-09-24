import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../domain/auth_service.dart';

final class SupabaseAuthService implements AuthService {
  SupabaseAuthService({
    required supabase.SupabaseClient client,
    required this.redirectUrl,
    FlutterSecureStorage? storage,
  }) : _client = client,
       _storage = storage ?? const FlutterSecureStorage(),
       _state = _fromSession(client.auth.currentSession) {
    _subscription = _client.auth.onAuthStateChange.listen(
      (change) => _enqueueTransition(() => _acceptSession(change.session)),
      onError: (_, _) => _enqueueTransition(_acceptMissingSession),
    );
  }

  static const _priorSignInKey = 'letter.auth.prior-sign-in';
  static const _priorUserIdKey = 'letter.auth.prior-user-id';
  static const _accountDeletedKey = 'letter.auth.account-deleted';
  static const _authRequestTimeout = Duration(seconds: 20);

  final supabase.SupabaseClient _client;
  final FlutterSecureStorage _storage;
  final String redirectUrl;
  final _controller = StreamController<AuthState>.broadcast();
  late final StreamSubscription<supabase.AuthState> _subscription;
  AuthState _state;
  Future<void> _transitionQueue = Future<void>.value();
  bool _disposed = false;

  static AuthState _fromSession(supabase.Session? session) {
    final user = session?.user;
    if (user == null) return const AuthState(status: AuthStatus.signedOut);
    return AuthState(
      status: AuthStatus.authenticated,
      userId: user.id,
      email: user.email,
    );
  }

  @override
  AuthState get current => _state;

  @override
  Stream<AuthState> watch() => _controller.stream;

  @override
  Future<AuthState> initialize() async {
    _enqueueTransition(() async {
      final session = _client.auth.currentSession;
      if (session != null) {
        await _acceptSession(session);
      } else {
        await _acceptMissingSession();
      }
    });
    await _transitionQueue;
    return _state;
  }

  void _enqueueTransition(Future<void> Function() transition) {
    _transitionQueue = _transitionQueue.then((_) => _runTransition(transition));
  }

  Future<void> _runTransition(Future<void> Function() transition) async {
    if (_disposed) return;
    try {
      await transition();
    } on Object {
      // Auth callbacks are fire-and-forget. A provider or storage failure must
      // not become an unhandled future or stop later auth events being handled.
    }
  }

  Future<void> _acceptSession(supabase.Session? session) async {
    if (session == null) {
      await _acceptMissingSession();
      return;
    }
    if (await _readStorage(_accountDeletedKey) == 'true') {
      if (_disposed) return;
      _set(const AuthState(status: AuthStatus.localOnlyAfterAccountDeletion));
      try {
        await _client.auth.signOut(scope: supabase.SignOutScope.local);
      } on Object {
        // The deleted account marker still prevents this stale session from
        // reopening local records as an authenticated account.
      }
      return;
    }
    final localDataOwner = await _readStorage(_priorUserIdKey);
    if (localDataOwner != null && localDataOwner != session.user.id) {
      if (_disposed) return;
      _set(const AuthState(status: AuthStatus.localDataAccountMismatch));
      // End the mismatched provider session as well as closing Letter Within's
      // local gate. A later signed-out event must not make the records visible.
      try {
        await _client.auth.signOut();
      } on Object {
        // The in-app gate is already closed. Remote revocation can be retried
        // by the provider without weakening the local privacy boundary.
      }
      return;
    }

    final ownerStored =
        localDataOwner != null ||
        await _writeStorage(_priorUserIdKey, session.user.id);
    final priorSignInStored = await _writeStorage(_priorSignInKey, 'true');
    if (!ownerStored || !priorSignInStored) {
      if (_disposed) return;
      _set(const AuthState(status: AuthStatus.signedOut));
      return;
    }
    if (_disposed) return;
    _set(_fromSession(session));
  }

  Future<void> _acceptMissingSession() async {
    if (_state.hasLocalDataAccountMismatch) return;
    if (await _readStorage(_accountDeletedKey) == 'true') {
      if (_disposed) return;
      _set(const AuthState(status: AuthStatus.localOnlyAfterAccountDeletion));
      return;
    }
    final signedInBefore = await _readStorage(_priorSignInKey) == 'true';
    final priorUserId = signedInBefore
        ? await _readStorage(_priorUserIdKey)
        : null;
    if (_disposed) return;
    _set(
      AuthState(
        status: signedInBefore
            ? AuthStatus.offlineOrExpired
            : AuthStatus.signedOut,
        userId: _state.userId ?? priorUserId,
        email: _state.email,
      ),
    );
  }

  Future<bool> _writeStorage(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
      return true;
    } on Object {
      // Account ownership is a privacy boundary. Fail closed if it cannot be
      // persisted, otherwise another account could open the same local data.
      return false;
    }
  }

  Future<String?> _readStorage(String key) async {
    try {
      return await _storage.read(key: key);
    } on Object {
      return null;
    }
  }

  void _set(AuthState next) {
    if (_disposed) return;
    _state = next;
    _controller.add(next);
  }

  @override
  Future<void> signInWithApple() async {
    final launched = await _client.auth.signInWithOAuth(
      supabase.OAuthProvider.apple,
      redirectTo: redirectUrl,
    );
    if (!launched) {
      throw const supabase.AuthException('Could not open Apple sign-in.');
    }
  }

  @override
  Future<void> sendMagicLink(String email) {
    final normalized = email.trim();
    if (normalized.isEmpty || !normalized.contains('@')) {
      throw const FormatException('Enter a valid email address.');
    }
    return _client.auth
        .signInWithOtp(
          email: normalized,
          emailRedirectTo: redirectUrl,
          shouldCreateUser: true,
        )
        .timeout(_authRequestTimeout);
  }

  @override
  Future<void> signInWithPassword(String email, String password) async {
    final normalized = email.trim();
    if (normalized.isEmpty || !normalized.contains('@')) {
      throw const FormatException('Enter a valid email address.');
    }
    if (password.isEmpty) {
      throw const FormatException('Enter your password.');
    }
    await _client.auth
        .signInWithPassword(email: normalized, password: password)
        .timeout(_authRequestTimeout);
  }

  @override
  Future<void> signOut() async {
    Object? providerFailure;
    StackTrace? providerStackTrace;
    try {
      await _client.auth.signOut();
    } on Object catch (error, stackTrace) {
      providerFailure = error;
      providerStackTrace = stackTrace;
    } finally {
      // Explicit sign-out is a local privacy boundary first. Even when the
      // provider cannot revoke the remote session, Letter Within must close the local
      // data gate and forget the prior-account marker immediately.
      await _closeLocalGate();
    }
    if (providerFailure != null) {
      Error.throwWithStackTrace(providerFailure, providerStackTrace!);
    }
  }

  @override
  Future<void> deleteAccount() async {
    final session = _client.auth.currentSession;
    if (session == null) {
      throw const supabase.AuthException(
        'Sign in again before deleting the account.',
      );
    }
    final response = await _client.functions.invoke('delete-account');
    if (response.status < 200 || response.status >= 300) {
      throw supabase.AuthException(
        'Account deletion failed (${response.status}).',
      );
    }
    await _writeStorage(_accountDeletedKey, 'true');
    // The server identity is gone, but health records were never uploaded and
    // remain useful on this installation. Clear the invalid provider session
    // while preserving the local owner marker and offline access gate.
    try {
      await _client.auth.signOut(scope: supabase.SignOutScope.local);
    } on Object {
      // The server may have invalidated the token before local sign-out runs.
    }
    if (_disposed) return;
    _set(const AuthState(status: AuthStatus.localOnlyAfterAccountDeletion));
  }

  Future<void> _closeLocalGate() async {
    try {
      await _storage.delete(key: _priorSignInKey);
    } on Object {
      // Local sign-out must still close the in-memory gate if storage fails.
    }
    // Keep the owner marker. Signing out must not allow a different account
    // on the same device to inherit the existing local health database.
    _set(const AuthState(status: AuthStatus.signedOut));
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await _subscription.cancel();
    await _controller.close();
  }
}
