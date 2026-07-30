import 'dart:async';

import '../domain/auth_service.dart';

/// Dev adapter that keeps the user in anonymous state. All local features
/// work; server capabilities show an honest "needs account" message.
final class DevAuthService implements AuthService {
  DevAuthService() : _state = const AuthState(status: AuthStatus.anonymous);

  AuthState _state;
  final _controller = StreamController<AuthState>.broadcast();

  @override
  AuthState get current => _state;

  @override
  Stream<AuthState> watch() => _controller.stream;

  @override
  Future<AuthState> signIn({String? email, String? password}) async {
    // Dev adapter: simulate authenticated state.
    _set(
      AuthState(
        status: AuthStatus.authenticated,
        userId: 'dev-user-001',
        email: email ?? 'dev@letter.app',
      ),
    );
    return _state;
  }

  @override
  Future<AuthState> signUp({
    required String email,
    required String password,
  }) async {
    _set(
      AuthState(
        status: AuthStatus.authenticated,
        userId: 'dev-user-001',
        email: email,
      ),
    );
    return _state;
  }

  @override
  Future<void> signOut() async {
    _set(const AuthState(status: AuthStatus.anonymous));
  }

  @override
  Future<void> deleteAccount() async {
    _set(const AuthState(status: AuthStatus.anonymous));
  }

  void _set(AuthState next) {
    _state = next;
    _controller.add(next);
  }

  @override
  Future<void> dispose() async => _controller.close();
}
