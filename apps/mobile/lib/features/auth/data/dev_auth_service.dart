import 'dart:async';

import '../domain/auth_service.dart';

/// Deterministic account adapter for tests and local UI development.
final class DevAuthService implements AuthService {
  DevAuthService({AuthState? initialState})
    : _state = initialState ?? const AuthState(status: AuthStatus.signedOut);

  AuthState _state;
  final _controller = StreamController<AuthState>.broadcast();

  @override
  AuthState get current => _state;

  @override
  Stream<AuthState> watch() => _controller.stream;

  @override
  Future<AuthState> initialize() async => _state;

  @override
  Future<void> signInWithApple() async {
    _set(
      const AuthState(status: AuthStatus.authenticated, userId: 'dev-user-001'),
    );
  }

  @override
  Future<void> sendMagicLink(String email) async {
    _set(
      AuthState(
        status: AuthStatus.authenticated,
        userId: 'dev-user-001',
        email: email.trim(),
      ),
    );
  }

  @override
  Future<void> signOut() async {
    _set(const AuthState(status: AuthStatus.signedOut));
  }

  @override
  Future<void> deleteAccount() async {
    _set(const AuthState(status: AuthStatus.localOnlyAfterAccountDeletion));
  }

  void expireSession() {
    _set(
      AuthState(
        status: AuthStatus.offlineOrExpired,
        userId: _state.userId,
        email: _state.email,
      ),
    );
  }

  void _set(AuthState next) {
    _state = next;
    _controller.add(next);
  }

  @override
  Future<void> dispose() async => _controller.close();
}
